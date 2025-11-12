#!/bin/bash
# Check if container exists
if container ls --all --format json 2>/dev/null | jq -e '.[] | select(.configuration.id == "claude-dev")' >/dev/null 2>&1; then
    # Check status
    STATUS=$(container ls --all --format json 2>/dev/null | jq -r '.[] | select(.configuration.id == "claude-dev") | .status')
    
    if [ "$STATUS" = "running" ]; then
        echo "Container is running, attaching..."
        container exec -it claude-dev /bin/zsh
    else
        echo "Starting stopped container..."
        container start claude-dev
        container exec -it claude-dev /bin/zsh
    fi
else
    echo "Creating new container..."
    container run -it \
      --name claude-dev \
      --volume claude-home:/home/claude \
      --volume claude-history:/commandhistory \
      --volume $(pwd):/workspace \
      --memory 8g \
      --cpus 4 \
      --dns-domain local \
      claude:latest
fi
