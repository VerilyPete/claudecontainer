# Claude Code Container

A secure, isolated container environment for running [Claude Code](https://claude.ai/claude-code) with network-level sandboxing.

## Overview

This project provides a containerized environment for Claude Code with strict network egress controls. The setup ensures Claude Code can only access explicitly whitelisted domains, providing an additional layer of security for AI-assisted development workflows. This is intended to be ideal for [YOLO mode](https://simonwillison.net/2025/Sep/30/designing-agentic-loops/#the-joy-of-yolo-mode).

Built for Apple's container runtime but adaptable to other platforms with modifications.

## Features

- **Network Sandboxing**: Firewall rules restrict outbound connections to trusted domains only
- **Pre-configured Development Environment**: Includes common tools (git, gh, lazygit, micro, vim, zsh, fzf)
- **Persistent State**: Command history and home directory persist across container restarts
- **Simple Management**: Single script to create, start, and attach to containers
- **Debian Base**: Uses Debian Trixie Slim for stability and package availability

## Components

### Dockerfile

Builds a container image with:
- Debian Trixie Slim base
- Claude CLI (standalone installer from claude.ai)
- Development tools: git, gh, lazygit, micro, vim, zsh, fzf, tmux
- Network tools: iptables, ipset, iproute2, dnsutils, aggregate
- Non-root user (`claude`) with sudo access
- Persistent volumes for command history and workspace

### init-firewall.sh

Network security script that:
- Configures iptables-legacy for compatibility with Apple container runtime
- Fetches GitHub IP ranges dynamically from their API
- Resolves and whitelists specific domains:
  - `github.com` (via API meta endpoint)
  - `registry.npmjs.org`
  - `api.anthropic.com`
  - `sentry.io`
  - `statsig.anthropic.com` / `statsig.com`
  - `marketplace.visualstudio.com`
  - `vscode.blob.core.windows.net`
  - `update.code.visualstudio.com`
- Uses ipset for efficient IP address management
- Allows localhost and SSH access
- Validates firewall configuration on startup
- Drops all other traffic by default

### claude-dev.sh

Container lifecycle management script that:
- Checks if container `claude-dev` exists
- Attaches to running containers
- Starts stopped containers
- Creates new containers from the `claude` image with:
  - Persistent volumes for home directory and command history
  - Current directory mounted at `/workspace`
  - 8GB memory limit
  - 4 CPU limit

## Quick Start

### 1. Build the Image

Start the container buildkit image with 8GB memory limit (4GB may work, I just use 8GB and stop the builder afterward.)

```bash
container builder start -m 8G
```

Build the container image

```bash
container build -t claude:latest .
```

### 2. Run the Container

```bash
./claude-dev.sh
```

The script will automatically:
- Create a new container if none exists
- Start a stopped container
- Attach to a running container

### 3. Use Claude Code

Once inside the container, run Claude in YOLO mode:

```bash
IS_SANDBOX=1 claude --dangerously-skip-permissions
```

## How It Works

1. **Container Creation**: The Dockerfile creates an image with all necessary tools and the Claude CLI
2. **Entrypoint**: On container start, the entrypoint script:
   - Runs `init-firewall.sh` to configure network restrictions
   - Fixes permissions on mounted volumes
   - Launches the shell
3. **Network Isolation**: iptables rules ensure only whitelisted domains are accessible
4. **State Persistence**: Named volumes preserve command history and home directory across restarts

## Firewall Details

The firewall configuration:
- **Default Policy**: DROP all INPUT/OUTPUT/FORWARD traffic
- **Allowed**:
  - Localhost traffic
  - DNS queries (UDP port 53)
  - SSH connections (TCP port 22)
  - Host network traffic (detected via default route)
  - Traffic to whitelisted IPs/domains
- **Verification**: Tests blocking example.com and allowing api.github.com on startup

## Customization

### Adding Allowed Domains

Edit `init-firewall.sh` and add domains to the `for domain in` loop around line 73:

```bash
for domain in \
    "registry.npmjs.org" \
    "api.anthropic.com" \
    "your-domain.com"; do
```

### Modifying Container Resources

Edit `claude-dev.sh` to adjust memory/CPU limits:

```bash
--memory 8g \
--cpus 4 \
```

### Installing Additional/Different Tools

Add packages to the Dockerfile's `apt-get install` command around line 8.

## Differences from Anthropic's Reference Dockerfile

This implementation differs from [Anthropic's reference .devcontainer](https://github.com/anthropics/claude-code/tree/main/.devcontainer) in several ways:

- **Base Image**: Uses `debian:trixie-slim` instead of a Node.js image
- **Claude Installation**: Uses the standalone installer instead of npm
- **fzf**: Updated installation method for Debian
- **Additional Tools**: Includes lazygit, micro, aggregate, and other personal preferences
- **Firewall**: Implements network sandboxing via iptables-legacy for compatibility with Apple containers
- **Entrypoint**: Runs firewall initialization as part of entrypoint

## Security Considerations

- The firewall provides defense-in-depth but is not foolproof
- IP addresses may change; the script dynamically resolves them on startup
- GitHub IP ranges are aggregated to reduce ipset entries
- Sudo access is granted to the `claude` user for flexibility
- Only `init-firewall.sh` requires root privileges via sudoers

## Troubleshooting

### Container won't start
Check firewall initialization logs:
```bash
container logs claude-dev
```

### Can't reach a required domain
Add the domain to `init-firewall.sh` and rebuild:
```bash
container stop claude-dev
container rm claude-dev
container build -t claude:latest .
./claude-dev.sh
```

### Firewall verification fails
The script validates that:
- `example.com` is blocked (expected)
- `api.github.com` is accessible (required)

If validation fails, check your network connection and DNS resolution.

## Requirements

- Apple container runtime (or Docker/Podman with modifications)
- Internet connection for building image and resolving IP addresses
- Basic understanding of container management

## License

This project is provided as-is for personal use. Claude Code and related trademarks are property of Anthropic.

## Acknowledgments

Based on [Anthropic's reference .devcontainer](https://github.com/anthropics/claude-code/tree/main/.devcontainer) with adaptations for Apple container compatibility.
