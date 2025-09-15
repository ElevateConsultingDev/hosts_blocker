# Hosts Blocker

A professional, automated hosts file blocking system for macOS that uses the StevenBlack hosts repository to block unwanted websites and provides easy management tools.

## 🚀 Features

- **Automated Setup**: One-command installation with interactive category selection
- **Multiple Blocking Categories**: Porn, social media, gambling, fake news, and more
- **Smart Whitelisting**: Add exceptions for sites you need to access
- **Browser History Integration**: Check what will be blocked before installation
- **Easy Management**: Simple commands to add/remove sites and update blocks
- **Professional Testing**: Comprehensive test suite to verify functionality
- **macOS Optimized**: Uses launchd for reliable background operation

## 📁 Project Structure

```
hosts_blocker/
├── bin/                    # Executable scripts
│   ├── setup-hosts-blocker.sh    # Main installation script
│   ├── remove-hosts-blocker.sh   # Uninstall script
│   ├── update-hosts.sh           # Update hosts file
│   ├── check-site.sh             # Check if site is blocked
│   ├── whitelist-manager.sh      # Manage whitelist
│   ├── simple-history-check.sh   # Check browser history
│   └── history-checker.sh        # Advanced history analysis
├── tests/                  # Test suite
│   ├── test-hosts-blocker.sh     # Main test suite
│   ├── quick-test.sh             # Quick verification
│   ├── test-interactive-setup.sh # Interactive setup tests
│   └── simple-test.sh            # Simple functionality tests
├── docs/                   # Documentation
│   └── manual-test.md           # Manual testing guide
├── examples/               # Usage examples
├── config/                 # Configuration files
└── README.md              # This file
```

## 🛠 Installation

### Quick Install

```bash
# Clone the repository
git clone https://github.com/ElevateConsultingDev/hosts_blocker.git
cd hosts_blocker

# Run the setup script
sudo ./bin/setup-hosts-blocker.sh
```

### Interactive Setup

The setup script will guide you through:

1. **Category Selection** (single-letter choices):
   - `p` - Pornography and adult content
   - `s` - Social media platforms
   - `g` - Gambling and betting sites
   - `f` - Fake news and misinformation
   - `a` - All categories
   - `d` - Default (malware and ads only)

2. **Browser History Check**: Automatically detects your browser and shows what will be blocked

3. **Whitelist Setup**: Add exceptions for sites you need to access

4. **Service Installation**: Sets up automatic updates via launchd

## 📖 Usage

### Basic Commands

```bash
# Check if a site is blocked
./bin/check-site.sh facebook.com

# Add a site to whitelist
sudo ./bin/whitelist-manager.sh add linkedin.com

# Remove a site from whitelist
sudo ./bin/whitelist-manager.sh remove linkedin.com

# List whitelisted sites
./bin/whitelist-manager.sh list

# Update hosts file manually
sudo ./bin/update-hosts.sh

# Check browser history for conflicts
./bin/simple-history-check.sh
```

### Management Commands

```bash
# Uninstall (keeps scripts)
sudo ./bin/remove-hosts-blocker.sh

# Complete removal (restores system)
sudo ./bin/remove-hosts-blocker.sh

# Run test suite
./tests/test-hosts-blocker.sh

# Quick verification
./tests/quick-test.sh
```

## 🔧 Configuration

### Categories Available

| Letter | Category | Description |
|--------|----------|-------------|
| `p` | Porn | Pornography and adult content |
| `s` | Social | Social media platforms |
| `g` | Gambling | Gambling and betting sites |
| `f` | Fake News | Fake news and misinformation |
| `a` | All | All categories combined |
| `d` | Default | Malware and ads only |

### Whitelist Management

The whitelist allows you to access specific sites even if they're in blocked categories:

```bash
# Add multiple sites
sudo ./bin/whitelist-manager.sh add linkedin.com github.com

# Remove sites
sudo ./bin/whitelist-manager.sh remove github.com

# Apply whitelist to hosts file
sudo ./bin/whitelist-manager.sh apply

# Check whitelist status
./bin/whitelist-manager.sh check
```

