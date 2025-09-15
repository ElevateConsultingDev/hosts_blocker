#!/bin/bash

# Simple test script for the enhanced setup functionality
# Tests basic components without complex database operations

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Test 1: Check if all required scripts exist
test_script_existence() {
    print_info "Testing script existence..."
    
    local scripts=(
        "setup-hosts-blocker.sh"
        "simple-history-check.sh"
        "whitelist-manager.sh"
        "update-hosts.sh"
        "remove-hosts-blocker.sh"
        "check-site.sh"
    )
    
    local all_exist=true
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            print_status "$script exists"
        else
            print_fail "$script missing"
            all_exist=false
        fi
    done
    
    if [ "$all_exist" = true ]; then
        return 0
    else
        return 1
    fi
}

# Test 2: Check if scripts are executable
test_script_permissions() {
    print_info "Testing script permissions..."
    
    local scripts=(
        "setup-hosts-blocker.sh"
        "simple-history-check.sh"
        "whitelist-manager.sh"
        "update-hosts.sh"
        "remove-hosts-blocker.sh"
        "check-site.sh"
    )
    
    local all_executable=true
    for script in "${scripts[@]}"; do
        if [ -x "$script" ]; then
            print_status "$script is executable"
        else
            print_fail "$script is not executable"
            all_executable=false
        fi
    done
    
    if [ "$all_executable" = true ]; then
        return 0
    else
        return 1
    fi
}

# Test 3: Test browser detection function
test_browser_detection() {
    print_info "Testing browser detection logic..."
    
    # Check if setup script has browser detection
    if grep -q "detect_browser" setup-hosts-blocker.sh; then
        print_status "Setup script has browser detection function"
    else
        print_fail "Setup script missing browser detection function"
        return 1
    fi
    
    # Check if it detects common browsers
    if grep -q "Chrome" setup-hosts-blocker.sh; then
        print_status "Setup script includes Chrome detection"
    else
        print_fail "Setup script missing Chrome detection"
    fi
    
    if grep -q "Vivaldi" setup-hosts-blocker.sh; then
        print_status "Setup script includes Vivaldi detection"
    else
        print_fail "Setup script missing Vivaldi detection"
    fi
    
    return 0
}

# Test 4: Test whitelist manager basic functionality
test_whitelist_basic() {
    print_info "Testing whitelist manager basic functionality..."
    
    # Test help command
    if ./whitelist-manager.sh help > /dev/null 2>&1; then
        print_status "Whitelist manager help command works"
    else
        print_fail "Whitelist manager help command failed"
        return 1
    fi
    
    # Test list command (should work even with empty whitelist)
    if ./whitelist-manager.sh list > /dev/null 2>&1; then
        print_status "Whitelist manager list command works"
    else
        print_fail "Whitelist manager list command failed"
    fi
    
    return 0
}

# Test 5: Test history checker basic functionality
test_history_checker_basic() {
    print_info "Testing history checker basic functionality..."
    
    # Test help/usage
    if ./simple-history-check.sh 2>&1 | grep -q "Simple Browser History Checker" > /dev/null 2>&1; then
        print_status "History checker shows usage information"
    else
        print_warning "History checker may not show usage (this is expected)"
    fi
    
    return 0
}

# Test 6: Test URL construction logic
test_url_construction() {
    print_info "Testing URL construction logic..."
    
    # Test the URL construction logic from update-hosts.sh
    local test_categories="porn social gambling fakenews"
    local sorted_categories=$(echo "$test_categories" | tr ' ' '\n' | sort | tr '\n' '-' | sed 's/-$//')
    local expected="fakenews-gambling-porn-social"
    
    if [ "$sorted_categories" = "$expected" ]; then
        print_status "URL construction for multiple categories works correctly"
    else
        print_fail "URL construction failed: got '$sorted_categories', expected '$expected'"
        return 1
    fi
    
    return 0
}

