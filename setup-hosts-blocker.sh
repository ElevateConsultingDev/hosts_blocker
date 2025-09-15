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
CURRENT_USER=$(whoami)
PLIST_LABEL="com.${CURRENT_USER}.hosts-blocker"

# Choose between LaunchAgent (user) or LaunchDaemon (system)
# LaunchDaemon is more reliable for system-wide services
PLIST_FILE="/Library/LaunchDaemons/$PLIST_LABEL.plist"
CONFIG_FILE="$SCRIPT_DIR/hosts-config.txt"

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
    for i in "${!CATEGORY_KEYS[@]}"; do
        echo "  ${CATEGORY_KEYS[$i]} - ${CATEGORY_DESCRIPTIONS[$i]}"
    done
    echo
}

# Function to get user's category selection
get_category_selection() {
    echo "Select categories to block (separate multiple with spaces):"
    echo "Example: porn social gambling"
    echo "Leave empty for default (malware and ads only)"
    echo
    read -p "Categories: " -r selected_categories
    
    if [ -z "$selected_categories" ]; then
        selected_categories=""
        print_status "Using base hosts file (includes malware and ads by default)"
    else
        # Validate categories
        for category in $selected_categories; do
            valid_category=false
            for key in "${CATEGORY_KEYS[@]}"; do
                if [ "$category" = "$key" ]; then
                    valid_category=true
                    break
                fi
            done
            if [ "$valid_category" = false ]; then
                print_error "Invalid category: $category"
                print_error "Available categories: ${CATEGORY_KEYS[*]}"
                exit 1
            fi
        done
        print_status "Selected categories: $selected_categories"
    fi
}

# Function to create configuration file
create_config() {
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
  <string>$SCRIPT_DIR/logs/launchd.log</string>

  <key>StandardErrorPath</key>
  <string>$SCRIPT_DIR/logs/launchd.err</string>
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
    echo "  - Logs directory: $SCRIPT_DIR/logs"
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
    get_category_selection
    create_config
    create_plist
    load_launch_agent
    test_setup
    show_status
}

# Run main function
main "$@"
