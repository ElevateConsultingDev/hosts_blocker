#!/bin/bash

# Browser History Checker for Hosts Blocker
# Checks browser history against blocking categories to warn about potential conflicts

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_DIR="/tmp/hosts-blocker-history"
HISTORY_FILE="$TEMP_DIR/combined_history.txt"

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

# Function to check if sqlite3 is available
check_sqlite() {
    if ! command -v sqlite3 &> /dev/null; then
        print_error "sqlite3 is not installed. Please install it first:"
        print_info "brew install sqlite3"
        return 1
    fi
    return 0
}

# Function to extract domain from URL
extract_domain() {
    local url="$1"
    # Remove protocol and path, extract domain
    echo "$url" | sed -E 's|^https?://||' | sed -E 's|^www\.||' | sed -E 's|/.*$||' | sed -E 's|:.*$||'
}

# Function to get Vivaldi history
get_vivaldi_history() {
    local vivaldi_history="$HOME/Library/Application Support/Vivaldi/Default/History"
    
    if [ ! -f "$vivaldi_history" ]; then
        print_warning "Vivaldi history not found at: $vivaldi_history"
        return 1
    fi
    
    print_info "Extracting Vivaldi history..."
    
    SQLITE3_OPTS="-noheader -separator '|'" sqlite3 "$vivaldi_history" "
    SELECT 
        url,
        title,
        visit_count,
        datetime(last_visit_time/1000000 + (strftime('%s', '1601-01-01')), 'unixepoch') as visit_time
    FROM urls 
    WHERE visit_count > 0
    ORDER BY visit_count DESC
    LIMIT 1000;
    " > "$TEMP_DIR/vivaldi_history.txt"
    
    if [ -s "$TEMP_DIR/vivaldi_history.txt" ]; then
        print_status "Vivaldi history extracted ($(wc -l < "$TEMP_DIR/vivaldi_history.txt") entries)"
        return 0
    else
        print_warning "No Vivaldi history found or database is locked"
        return 1
    fi
}

# Function to get Chrome history
get_chrome_history() {
    local chrome_history="$HOME/Library/Application Support/Google/Chrome/Default/History"
    
    if [ ! -f "$chrome_history" ]; then
        print_warning "Chrome history not found at: $chrome_history"
        return 1
    fi
    
    print_info "Extracting Chrome history..."
    
    SQLITE3_OPTS="-noheader -separator '|'" sqlite3 "$chrome_history" "
    SELECT 
        url,
        title,
        visit_count,
        datetime(last_visit_time/1000000 + (strftime('%s', '1601-01-01')), 'unixepoch') as visit_time
    FROM urls 
    WHERE visit_count > 0
    ORDER BY visit_count DESC
    LIMIT 1000;
    " > "$TEMP_DIR/chrome_history.txt"
    
    if [ -s "$TEMP_DIR/chrome_history.txt" ]; then
        print_status "Chrome history extracted ($(wc -l < "$TEMP_DIR/chrome_history.txt") entries)"
        return 0
    else
        print_warning "No Chrome history found or database is locked"
        return 1
    fi
}

