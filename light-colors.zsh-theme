# Main prompt arrow
PROMPT="%(?:%{$fg_bold[cyan]%}➜ :%{$fg_bold[yellow]%}➜ )"
# Current directory
PROMPT+=' %{$fg[blue]%}%c%{$reset_color%} $(git_prompt_info)'

# Git prompt styling
ZSH_THEME_GIT_PROMPT_PREFIX="%{$FG[189]%}git:(%{$fg[cyan]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_DIRTY="%{$FG[189]%}) %{$fg[yellow]%}✗"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$FG[189]%})"
