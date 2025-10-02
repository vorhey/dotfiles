export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="light-colors"
plugins=(git fzf zsh-autosuggestions)
source $ZSH/oh-my-zsh.sh

# FZF configuration
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border"
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_CTRL_R_OPTS="--preview=''"
export FZF_ALT_C_COMMAND="fd --type d --hidden --follow --exclude .git"
if command -v bat >/dev/null; then
  export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always {}'"
else
  export FZF_CTRL_T_OPTS="--preview 'cat {}'"
fi

# FZF functions
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

# NVM configuration
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion

# Path configurations
export PATH="$HOME/bin:$PATH"
export PATH="$PATH:/opt/nvim-linux64/bin"
export PATH="$PATH:/opt/nvim-linux-x86_64/bin"
export PATH=$PATH:/usr/local/go/bin
export PATH="$HOME/.local/bin:$PATH"
export PATH="$PATH:/home/$USER/go/bin"

# Editor configurations
export EDITOR=nvim
export SUDO_EDITOR=nvim

# Tmux configurations
alias tm="tmux attach -t default || tmux new -s default"
export TMUX_TMPDIR='/tmp'

# pnpm
export PNPM_HOME="/home/jorge/.local/share/pnpm"
case ":$PATH:" in
*":$PNPM_HOME:"*) ;;
*) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# colorls
COLORLS_PATH=$(gem which colorls)
if [ -n "$COLORLS_PATH" ]; then
  source $(dirname $COLORLS_PATH)/tab_complete.sh
  alias l='colorls -la'
fi

alias lt='eza --tree --level=2 --long --header --git --icons --group-directories-first --ignore-glob="node_modules|dist|build|target|.git|bin|obj|Debug|Release|.next|.nuxt|.vscode|.idea|coverage|__pycache__|*.pyc"'
alias ltt='eza --tree --level=3 --long --header --git --icons --group-directories-first --ignore-glob="node_modules|dist|build|target|.git|bin|obj|Debug|Release|.next|.nuxt|.vscode|.idea|coverage|__pycache__|*.pyc"'
alias ltf='eza --tree --long --header --git --icons --group-directories-first --ignore-glob="node_modules|dist|build|target|.git|bin|obj|Debug|Release|.next|.nuxt|.vscode|.idea|coverage|__pycache__|*.pyc"'

alias dp='[ "$(docker ps -aq)" ] && docker stop $(docker ps -aq) || true; [ "$(docker container ls -aq)" ] && docker container rm -f $(docker container ls -aq) || true; [ "$(docker volume ls -q)" ] && docker volume rm -f $(docker volume ls -q) || true'

alias lz='lazygit'

alias cls='clear && printf "\033[3J"'

export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

# bun completions
[ -s "/home/jorge/.bun/_bun" ] && source "/home/jorge/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
eval "$(zoxide init zsh)"

# source
source ~/dotfiles/.zsh_history_ignore
source ~/.sdkman/bin/sdkman-init.sh

# cli rename
_tmux_with_prefix_title() {
  local prefix="$1"
  shift

  if [ -n "$TMUX" ]; then
    local node_path=$(command -v node)
    local cmd_path=$(command which "$prefix" 2>/dev/null | head -1)
    (exec -a "$prefix" "$node_path" "$cmd_path" "$@")
  else
    command "$prefix" "$@"
  fi
}

# Simpler wrappers - using the same name for both prefix and command
codex() { _tmux_with_prefix_title codex "$@"; }
gemini() { _tmux_with_prefix_title gemini "$@"; }
qwen() { _tmux_with_prefix_title qwen "$@"; }
copilot() { _tmux_with_prefix_title copilot "$@"; }

# --- Warp tab title (no tmux) -------------------------------------------------
# Send OSC title: ESC ] 0 ; <title> BEL
_warp_set_title() {
  local t="${1//$'\n'/ }"
  printf '\033]0;%s\007' "$t"
}

# Optional helpers reusing your scripts
_icon_for() {
  # map a command to an icon via your existing script
  "$HOME/dotfiles/get_process_icon.sh" "$1" 2>/dev/null || echo ""
}

_project_root_name() {
  local root="$("$HOME/dotfiles/get_project_root.sh" "$PWD" 2>/dev/null)"
  [[ -n "$root" ]] && basename "$root" || basename "$PWD"
}

_git_branch() {
  command git branch --show-current 2>/dev/null
}

# Idle title (shown at prompt)
_pretty_idle_title() {
  local base proj branch
  base="${PWD##*/}"
  proj="$(_project_root_name)"
  branch="$(_git_branch)"
  [[ -n "$branch" ]] && branch=" · ${branch}"
  echo "${base} · ${proj}${branch}"
}

# Busy title (before running a command)
_pretty_busy_title() {
  local proj="$(_project_root_name)"
  local cmd="${1%% *}" # first token of the command line
  local icon="$(_icon_for "$cmd")"
  if [[ -n "$icon" ]]; then
    echo "${icon}  $1 · ${proj}"
  else
    echo "$1 · ${proj}"
  fi
}

# Hook into zsh lifecycle
_preexec_title() { _warp_set_title "$(_pretty_busy_title "$1")"; }
_precmd_title() { _warp_set_title "$(_pretty_idle_title)"; }

# Register hooks (compatible with other plugins)
precmd_functions+=(_precmd_title)
preexec_functions+=(_preexec_title)

# If oh-my-zsh tries to manage titles, ensure we’re in charge
export DISABLE_AUTO_TITLE="true"
# ------------------------------------------------------------------------------
