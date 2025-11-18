#!/bin/bash
OUTPUT_FILE="/etc/pf.anchors/allowed_destinations"

# Clear the file
echo "# Allowed destinations - auto-generated" | sudo tee "$OUTPUT_FILE" > /dev/null

# Add GitHub IP ranges with aggregation
echo "Fetching GitHub IP ranges..."
gh_ranges=$(curl -s https://api.github.com/meta)
if [ -z "$gh_ranges" ]; then
    echo "ERROR: Failed to fetch GitHub IP ranges"
    exit 1
fi

if ! echo "$gh_ranges" | jq -e '.web and .api and .git' >/dev/null; then
    echo "ERROR: GitHub API response missing required fields"
    exit 1
fi

echo "Processing GitHub IPs..."
echo "$gh_ranges" | jq -r '(.web + .api + .git)[]' | aggregate -q | while read -r cidr; do
    if [[ ! "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        echo "ERROR: Invalid CIDR range: $cidr"
        exit 1
    fi
    echo "Adding GitHub range $cidr"
    echo "$cidr" | sudo tee -a "$OUTPUT_FILE" > /dev/null
done

# Add Anthropic subnet block
echo "Adding Anthropic subnet block..."
echo "160.79.104.0/23" | sudo tee -a "$OUTPUT_FILE" > /dev/null

# Add Sentry.io IP ranges
echo "Adding Sentry.io IP ranges..."
for ip in \
    "35.186.247.156/32" \
    "34.120.195.249/32" \
    "35.184.238.160/32" \
    "104.155.159.182/32" \
    "104.155.149.19/32" \
    "130.211.230.102/32"; do
    echo "Adding Sentry.io range $ip"
    echo "$ip" | sudo tee -a "$OUTPUT_FILE" > /dev/null
done

# Add Statsig IP ranges
echo "Adding Statsig IP ranges..."
for ip in \
    "34.120.214.181/32" \
    "34.128.128.0/29"; do
    echo "Adding Statsig range $ip"
    echo "$ip" | sudo tee -a "$OUTPUT_FILE" > /dev/null
done

# Add Anthropic outbound IP block
echo "Adding Anthropic outbound IP block..."
for ip in \
    "34.162.46.92/32" \
    "34.162.102.82/32" \
    "34.162.136.91/32" \
    "34.162.142.92/32" \
    "34.162.183.95/32"; do
    echo "Adding Anthropic outbound IP $ip"
    echo "$ip" | sudo tee -a "$OUTPUT_FILE" > /dev/null
done

# Resolve and add allowed domains (for NPM and VSCode which don't have documented CIDR blocks)
for domain in \
    "registry.npmjs.org" \
    "marketplace.visualstudio.com" \
    "vscode.blob.core.windows.net" \
    "update.code.visualstudio.com"; do
    
    echo "Resolving $domain..."
    ips=$(dig +noall +answer A "$domain" | awk '$4 == "A" {print $5}')
    if [ -z "$ips" ]; then
        echo "ERROR: Failed to resolve $domain"
        exit 1
    fi
    
    while read -r ip; do
        if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "ERROR: Invalid IP from DNS for $domain: $ip"
            exit 1
        fi
        echo "Adding $ip for $domain"
        echo "$ip" | sudo tee -a "$OUTPUT_FILE" > /dev/null
    done < <(echo "$ips")
done

echo "Done. IPs written to $OUTPUT_FILE"
