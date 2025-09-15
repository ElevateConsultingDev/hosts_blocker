#!/bin/bash

# Simple wrapper for adding domains with smart discovery
# This integrates with the existing whitelist system

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -eq 0 ]; then
    echo "Usage: $0 <domain>"
    echo "Example: $0 linkedin.com"
    echo "         $0 github.com"
    echo "         $0 facebook.com"
    exit 1
fi

# Use the smart whitelist manager
"$SCRIPT_DIR/smart-whitelist.sh" add "$1"
