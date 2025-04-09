#!/bin/bash

# Function to create symlink
create_symlink() {
    local source="$1"
    local target="$2"

    # Create parent directory if it doesn't exist
    mkdir -p "$(dirname "$target")"

    # Remove existing file/symlink if it exists
    if [ -e "$target" ] || [ -L "$target" ]; then
        rm -f "$target"
    fi

    # Create the symlink
    ln -s "$source" "$target"
    echo "Created symlink: $target -> $source"
}

# Create symlinks
create_symlink ~/.config/nvim nvim
create_symlink ~/dotfiles/.zshrc ~/.zshrc
create_symlink ~/dotfiles/.tmux.conf ~/.tmux.conf
create_symlink ~/dotfiles/dark_colors.yaml ~/.config/colorls/dark_colors.yaml
create_symlink ~/dotfiles/light-colors.zsh-theme ~/.oh-my-zsh/themes/light-colors.zsh-theme
