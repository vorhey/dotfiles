# Theme colors based on TERM_COLOR environment variable
if [[ "$TERM_COLOR" == "dark" ]]; then
    # Dark theme colors (One Dark palette)
    PRIMARY_COLOR="075"      # Bright blue (#61AFEF)
    SECONDARY_COLOR="176"    # Purple (#C678DD)
    ERROR_COLOR="204"        # Red (#E06C75)
else
    # Light theme colors (default)
    PRIMARY_COLOR="117"      # Soft blue
    SECONDARY_COLOR="025"    # Darker blue
    ERROR_COLOR="red"
fi

# Main prompt arrow
PROMPT="%(?:%{$fg_bold[$PRIMARY_COLOR]%}➜ :%{$fg_bold[$ERROR_COLOR]%}➜ )"
# Current directory
PROMPT+=' %{$fg[$PRIMARY_COLOR]%}%c%{$reset_color%} $(git_prompt_info)'

# Git prompt styling
ZSH_THEME_GIT_PROMPT_PREFIX="%{$FG[$SECONDARY_COLOR]%}git:(%{$fg[$PRIMARY_COLOR]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_DIRTY="%{$FG[$SECONDARY_COLOR]%}) %{$fg[$ERROR_COLOR]%}✗"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$FG[$SECONDARY_COLOR]%})"
