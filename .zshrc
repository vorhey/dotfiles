# =============================================================================
# ZSH CONFIGURATION
# =============================================================================

# Path to Oh My Zsh installation
export ZSH="$HOME/.oh-my-zsh"

# ZSH AI plugin configuration
export ZSH_AI_PROVIDER="gemini"

# Theme and plugins
ZSH_THEME="light-colors"
plugins=(git fzf zsh-autosuggestions zsh-ai)

# Prevent Oh My Zsh from forcing username@host titles; we'll manage Warp titles below
DISABLE_AUTO_TITLE="true"

# Autosuggestions custom color
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=245'

# Initialize Oh My Zsh
source $ZSH/oh-my-zsh.sh

# =============================================================================
# FZF CONFIGURATION
# =============================================================================

# Load fzf key bindings and fuzzy completion
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# FZF default options
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border"

# FZF default command for file searching
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'

# FZF command for Ctrl+T (files)
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# FZF command for Ctrl+R (history)
export FZF_CTRL_R_OPTS="--preview=''"

# FZF command for Alt+C (directories)
export FZF_ALT_C_COMMAND="fd --type d --hidden --follow --exclude .git"

# FZF preview options for file selection
if command -v bat >/dev/null; then
  export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always {}'"
else
  export FZF_CTRL_T_OPTS="--preview 'cat {}'"
fi

# FZF utility functions
fcd() {
  local dir
  dir=$(fd --type d --hidden --follow --exclude .git | fzf --preview 'eza --tree --level=1 {}') && cd "$dir"
}

fe() {
  local file
  file=$(fzf --preview 'bat --style=numbers --color=always {}') && ${EDITOR:-nvim} "$file"
}

fkill() {
  local pid
  pid=$(ps -ef | sed 1d | fzf -m | awk '{print $2}')
  if [ "x$pid" != "x" ]; then
    echo $pid | xargs kill -${1:-9}
  fi
}

export FZF_DEFAULT_OPTS="
    --color=bg:-1,bg+:-1,spinner:#6c6f93,hl:#FA6EBD
    --color=fg:#c0c0c0,header:#FA6EBD,info:#FA6EBD,pointer:#A98FD9
    --color=marker:#d70000,fg+:#c0c0c0,prompt:#FA6EBD,hl+:#A98FD9
    --color=border:#CFCFCF
    --pointer='▌'
    --reverse
    --border
    --preview-window=border-rounded
  "

# =============================================================================
# NODE VERSION MANAGER (NVM)
# =============================================================================

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion

# =============================================================================
# PATH CONFIGURATION
# =============================================================================

# Add custom paths to PATH
export PATH="$HOME/bin:$PATH"
export PATH="$PATH:/opt/nvim-linux64/bin"
export PATH="$PATH:/opt/nvim-linux-x86_64/bin"
export PATH=$PATH:/usr/local/go/bin
export PATH="$HOME/.local/bin:$PATH"
export PATH="$PATH:/home/$USER/go/bin"

# =============================================================================
# EDITOR CONFIGURATION
# =============================================================================

export EDITOR=nvim
export SUDO_EDITOR=nvim

# =============================================================================
# TMUX CONFIGURATION
# =============================================================================

alias tm="tmux attach -t default || tmux new -s default"
export TMUX_TMPDIR='/tmp'

# =============================================================================
# PNPM CONFIGURATION
# =============================================================================

export PNPM_HOME="/home/jorge/.local/share/pnpm"
case ":$PATH:" in
*":$PNPM_HOME:"*) ;;
*) export PATH="$PNPM_HOME:$PATH" ;;
esac

# =============================================================================
# ALIASES
# =============================================================================

# File listing aliases with eza
alias l='eza -la --header --git --icons --group-directories-first'
alias lt='eza --tree --level=2 --long --header --git --icons --group-directories-first --ignore-glob="node_modules|dist|build|target|.git|bin|obj|Debug|Release|.next|.nuxt|.vscode|.idea|coverage|__pycache__|*.pyc"'
alias ltt='eza --tree --level=3 --long --header --git --icons --group-directories-first --ignore-glob="node_modules|dist|build|target|.git|bin|obj|Debug|Release|.next|.nuxt|.vscode|.idea|coverage|__pycache__|*.pyc"'
alias ltf='eza --tree --long --header --git --icons --group-directories-first --ignore-glob="node_modules|dist|build|target|.git|bin|obj|Debug|Release|.next|.nuxt|.vscode|.idea|coverage|__pycache__|*.pyc"'

# Docker cleanup alias
alias dp='[ "$(docker ps -aq)" ] && docker stop $(docker ps -aq) || true; [ "$(docker container ls -aq)" ] && docker container rm -f $(docker container ls -aq) || true; [ "$(docker volume ls -q)" ] && docker volume rm -f $(docker volume ls -q) || true'

# Other useful aliases
alias lz='lazygit'
alias c='clear && printf "\033[3J"'

# =============================================================================
# XDG BASE DIRECTORY SPECIFICATION
# =============================================================================

export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

# =============================================================================
# BUN CONFIGURATION
# =============================================================================

# Bun completions
[ -s "/home/jorge/.bun/_bun" ] && source "/home/jorge/.bun/_bun"

# Bun path
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# =============================================================================
# ZOXIDE CONFIGURATION
# =============================================================================

eval "$(zoxide init zsh)"

# =============================================================================
# CUSTOM CONFIGURATIONS
# =============================================================================

# Source custom configurations
source ~/dotfiles/.zsh_history_ignore
source ~/.sdkman/bin/sdkman-init.sh

# =============================================================================
# WARP TERMINAL TABS
# =============================================================================
# Warp tab titles with process icons
if [[ "$TERM_PROGRAM" == "WarpTerminal" ]]; then
  autoload -Uz add-zsh-hook

  _warp_title() {
    local cmd=${1:-zsh}
    local icon=$(bash ~/dotfiles/get_process_icon.sh "$cmd" 2>/dev/null | tr -d '\n\r' | xargs)
    printf '\033]0;%s\007' "${icon:+$icon    }$cmd"
  }

  _warp_precmd() { _warp_title zsh; }
  _warp_preexec() { _warp_title "${1%% *}"; }

  add-zsh-hook precmd _warp_precmd
  add-zsh-hook preexec _warp_preexec
fi

# =============================================================================
# CLI RENAME FUNCTIONS (FOR TMUX)
# =============================================================================

# Helper function to set process title in tmux
_tmux_with_prefix_title() {
  local prefix="$1"
  shift

  if [ -n "$TMUX" ]; then
    local cmd_path=$(whence -p "$prefix" 2>/dev/null)
    [ -z "$cmd_path" ] && return 1
    [[ "$cmd_path" == "$0" ]] && return 2
    if head -1 "$cmd_path" 2>/dev/null | grep -qE '^#!.*node'; then
      local node_path=$(command -v node)
      (exec -a "$prefix" "$node_path" "$cmd_path" "$@")
    else
      (exec -a "$prefix" "$cmd_path" "$@")
    fi
  else
    command "$prefix" "$@"
  fi
}

# Wrapper functions for CLI tools with custom titles
codex() { _tmux_with_prefix_title codex "$@"; }
gemini() { _tmux_with_prefix_title gemini "$@"; }
qwen() { _tmux_with_prefix_title qwen "$@"; }
copilot() { _tmux_with_prefix_title copilot "$@"; }
