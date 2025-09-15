#!/bin/bash

# Basic Usage Examples for Hosts Blocker
# This script demonstrates common usage patterns

echo "Hosts Blocker - Basic Usage Examples"
echo "===================================="
echo

echo "1. Check if a site is blocked:"
echo "   hosts-blocker-check facebook.com"
echo

echo "2. Add a site to whitelist:"
echo "   sudo hosts-blocker-whitelist add linkedin.com"
echo

echo "3. Remove a site from whitelist:"
echo "   sudo hosts-blocker-whitelist remove linkedin.com"
echo

echo "4. List all whitelisted sites:"
echo "   hosts-blocker-whitelist list"
echo

echo "5. Apply whitelist changes:"
echo "   sudo hosts-blocker-whitelist apply"
echo

echo "6. Update hosts file manually:"
echo "   sudo hosts-blocker-update"
echo

echo "7. Check browser history for conflicts:"
echo "   simple-history-check.sh"
echo

echo "8. Run test suite:"
echo "   ./tests/test-hosts-blocker.sh"
echo

echo "9. Quick verification:"
echo "   ./tests/quick-test.sh"
echo

echo "10. Uninstall:"
echo "    sudo hosts-blocker-remove"
echo
