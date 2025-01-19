export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
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
export PATH=$PATH:/usr/local/go/bin
export PATH="$HOME/.local/bin:$PATH"
export PATH="$PATH:/home/$USER/go/bin"

# Editor configurations
export EDITOR=nvim
export SUDO_EDITOR=nvim

# Tmux configurations
alias tmux="tmux attach -t default || tmux new -s default"
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
