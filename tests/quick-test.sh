#!/bin/bash

# Quick test script to verify specific sites are blocked/allowed
# Usage: ./quick-test.sh [site1] [site2] [site3] ...

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to check if a domain is blocked
check_domain() {
    local domain="$1"
    if grep -q "0.0.0.0 $domain" /etc/hosts 2>/dev/null; then
        echo -e "${RED}❌ BLOCKED${NC} - $domain"
        return 0
    else
        echo -e "${GREEN}✅ ALLOWED${NC} - $domain"
        return 1
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [site1] [site2] [site3] ..."
    echo
    echo "Examples:"
    echo "  $0 facebook.com google.com"
    echo "  $0 pornhub.com twitter.com instagram.com"
    echo
    echo "Or run without arguments to test common sites:"
    echo "  $0"
}

# Default test sites if no arguments provided
if [ $# -eq 0 ]; then
    echo "Testing common sites..."
    echo "======================"
    
    # Sites that should be blocked (based on current config)
    echo "Sites that should be BLOCKED:"
    check_domain "facebook.com"
    check_domain "twitter.com"
    check_domain "instagram.com"
    check_domain "pornhub.com"
    check_domain "bet365.com"
    
    echo
    echo "Sites that should be ALLOWED:"
    check_domain "google.com"
    check_domain "wikipedia.org"
    check_domain "stackoverflow.com"
    check_domain "github.com"
    check_domain "apple.com"
    
else
    echo "Testing provided sites..."
    echo "========================"
    
    for site in "$@"; do
        check_domain "$site"
    done
fi

echo
echo "Note: Some sites may be blocked by StevenBlack hosts even if they seem legitimate."
echo "This is normal behavior for comprehensive ad/tracking blocking."
