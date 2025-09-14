#!/bin/bash

# Hosts Blocker Removal Script
# Offers both quick uninstall and complete removal options

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
CURRENT_USER=$(whoami)
PLIST_LABEL="com.${CURRENT_USER}.hosts-blocker"
PLIST_FILE="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"
CONFIG_FILE="$SCRIPT_DIR/hosts-config.txt"
LOGS_DIR="$SCRIPT_DIR/logs"

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
    echo -e "${BLUE}  Hosts Blocker Removal Script${NC}"
    echo -e "${BLUE}================================${NC}"
    echo
}

# Function to show removal options
show_removal_options() {
    echo "Choose removal type:"
    echo
    echo -e "${CYAN}1) Quick Uninstall${NC}"
    echo "   - Stop the service and remove configuration"
    echo "   - Keep all script files for future use"
    echo "   - Easy to re-enable later"
    echo "   - No sudo required"
    echo
    echo -e "${CYAN}2) Complete Removal${NC}"
    echo "   - Stop the service and remove everything"
    echo "   - Restore original hosts file"
    echo "   - Remove all script files and repository"
    echo "   - Requires sudo"
    echo "   - Cannot be undone"
    echo
    echo -e "${CYAN}3) Cancel${NC}"
    echo "   - Exit without making changes"
    echo
}

# Function to get user choice
get_removal_choice() {
    while true; do
        read -p "Enter your choice (1-3): " choice
        case $choice in
            1)
                return "quick"
                ;;
            2)
                return "complete"
                ;;
            3)
                return "cancel"
                ;;
            *)
                print_error "Invalid choice. Please enter 1, 2, or 3."
                ;;
        esac
    done
}

# Function to check if running as root (for complete removal)
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Complete removal requires root privileges (use sudo)"
        print_error "Run: sudo ./remove-hosts-blocker.sh"
        exit 1
    fi
}

# Function to stop and remove launch agent
remove_launch_agent() {
    print_status "Stopping and removing launch agent..."
    
    if [ -f "$PLIST_FILE" ]; then
        # Unload the agent
        launchctl unload "$PLIST_FILE" 2>/dev/null || true
        print_status "Launch agent unloaded"
        
        # Remove the plist file
        rm "$PLIST_FILE"
        print_status "Plist file removed: $PLIST_FILE"
    else
        print_warning "Plist file not found: $PLIST_FILE"
    fi
}

# Function to find and restore original hosts file
restore_hosts_file() {
    print_status "Looking for original hosts file backup..."
    
    # Find the most recent backup
    local backup_file=$(ls -t /etc/hosts.backup.* 2>/dev/null | head -n1)
    
    if [ -n "$backup_file" ] && [ -f "$backup_file" ]; then
        print_status "Found backup: $backup_file"
        echo "Do you want to restore the original hosts file from this backup? (y/N)"
        read -r response
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
            # Create a backup of current hosts file first
            cp /etc/hosts "/etc/hosts.blocked.$(date +%Y%m%d%H%M%S)"
            print_status "Created backup of current hosts file"
            
            # Restore original
            cp "$backup_file" /etc/hosts
            print_status "Hosts file restored from backup"
            
            # Flush DNS cache
            dscacheutil -flushcache
            killall -HUP mDNSResponder
            print_status "DNS cache flushed"
            
            return 0
        else
            print_warning "Skipping hosts file restoration"
            return 1
        fi
    else
        print_warning "No hosts file backup found"
        print_warning "You may need to manually restore your hosts file"
        return 1
    fi
}

# Function to clean up configuration files
cleanup_config() {
    print_status "Cleaning up configuration files..."
    
    # Remove config file
    if [ -f "$CONFIG_FILE" ]; then
        rm "$CONFIG_FILE"
        print_status "Configuration file removed: $CONFIG_FILE"
    else
        print_warning "Configuration file not found: $CONFIG_FILE"
    fi
}

# Function to clean up log files
cleanup_logs() {
    print_status "Cleaning up log files..."
    
    if [ -d "$LOGS_DIR" ]; then
        echo "Do you want to remove log files? (y/N)"
        read -r response
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
            rm -rf "$LOGS_DIR"
            print_status "Log files removed: $LOGS_DIR"
        else
            print_warning "Log files kept in: $LOGS_DIR"
        fi
    else
        print_warning "Log directory not found: $LOGS_DIR"
    fi
}

