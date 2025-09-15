#!/bin/bash

# Hosts Blocker Update Script
# Downloads and applies StevenBlack hosts file with selected categories

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/update-hosts.log"
ERR_FILE="$LOG_DIR/update-hosts.err"
CONFIG_FILE="$PROJECT_ROOT/hosts-config.txt"

# Create logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to log errors
log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" | tee -a "$ERR_FILE"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

log_message "=== Hosts update started ==="

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    log_error "Configuration file not found: $CONFIG_FILE"
    log_error "Please run the setup script first"
    exit 1
fi

# Read configuration
source "$CONFIG_FILE"

# Build URL based on selected categories
BASE_URL="https://raw.githubusercontent.com/StevenBlack/hosts/master"
if [ -n "$SELECTED_CATEGORIES" ]; then
    # Convert categories to StevenBlack format (hyphenated, alphabetical order)
    # StevenBlack uses specific combinations like "fakenews-gambling-porn-social"
    SORTED_CATEGORIES=$(echo "$SELECTED_CATEGORIES" | tr ' ' '\n' | sort | tr '\n' '-' | sed 's/-$//')
    HOSTS_URL="$BASE_URL/alternates/$SORTED_CATEGORIES/hosts"
else
    # Default to base hosts file
    HOSTS_URL="$BASE_URL/hosts"
fi

log_message "Downloading hosts file from: $HOSTS_URL"

# Download the hosts file
curl -s "$HOSTS_URL" -o /tmp/hosts.new >> "$LOG_FILE" 2>> "$ERR_FILE"

if [ -s /tmp/hosts.new ]; then
    # Create backup
    BACKUP_FILE="/etc/hosts.backup.$(date +%Y%m%d%H%M%S)"
    cp /etc/hosts "$BACKUP_FILE" >> "$LOG_FILE" 2>> "$ERR_FILE"
    log_message "Created backup: $BACKUP_FILE"
    
    # Replace hosts file
    cp /tmp/hosts.new /etc/hosts >> "$LOG_FILE" 2>> "$ERR_FILE"
    
    # Flush DNS cache
    dscacheutil -flushcache >> "$LOG_FILE" 2>> "$ERR_FILE"
    killall -HUP mDNSResponder >> "$LOG_FILE" 2>> "$ERR_FILE"
    
    log_message "Update successful - Categories: ${SELECTED_CATEGORIES:-'default'}"
    log_message "DNS cache flushed"
else
    log_error "Download failed - no data retrieved"
    exit 1
fi

# Clean up
rm -f /tmp/hosts.new

log_message "=== Hosts update completed ==="
