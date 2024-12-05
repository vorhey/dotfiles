export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)
source $ZSH/oh-my-zsh.sh

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
alias tmux="tmux attach -t main || tmux new -s main"
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
