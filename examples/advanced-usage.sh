#!/bin/bash

# Advanced Usage Examples for Hosts Blocker
# This script demonstrates advanced usage patterns and automation

echo "Hosts Blocker - Advanced Usage Examples"
echo "======================================="
echo

echo "1. Batch whitelist multiple sites:"
echo "   echo 'linkedin.com' > whitelist.txt"
echo "   echo 'github.com' >> whitelist.txt"
echo "   echo 'stackoverflow.com' >> whitelist.txt"
echo "   sudo hosts-blocker-whitelist apply"
echo

echo "2. Check multiple sites at once:"
echo "   for site in facebook.com twitter.com instagram.com; do"
echo "     echo \"\$site: \$(hosts-blocker-check \$site)\""
echo "   done"
echo

echo "3. Monitor whitelist changes:"
echo "   watch -n 5 'hosts-blocker-whitelist list'"
echo

echo "4. Backup current configuration:"
echo "   sudo cp /etc/hosts /etc/hosts.backup.\$(date +%Y%m%d_%H%M%S)"
echo "   sudo cp hosts-config.txt hosts-config.txt.backup.\$(date +%Y%m%d_%H%M%S)"
echo

echo "5. Restore from backup:"
echo "   sudo cp /etc/hosts.backup.20240101_120000 /etc/hosts"
echo "   sudo dscacheutil -flushcache"
echo

echo "6. Check service status:"
echo "   sudo launchctl list | grep hosts-blocker"
echo

echo "7. View logs:"
echo "   tail -f logs/update-hosts.log"
echo

echo "8. Test specific categories:"
echo "   # Test porn blocking"
echo "   hosts-blocker-check pornhub.com"
echo "   # Test social media blocking"
echo "   hosts-blocker-check facebook.com"
echo "   # Test gambling blocking"
echo "   hosts-blocker-check bet365.com"
echo

echo "9. Custom update frequency:"
echo "   # Edit the plist file to change update frequency"
echo "   sudo nano /Library/LaunchDaemons/com.\$(whoami).hosts-blocker.plist"
echo "   # Change StartInterval value (in seconds)"
echo

echo "10. Debug DNS issues:"
echo "    nslookup facebook.com"
echo "    dig facebook.com"
echo "    sudo dscacheutil -flushcache"
echo
