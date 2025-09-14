#!/bin/bash

# Hosts Blocker Uninstall Script
# Removes the hosts blocker service and restores original hosts file

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
PLIST_FILE="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"

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
    echo -e "${BLUE}  Hosts Blocker Uninstall${NC}"
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

# Function to unload launch agent
unload_launch_agent() {
    print_status "Unloading launch agent..."
    
    if [ -f "$PLIST_FILE" ]; then
        launchctl unload "$PLIST_FILE" 2>/dev/null || true
        print_status "Launch agent unloaded"
    else
        print_warning "Plist file not found: $PLIST_FILE"
    fi
}

# Function to remove plist file
remove_plist() {
    print_status "Removing plist file..."
    
    if [ -f "$PLIST_FILE" ]; then
        rm "$PLIST_FILE"
        print_status "Plist file removed: $PLIST_FILE"
    else
        print_warning "Plist file not found: $PLIST_FILE"
    fi
}

# Function to restore original hosts file
restore_hosts() {
    print_status "Looking for hosts file backup..."
    
    # Find the most recent backup
    BACKUP_FILE=$(ls -t /etc/hosts.backup.* 2>/dev/null | head -n1)
    
    if [ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ]; then
        print_warning "Found backup: $BACKUP_FILE"
        echo "Do you want to restore the original hosts file from this backup? (y/N)"
        read -r response
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
            if [ "$EUID" -ne 0 ]; then
                print_error "This operation requires sudo privileges"
                echo "Please run: sudo cp $BACKUP_FILE /etc/hosts"
            else
                cp "$BACKUP_FILE" /etc/hosts
                dscacheutil -flushcache
                killall -HUP mDNSResponder
                print_status "Hosts file restored from backup"
            fi
        else
            print_warning "Skipping hosts file restoration"
        fi
    else
        print_warning "No hosts file backup found"
        print_warning "You may need to manually restore your hosts file"
    fi
}

# Function to clean up files
cleanup_files() {
    print_status "Cleaning up files..."
    
    # Remove config file
    if [ -f "$SCRIPT_DIR/hosts-config.txt" ]; then
        rm "$SCRIPT_DIR/hosts-config.txt"
        print_status "Configuration file removed"
    fi
    
    # Ask about removing logs
    if [ -d "$SCRIPT_DIR/logs" ]; then
        echo "Do you want to remove log files? (y/N)"
        read -r response
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
            rm -rf "$SCRIPT_DIR/logs"
            print_status "Log files removed"
        else
            print_warning "Log files kept in: $SCRIPT_DIR/logs"
        fi
    fi
}

# Function to show final status
show_final_status() {
    echo
    print_status "Uninstall completed!"
    echo
    echo "What was removed:"
    echo "  - Launch agent: $PLIST_LABEL"
    echo "  - Plist file: $PLIST_FILE"
    echo "  - Configuration file: $SCRIPT_DIR/hosts-config.txt"
    echo
    echo "What was kept:"
    echo "  - Update script: $SCRIPT_DIR/update-hosts.sh"
    echo "  - This uninstall script"
    echo "  - Log files (if you chose to keep them)"
    echo
    print_warning "Note: Your hosts file may still contain blocked domains."
    print_warning "If you restored from backup, it should be clean."
    print_warning "Otherwise, you may need to manually edit /etc/hosts"
    echo
}

# Main execution
main() {
    print_header
    
    check_macos
    unload_launch_agent
    remove_plist
    restore_hosts
    cleanup_files
    show_final_status
}

# Run main function
main "$@"
