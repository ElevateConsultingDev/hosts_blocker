#!/bin/bash

# Simple Browser History Checker
# Checks your top visited sites against blocking categories

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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

print_highlight() {
    echo -e "${CYAN}[HIGHLIGHT]${NC} $1"
}

# Function to extract domain from URL
extract_domain() {
    local url="$1"
    echo "$url" | sed -E 's|^https?://||' | sed -E 's|^www\.||' | sed -E 's|/.*$||' | sed -E 's|:.*$||'
}

# Function to get top sites from Chrome
get_chrome_top_sites() {
    local chrome_history="$HOME/Library/Application Support/Google/Chrome/Default/History"
    
    if [ ! -f "$chrome_history" ]; then
        print_warning "Chrome history not found"
        return 1
    fi
    
    print_info "Extracting top sites from Chrome history..."
    
    # Use a temporary file to avoid .sqliterc interference
    local temp_sql=$(mktemp)
    cat > "$temp_sql" << 'EOF'
.mode list
.separator |
SELECT url, title, visit_count 
FROM urls 
WHERE visit_count > 0 
ORDER BY visit_count DESC 
LIMIT 50;
EOF
    
    sqlite3 "$chrome_history" < "$temp_sql" > /tmp/chrome_sites.txt
    rm "$temp_sql"
    
    if [ -s "/tmp/chrome_sites.txt" ]; then
        print_status "Chrome history extracted"
        return 0
    else
        print_warning "No Chrome history found"
        return 1
    fi
}

# Function to process and show top sites
show_top_sites() {
    local categories="$1"
    
    print_info "Processing top visited sites..."
    
    # Create a temporary file for domain aggregation
    local temp_domains=$(mktemp)
    
    # Process each line
    while IFS='|' read -r url title visit_count; do
        if [ -n "$url" ] && [ -n "$visit_count" ] && [ "$visit_count" -gt 0 ]; then
            local domain=$(extract_domain "$url")
            if [ -n "$domain" ] && [ "$domain" != "localhost" ] && [ "$domain" != "127.0.0.1" ]; then
                echo "$domain|$visit_count|$title" >> "$temp_domains"
            fi
        fi
    done < "/tmp/chrome_sites.txt"
    
    # Aggregate by domain
    awk -F'|' '
    {
        domain = $1
        count = $2
        title = $3
        visits[domain] += count
        titles[domain] = title
    }
    END {
        for (domain in visits) {
            print domain "|" visits[domain] "|" titles[domain]
        }
    }' "$temp_domains" | sort -t'|' -k2 -nr > /tmp/top_domains.txt
    
    local total_domains=$(wc -l < /tmp/top_domains.txt)
    print_status "Found $total_domains unique domains"
    
    # Show top 20
    echo
    print_info "Top 20 Most Visited Sites:"
    echo "============================="
    echo
    
    local count=0
    while IFS='|' read -r domain visit_count title && [ $count -lt 20 ]; do
        count=$((count + 1))
        printf "%2d. %-30s %8s visits  %s\n" "$count" "$domain" "$visit_count" "$title"
    done < /tmp/top_domains.txt
    
    # Check against categories if provided
    if [ -n "$categories" ]; then
        echo
        print_info "Checking against selected categories: $categories"
        check_against_categories "$categories"
    fi
    
    # Cleanup
    rm -f "$temp_domains" /tmp/chrome_sites.txt /tmp/top_domains.txt
}

# Function to check against blocking categories
check_against_categories() {
    local categories="$1"
    
    # Download the hosts file to check against
    local temp_hosts=$(mktemp)
    local base_url="https://raw.githubusercontent.com/StevenBlack/hosts/master"
    
    if [ -n "$categories" ]; then
        local sorted_categories=$(echo "$categories" | tr ' ' '\n' | sort | tr '\n' '-' | sed 's/-$//')
        local hosts_url="$base_url/alternates/$sorted_categories/hosts"
    else
        local hosts_url="$base_url/hosts"
    fi
    
    print_info "Downloading hosts file: $hosts_url"
    if ! curl -s "$hosts_url" -o "$temp_hosts"; then
        print_error "Failed to download hosts file"
        rm "$temp_hosts"
        return 1
    fi
    
    print_status "Hosts file downloaded successfully"
    
    # Check top 20 domains
    local conflicts=0
    local total_checked=0
    
    echo
    print_info "Blocking Analysis:"
    echo "==================="
    echo
    
    while IFS='|' read -r domain visit_count title && [ $total_checked -lt 20 ]; do
        total_checked=$((total_checked + 1))
        
        if grep -q "0\.0\.0\.0 $domain$" "$temp_hosts" 2>/dev/null; then
            echo -e "${RED}❌ BLOCKED${NC}  ${CYAN}$domain${NC}  ${YELLOW}$visit_count visits${NC}  $title"
            conflicts=$((conflicts + 1))
        else
            echo -e "${GREEN}✅ ALLOWED${NC}  ${CYAN}$domain${NC}  ${YELLOW}$visit_count visits${NC}  $title"
        fi
    done < /tmp/top_domains.txt
    
    echo
    print_highlight "Summary: $conflicts out of $total_checked top sites would be blocked"
    
    if [ "$conflicts" -gt 0 ]; then
        echo
        print_warning "⚠️  WARNING: Blocking these categories will block $conflicts of your top $total_checked most visited sites!"
        print_info "Consider using the whitelist feature to allow specific sites:"
        print_info "  ./whitelist-manager.sh add <domain>"
    else
        print_status "✅ No conflicts found with your top visited sites"
    fi
    
    rm "$temp_hosts"
}

# Function to show usage
show_usage() {
    echo "Simple Browser History Checker"
    echo "=============================="
    echo
    echo "Usage: $0 [categories]"
    echo
    echo "Arguments:"
    echo "  categories    - Space-separated list of categories to check against"
    echo "                  (e.g., 'porn social gambling fakenews')"
    echo
    echo "Examples:"
    echo "  $0                           # Show top 20 most visited sites"
    echo "  $0 social                    # Check against social media blocking"
    echo "  $0 porn social gambling      # Check against multiple categories"
}

# Main execution
main() {
    echo "========================================"
    echo "  Simple Browser History Checker"
    echo "========================================"
    echo
    
    # Get Chrome history
    if ! get_chrome_top_sites; then
        print_error "Could not extract browser history"
        exit 1
    fi
    
    # Show top sites and check against categories
    show_top_sites "$1"
}

# Run main function
main "$@"