## 🧪 Testing

### Automated Tests

```bash
# Run full test suite
./tests/test-hosts-blocker.sh

# Quick verification
./tests/quick-test.sh

# Test interactive setup
./tests/test-interactive-setup.sh
```

### Manual Testing

See `docs/manual-test.md` for detailed manual testing procedures.

## 📋 Requirements

- **macOS**: 10.12 or later
- **sudo access**: Required for system file modifications
- **Internet connection**: For downloading hosts files
- **curl**: For downloading hosts files
- **sqlite3**: For browser history analysis (optional)

## 🔒 Security

- All system modifications require sudo authentication
- Hosts files are downloaded from trusted StevenBlack repository
- Automatic backups are created before any changes
- DNS cache is flushed after updates for immediate effect

## 🧠 Smart Whitelist Management

The hosts blocker includes an intelligent whitelist system that automatically discovers and whitelists all necessary subdomains and CDN domains for any site you want to allow.

### Smart Whitelist Features

- **Automatic Discovery**: Analyzes websites to find all related domains (CDN, static content, API endpoints)
- **Comprehensive Coverage**: Whitelists subdomains, CDN domains, and static content domains
- **One-Command Setup**: Add a domain and all its dependencies with a single command
- **Safe Operation**: Creates backups before making changes

### Usage

```bash
# Add a domain with smart discovery
./bin/smart-whitelist.sh add linkedin.com

# Discover related domains without adding (dry run)
./bin/smart-whitelist.sh discover github.com

# Apply whitelist to hosts file
./bin/smart-whitelist.sh apply

# List all whitelisted domains
./bin/smart-whitelist.sh list

# Simple wrapper for quick adding
./bin/whitelist-add.sh facebook.com
```

### Examples

```bash
# Add LinkedIn (discovers static.licdn.com, media.licdn.com, etc.)
./bin/smart-whitelist.sh add linkedin.com

# Add GitHub (discovers api.github.com, assets.github.com, etc.)
./bin/smart-whitelist.sh add github.com

# Add Facebook (discovers cdn.facebook.com, static.facebook.com, etc.)
./bin/smart-whitelist.sh add facebook.com
```

### How It Works

1. **Domain Analysis**: Fetches the website content to analyze its structure
2. **Pattern Recognition**: Identifies common CDN patterns (static, media, cdn, assets, etc.)
3. **Content Extraction**: Extracts domains from HTML, CSS, and JavaScript references
4. **Validation**: Validates that discovered domains are actually related to the target domain
5. **Whitelist Application**: Adds all discovered domains to the whitelist and removes them from the hosts file

This eliminates the need for manual domain discovery and ensures complete website functionality.

## 🚨 Troubleshooting

### Common Issues

1. **Permission Denied**: Run commands with `sudo`
2. **Service Not Starting**: Check launchd status with `launchctl list`
3. **Sites Not Blocked**: Flush DNS cache with `sudo dscacheutil -flushcache`
4. **Whitelist Not Working**: Ensure whitelist is applied with `sudo ./bin/whitelist-manager.sh apply`

### Debug Commands

```bash
# Check service status
sudo launchctl list | grep hosts-blocker

# View logs
tail -f logs/update-hosts.log

# Check hosts file
sudo head -20 /etc/hosts

# Test DNS resolution
nslookup facebook.com
```

## 📚 Documentation

- [Manual Testing Guide](docs/manual-test.md)
- [StevenBlack Hosts Repository](https://github.com/StevenBlack/hosts)
- [macOS launchd Documentation](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- [StevenBlack](https://github.com/StevenBlack) for the comprehensive hosts file repository
- macOS community for launchd documentation and best practices

## 📞 Support

For issues and questions:
- Create an issue on GitHub
- Check the troubleshooting section above
- Review the test suite for expected behavior

---

**Note**: This tool modifies system files and requires administrator privileges. Always backup your system before installation.