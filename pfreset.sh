#!/bin/bash

# Disable packet filter
sudo pfctl -d

# Flush all rules from main ruleset
sudo pfctl -F all

# Flush all rules from claude_firewall anchor
sudo pfctl -a claude_firewall -F all

# Reload default pf configuration
sudo pfctl -f /etc/pf.conf

echo "Firewall reset complete - loaded default /etc/pf.conf"
