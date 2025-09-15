#!/bin/bash

# Smart Whitelist Manager
# Automatically detects and whitelists all necessary subdomains and CDN domains
# for any site added to the whitelist

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WHITELIST_FILE="$PROJECT_ROOT/whitelist.txt"
HOSTS_FILE="/etc/hosts"
TEMP_DIR="/tmp/smart-whitelist-$$"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Function to extract domain from URL
extract_domain() {
    local url="$1"
    echo "$url" | sed -E 's|^https?://||' | sed -E 's|^www\.||' | sed -E 's|/.*$||' | sed -E 's|:.*$||'
}

# Function to discover related domains for a given domain
discover_related_domains() {
    local domain="$1"
    local discovered_domains=()
    
    print_info "Discovering related domains for: $domain"
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    
    # Try to fetch the main page to discover related domains
    local main_url="https://www.$domain"
    local www_url="https://$domain"
    
    # Try both www and non-www versions
    for url in "$main_url" "$www_url"; do
        print_info "Analyzing $url..."
        
        # Fetch the page content (redirect stderr to avoid capturing print statements)
        local content=$(curl -s -L --connect-timeout 10 --max-time 30 "$url" 2>/dev/null)
        
        if [ -n "$content" ]; then
            # Extract domains from various sources
            local domains_found=()
            
            # 1. Extract from href/src attributes
            domains_found+=($(echo "$content" | grep -oE 'href="https?://[^"]*"' | grep -oE 'https?://[^"]*' | sed 's|^https\?://||' | sed 's|/.*$||' | grep -E "^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$" | grep -E "\.$domain$|^$domain$" | sort -u))
            
            # 2. Extract from JavaScript/CSS references
            domains_found+=($(echo "$content" | grep -oE 'src="https?://[^"]*"' | grep -oE 'https?://[^"]*' | sed 's|^https\?://||' | sed 's|/.*$||' | grep -E "^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$" | grep -E "\.$domain$|^$domain$" | sort -u))
            
            # 3. Extract from CSS @import and url() references
            domains_found+=($(echo "$content" | grep -oE '@import[^;]*url\([^)]*\)' | grep -oE 'https?://[^"]*' | sed 's|^https\?://||' | sed 's|/.*$||' | grep -E "^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$" | grep -E "\.$domain$|^$domain$" | sort -u))
            
            # 4. Extract from JavaScript fetch/XMLHttpRequest calls
            domains_found+=($(echo "$content" | grep -oE 'fetch\(["'"'"']https?://[^"'"'"']*["'"'"']' | grep -oE 'https?://[^"]*' | sed 's|^https\?://||' | sed 's|/.*$||' | grep -E "^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$" | grep -E "\.$domain$|^$domain$" | sort -u))
            
            # 5. Look for common CDN patterns
            local cdn_patterns=("static" "media" "cdn" "assets" "img" "images" "js" "css" "api" "www" "app" "m" "mobile")
            for pattern in "${cdn_patterns[@]}"; do
                domains_found+=("$pattern.$domain")
            done
            
            # Add discovered domains to our list
            for found_domain in "${domains_found[@]}"; do
                # Clean and validate domain
                found_domain=$(echo "$found_domain" | tr -d '[]' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
                if [ -n "$found_domain" ] && [[ "$found_domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] && [[ "$found_domain" =~ \.$domain$|^$domain$ ]]; then
                    discovered_domains+=("$found_domain")
                fi
            done
            
            break  # If we got content from one URL, no need to try the other
        fi
    done
    
    # Remove duplicates and sort
    discovered_domains=($(printf '%s\n' "${discovered_domains[@]}" | sort -u))
    
    # Clean up temp directory
    rm -rf "$TEMP_DIR"
    
    # Return discovered domains
    printf '%s\n' "${discovered_domains[@]}"
}

# Function to check if a domain is currently blocked
is_domain_blocked() {
    local domain="$1"
    sudo grep -q "^0\.0\.0\.0 $domain$" "$HOSTS_FILE" 2>/dev/null
}

# Function to add domain to whitelist
add_to_whitelist() {
    local domain="$1"
    
    if ! grep -q "^$domain$" "$WHITELIST_FILE" 2>/dev/null; then
        echo "$domain" >> "$WHITELIST_FILE"
        print_success "Added '$domain' to whitelist"
        return 0
    else
        print_info "Domain '$domain' already in whitelist"
        return 1
    fi
}

# Function to remove blocked domains from hosts file
remove_blocked_domains() {
    local domains=("$@")
    local removed_count=0
    
    print_info "Removing blocked domains from hosts file..."
    
    # Create backup
    sudo cp "$HOSTS_FILE" "$HOSTS_FILE.backup.$(date +%Y%m%d%H%M%S)"
    
    for domain in "${domains[@]}"; do
        if is_domain_blocked "$domain"; then
            print_info "Removing blocked entry for: $domain"
            
            # Remove exact domain matches
            sudo sed -i '' "/^0\.0\.0\.0 $domain$/d" "$HOSTS_FILE"
            
            # Remove subdomain matches
            sudo sed -i '' "/^0\.0\.0\.0 [^ ]*\.$domain$/d" "$HOSTS_FILE"
            
            removed_count=$((removed_count + 1))
        fi
    done
    
    print_success "Removed $removed_count blocked domains"
}

# Function to flush DNS cache
flush_dns() {
    print_info "Flushing DNS cache..."
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder
    print_success "DNS cache flushed"
}

# Function to show help
show_help() {
    echo "Smart Whitelist Manager"
    echo "======================"
    echo
    echo "Usage: $0 [COMMAND] [DOMAIN]"
    echo
    echo "Commands:"
    echo "  add <domain>     - Add domain and discover/whitelist all related domains"
    echo "  remove <domain>  - Remove domain and all related domains from whitelist"
    echo "  list             - List all whitelisted domains"
    echo "  apply            - Apply whitelist to hosts file (remove blocked domains)"
    echo "  discover <domain> - Discover related domains for a domain (dry run)"
    echo "  help             - Show this help message"
    echo
    echo "Examples:"
    echo "  $0 add linkedin.com"
    echo "  $0 add github.com"
    echo "  $0 discover facebook.com"
    echo "  $0 apply"
}

# Function to add a domain with smart discovery
add_domain() {
    local domain="$1"
    
    if [ -z "$domain" ]; then
        print_error "Please provide a domain to add"
        return 1
    fi
    
    # Clean the domain
    domain=$(extract_domain "$domain")
    
    print_info "Adding domain: $domain"
    
    # Add the main domain to whitelist
    add_to_whitelist "$domain"
    
    # Discover related domains
    print_info "Discovering related domains..."
    local related_domains=($(discover_related_domains "$domain"))
    
    if [ ${#related_domains[@]} -gt 0 ]; then
        print_info "Found ${#related_domains[@]} related domains:"
        for related_domain in "${related_domains[@]}"; do
            echo "  - $related_domain"
        done
        
        # Add related domains to whitelist
        for related_domain in "${related_domains[@]}"; do
            add_to_whitelist "$related_domain"
        done
    else
        print_warning "No related domains discovered"
    fi
    
    # Apply the whitelist
    print_info "Applying whitelist..."
    local all_domains=("$domain" "${related_domains[@]}")
    remove_blocked_domains "${all_domains[@]}"
    
    # Flush DNS cache
    flush_dns
    
    print_success "Domain '$domain' and related domains added successfully!"
}

# Function to discover domains (dry run)
discover_domains() {
    local domain="$1"
    
    if [ -z "$domain" ]; then
        print_error "Please provide a domain to discover"
        return 1
    fi
    
    # Clean the domain
    domain=$(extract_domain "$domain")
    
    print_info "Discovering related domains for: $domain"
    local related_domains=($(discover_related_domains "$domain"))
    
    if [ ${#related_domains[@]} -gt 0 ]; then
        print_info "Found ${#related_domains[@]} related domains:"
        for related_domain in "${related_domains[@]}"; do
            echo "  - $related_domain"
        done
    else
        print_warning "No related domains discovered"
    fi
}

# Function to apply whitelist
apply_whitelist() {
    print_info "Applying whitelist to hosts file..."
    
    # Get all whitelisted domains
    local whitelist_domains=($(grep -v '^#' "$WHITELIST_FILE" | grep -v '^$'))
    
    if [ ${#whitelist_domains[@]} -eq 0 ]; then
        print_warning "No domains in whitelist"
        return 0
    fi
    
    print_info "Found ${#whitelist_domains[@]} whitelisted domains"
    
    # Remove blocked domains
    remove_blocked_domains "${whitelist_domains[@]}"
    
    # Flush DNS cache
    flush_dns
    
    print_success "Whitelist applied successfully!"
}

# Function to list whitelisted domains
list_domains() {
    print_info "Whitelisted domains:"
    echo "===================="
    
    if [ -f "$WHITELIST_FILE" ]; then
        local domains=($(grep -v '^#' "$WHITELIST_FILE" | grep -v '^$'))
        if [ ${#domains[@]} -gt 0 ]; then
            for domain in "${domains[@]}"; do
                echo "  - $domain"
            done
            echo
            print_info "Total: ${#domains[@]} domains"
        else
            print_warning "No domains in whitelist"
        fi
    else
        print_warning "Whitelist file not found"
    fi
}

# Main execution
main() {
    case "$1" in
        "add")
            add_domain "$2"
            ;;
        "discover")
            discover_domains "$2"
            ;;
        "apply")
            apply_whitelist
            ;;
        "list")
            list_domains
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
