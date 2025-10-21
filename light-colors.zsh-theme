# Main prompt arrow
PROMPT="%(?:%{$fg_bold[117]%}➜ :%{$fg_bold[red]%}➜ )"
# Current directory
PROMPT+=' %{$fg[117]%}%c%{$reset_color%} $(git_prompt_info)'

# Git prompt styling
ZSH_THEME_GIT_PROMPT_PREFIX="%{$FG[025]%}git:(%{$fg[117]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_DIRTY="%{$FG[025]%}) %{$fg[red]%}✗"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$FG[025]%})"
