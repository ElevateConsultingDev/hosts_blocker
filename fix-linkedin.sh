#!/bin/bash

# Simple script to remove LinkedIn domains from hosts file

HOSTS_FILE="/etc/hosts"
WHITELIST_FILE="whitelist.txt"

echo "Removing LinkedIn domains from hosts file..."

# Create backup
sudo cp "$HOSTS_FILE" "$HOSTS_FILE.backup.$(date +%Y%m%d%H%M%S)"

# Get whitelisted domains
whitelist_domains=$(grep -v '^#' "$WHITELIST_FILE" | grep -v '^$')

if [ -z "$whitelist_domains" ]; then
    echo "No domains to whitelist"
    exit 0
fi

# Process each domain individually
for domain in $whitelist_domains; do
    echo "Removing blocked entries for: $domain"
    
    # Remove exact domain matches
    sudo sed -i '' "/^0\.0\.0\.0 $domain$/d" "$HOSTS_FILE"
    
    # Remove subdomain matches
    sudo sed -i '' "/^0\.0\.0\.0 [^ ]*\.$domain$/d" "$HOSTS_FILE"
done

echo "LinkedIn domains removed successfully!"
echo "Flushing DNS cache..."

# Flush DNS cache
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

echo "Done!"
