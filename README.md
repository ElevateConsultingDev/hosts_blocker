# Hosts Blocker

An automated system for blocking unwanted websites using the `/etc/hosts` file on macOS. This tool uses the [StevenBlack/hosts](https://github.com/StevenBlack/hosts) repository to provide comprehensive blocking of various categories of websites.

## Features

- **Automated Updates**: Runs every 7 days to keep your blocklist current
- **Category Selection**: Choose which types of content to block
- **Easy Setup**: One-command installation with interactive configuration
- **Safe Operation**: Creates backups before making changes
- **Comprehensive Logging**: Track all operations and errors
- **Easy Management**: Simple commands to start, stop, and uninstall

## Available Blocking Categories

The StevenBlack hosts repository provides these 4 extension categories:

- **porn**: Pornography and adult content
- **social**: Social media platforms (Facebook, Twitter, Instagram, etc.)
- **gambling**: Gambling and betting sites
- **fakenews**: Fake news and misinformation sites

**Note**: The base hosts file already includes malware and ad blocking by default. Additional categories like drugs and violence are not available as extensions in the StevenBlack repository.

## Quick Start

1. **Clone this repository**:
   ```bash
   git clone https://github.com/ElevateConsultingDev/hosts_blocker.git
   cd hosts_blocker
   ```

2. **Run the setup script**:
   ```bash
   chmod +x setup-hosts-blocker.sh
   ./setup-hosts-blocker.sh
   ```

3. **Follow the interactive prompts** to select which categories to block

That's it! The system will automatically start blocking websites and update every 7 days.

## Manual Installation

If you prefer to set up manually:

1. **Make scripts executable**:
   ```bash
   chmod +x update-hosts.sh setup-hosts-blocker.sh uninstall-hosts-blocker.sh
   ```

2. **Create configuration**:
   ```bash
   echo "SELECTED_CATEGORIES=\"porn social gambling\"" > hosts-config.txt
   ```

3. **Test the update script**:
   ```bash
   sudo ./update-hosts.sh
   ```

4. **Set up launchd** (see the plist template in the repository)

## Usage

### Checking Status
```bash
launchctl list | grep hosts-blocker
```
**Note**: The service name includes your username (e.g., `com.john.hosts-blocker`) to ensure it works for any macOS user.

### Manual Update
```bash
sudo ./update-hosts.sh
```

### Viewing Logs
```bash
tail -f logs/update-hosts.log
tail -f logs/update-hosts.err
```

### Stopping the Service
```bash
launchctl unload ~/Library/LaunchAgents/com.$(whoami).hosts-blocker.plist
```

### Starting the Service
```bash
launchctl load ~/Library/LaunchAgents/com.$(whoami).hosts-blocker.plist
```

## Uninstalling

To completely remove the hosts blocker:

```bash
./uninstall-hosts-blocker.sh
```

This will:
- Stop the automated service
- Remove the launch agent
- Optionally restore your original hosts file
- Clean up configuration files

## Configuration

The system uses a configuration file (`hosts-config.txt`) to store your preferences:

```bash
# Selected categories for blocking
SELECTED_CATEGORIES="porn social gambling"

# Update interval (in seconds)
# 86400 = 1 day, 604800 = 7 days, 2592000 = 30 days
UPDATE_INTERVAL=604800

# Log retention (number of days)
LOG_RETENTION_DAYS=30
```

## How It Works

1. **Download**: Fetches the latest hosts file from StevenBlack's repository
2. **Backup**: Creates a timestamped backup of your current `/etc/hosts` file
3. **Update**: Replaces your hosts file with the new blocklist
4. **Flush**: Clears the DNS cache to apply changes immediately
5. **Log**: Records all operations for troubleshooting

## Troubleshooting

### Permission Issues
If you get permission errors, make sure to run with sudo:
```bash
sudo ./update-hosts.sh
```

### Service Not Running
Check if the launch agent is loaded:
```bash
launchctl list | grep com.user.hosts-blocker
```

If not loaded, reload it:
```bash
launchctl load ~/Library/LaunchAgents/com.user.hosts-blocker.plist
```

### Websites Still Loading
After updating the hosts file, try:
1. Flush DNS cache: `sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder`
2. Restart your browser
3. Check if the domain is in the hosts file: `grep "example.com" /etc/hosts`

### Restore Original Hosts File
If you need to restore your original hosts file:
```bash
sudo cp /etc/hosts.backup.YYYYMMDDHHMMSS /etc/hosts
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

## File Structure

```
hosts_blocker/
├── README.md                    # This file
├── setup-hosts-blocker.sh      # Installation script
├── uninstall-hosts-blocker.sh  # Uninstallation script
├── update-hosts.sh             # Main update script
├── com.user.update-hosts.plist # Launch agent template
├── hosts-config.txt            # Configuration (created during setup)
└── logs/                       # Log files directory
    ├── update-hosts.log        # Update operations log
    ├── update-hosts.err        # Error log
    ├── launchd.log             # Launch agent output
    └── launchd.err             # Launch agent errors
```

## Requirements

- **macOS 10.10+** (uses launchd for scheduling)
- **curl** (included with macOS)
- **sudo privileges** (for modifying /etc/hosts)
- **Internet connection** (for downloading updates)
- **Git** (for cloning the repository)

### macOS Compatibility
This tool is designed to work on any modern macOS system. It automatically:
- Detects the current username for unique service naming
- Uses the system's built-in `launchd` for scheduling
- Leverages macOS's native DNS cache flushing commands
- Creates user-specific launch agents (no system-wide installation required)

## Security Notes

- This script modifies your system's hosts file, which affects all network requests
- Always review what categories you're blocking before installation
- The script creates backups, but keep your own backup of important hosts file entries
- Only download from trusted sources (StevenBlack's official repository)

## Contributing

Feel free to submit issues and enhancement requests!

## License

This project is open source. The hosts files come from the StevenBlack/hosts repository.

## Acknowledgments

- [StevenBlack/hosts](https://github.com/StevenBlack/hosts) - The comprehensive hosts file repository
- macOS launchd - For reliable background task scheduling
