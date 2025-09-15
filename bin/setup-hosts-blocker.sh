#!/bin/bash

# Hosts Blocker Setup Script
# Sets up automated hosts file blocking using StevenBlack hosts repository

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CURRENT_USER=$(whoami)
PLIST_LABEL="com.${CURRENT_USER}.hosts-blocker"

# Choose between LaunchAgent (user) or LaunchDaemon (system)
# LaunchDaemon is more reliable for system-wide services
PLIST_FILE="/Library/LaunchDaemons/$PLIST_LABEL.plist"
CONFIG_FILE="$PROJECT_ROOT/hosts-config.txt"

# Available categories from StevenBlack hosts
# Using arrays instead of associative arrays for better compatibility
CATEGORY_KEYS=("porn" "social" "gambling" "fakenews")
CATEGORY_DESCRIPTIONS=(
    "Pornography and adult content"
    "Social media platforms" 
    "Gambling and betting sites"
    "Fake news and misinformation"
)

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

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  Hosts Blocker Setup Script${NC}"
    echo -e "${BLUE}================================${NC}"
    echo
}

# Function to check if running on macOS
check_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_error "This script is designed for macOS only"
        exit 1
    fi
}

# Function to check for required tools
check_dependencies() {
    print_status "Checking dependencies..."
    
    if ! command -v curl &> /dev/null; then
        print_error "curl is required but not installed"
        exit 1
    fi
    
    if ! command -v launchctl &> /dev/null; then
        print_error "launchctl is required but not found"
        exit 1
    fi
    
    print_status "All dependencies found"
}

# Function to display available categories
show_categories() {
    echo
    echo "Available blocking categories:"
    echo "=============================="
    echo "  p - Pornography and adult content"
    echo "  s - Social media platforms"
    echo "  g - Gambling and betting sites"
    echo "  f - Fake news and misinformation"
    echo "  a - All categories (p + s + g + f)"
    echo "  d - Default (malware and ads only)"
    echo
}

