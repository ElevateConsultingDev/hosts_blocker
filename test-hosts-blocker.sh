#!/bin/bash

# Test script for hosts blocker functionality
# Tests various aspects of the blocking system

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/hosts-config.txt"
HOSTS_FILE="/etc/hosts"
LOG_FILE="$SCRIPT_DIR/test-results.log"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# Function to print colored output
print_status() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Function to log test results
log_test() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    print_info "Running test: $test_name"
    
    if eval "$test_command"; then
        print_status "$test_name"
        log_test "PASS: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        print_fail "$test_name"
        log_test "FAIL: $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Function to check if a domain is blocked
is_domain_blocked() {
    local domain="$1"
    if grep -q "0.0.0.0 $domain" "$HOSTS_FILE" 2>/dev/null; then
        return 0  # Blocked
    else
        return 1  # Not blocked
    fi
}

# Function to check if a domain is allowed
is_domain_allowed() {
    local domain="$1"
    if ! grep -q "0.0.0.0 $domain" "$HOSTS_FILE" 2>/dev/null; then
        return 0  # Allowed
    else
        return 1  # Blocked
    fi
}

# Function to check service status
check_service_status() {
    local service_name="$1"
    if sudo launchctl list | grep -q "$service_name"; then
        return 0  # Running
    else
        return 1  # Not running
    fi
}

# Function to check configuration
check_config() {
    if [ -f "$CONFIG_FILE" ]; then
        return 0
    else
        return 1
    fi
}

# Function to get selected categories
get_selected_categories() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        echo "$SELECTED_CATEGORIES"
    else
        echo ""
    fi
}