# Function to combine and process history
process_history() {
    print_info "Processing browser history..."
    
    # Combine all history files
    cat "$TEMP_DIR"/*_history.txt 2>/dev/null > "$HISTORY_FILE"
    
    if [ ! -s "$HISTORY_FILE" ]; then
        print_error "No browser history found"
        return 1
    fi
    
    # Process and aggregate by domain
    print_info "Aggregating visits by domain..."
    
    # Create a temporary file for domain aggregation
    local temp_aggregated=$(mktemp)
    
    # Debug: show first few lines of history file
    print_info "Sample history data:"
    head -3 "$HISTORY_FILE" | while IFS='|' read -r url title visit_count visit_time; do
        echo "  URL: $url"
        echo "  Title: $title"
        echo "  Visits: $visit_count"
        echo "  Time: $visit_time"
        echo "  ---"
    done
    
    while IFS='|' read -r url title visit_count visit_time; do
        if [ -n "$url" ] && [ -n "$visit_count" ] && [ "$visit_count" -gt 0 ]; then
            local domain=$(extract_domain "$url")
            if [ -n "$domain" ] && [ "$domain" != "localhost" ] && [ "$domain" != "127.0.0.1" ]; then
                echo "$domain|$visit_count|$title" >> "$temp_aggregated"
            fi
        fi
    done < "$HISTORY_FILE"
    
    # Aggregate by domain (sum visit counts)
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
    }' "$temp_aggregated" | sort -t'|' -k2 -nr > "$TEMP_DIR/top_domains.txt"
    
    rm "$temp_aggregated"
    
    local total_domains=$(wc -l < "$TEMP_DIR/top_domains.txt")
    print_status "Processed $total_domains unique domains"
}

# Function to check domains against blocking categories
check_against_categories() {
    local categories="$1"
    
    if [ -z "$categories" ]; then
        print_info "No categories selected, showing top 20 most visited sites:"
        echo
        head -20 "$TEMP_DIR/top_domains.txt" | while IFS='|' read -r domain visit_count title; do
            printf "%-30s %8s visits  %s\n" "$domain" "$visit_count" "$title"
        done
        return 0
    fi
    
    print_info "Checking top 20 most visited sites against selected categories: $categories"
    echo
    
    # Download the hosts file to check against
    local temp_hosts=$(mktemp)
    local base_url="https://raw.githubusercontent.com/StevenBlack/hosts/master"
    
    if [ -n "$categories" ]; then
        local sorted_categories=$(echo "$categories" | tr ' ' '\n' | sort | tr '\n' '-' | sed 's/-$//')
        local hosts_url="$base_url/alternates/$sorted_categories/hosts"
    else
        local hosts_url="$base_url/hosts"
    fi
    
    print_info "Downloading hosts file to check against: $hosts_url"
    if curl -s "$hosts_url" -o "$temp_hosts"; then
        print_status "Hosts file downloaded successfully"
    else
        print_error "Failed to download hosts file"
        rm "$temp_hosts"
        return 1
    fi
    
    # Check top 20 domains
    local conflicts=0
    local total_checked=0
    
    echo "Top 20 Most Visited Sites:"
    echo "========================="
    echo
    
    head -20 "$TEMP_DIR/top_domains.txt" | while IFS='|' read -r domain visit_count title; do
        total_checked=$((total_checked + 1))
        
        if grep -q "0\.0\.0\.0 $domain$" "$temp_hosts" 2>/dev/null; then
            echo -e "${RED}❌ BLOCKED${NC}  ${CYAN}$domain${NC}  ${YELLOW}$visit_count visits${NC}  $title"
            conflicts=$((conflicts + 1))
        else
            echo -e "${GREEN}✅ ALLOWED${NC}  ${CYAN}$domain${NC}  ${YELLOW}$visit_count visits${NC}  $title"
        fi
    done
    
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
    echo "Browser History Checker for Hosts Blocker"
    echo "========================================="
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
    echo
    echo "This script will:"
    echo "  1. Extract your browser history from Vivaldi and Chrome"
    echo "  2. Show your top 20 most visited sites"
    echo "  3. Check which ones would be blocked by the selected categories"
    echo "  4. Warn you about potential conflicts"
}

# Function to cleanup
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Main execution
main() {
    # Check dependencies
    if ! check_sqlite; then
        exit 1
    fi
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    
    # Set up cleanup on exit
    trap cleanup EXIT
    
    echo "========================================"
    echo "  Browser History Checker"
    echo "========================================"
    echo
    
    # Extract history from browsers
    local history_found=false
    
    if get_vivaldi_history; then
        history_found=true
    fi
    
    if get_chrome_history; then
        history_found=true
    fi
    
    if [ "$history_found" = false ]; then
        print_error "No browser history found. Make sure you have:"
        print_info "  - Vivaldi or Chrome installed"
        print_info "  - Browsed some websites recently"
        print_info "  - Browser is not currently running (to avoid database locks)"
        exit 1
    fi
    
    # Process history
    if ! process_history; then
        exit 1
    fi
    
    # Check against categories
    check_against_categories "$1"
}

# Run main function
main "$@"