# Function to detect and select browser
detect_browser() {
    # Detect available browsers
    local available_browsers=()
    local browser_paths=()
    
    # Check for common browsers
    if [ -d "$HOME/Library/Application Support/Google/Chrome" ]; then
        available_browsers+=("Chrome")
        browser_paths+=("$HOME/Library/Application Support/Google/Chrome/Default/History")
    fi
    
    if [ -d "$HOME/Library/Application Support/Vivaldi" ]; then
        available_browsers+=("Vivaldi")
        browser_paths+=("$HOME/Library/Application Support/Vivaldi/Default/History")
    fi
    
    if [ -d "$HOME/Library/Application Support/Firefox" ]; then
        available_browsers+=("Firefox")
        browser_paths+=("$HOME/Library/Application Support/Firefox/Profiles")
    fi
    
    if [ -d "$HOME/Library/Application Support/Safari" ]; then
        available_browsers+=("Safari")
        browser_paths+=("$HOME/Library/Application Support/Safari/History.db")
    fi
    
    if [ -d "$HOME/Library/Application Support/Microsoft Edge" ]; then
        available_browsers+=("Edge")
        browser_paths+=("$HOME/Library/Application Support/Microsoft Edge/Default/History")
    fi
    
    if [ ${#available_browsers[@]} -eq 0 ]; then
        return 1
    fi
    
    # Auto-select the first browser if only one is found
    if [ ${#available_browsers[@]} -eq 1 ]; then
        local selected_browser="${available_browsers[0]}"
        local selected_path="${browser_paths[0]}"
        echo "$selected_browser|$selected_path"
        return 0
    fi
    
    # If multiple browsers, show selection
    echo "Multiple browsers detected:"
    for i in "${!available_browsers[@]}"; do
        echo "  $((i+1)). ${available_browsers[$i]}"
    done
    echo "  $(( ${#available_browsers[@]} + 1 )). Skip history checking"
    echo
    
    # Use a simple selection without infinite loop
    read -p "Select browser (1-$(( ${#available_browsers[@]} + 1 ))): " -r choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le $(( ${#available_browsers[@]} + 1 )) ]; then
        if [ "$choice" -eq $(( ${#available_browsers[@]} + 1 )) ]; then
            return 1
        else
            local selected_browser="${available_browsers[$((choice-1))]}"
            local selected_path="${browser_paths[$((choice-1))]}"
            echo "$selected_browser|$selected_path"
            return 0
        fi
    else
        return 1
    fi
}

# Function to get user's category selection
get_category_selection() {
    read -p "Categories: " -r choice
    
    # Convert single letters to full category names
    local selected_categories=""
    
    if [ -z "$choice" ] || [ "$choice" = "d" ]; then
        selected_categories=""
    elif [ "$choice" = "a" ]; then
        selected_categories="porn social gambling fakenews"
    else
        # Parse individual letters
        for (( i=0; i<${#choice}; i++ )); do
            local letter="${choice:$i:1}"
            case "$letter" in
                "p")
                    selected_categories="$selected_categories porn"
                    ;;
                "s")
                    selected_categories="$selected_categories social"
                    ;;
                "g")
                    selected_categories="$selected_categories gambling"
                    ;;
                "f")
                    selected_categories="$selected_categories fakenews"
                    ;;
                *)
                    print_error "Invalid choice: $letter"
                    print_error "Valid choices: p, s, g, f, a, d"
                    exit 1
                    ;;
            esac
        done
        
        # Remove leading space
        selected_categories="${selected_categories# }"
    fi
    
    # Return the selected categories
    echo "$selected_categories"
}

# Function to add exceptions interactively
add_exceptions_interactive() {
    local categories="$1"
    
    echo
    print_status "Interactive Exception Setup"
    echo "=============================="
    echo
    echo "You can add sites to the whitelist so they won't be blocked."
    echo "These sites will remain accessible even with the selected categories."
    echo
    echo "Press Enter with no input when you're done adding exceptions."
    echo
    
    # Initialize whitelist file
    if [ ! -f "$PROJECT_ROOT/whitelist.txt" ]; then
        cat > "$PROJECT_ROOT/whitelist.txt" << EOF
# Hosts Blocker Whitelist
# Add domains here that should be allowed even if they're in blocked categories
# One domain per line, without http:// or https://
# 
# Examples:
# linkedin.com
# github.com
# stackoverflow.com
EOF
        print_status "Created whitelist file"
    fi
    
    while true; do
        echo
        echo "Sites that would be blocked with categories: $categories"
        echo "--------------------------------------------------------"
        
        # Show what would be blocked
        local temp_hosts=$(mktemp)
        local base_url="https://raw.githubusercontent.com/StevenBlack/hosts/master"
        local sorted_categories=$(echo "$categories" | tr ' ' '\n' | sort | tr '\n' '-' | sed 's/-$//')
        local hosts_url="$base_url/alternates/$sorted_categories/hosts"
        
        if curl -s "$hosts_url" -o "$temp_hosts" 2>/dev/null; then
            # Get top sites from history
            local temp_sites=$(mktemp)
            if [ -f "$HOME/Library/Application Support/Google/Chrome/Default/History" ]; then
                sqlite3 -noheader -separator '|' "$HOME/Library/Application Support/Google/Chrome/Default/History" "
                SELECT url, title, visit_count 
                FROM urls 
                WHERE visit_count > 0 
                ORDER BY visit_count DESC 
                LIMIT 20;
                " > "$temp_sites" 2>/dev/null
                
                echo "Top sites that would be blocked:"
                local count=0
                while IFS='|' read -r url title visit_count && [ $count -lt 10 ]; do
                    if [ -n "$url" ] && [ -n "$visit_count" ]; then
                        local domain=$(echo "$url" | sed -E 's|^https?://||' | sed -E 's|^www\.||' | sed -E 's|/.*$||' | sed -E 's|:.*$||')
                        if [ -n "$domain" ] && grep -q "0\.0\.0\.0 $domain$" "$temp_hosts" 2>/dev/null; then
                            count=$((count + 1))
                            echo "  $count. $domain ($visit_count visits) - $title"
                        fi
                    fi
                done < "$temp_sites"
                rm "$temp_sites"
            fi
        fi
        rm "$temp_hosts"
        
        echo
        read -p "Enter domain to whitelist (or press Enter to finish): " -r domain
        
        if [ -z "$domain" ]; then
            break
        fi
        
        # Clean domain
        domain=$(echo "$domain" | sed 's|^https\?://||' | sed 's|^www\.||' | sed 's|/$||')
        
        # Add to whitelist
        if ! grep -q "^$domain$" "$PROJECT_ROOT/whitelist.txt" 2>/dev/null; then
            echo "$domain" >> "$PROJECT_ROOT/whitelist.txt"
            print_status "Added '$domain' to whitelist"
        else
            print_warning "Domain '$domain' is already whitelisted"
        fi
    done
    
    # Show final whitelist
    local whitelist_count=$(grep -v '^#' "$PROJECT_ROOT/whitelist.txt" | grep -v '^$' | wc -l)
    if [ "$whitelist_count" -gt 0 ]; then
        echo
        print_status "Whitelist summary:"
        grep -v '^#' "$PROJECT_ROOT/whitelist.txt" | grep -v '^$' | while read -r domain; do
            echo "  - $domain"
        done
        print_status "Total whitelisted domains: $whitelist_count"
    fi
}

# Function to create configuration file
create_config() {
    local selected_categories="$1"
    print_status "Creating configuration file..."
    
    cat > "$CONFIG_FILE" << EOF
# Hosts Blocker Configuration
# Generated on $(date)

# Selected categories for blocking
SELECTED_CATEGORIES="$selected_categories"

# Update interval (in seconds)
# 86400 = 1 day, 604800 = 7 days, 2592000 = 30 days
UPDATE_INTERVAL=604800

# Log retention (number of days)
LOG_RETENTION_DAYS=30
EOF
    
    print_status "Configuration saved to: $CONFIG_FILE"
}

# Function to create plist file
create_plist() {
    print_status "Creating launchd plist file..."
    
    # Create LaunchDaemons directory if it doesn't exist
    sudo mkdir -p "/Library/LaunchDaemons"
    
    sudo tee "$PLIST_FILE" > /dev/null << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$PLIST_LABEL</string>

  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$SCRIPT_DIR/update-hosts.sh</string>
  </array>

  <!-- Run every 7 days = 604800 seconds -->
  <key>StartInterval</key>
  <integer>604800</integer>

  <!-- Run at load -->
  <key>RunAtLoad</key>
  <true/>

  <!-- Logs -->
  <key>StandardOutPath</key>
  <string>$PROJECT_ROOT/logs/launchd.log</string>

  <key>StandardErrorPath</key>
  <string>$PROJECT_ROOT/logs/launchd.err</string>
</dict>
</plist>
EOF
    
    print_status "Plist file created: $PLIST_FILE"
}

# Function to load the launch daemon
load_launch_agent() {
    print_status "Loading launch daemon..."
    
    # Unload if already loaded
    sudo launchctl bootout system "$PLIST_FILE" 2>/dev/null || true
    
    # Load the new plist
    sudo launchctl bootstrap system "$PLIST_FILE"
    
    if [ $? -eq 0 ]; then
        print_status "Launch daemon loaded successfully"
    else
        print_error "Failed to load launch daemon"
        exit 1
    fi
}

# Function to test the setup
test_setup() {
    print_status "Testing the setup..."
    
    # Make sure the script is executable
    chmod +x "$SCRIPT_DIR/update-hosts.sh"
    
    # Test run (this will require sudo)
    print_warning "Testing requires sudo privileges..."
    if sudo "$SCRIPT_DIR/update-hosts.sh"; then
        print_status "Test run successful!"
    else
        print_error "Test run failed. Check the logs for details."
        exit 1
    fi
}

# Function to show status
show_status() {
    echo
    print_status "Setup completed successfully!"
    echo
    echo "Configuration:"
    echo "  - Categories: ${selected_categories:-'default (malware + ads)'}"
    echo "  - Update interval: 7 days"
    echo "  - Logs directory: $PROJECT_ROOT/logs"
    echo "  - Plist file: $PLIST_FILE"
    echo
    echo "Management commands:"
    echo "  - Check status: launchctl list | grep $PLIST_LABEL"
    echo "  - Unload: sudo launchctl bootout system $PLIST_FILE"
    echo "  - Reload: sudo launchctl bootout system $PLIST_FILE && sudo launchctl bootstrap system $PLIST_FILE"
    echo "  - Manual update: sudo $SCRIPT_DIR/update-hosts.sh"
    echo
    print_status "The hosts blocker will start automatically and update every 7 days."
}

# Main execution
main() {
    print_header
    
    check_macos
    check_dependencies
    show_categories
    
    echo "Select categories to block (enter letters, e.g., 'psg' for porn+social+gambling):"
    echo "Example: psg (porn + social + gambling)"
    echo "         a (all categories)"
    echo "         d (default - malware and ads only)"
    echo
    
    # Get category selection
    local selected_categories=$(get_category_selection)
    
    # Check what would be blocked with these categories
    if [ -n "$selected_categories" ] && [ -f "$SCRIPT_DIR/simple-history-check.sh" ]; then
        echo
        print_status "Checking what would be blocked with your selection..."
        echo "========================================"
        
        # Run the history check and capture output
        local history_output=$(mktemp)
        "$SCRIPT_DIR/simple-history-check.sh" "$selected_categories" > "$history_output" 2>&1
        
        # Show the analysis
        if [ -s "$history_output" ]; then
            cat "$history_output"
        fi
        rm "$history_output"
        
        # Ask if user wants to add exceptions
        echo
        print_warning "⚠️  Some of your frequently visited sites would be blocked!"
        echo
        read -p "Would you like to add any sites to the whitelist now? (y/n): " -r add_exceptions
        
        if [ "$add_exceptions" = "y" ] || [ "$add_exceptions" = "Y" ]; then
            add_exceptions_interactive "$selected_categories"
        fi
    fi
    
    create_config "$selected_categories"
    create_plist
    load_launch_agent
    test_setup
    show_status
}

# Run main function
main "$@"
