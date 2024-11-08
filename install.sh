#!/bin/bash

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            echo $NAME
        else
            echo "Unknown Linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macOS"
    else
        echo "Unknown"
    fi
}

install_dev_tools() {
    OS=$(detect_os)
    echo "Installing development tools for $OS..."
    case $OS in
    "Ubuntu" | "Debian GNU/Linux")
        echo "Installing build-essential..."
        sudo apt update
        sudo apt install -y build-essential
        ;;
    "openSUSE Tumbleweed")
        echo "Installing development patterns..."
        sudo zypper refresh
        sudo zypper install -y -t pattern devel_basis devel_C_C++
        ;;
    "Fedora Linux")
        echo "Installing development tools..."
        sudo dnf group install -y "Development Tools" "C Development Tools and Libraries"
        sudo dnf install -y gcc gcc-c++ make
        ;;
    *)
        echo "No specific development tools installation defined for $OS."
        ;;
    esac
    echo "Development tools installation complete."
}

install_rust() {
    if ! command_exists rustc; then
        echo "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
        source $HOME/.cargo/env
        echo "Rust installed successfully."
    else
        echo "Rust is already installed."
    fi
}

install_nvm() {
    if [ ! -d "$HOME/.nvm" ]; then
        echo "Installing NVM..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        echo "NVM installed successfully."
    else
        echo "NVM is already installed."
    fi
}

install_go() {
    if ! command -v go &>/dev/null; then
        echo "Installing Go..."
        GO_VERSION=$(curl -sL 'https://go.dev/VERSION?m=text' | grep -o 'go[0-9.]*')
        if [ -z "$GO_VERSION" ]; then
            echo "Failed to retrieve Go version. Exiting."
            return 1
        fi
        FILENAME="${GO_VERSION}.linux-amd64.tar.gz"
        curl -O "https://dl.google.com/go/${FILENAME}"
        if [ $? -ne 0 ]; then
            echo "Failed to download Go package. Exiting."
            return 1
        fi
        # Install Go
        echo "Extracting Go..."
        sudo rm -rf /usr/local/go
        sudo tar -C /usr/local -xzf "${FILENAME}"
        rm "${FILENAME}"

        echo 'export PATH=$PATH:/usr/local/go/bin' >>~/.zshrc
        source ~/.zshrc

        echo "Go installed successfully."
    else
        echo "Go is already installed."
    fi
}

install_node() {
    if ! command_exists node; then
        echo "Installing node"
        . ~/.nvm/nvm.sh
        nvm install --lts
        echo "Node installed"
    else
        echo "Node is already installed."
    fi
}

install_nvim() {
    if ! command_exists nvim; then
        echo "Installing nvim"
        OS=$(detect_os)
        case $OS in
        "Fedora Linux")
            sudo dnf install -y neovim python3-neovim
            ;;
        *)
            curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
            sudo rm -rf /opt/nvim
            sudo tar -C /opt -xzf nvim-linux64.tar.gz
            echo 'export PATH="$PATH:/opt/nvim-linux64/bin"' >>~/.zshrc
            source ~/.zshrc
            ;;
        esac
        echo "nvim installed"
    else
        echo "nvim is already installed."
    fi
}

install_tmux() {
    if ! command_exists tmux; then
        echo "Installing tmux"
        OS=$(detect_os)
        case $OS in
        "Fedora Linux")
            sudo dnf install -y tmux
            ;;
        "openSUSE Tumbleweed")
            sudo zypper in tmux
            ;;
        "Ubuntu" | "Debian GNU/Linux")
            sudo apt install -y tmux
            ;;
        esac
        git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
        echo "tmux installed"
    else
        echo "tmux is already installed."
    fi
}

install_catppuccin() {
    if [ ! -d "$HOME/.config/tmux/plugins/catppuccin" ]; then
        echo "Installing Catppuccin for tmux..."
        mkdir -p ~/.config/tmux/plugins/catppuccin
        git clone https://github.com/catppuccin/tmux.git ~/.config/tmux/plugins/catppuccin/tmux
        echo "run ~/.config/tmux/plugins/catppuccin/tmux/catppuccin.tmux" >>~/.tmux.conf
        echo "Catppuccin installed successfully."
    else
        echo "Catppuccin is already installed."
    fi
}

install_tpm() {
    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
        echo "Installing tmux TPM"
        mkdir -p ~/.tmux/plugins/tpm
        git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
        echo "TPM Installed"
    else
        echo "TPM is already installed."
    fi
}

install_gitmux() {
    if ! command_exists gitmux; then
        echo "Installing Gitmux..."
        go install github.com/arl/gitmux@latest
        echo "Gitmux installed successfully."
    else
        echo "Gitmux is already installed."
    fi
}

install_lsbrelease() {
    OS=$(detect_os)
    echo "Installing lsb-release for $OS..."
    case $OS in
    "Ubuntu" | "Debian GNU/Linux")
        echo "Installing lsb-release..."
        sudo apt update
        sudo apt install -y lsb-release
        ;;
    "openSUSE Tumbleweed")
        echo "Installing lsb-release..."
        sudo zypper refresh
        sudo zypper install -y lsb-release
        ;;
    "Fedora Linux")
        echo "Installing redhat-lsb-core..."
        sudo dnf install -y redhat-lsb-core
        ;;
    *)
        echo "No specific lsb-release installation defined for $OS."
        ;;
    esac
    echo "lsb-release installation complete."
}

install_pnpm() {
    if ! command_exists pnpm; then
        echo "Installing pnpm..."
        curl -fsSL https://get.pnpm.io/install.sh | sh -
        echo "pnpm installed successfully."
    else
        echo "pnpm is already installed."
    fi
}

install_ripgrep() {
    OS=$(detect_os)
    echo "Installing ripgrep for $OS..."
    case $OS in
    "Ubuntu" | "Debian GNU/Linux")
        sudo apt install -y ripgrep
        ;;
    "openSUSE Tumbleweed")
        sudo zypper install -y ripgrep
        ;;
    "Fedora Linux")
        sudo dnf install -y ripgrep
        ;;
    *)
        echo "No specific ripgrep installation defined for $OS."
        ;;
    esac
    echo "Development tools installation complete."
}

echo "Starting installation of development tools..."

install_dev_tools
install_rust
install_nvm
install_go
install_node
install_nvim
install_tmux
install_catppuccin
install_gitmux
install_lsbrelease
install_pnpm
install_ripgrep

echo "Installation complete. Please restart your terminal or run 'source ~/.zshrc' to apply changes."
