FROM debian:trixie-slim
ARG TZ=America/Chicago
ENV TZ="$TZ"
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# Install basic development tools
RUN apt-get update && apt-get install -y --no-install-recommends \
  curl \
  ca-certificates \
  git \
  zsh \
  bash \
  fzf \
  gh \
  iptables \
  ipset \
  iproute2 \
  dnsutils \
  aggregate \
  jq \
  lazygit \
  micro \
  vim \
  sudo \
  less \
  procps \
  man-db \
  unzip \
  gnupg2 \
  wget \
  tmux \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Node.js 20.19.5 from NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Claude CLI to system location
RUN curl -fsSL https://claude.ai/install.sh | bash && \
    cp /root/.local/bin/claude /usr/local/bin/ && \
    chmod +x /usr/local/bin/claude

# Create non-root user
ARG USERNAME=claude
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN groupadd --gid $USER_GID $USERNAME && \
    useradd --uid $USER_UID --gid $USER_GID -m $USERNAME && \
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create directories
RUN mkdir -p /commandhistory /workspace && \
    touch /commandhistory/.bash_history /commandhistory/.zsh_history && \
    chown -R $USERNAME:$USERNAME /commandhistory /workspace

# Create entrypoint script to fix permissions after volume mounts
RUN echo '#!/bin/sh' > /entrypoint.sh && \
    echo 'sudo chown -R claude:claude /commandhistory 2>/dev/null || true' >> /entrypoint.sh && \
    echo 'exec "$@"' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

ENV DEVCONTAINER=true
WORKDIR /workspace
USER $USERNAME
ENTRYPOINT ["/entrypoint.sh"]

# Set PATH
ENV PATH="/home/$USERNAME/.local/bin:$PATH"
ENV SHELL=/bin/zsh
ENV EDITOR=micro
ENV VISUAL=micro

# Configure zsh history
ENV HISTFILE=/commandhistory/.zsh_history
ENV HISTSIZE=10000
ENV SAVEHIST=20000

# Create .zshrc to configure history saving and fzf integration
RUN echo 'export HISTFILE=/commandhistory/.zsh_history' >> /home/$USERNAME/.zshrc && \
    echo 'export HISTSIZE=10000' >> /home/$USERNAME/.zshrc && \
    echo 'export SAVEHIST=20000' >> /home/$USERNAME/.zshrc && \
    echo 'setopt INC_APPEND_HISTORY' >> /home/$USERNAME/.zshrc && \
    echo 'setopt SHARE_HISTORY' >> /home/$USERNAME/.zshrc && \
    echo 'setopt HIST_IGNORE_DUPS' >> /home/$USERNAME/.zshrc && \
    echo 'setopt HIST_FIND_NO_DUPS' >> /home/$USERNAME/.zshrc && \
    echo '' >> /home/$USERNAME/.zshrc && \
    echo '# fzf integration' >> /home/$USERNAME/.zshrc && \
    echo 'source <(fzf --zsh)' >> /home/$USERNAME/.zshrc && \
    chown $USERNAME:$USERNAME /home/$USERNAME/.zshrc

CMD ["/bin/zsh"]
