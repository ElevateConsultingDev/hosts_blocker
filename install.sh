#!/bin/bash

# Hosts Blocker Professional Installer
# Installs the hosts blocker system with proper permissions and structure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/usr/local/hosts-blocker"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    echo -e "${BLUE}  Hosts Blocker Installer${NC}"
    echo -e "${BLUE}================================${NC}"
    echo
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This installer must be run as root (use sudo)"
        exit 1
    fi
}

# Function to check macOS
check_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_error "This installer is designed for macOS only"
        exit 1
    fi
}

# Function to check dependencies
check_dependencies() {
    print_status "Checking dependencies..."
    
    local missing_deps=()
    
    if ! command -v curl >/dev/null 2>&1; then
        missing_deps+=("curl")
    fi
    
    if ! command -v launchctl >/dev/null 2>&1; then
        missing_deps+=("launchctl")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_error "Please install them and try again"
        exit 1
    fi
    
    print_status "All dependencies found"
}

# Function to create installation directory
create_install_dir() {
    print_status "Creating installation directory: $INSTALL_DIR"
    
    mkdir -p "$INSTALL_DIR"/{bin,lib,tests,docs,examples,config,logs}
    
    # Set proper permissions
    chown -R root:wheel "$INSTALL_DIR"
    chmod -R 755 "$INSTALL_DIR"
}

# Function to install files
install_files() {
    print_status "Installing files..."
    
    # Install main scripts
    cp "$CURRENT_DIR"/bin/*.sh "$INSTALL_DIR/bin/"
    chmod +x "$INSTALL_DIR/bin/"*.sh
    
    # Install test scripts
    cp "$CURRENT_DIR"/tests/*.sh "$INSTALL_DIR/tests/"
    chmod +x "$INSTALL_DIR/tests/"*.sh
    
    # Install documentation
    cp "$CURRENT_DIR"/docs/*.md "$INSTALL_DIR/docs/" 2>/dev/null || true
    
    # Create symlinks for easy access
    ln -sf "$INSTALL_DIR/bin/setup-hosts-blocker.sh" /usr/local/bin/hosts-blocker-setup
    ln -sf "$INSTALL_DIR/bin/remove-hosts-blocker.sh" /usr/local/bin/hosts-blocker-remove
    ln -sf "$INSTALL_DIR/bin/check-site.sh" /usr/local/bin/hosts-blocker-check
    ln -sf "$INSTALL_DIR/bin/whitelist-manager.sh" /usr/local/bin/hosts-blocker-whitelist
    ln -sf "$INSTALL_DIR/bin/update-hosts.sh" /usr/local/bin/hosts-blocker-update
}

# Function to create configuration
create_config() {
    print_status "Creating configuration..."
    
    cat > "$INSTALL_DIR/config/hosts-blocker.conf" << EOF
# Hosts Blocker Configuration
# This file contains default settings for the hosts blocker system

# Installation directory
INSTALL_DIR="$INSTALL_DIR"

# Log directory
LOG_DIR="$INSTALL_DIR/logs"

# Configuration file location
CONFIG_FILE="$INSTALL_DIR/config/hosts-config.txt"

# Whitelist file location
WHITELIST_FILE="$INSTALL_DIR/config/whitelist.txt"

# Update frequency (in seconds) - 86400 = 24 hours
UPDATE_FREQUENCY=86400

# Enable browser history checking
ENABLE_HISTORY_CHECK=true

# Enable automatic whitelist application
AUTO_APPLY_WHITELIST=true
EOF

    chmod 644 "$INSTALL_DIR/config/hosts-blocker.conf"
}

# Function to create uninstaller
create_uninstaller() {
    print_status "Creating uninstaller..."
    
    cat > "$INSTALL_DIR/uninstall.sh" << 'EOF'
#!/bin/bash

# Hosts Blocker Uninstaller
# Removes the hosts blocker system

set -e

INSTALL_DIR="/usr/local/hosts-blocker"

echo "Hosts Blocker Uninstaller"
echo "========================="
echo

read -p "Are you sure you want to uninstall Hosts Blocker? (y/N): " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled"
    exit 0
fi

echo "Stopping services..."
sudo launchctl bootout system /Library/LaunchDaemons/com.*.hosts-blocker.plist 2>/dev/null || true

echo "Removing files..."
sudo rm -rf "$INSTALL_DIR"
sudo rm -f /usr/local/bin/hosts-blocker-*

echo "Restoring original hosts file..."
if [ -f /etc/hosts.backup.original ]; then
    sudo cp /etc/hosts.backup.original /etc/hosts
    echo "Original hosts file restored"
else
    echo "No original hosts file backup found"
fi

echo "Flushing DNS cache..."
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

echo "Hosts Blocker uninstalled successfully"
EOF

    chmod +x "$INSTALL_DIR/uninstall.sh"
}

# Function to show post-install instructions
show_post_install() {
    echo
    print_status "Installation completed successfully!"
    echo
    echo "Next steps:"
    echo "1. Run the setup script: sudo $INSTALL_DIR/bin/setup-hosts-blocker.sh"
    echo "2. Or use the convenient command: sudo hosts-blocker-setup"
    echo
    echo "Available commands:"
    echo "  hosts-blocker-setup    - Run interactive setup"
    echo "  hosts-blocker-check    - Check if a site is blocked"
    echo "  hosts-blocker-whitelist - Manage whitelist"
    echo "  hosts-blocker-update   - Update hosts file"
    echo "  hosts-blocker-remove   - Remove installation"
    echo
    echo "Documentation: $INSTALL_DIR/docs/"
    echo "Configuration: $INSTALL_DIR/config/"
    echo
}

# Main function
main() {
    print_header
    
    check_root
    check_macos
    check_dependencies
    create_install_dir
    install_files
    create_config
    create_uninstaller
    show_post_install
}

# Run main function
main "$@"
