#!/bin/bash

# Create backup of existing bashrc if it exists
if [ -f ~/.bashrc ]; then
    cp ~/.bashrc ~/.bashrc.backup
fi

# Install required packages
sudo dnf install -y \
    bash-completion \
    vim \
    git \
    curl \
    wget \
    tmux \
    make \
    gcc \
    python3-pip

# Setup bash completion for Docker
sudo curl -L https://raw.githubusercontent.com/docker/compose/master/contrib/completion/bash/docker-compose -o /usr/share/bash-completion/completions/docker-compose
sudo curl -L https://raw.githubusercontent.com/docker/cli/master/contrib/completion/bash/docker -o /usr/share/bash-completion/completions/docker

# Create new bashrc
cat > ~/.bashrc << 'EOL'
# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Don't put duplicate lines or lines starting with space in the history
HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s histappend
shopt -s checkwinsize

# Set prompt
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Enable color support and aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Useful aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias d='docker'
alias dc='docker-compose'
alias dps='docker ps'
alias dim='docker images'

# Enable programmable completion features
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# Load Docker completions
for f in /usr/share/bash-completion/completions/docker*; do
    if [ -f "$f" ]; then
        . "$f"
    fi
done

# Environment variables
export PATH=$PATH:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin
export ODBCSYSINI=/etc
export ODBCINI=/etc/odbc.ini
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
export BUILDKIT_PROGRESS=plain
export EDITOR=vim

# WSL-specific settings
if grep -qi microsoft /proc/version; then
    # Windows paths
    export DOCKER_HOST=tcp://localhost:2375
    # Auto CD to project directory
    if [ "$PWD" = "$HOME" ]; then
        cd /home/jean-sebastien/PaQBoT_Base
    fi
fi

# Custom functions
parse_git_branch() {
    git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}

# Enhanced prompt with git branch
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[33m\]$(parse_git_branch)\[\033[00m\]\$ '

EOL

# Create inputrc for better completion
cat > ~/.inputrc << 'EOL'
# Make Tab autocomplete regardless of filename case
set completion-ignore-case on

# List all matches in case multiple possible completions are possible
set show-all-if-ambiguous on

# Immediately add a trailing slash when autocompleting symlinks to directories
set mark-symlinked-directories on

# Use the text that has already been typed as the prefix for searching through
# commands (i.e. more intelligent Up/Down behavior)
"\e[B": history-search-forward
"\e[A": history-search-backward

# Do not autocomplete hidden files unless the pattern explicitly begins with a dot
set match-hidden-files off

# Show all autocomplete results at once
set page-completions off

# If there are more than 200 possible completions for a word, ask to show them all
set completion-query-items 200

# Show extra file information when completing, like `ls -F` does
set visible-stats on

# Be more intelligent when autocompleting by also looking at the text after
# the cursor. For example, when the current line is "cd ~/src/mozil", and
# the cursor is on the "z", pressing Tab will not autocomplete it to "cd
# ~/src/mozillail", but to "cd ~/src/mozilla".
set skip-completed-text on

# Allow UTF-8 input and output, instead of showing stuff like $'\0123\0456'
set input-meta on
set output-meta on
set convert-meta off
EOL

# Make the script executable
chmod +x ~/.bashrc

# Source the new configuration
source ~/.bashrc

echo "Shell setup complete. Please restart your terminal or run 'source ~/.bashrc' to apply changes."