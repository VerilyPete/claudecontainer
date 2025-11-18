#!/bin/bash

# Get the claude network address
CLAUDE_NETWORK=$(container network list --format json | jq -r '.[] | select(.id == "claude") | .status.address')

if [ -z "$CLAUDE_NETWORK" ]; then
    echo "ERROR: Could not find 'claude' network"
    exit 1
fi

echo "Found claude network: $CLAUDE_NETWORK"

# Update the firewall config
FIREWALL_FILE="/etc/pf.anchors/claude_firewall"

sudo sed -i '' "s|^container_network = .*|container_network = \"$CLAUDE_NETWORK\"|" "$FIREWALL_FILE"

echo "Updated $FIREWALL_FILE with network $CLAUDE_NETWORK"