# Function to clean up script files (complete removal only)
cleanup_scripts() {
    print_status "Cleaning up script files..."
    
    echo "Do you want to remove all hosts blocker script files? (y/N)"
    echo "This will remove:"
    echo "  - setup-hosts-blocker.sh"
    echo "  - update-hosts.sh"
    echo "  - check-site.sh"
    echo "  - com.user.update-hosts.plist"
    echo "  - README.md"
    echo "  - .gitignore"
    echo
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        # Remove script files
        rm -f "$SCRIPT_DIR/setup-hosts-blocker.sh"
        rm -f "$SCRIPT_DIR/update-hosts.sh"
        rm -f "$SCRIPT_DIR/check-site.sh"
        rm -f "$SCRIPT_DIR/com.user.update-hosts.plist"
        rm -f "$SCRIPT_DIR/README.md"
        rm -f "$SCRIPT_DIR/.gitignore"
        print_status "Script files removed"
        
        # Remove .git directory if it exists
        if [ -d "$SCRIPT_DIR/.git" ]; then
            echo "Do you want to remove the .git directory? (y/N)"
            read -r git_response
            if [[ "$git_response" =~ ^[Yy]$ ]]; then
                rm -rf "$SCRIPT_DIR/.git"
                print_status "Git repository removed"
            fi
        fi
        
        print_status "All hosts blocker files removed"
    else
        print_warning "Script files kept"
    fi
}

# Function to show final status
show_final_status() {
    local removal_type="$1"
    
    echo
    print_status "Removal completed!"
    echo
    echo "What was removed:"
    echo "  - Launch agent: $PLIST_LABEL"
    echo "  - Plist file: $PLIST_FILE"
    echo "  - Configuration file: $CONFIG_FILE"
    echo "  - Log files: $LOGS_DIR"
    echo
    
    if [ "$removal_type" = "quick" ]; then
        echo "What was kept:"
        echo "  - All script files (setup, update, check-site, etc.)"
        echo "  - This removal script"
        echo "  - README.md documentation"
        echo
        print_status "You can re-enable the hosts blocker by running: ./setup-hosts-blocker.sh"
    else
        echo "What was restored:"
        echo "  - Original hosts file (if backup was found and restored)"
        echo "  - DNS cache flushed"
        echo
        print_warning "Note: If no backup was found, you may need to manually restore your hosts file"
        print_warning "The original hosts file typically contains only localhost entries"
    fi
    
    echo
    print_status "Your system is now clean"
}

# Function to show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Remove the hosts blocker with interactive options."
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -q, --quick    Skip menu and do quick uninstall"
    echo "  -c, --complete Skip menu and do complete removal"
    echo
    echo "Removal Types:"
    echo "  Quick Uninstall:"
    echo "    - Stop service and remove configuration"
    echo "    - Keep script files for future use"
    echo "    - No sudo required"
    echo
    echo "  Complete Removal:"
    echo "    - Stop service and remove everything"
    echo "    - Restore original hosts file"
    echo "    - Remove all files and repository"
    echo "    - Requires sudo"
    echo
}

# Function to perform quick uninstall
do_quick_uninstall() {
    print_status "Performing quick uninstall..."
    echo
    
    remove_launch_agent
    cleanup_config
    cleanup_logs
    show_final_status "quick"
}

# Function to perform complete removal
do_complete_removal() {
    print_status "Performing complete removal..."
    echo
    
    # Check if running as root
    check_root
    
    remove_launch_agent
    restore_hosts_file
    cleanup_config
    cleanup_logs
    cleanup_scripts
    show_final_status "complete"
}

# Main function
main() {
    local skip_menu="false"
    local removal_type=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -q|--quick)
                skip_menu="true"
                removal_type="quick"
                shift
                ;;
            -c|--complete)
                skip_menu="true"
                removal_type="complete"
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                print_error "Unexpected argument: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    print_header
    
    # If menu is not skipped, show options
    if [ "$skip_menu" != "true" ]; then
        show_removal_options
        removal_type=$(get_removal_choice)
    fi
    
    # Handle cancellation
    if [ "$removal_type" = "cancel" ]; then
        print_status "Removal cancelled"
        exit 0
    fi
    
    # Confirm removal
    if [ "$removal_type" = "complete" ]; then
        print_warning "This will completely remove the hosts blocker and restore your original hosts file."
        print_warning "This action cannot be undone!"
        echo
        echo "Are you sure you want to continue? (y/N)"
        read -r response
        
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            print_status "Removal cancelled"
            exit 0
        fi
    fi
    
    # Perform the chosen removal
    if [ "$removal_type" = "quick" ]; then
        do_quick_uninstall
    elif [ "$removal_type" = "complete" ]; then
        do_complete_removal
    fi
}

# Run main function
main "$@"