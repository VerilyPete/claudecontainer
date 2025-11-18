# Claude Development Container

A secure, network-restricted Alpine Linux development container for Claude Code with integrated macOS firewall management using OpenBSD's Packet Filter (pf).

## Overview

This project provides a minimal Alpine-based container pre-configured with Claude CLI and essential development tools, designed to run with strict network controls. It uses macOS's native `pf` firewall to create an allowlist-based network policy that permits only necessary destinations while blocking all other traffic from the container.

## Key Features

- **🔒 Network Security**: Allowlist-based firewall using macOS pf
- **🐳 Apple Container Runtime**: Optimized for macOS native containers
- **⚡ Lightweight**: Alpine Linux base (~100MB)
- **🛠️ Pre-configured Tools**: Claude CLI, git, zsh, fzf, lazygit, micro, vim, and more
- **📝 Persistent History**: Command history persists across container restarts
- **🔄 Auto-discovery**: Dynamically updates container subnet and allowed IPs

## Architecture

### Container
- **Base**: Alpine Linux (latest)
- **User**: Non-root `claude` user with sudo access
- **Shell**: Zsh with fzf integration
- **Workspace**: Container directory mounted at `/workspace` - clone the repo you want to edit in claude here
- **Volumes**: Persistent home directory and command history

### Network Security
The firewall configuration allows:
- ✅ DNS queries (UDP port 53)
- ✅ SSH (TCP port 22)
- ✅ Container-to-container communication
- ✅ GitHub (API, web, git endpoints)
- ✅ Anthropic API endpoints
- ✅ Sentry.io telemetry
- ✅ Statsig analytics
- ✅ NPM registry
- ✅ VS Code marketplace
- ❌ All other outbound traffic (blocked)

## Prerequisites

### macOS Requirements
- macOS with Apple's container runtime (`container` command)
- OpenBSD Packet Filter (pf) - built into macOS
- Root/sudo access for firewall management

### Required Tools
```bash
# Install via Homebrew
brew install jq          # JSON processing
brew install aggregate   # CIDR aggregation
brew install bind        # DNS tools (dig)
```

### Container Network Setup
Create a dedicated container network for pf to filter:
```bash
container network create claude
```

## Installation

### 1. Clone the Repository
```bash
git clone https://github.com/VerilyPete/claudecontainer.git
cd claudecontainer
```

### 2. Install Firewall Configuration
Copy the firewall anchor and config to the system location:
```bash
sudo cp ./pf_configs/pf.anchors/claude_firewall /etc/pf.anchors/claude_firewall
sudo chmod 644 /etc/pf.anchors/claude_firewall
sudo cp ./pf_configs/claude_firewall.conf /etc
sudo chmod 644 /etc/claude_firewall.conf
```


### 3. Build the Container Image
```bash
container build -t claudepine:latest .
```

### 4. Make Scripts Executable
```bash
chmod +x claude-dev.sh pfreset.sh update_subnet.sh populate_allowed_ips.sh
```

## Usage

### Starting the Container
Simply run the main script from your project directory:
```bash
./claude-dev.sh
```

This script will:
1. Detect the container network subnet
2. Populate allowed destination IPs
3. Enable and configure the pf firewall
4. Start or attach to the container
5. Automatically tear down the firewall on exit

### Manual Container Management
If you prefer to manage the container separately:

**Start the container:**
```bash
container run -it \
  --name claude-alpine \
  --volume alpine-home:/home/claude \
  --volume claude-history:/commandhistory \
  --volume $(pwd):/workspace \
  --memory 8g \
  --network claude \
  --cpus 4 \
  claudepine:latest
```

**Attach to running container:**
```bash
container exec -it claude-alpine /bin/zsh
```

**Stop the container:**
```bash
container stop claude-alpine
```

**Remove the container:**
```bash
container rm claude-alpine
```

## Scripts Reference

### `claude-dev.sh`
Main entry point that orchestrates firewall setup and container lifecycle.