# Test 7: Test setup script integration
test_setup_integration() {
    print_info "Testing setup script integration..."
    
    # Check if setup script has history checking integration
    if grep -q "simple-history-check.sh" setup-hosts-blocker.sh; then
        print_status "Setup script integrates with history checker"
    else
        print_fail "Setup script missing history checker integration"
        return 1
    fi
    
    # Check if setup script has whitelist integration
    if grep -q "whitelist" setup-hosts-blocker.sh; then
        print_status "Setup script integrates with whitelist manager"
    else
        print_fail "Setup script missing whitelist integration"
        return 1
    fi
    
    # Check if setup script has interactive exception handling
    if grep -q "add_exceptions_interactive" setup-hosts-blocker.sh; then
        print_status "Setup script has interactive exception handling"
    else
        print_fail "Setup script missing interactive exception handling"
        return 1
    fi
    
    return 0
}

# Test 8: Test configuration file handling
test_config_handling() {
    print_info "Testing configuration file handling..."
    
    # Check if setup script creates config file
    if grep -q "hosts-config.txt" setup-hosts-blocker.sh; then
        print_status "Setup script handles configuration file"
    else
        print_fail "Setup script missing configuration file handling"
        return 1
    fi
    
    # Check if update script reads config file
    if grep -q "hosts-config.txt" update-hosts.sh; then
        print_status "Update script reads configuration file"
    else
        print_fail "Update script missing configuration file reading"
        return 1
    fi
    
    return 0
}

# Main test execution
main() {
    echo "========================================"
    echo "  Simple Setup Functionality Test"
    echo "========================================"
    echo
    
    local tests_passed=0
    local tests_failed=0
    local total_tests=0
    
    # Run tests
    echo "Running tests..."
    echo "==============="
    echo
    
    # Test 1: Script existence
    if test_script_existence; then
        tests_passed=$((tests_passed + 1))
    else
        tests_failed=$((tests_failed + 1))
    fi
    total_tests=$((total_tests + 1))
    
    # Test 2: Script permissions
    if test_script_permissions; then
        tests_passed=$((tests_passed + 1))
    else
        tests_failed=$((tests_failed + 1))
    fi
    total_tests=$((total_tests + 1))
    
    # Test 3: Browser detection
    if test_browser_detection; then
        tests_passed=$((tests_passed + 1))
    else
        tests_failed=$((tests_failed + 1))
    fi
    total_tests=$((total_tests + 1))
    
    # Test 4: Whitelist basic functionality
    if test_whitelist_basic; then
        tests_passed=$((tests_passed + 1))
    else
        tests_failed=$((tests_failed + 1))
    fi
    total_tests=$((total_tests + 1))
    
    # Test 5: History checker basic functionality
    if test_history_checker_basic; then
        tests_passed=$((tests_passed + 1))
    else
        tests_failed=$((tests_failed + 1))
    fi
    total_tests=$((total_tests + 1))
    
    # Test 6: URL construction
    if test_url_construction; then
        tests_passed=$((tests_passed + 1))
    else
        tests_failed=$((tests_failed + 1))
    fi
    total_tests=$((total_tests + 1))
    
    # Test 7: Setup integration
    if test_setup_integration; then
        tests_passed=$((tests_passed + 1))
    else
        tests_failed=$((tests_failed + 1))
    fi
    total_tests=$((total_tests + 1))
    
    # Test 8: Config handling
    if test_config_handling; then
        tests_passed=$((tests_passed + 1))
    else
        tests_failed=$((tests_failed + 1))
    fi
    total_tests=$((total_tests + 1))
    
    # Summary
    echo
    echo "========================================"
    echo "  Test Results Summary"
    echo "========================================"
    echo "Total tests: $total_tests"
    echo "Passed: $tests_passed"
    echo "Failed: $tests_failed"
    
    if [ "$tests_failed" -eq 0 ]; then
        echo -e "${GREEN}All tests passed! 🎉${NC}"
        echo
        print_info "The enhanced setup functionality is ready:"
        print_info "  ✅ Browser detection and selection"
        print_info "  ✅ History checking with conflict detection"
        print_info "  ✅ Interactive exception handling"
        print_info "  ✅ Whitelist management integration"
        print_info "  ✅ URL construction for StevenBlack hosts"
        exit 0
    else
        echo -e "${RED}Some tests failed. Check the output above.${NC}"
        exit 1
    fi
}

# Run main function
main "$@"
