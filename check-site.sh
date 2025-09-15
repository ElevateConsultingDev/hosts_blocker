#!/bin/bash

# Site Checker Utility for Hosts Blocker
# Checks if a specific website will be blocked by the current hosts configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/hosts-config.txt"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_blocked() {
    echo -e "${RED}[BLOCKED]${NC} $1"
}

print_allowed() {
    echo -e "${GREEN}[ALLOWED]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  Hosts Blocker Site Checker${NC}"
    echo -e "${BLUE}================================${NC}"
    echo
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] <domain>"
    echo
    echo "Check if a website will be blocked by the current hosts configuration."
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --verbose  Show detailed information"
    echo "  -c, --config   Show current configuration"
    echo "  -l, --list     List all blocked domains (first 50)"
    echo
    echo "Examples:"
    echo "  $0 facebook.com"
    echo "  $0 -v twitter.com"
    echo "  $0 --config"
    echo "  $0 --list"
    echo
}

# Function to normalize domain
normalize_domain() {
    local domain="$1"
    # Remove protocol if present
    domain="${domain#http://}"
    domain="${domain#https://}"
    # Remove www. prefix
    domain="${domain#www.}"
    # Remove trailing slash
    domain="${domain%/}"
    # Convert to lowercase
    echo "$domain" | tr '[:upper:]' '[:lower:]'
}

# Function to check if domain is blocked
check_domain() {
    local domain="$1"
    local verbose="$2"
    
    # Normalize the domain
    local normalized_domain=$(normalize_domain "$domain")
    
    if [ "$verbose" = "true" ]; then
        echo -e "${CYAN}Checking domain: $normalized_domain${NC}"
        echo
    fi
    
    if grep -q "^0\.0\.0\.0 $normalized_domain$" /etc/hosts; then
        print_blocked "Domain '$normalized_domain' is BLOCKED"
        
        if [ "$verbose" = "true" ]; then
            echo "Blocking entries found:"
            grep "^0\.0\.0\.0 $normalized_domain$" /etc/hosts | while read line; do
                echo "  $line"
            done
        fi
        return 0
    else
        print_allowed "Domain '$normalized_domain' is ALLOWED"
        
        if [ "$verbose" = "true" ]; then
            echo "No blocking entries found in /etc/hosts"
        fi
        return 1
    fi
}

# Function to show current configuration
show_config() {
    print_status "Current Hosts Blocker Configuration:"
    echo
    
    if [ -f "$CONFIG_FILE" ]; then
        echo "Configuration file: $CONFIG_FILE"
        echo "Contents:"
        cat "$CONFIG_FILE" | sed 's/^/  /'
        echo
    else
        print_warning "No configuration file found at $CONFIG_FILE"
        print_warning "Run the setup script first: ./setup-hosts-blocker.sh"
        return 1
    fi
    
    # Show current hosts file info
    local hosts_size=$(wc -l < /etc/hosts)
    local blocked_count=$(grep -c "^0\.0\.0\.0" /etc/hosts 2>/dev/null || echo "0")
    
    echo "Current /etc/hosts file:"
    echo "  Total lines: $hosts_size"
    echo "  Blocked domains: $blocked_count"
    echo
}

# Function to list blocked domains
list_blocked() {
    print_status "Blocked domains (showing first 50):"
    echo
    
    local blocked_domains=$(grep "^0\.0\.0\.0" /etc/hosts | head -50)
    
    if [ -z "$blocked_domains" ]; then
        print_warning "No blocked domains found in /etc/hosts"
        return 1
    fi
    
    echo "$blocked_domains" | while read line; do
        local domain=$(echo "$line" | awk '{print $2}')
        echo "  $domain"
    done
    
    local total_blocked=$(grep -c "^0\.0\.0\.0" /etc/hosts 2>/dev/null || echo "0")
    if [ "$total_blocked" -gt 50 ]; then
        echo "  ... and $((total_blocked - 50)) more domains"
    fi
    echo
}

# Function to test DNS resolution
test_dns() {
    local domain="$1"
    local normalized_domain=$(normalize_domain "$domain")
    
    echo -e "${CYAN}Testing DNS resolution for: $normalized_domain${NC}"
    
    # Try to resolve the domain
    if nslookup "$normalized_domain" >/dev/null 2>&1; then
        local ip=$(nslookup "$normalized_domain" 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}')
        if [ "$ip" = "0.0.0.0" ]; then
            print_blocked "DNS resolves to 0.0.0.0 (BLOCKED)"
        else
            print_allowed "DNS resolves to $ip (ALLOWED)"
        fi
    else
        print_warning "DNS resolution failed"
    fi
    echo
}

# Main function
main() {
    local verbose="false"
    local domain=""
    local show_config_flag="false"
    local list_flag="false"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                verbose="true"
                shift
                ;;
            -c|--config)
                show_config_flag="true"
                shift
                ;;
            -l|--list)
                list_flag="true"
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                if [ -z "$domain" ]; then
                    domain="$1"
                else
                    print_error "Multiple domains specified. Please check one domain at a time."
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    print_header
    
    # Handle special commands
    if [ "$show_config_flag" = "true" ]; then
        show_config
        exit 0
    fi
    
    if [ "$list_flag" = "true" ]; then
        list_blocked
        exit 0
    fi
    
    # Check if domain was provided
    if [ -z "$domain" ]; then
        print_error "No domain specified"
        show_usage
        exit 1
    fi
    
    # Check if running as root for hosts file access
    if [ ! -r "/etc/hosts" ]; then
        print_error "Cannot read /etc/hosts file. Try running with sudo or check permissions."
        exit 1
    fi
    
    # Perform the check
    check_domain "$domain" "$verbose"
    local is_blocked=$?
    
    # Test DNS resolution if verbose
    if [ "$verbose" = "true" ]; then
        test_dns "$domain"
    fi
    
    # Show summary
    echo
    if [ $is_blocked -eq 0 ]; then
        print_status "Summary: $domain will be BLOCKED"
    else
        print_status "Summary: $domain will be ALLOWED"
    fi
}

# Run main function
main "$@"
