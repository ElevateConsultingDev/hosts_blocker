#!/bin/bash

# Whitelist Manager for Hosts Blocker
# Allows specific domains to be allowed even if they're in blocked categories

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WHITELIST_FILE="$SCRIPT_DIR/whitelist.txt"
HOSTS_FILE="/etc/hosts"
CONFIG_FILE="$SCRIPT_DIR/hosts-config.txt"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Whitelist Manager for Hosts Blocker"
    echo "==================================="
    echo
    echo "Usage: $0 [command] [domain]"
    echo
    echo "Commands:"
    echo "  add <domain>     - Add domain to whitelist"
    echo "  remove <domain>  - Remove domain from whitelist"
    echo "  list             - Show current whitelist"
    echo "  apply            - Apply whitelist to hosts file"
    echo "  check <domain>   - Check if domain is whitelisted"
    echo "  help             - Show this help"
    echo
    echo "Examples:"
    echo "  $0 add linkedin.com"
    echo "  $0 add github.com"
    echo "  $0 remove facebook.com"
    echo "  $0 list"
    echo "  $0 apply"
    echo "  $0 check linkedin.com"
}

# Function to initialize whitelist file
init_whitelist() {
    if [ ! -f "$WHITELIST_FILE" ]; then
        cat > "$WHITELIST_FILE" << EOF
# Hosts Blocker Whitelist
# Add domains here that should be allowed even if they're in blocked categories
# One domain per line, without http:// or https://
# 
# Examples:
# linkedin.com
# github.com
# stackoverflow.com
EOF
        print_status "Created whitelist file: $WHITELIST_FILE"
    fi
}

# Function to add domain to whitelist
add_domain() {
    local domain="$1"
    
    if [ -z "$domain" ]; then
        print_error "Please provide a domain to add"
        return 1
    fi
    
    # Clean domain (remove http://, https://, www.)
    domain=$(echo "$domain" | sed 's|^https\?://||' | sed 's|^www\.||' | sed 's|/$||')
    
    # Check if domain is already whitelisted
    if grep -q "^$domain$" "$WHITELIST_FILE" 2>/dev/null; then
        print_warning "Domain '$domain' is already in whitelist"
        return 0
    fi
    
    # Add domain to whitelist
    echo "$domain" >> "$WHITELIST_FILE"
    print_status "Added '$domain' to whitelist"
    
    # Apply whitelist immediately
    apply_whitelist
}

# Function to remove domain from whitelist
remove_domain() {
    local domain="$1"
    
    if [ -z "$domain" ]; then
        print_error "Please provide a domain to remove"
        return 1
    fi
    
    # Clean domain
    domain=$(echo "$domain" | sed 's|^https\?://||' | sed 's|^www\.||' | sed 's|/$||')
    
    # Check if domain is in whitelist
    if ! grep -q "^$domain$" "$WHITELIST_FILE" 2>/dev/null; then
        print_warning "Domain '$domain' is not in whitelist"
        return 0
    fi
    
    # Remove domain from whitelist
    sed -i.bak "/^$domain$/d" "$WHITELIST_FILE"
    print_status "Removed '$domain' from whitelist"
    
    # Apply whitelist immediately
    apply_whitelist
}

# Function to list whitelisted domains
list_domains() {
    if [ ! -f "$WHITELIST_FILE" ]; then
        print_warning "Whitelist file does not exist"
        return 1
    fi
    
    local domains=$(grep -v '^#' "$WHITELIST_FILE" | grep -v '^$' | sort)
    
    if [ -z "$domains" ]; then
        print_info "No domains in whitelist"
    else
        print_info "Whitelisted domains:"
        echo "$domains" | while read -r domain; do
            if [ -n "$domain" ]; then
                echo "  - $domain"
            fi
        done
    fi
}

# Function to check if domain is whitelisted
check_domain() {
    local domain="$1"
    
    if [ -z "$domain" ]; then
        print_error "Please provide a domain to check"
        return 1
    fi
    
    # Clean domain
    domain=$(echo "$domain" | sed 's|^https\?://||' | sed 's|^www\.||' | sed 's|/$||')
    
    if grep -q "^$domain$" "$WHITELIST_FILE" 2>/dev/null; then
        print_status "Domain '$domain' is whitelisted"
        return 0
    else
        print_warning "Domain '$domain' is not whitelisted"
        return 1
    fi
}

# Function to apply whitelist to hosts file
apply_whitelist() {
    if [ ! -f "$WHITELIST_FILE" ]; then
        print_warning "Whitelist file does not exist"
        return 1
    fi
    
    if [ ! -f "$HOSTS_FILE" ]; then
        print_error "Hosts file does not exist"
        return 1
    fi
    
    print_info "Applying whitelist to hosts file..."
    
    # Create backup
    cp "$HOSTS_FILE" "$HOSTS_FILE.backup.$(date +%Y%m%d%H%M%S)"
    
    # Get whitelisted domains
    local whitelist_domains=$(grep -v '^#' "$WHITELIST_FILE" | grep -v '^$')
    
    if [ -z "$whitelist_domains" ]; then
        print_info "No domains to whitelist"
        return 0
    fi
    
    # Create temporary hosts file
    local temp_hosts=$(mktemp)
    
    # Process hosts file
    while IFS= read -r line; do
        # Check if line blocks a whitelisted domain
        local should_remove=false
        for domain in $whitelist_domains; do
            if echo "$line" | grep -q "0\.0\.0\.0 $domain$"; then
                should_remove=true
                print_status "Removing block for whitelisted domain: $domain"
                break
            fi
        done
        
        # Add line if not blocking a whitelisted domain
        if [ "$should_remove" = false ]; then
            echo "$line" >> "$temp_hosts"
        fi
    done < "$HOSTS_FILE"
    
    # Replace hosts file
    sudo mv "$temp_hosts" "$HOSTS_FILE"
    
    # Flush DNS cache
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder
    
    print_status "Whitelist applied successfully"
    print_info "DNS cache flushed"
}

# Function to show current status
show_status() {
    echo "Whitelist Status"
    echo "================"
    echo
    
    if [ -f "$WHITELIST_FILE" ]; then
        local count=$(grep -v '^#' "$WHITELIST_FILE" | grep -v '^$' | wc -l)
        print_info "Whitelist file: $WHITELIST_FILE"
        print_info "Whitelisted domains: $count"
        
        if [ "$count" -gt 0 ]; then
            echo
            list_domains
        fi
    else
        print_warning "Whitelist file does not exist"
    fi
}

# Main execution
main() {
    # Initialize whitelist file
    init_whitelist
    
    case "${1:-help}" in
        "add")
            add_domain "$2"
            ;;
        "remove")
            remove_domain "$2"
            ;;
        "list")
            list_domains
            ;;
        "apply")
            apply_whitelist
            ;;
        "check")
            check_domain "$2"
            ;;
        "status")
            show_status
            ;;
        "help"|*)
            show_usage
            ;;
    esac
}

# Run main function
main "$@"