**What it does:**
- Updates container subnet configuration
- Populates allowed IP destinations
- Enables pf firewall with custom rules
- Starts/attaches to the container
- Cleans up firewall on exit

### `update_subnet.sh`
Detects the current container network subnet and updates the firewall configuration.

**Usage:**
```bash
./update_subnet.sh
```

This is necessary because the container network subnet can change between system restarts.

### `populate_allowed_ips.sh`
Resolves DNS from domain names, then fetches and aggregates allowed destination IPs from sources contained in the file.

**Sources:**
- GitHub API metadata (web, API, git endpoints)
- Anthropic API ranges
- Sentry.io telemetry endpoints
- Statsig analytics endpoints
- DNS resolution for NPM and VS Code endpoints

**Output:** `/etc/pf.anchors/allowed_destinations`

**Usage:**
```bash
sudo ./populate_allowed_ips.sh
```

### `pfreset.sh`
Disables the firewall and restores default pf configuration.

**Usage:**
```bash
./pfreset.sh
```

Use this if you need to manually clean up the firewall or troubleshoot connectivity issues.

## Firewall Configuration

### Packet Filter Rules
The `claude_firewall` anchor applies these rules:

```pf
# Allow DNS queries
pass quick proto udp from $container_network to any port 53

# Allow SSH
pass quick proto tcp from $container_network to any port 22

# Allow container-to-container communication
pass quick from $container_network to $container_network

# Allow traffic to allowed destinations
pass quick proto tcp from $container_network to <allowed_destinations> keep state
pass quick proto udp from $container_network to <allowed_destinations> keep state

# Block everything else
block return from $container_network to any
block return from any to $container_network
```


## Customization

### Installing Additional Tools
The container has `sudo` access, so you can install packages as needed:

```bash
# Inside the container
sudo apk add nodejs npm    # Node.js
sudo apk add python3       # Python
sudo apk add go            # Go
```

### Modifying the Dockerfile
To permanently add tools, edit the Dockerfile and rebuild:

```dockerfile
RUN apk add --no-cache \
  nodejs \
  npm \
  # ... other packages
```

Then rebuild:
```bash
container build -t claudepine:latest .
```

### Changing Resource Limits
Edit `claude-dev.sh` to adjust memory and CPU allocation:

```bash
--memory 16g \    # Increase memory
--cpus 8 \        # Increase CPU cores
```

## Troubleshooting

### Container Can't Reach Network
1. Check if firewall is active from outside of the container: `sudo pfctl -s info`
2. Verify allowed IPs are populated: `cat /etc/pf.anchors/allowed_destinations`
3. Check pf rules: `sudo pfctl -s rules -a claude_firewall`
4. Test DNS: `container exec -it claude-alpine ping 8.8.8.8`

### Firewall Won't Enable
1. Reset firewall: `./pfreset.sh`
2. Check pf configuration syntax: `sudo pfctl -nf /etc/pf.anchors/claude_firewall`

### Permission Errors
Some operations require sudo access. The scripts will prompt for your password when needed.

## Performance Notes

This setup is optimized for Apple's native container runtime on macOS. Performance characteristics:
- Fast filesystem operations (native I/O)
- Low memory overhead (Alpine Linux)
- Minimal network latency (host-level firewall)

For performance comparisons with Docker/Colima, see the [blog post](https://shipit.peterhollmer.com).

## Contributing

Contributions welcome! Please:
1. Test changes thoroughly
2. Update documentation
3. Follow existing code style
4. Explain security implications

## License

MIT License

## Acknowledgments

- Based on Anthropic's Claude Code reference container
- Uses OpenBSD's Packet Filter (pf)
- Built for macOS Apple Container Runtime

## Related Resources

- [Claude Code Documentation](https://docs.claude.com/en/docs/claude-code)
- [OpenBSD PF User's Guide](https://www.openbsd.org/faq/pf/)
- [Apple Container Runtime](https://developer.apple.com/documentation/virtualization)

---

**Note:** This is an experimental setup. The Apple container runtime and Claude Code integration are both evolving. Report issues and share improvements!
