#!/bin/bash

# Create backup of existing bashrc if it exists
if [ -f ~/.bashrc ]; then
    cp ~/.bashrc ~/.bashrc.backup
fi

# Install required packages - use yum for OpenEuler compatibility
sudo yum install -y \
    bash-completion \
    vim \
    git \
    curl \
    wget \
    tmux \
    make \
    gcc \
    python3-pip || echo "Package installation failed, continuing anyway"

# Setup bash completion for Docker - create directories if they don't exist
sudo mkdir -p /usr/share/bash-completion/completions/
sudo curl -L https://raw.githubusercontent.com/docker/compose/master/contrib/completion/bash/docker-compose -o /usr/share/bash-completion/completions/docker-compose || echo "Failed to download docker-compose completion"
sudo curl -L https://raw.githubusercontent.com/docker/cli/master/contrib/completion/bash/docker -o /usr/share/bash-completion/completions/docker || echo "Failed to download docker completion"

# Create required directories
mkdir -p /home/jean-sebastien/PaQBoT_Base/cloud-setup/certs

# Configure ODBC if the directory exists
sudo mkdir -p /etc
sudo bash -c 'cat > /etc/odbcinst.ini << EOL
[ODBC Driver 17 for SQL Server]
Description=Microsoft ODBC Driver 17 for SQL Server
Driver=/opt/microsoft/msodbcsql17/lib64/libmsodbcsql-17.10.so.1.1
UsageCount=1
EOL'

# Configure Docker buildx
mkdir -p /home/jean-sebastien/.docker/buildx
cat > /home/jean-sebastien/.docker/buildx/buildx.toml << EOL
[registry."docker.io"]
  mirrors = ["harbor.local:443"]

[registry."harbor.local:443"]
  http = true
  insecure = true

[[worker.oci.gcpolicy]]
  keepDuration = "48h"
  keepBytes = 10000000000

[worker.oci]
  enabled = true
  platforms = ["linux/amd64", "linux/arm64"]

[worker.containerd]
  enabled = true
  platforms = ["linux/amd64", "linux/arm64"]
EOL

# Create new bashrc - simplified for OpenEuler compatibility
cat > ~/.bashrc << 'EOL'
# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# History settings
HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s histappend
shopt -s checkwinsize

# Basic prompt without fancy elements
PS1='\u@\h:\w\$ '

# Enable color support and aliases
alias ls='ls --color=auto'
alias grep='grep --color=auto'

# Useful aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias d='docker'
alias dc='docker-compose'
alias dps='docker ps'
alias dim='docker images'

# Enable bash completion if available
if [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

# Simple git branch parsing function
parse_git_branch() {
    git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}

# Enhanced prompt with git branch - simple version
PS1='\u@\h:\w$(parse_git_branch)\$ '

# Environment variables
export PATH=$PATH:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin
export ODBCSYSINI=/etc
export ODBCINI=/etc/odbc.ini
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
export BUILDKIT_PROGRESS=plain
export EDITOR=vim
export TERM=xterm-256color

# Docker settings
export DOCKER_HOST=unix:///var/run/docker.sock
export DOCKER_CONTEXT=default

# Auto CD to project directory
if [ "$PWD" = "$HOME" ]; then
    cd /home/jean-sebastien/PaQBoT_Base
fi
EOL

# Create simple inputrc for better completion
cat > ~/.inputrc << 'EOL'
# Make Tab autocomplete regardless of filename case
set completion-ignore-case on
# List all matches in case multiple possible completions are possible
set show-all-if-ambiguous on
# Use the text that has already been typed as the prefix for searching through commands
"\e[B": history-search-forward
"\e[A": history-search-backward
EOL

# Make the script executable
chmod +x ~/.bashrc

# Configure bash environment with a simplified profile
cat > /home/jean-sebastien/.bash_profile << 'EOL'
# Source bashrc
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

# Environment variables
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
export DOCKER_HOST=unix:///var/run/docker.sock

# Auto CD to project directory
if [ "$PWD" = "$HOME" ]; then
    cd /home/jean-sebastien/PaQBoT_Base
fi
EOL

# Set proper permissions
chmod 644 /home/jean-sebastien/.bash_profile
chmod 644 /home/jean-sebastien/.bashrc
chmod -R 755 /home/jean-sebastien/PaQBoT_Base/cloud-setup

# Configure Docker daemon - create directory if it doesn't exist
sudo mkdir -p /etc/docker
sudo bash -c 'cat > /etc/docker/daemon.json << EOL
{
    "insecure-registries": [
        "harbor.local:443",
        "hubproxy.docker.internal:5555",
        "::1/128",
        "127.0.0.0/8"
    ],
    "experimental": false,
    "features": {
        "buildkit": true
    },
    "builder": {
        "gc": {
            "enabled": true,
            "defaultKeepStorage": "20GB"
        }
    },
    "default-runtime": "runc",
    "log-driver": "json-file",
    "storage-driver": "overlay2"
}
EOL'

# Run a simpler command to initialize the shell
echo "Shell environment setup complete. Please run 'source ~/.bashrc' to apply changes immediately."