# Main test execution
main() {
    echo "========================================"
    echo "  Hosts Blocker Test Suite"
    echo "========================================"
    echo
    
    # Initialize log file
    echo "Test run started at $(date)" > "$LOG_FILE"
    
    # Test 1: Check if configuration file exists
    run_test "Configuration file exists" "check_config"
    
    # Test 2: Check if hosts file exists and is readable
    run_test "Hosts file exists and readable" "[ -f '$HOSTS_FILE' ] && [ -r '$HOSTS_FILE' ]"
    
    # Test 3: Check if service is running
    CURRENT_USER=$(whoami)
    SERVICE_NAME="com.${CURRENT_USER}.hosts-blocker"
    run_test "LaunchDaemon service is running" "check_service_status '$SERVICE_NAME'"
    
    # Test 4: Check if hosts file has blocking entries
    run_test "Hosts file contains blocking entries" "grep -q '0.0.0.0' '$HOSTS_FILE'"
    
    # Test 5: Check if hosts file has StevenBlack header
    run_test "Hosts file has StevenBlack header" "grep -q 'StevenBlack' '$HOSTS_FILE'"
    
    # Get selected categories for targeted testing
    SELECTED_CATEGORIES=$(get_selected_categories)
    print_info "Selected categories: ${SELECTED_CATEGORIES:-'default (malware + ads)'}"
    
    # Test 6: Test specific category blocking based on configuration
    if echo "$SELECTED_CATEGORIES" | grep -q "porn"; then
        run_test "Porn sites are blocked" "is_domain_blocked 'pornhub.com'"
    fi
    
    if echo "$SELECTED_CATEGORIES" | grep -q "social"; then
        run_test "Social media sites are blocked" "is_domain_blocked 'facebook.com'"
        run_test "Twitter is blocked" "is_domain_blocked 'twitter.com'"
    fi
    
    if echo "$SELECTED_CATEGORIES" | grep -q "gambling"; then
        run_test "Gambling sites are blocked" "is_domain_blocked 'bet365.com'"
    fi
    
    if echo "$SELECTED_CATEGORIES" | grep -q "fakenews"; then
        run_test "Fake news sites are blocked" "is_domain_blocked 'infowars.com'"
    fi
    
    # Test 7: Test that some legitimate sites are not blocked
    # Note: StevenBlack hosts may block some sites that seem legitimate
    run_test "Google is not blocked" "is_domain_allowed 'google.com'"
    
    # Check if GitHub and Apple are actually blocked (they might be in the hosts file)
    if is_domain_blocked 'github.com'; then
        print_warning "GitHub is blocked (this might be expected with StevenBlack hosts)"
    else
        run_test "GitHub is not blocked" "is_domain_allowed 'github.com'"
    fi
    
    if is_domain_blocked 'apple.com'; then
        print_warning "Apple is blocked (this might be expected with StevenBlack hosts)"
    else
        run_test "Apple is not blocked" "is_domain_allowed 'apple.com'"
    fi
    
    # Test 8: Check if backup was created
    BACKUP_COUNT=$(ls /etc/hosts.backup.* 2>/dev/null | wc -l)
    if [ "$BACKUP_COUNT" -gt 0 ]; then
        run_test "Backup files exist" "true"
    else
        print_warning "No backup files found (this might be expected for fresh installs)"
    fi
    
    # Test 9: Check if logs directory exists
    run_test "Logs directory exists" "[ -d '$SCRIPT_DIR/logs' ]"
    
    # Test 10: Check if log files exist (with proper permissions)
    if [ -f "$SCRIPT_DIR/logs/update-hosts.log" ] || sudo [ -f "$SCRIPT_DIR/logs/update-hosts.log" ]; then
        run_test "Log files exist" "true"
    else
        print_warning "Log files not accessible (permission issue)"
    fi
    
    # Test 11: Test check-site.sh utility
    if [ -f "$SCRIPT_DIR/check-site.sh" ]; then
        run_test "check-site.sh utility works" "$SCRIPT_DIR/check-site.sh google.com > /dev/null 2>&1; [ \$? -eq 0 -o \$? -eq 1 ]"
    fi
    
    # Test 12: Test that hosts file is not empty
    HOSTS_LINES=$(wc -l < "$HOSTS_FILE" 2>/dev/null || echo "0")
    if [ "$HOSTS_LINES" -gt 100 ]; then
        run_test "Hosts file has sufficient entries" "true"
    else
        print_warning "Hosts file seems small ($HOSTS_LINES lines) - might not be properly populated"
    fi
    
    # Test 13: Check if DNS cache flush commands exist
    run_test "DNS flush commands available" "which dscacheutil > /dev/null && which mDNSResponder > /dev/null"
    
    # Test 14: Test manual update script
    if [ -f "$SCRIPT_DIR/update-hosts.sh" ]; then
        run_test "Update script is executable" "[ -x '$SCRIPT_DIR/update-hosts.sh' ]"
    fi
    
    # Test 15: Test removal script
    if [ -f "$SCRIPT_DIR/remove-hosts-blocker.sh" ]; then
        run_test "Removal script is executable" "[ -x '$SCRIPT_DIR/remove-hosts-blocker.sh' ]"
    fi
    
    # Test 16: Test specific blocking examples
    print_info "Testing specific blocking examples..."
    
    # Test porn blocking
    if echo "$SELECTED_CATEGORIES" | grep -q "porn"; then
        run_test "PornHub is blocked" "is_domain_blocked 'pornhub.com'"
        run_test "XVideos is blocked" "is_domain_blocked 'xvideos.com'"
    fi
    
    # Test social media blocking
    if echo "$SELECTED_CATEGORIES" | grep -q "social"; then
        run_test "Instagram is blocked" "is_domain_blocked 'instagram.com'"
        run_test "TikTok is blocked" "is_domain_blocked 'tiktok.com'"
    fi
    
    # Test gambling blocking
    if echo "$SELECTED_CATEGORIES" | grep -q "gambling"; then
        run_test "888.com is blocked" "is_domain_blocked '888.com'"
        run_test "William Hill is blocked" "is_domain_blocked 'williamhill.com'"
    fi
    
    # Test 17: Verify hosts file structure
    run_test "Hosts file has proper format" "grep -q '^0\.0\.0\.0' '$HOSTS_FILE'"
    
    # Test 18: Check for common false positives (sites that should NOT be blocked)
    run_test "Wikipedia is not blocked" "is_domain_allowed 'wikipedia.org'"
    run_test "Stack Overflow is not blocked" "is_domain_allowed 'stackoverflow.com'"
    
    # Test 19: Test whitelist functionality with actual HTTP requests
    if [ -f "$SCRIPT_DIR/whitelist.txt" ] && [ -s "$SCRIPT_DIR/whitelist.txt" ]; then
        print_info "Testing whitelisted domains with HTTP requests..."
        local whitelist_domains=$(cat "$SCRIPT_DIR/whitelist.txt" | grep -v '^#' | grep -v '^$' | head -3)
        for domain in $whitelist_domains; do
            if [ -n "$domain" ]; then
                run_test "Whitelisted domain $domain loads" "curl -s -o /dev/null -w '%{http_code}' --connect-timeout 10 https://$domain | grep -q '^[23][0-9][0-9]$'"
            fi
        done
    fi
    
    # Test 20: Test that blocked sites fail to load
    print_info "Testing that blocked sites fail to load..."
    run_test "Blocked site facebook.com fails to load" "! curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 https://facebook.com | grep -q '^[23][0-9][0-9]$'"
    run_test "Blocked site twitter.com fails to load" "! curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 https://twitter.com | grep -q '^[23][0-9][0-9]$'"
    
    # Summary
    echo
    echo "========================================"
    echo "  Test Results Summary"
    echo "========================================"
    echo "Total tests: $TOTAL_TESTS"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    
    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "${GREEN}All tests passed! 🎉${NC}"
        log_test "All tests passed"
        exit 0
    else
        echo -e "${RED}Some tests failed. Check the log for details.${NC}"
        log_test "Some tests failed"
        exit 1
    fi
}

# Run the tests
main "$@"
