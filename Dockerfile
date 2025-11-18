FROM alpine:latest
ARG TZ=America/Chicago
ENV TZ="$TZ"
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# Set required environment variable for Alpine native build
ENV USE_BUILTIN_RIPGREP=0

# Install basic development tools and Claude CLI dependencies
RUN apk add --no-cache \
  curl \
  ca-certificates \
  git \
  zsh \
  bash \
  fzf \
  github-cli \
  jq \
  lazygit \
  micro \
  vim \
  sudo \
  less \
  procps \
  mandoc \
  man-pages \
  unzip \
  gnupg \
  wget \
  tmux \
  libgcc \
  libstdc++ \
  ripgrep

# Install Claude CLI
RUN curl -fsSL https://claude.ai/install.sh | bash && \
  chmod +x /root/.local/bin/claude && \
  cp /root/.local/bin/claude /usr/local/bin/

# Create non-root user
ARG USERNAME=claude
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN addgroup -g $USER_GID $USERNAME && \
  adduser -D -u $USER_UID -G $USERNAME -s /bin/zsh $USERNAME && \
  echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create directories
RUN mkdir -p /commandhistory /workspace && \
  touch /commandhistory/.bash_history /commandhistory/.zsh_history && \
  chown -R $USERNAME:$USERNAME /commandhistory /workspace

# Create entrypoint script to fix permissions after volume mounts
RUN echo '#!/bin/sh' > /entrypoint.sh && \
  echo 'sudo chown -R claude:claude /commandhistory 2>/dev/null || true' >> /entrypoint.sh && \
  echo 'sudo chown -R claude:claude /home/claude/.config 2>/dev/null || true' >> /entrypoint.sh && \
  echo 'sudo chown -R claude:claude /home/claude/.ssh 2>/dev/null || true' >> /entrypoint.sh && \
  echo 'sudo chmod 700 /home/claude/.ssh 2>/dev/null || true' >> /entrypoint.sh && \
  echo 'sudo chmod 600 /home/claude/.ssh/* 2>/dev/null || true' >> /entrypoint.sh && \
  echo 'exec "$@"' >> /entrypoint.sh && \
  chmod +x /entrypoint.sh

USER $USERNAME

ENV DEVCONTAINER=true
WORKDIR /workspace

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
  echo '' >> /home/$USERNAME/.zshrc && \
  echo '# Network connectivity check' >> /home/$USERNAME/.zshrc && \
  echo 'curl https://api.github.com/zen' >> /home/$USERNAME/.zshrc && \
  chown $USERNAME:$USERNAME /home/$USERNAME/.zshrc

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/zsh"]
