# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Professional project structure with organized directories
- Comprehensive README.md with installation and usage instructions
- Professional installer script with proper permissions
- MIT License file
- Usage examples in examples/ directory
- Proper .gitignore file
- CHANGELOG.md for version tracking

### Changed
- Moved scripts to bin/ directory for better organization
- Moved tests to tests/ directory
- Moved documentation to docs/ directory
- Updated all script paths to reflect new structure

## [1.0.0] - 2024-01-15

### Added
- Initial release of Hosts Blocker
- Single-letter category selection (p, s, g, f, a, d)
- Automated setup script with interactive configuration
- Whitelist management with subdomain support
- Browser history integration for conflict detection
- Comprehensive test suite with 31 tests
- HTTP verification tests for whitelisted sites
- Professional logging and error handling
- macOS launchd integration for automatic updates
- StevenBlack hosts file integration
- Site checking utility
- Removal and uninstall scripts

### Features
- **Category Selection**: Easy single-letter choices for blocking categories
- **Smart Whitelisting**: Removes both exact domains and subdomains
- **Performance Optimized**: Handles 343k+ line hosts files efficiently
- **Browser Integration**: Checks history for potential conflicts
- **Comprehensive Testing**: Automated test suite with HTTP verification
- **Professional Management**: Easy-to-use command-line tools

### Technical Details
- Optimized for large hosts files (300k+ lines)
- Single-pass processing for whitelist operations
- Proper error handling and logging
- DNS cache flushing for immediate effect
- Backup creation before any changes
- System-wide LaunchDaemon for reliability
