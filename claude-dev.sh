#!/bin/bash

# Configure & start pf firewall before launching

# Update container subnet in case it changed
bash update_subnet.sh

# 1. Populate the file with fresh IPs
sudo bash populate_allowed_ips.sh

# 2. Load/reload PF config (which reads the file)
sudo pfctl -E -f /etc/claude_firewall.conf


# 3. Start or create container
# Check if container exists
if container ls --all --format json 2>/dev/null | jq -e '.[] | select(.configuration.id == "claude-alpine")' >/dev/null 2>&1; then
    # Check status
    STATUS=$(container ls --all --format json 2>/dev/null | jq -r '.[] | select(.configuration.id == "claude-alpine") | .status')

    if [ "$STATUS" = "running" ]; then
        echo "Container is running, attaching..."
        container exec -it claude-alpine /bin/zsh
    else
        echo "Starting stopped container..."
        container start claude-alpine
        container exec -it claude-alpine /bin/zsh
    fi
else
    echo "Creating new container..."
    container run -it \
      --name claude-alpine \
      --volume alpine-home:/home/claude \
      --volume claude-history:/commandhistory \
      --volume $(pwd):/workspace \
      --memory 8g \
      --network claude \
      --cpus 4 \
      --dns-domain local \
      claudepine:latest
fi

# Teardown firewall after exiting container
echo "Tearing down firewall..."
bash pfreset.sh
