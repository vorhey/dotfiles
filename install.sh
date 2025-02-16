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
            curl -LO https://github.com/neovim/neovim/releases/download/stable/nvim-linux-x86_64.tar.gz
            sudo rm -rf /opt/nvim
            sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
            echo 'export PATH="$PATH:/opt/nvim-linux64/bin"' >>~/.zshrc
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
        echo "tmux installed"
    else
        echo "tmux is already installed."
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

install_ruby_dev() {
    echo "Installing Ruby development tools..."
    OS=$(detect_os)
    case $OS in
    "Ubuntu" | "Debian GNU/Linux")
        sudo apt update
        sudo apt install -y ruby ruby-dev ruby-all-dev rubygems-integration
        ;;
    "openSUSE Tumbleweed")
        sudo zypper refresh
        sudo zypper install -y ruby-devel
        # Configure gem to install executables to /usr/local/bin
        sudo mkdir -p /usr/local/bin
        echo 'gem: --bindir /usr/local/bin' | sudo tee /etc/gemrc
        ;;
    "Fedora Linux")
        sudo dnf install -y ruby ruby-devel redhat-rpm-config gcc make
        ;;
    *)
        echo "No specific Ruby development tools installation defined for $OS."
        ;;
    esac
    echo "Ruby development tools installation complete."

    # Install colorls gem
    if ! command_exists colorls; then
        echo "Installing colorls gem..."
        sudo gem install colorls
        echo "colorls installed successfully."
        mkdir -p ~/.config/colorls/
    else
        echo "colorls is already installed."
    fi
}

install_eza() {
    if ! command_exists eza; then
        echo "Installing eza..."
        OS=$(detect_os)
        case $OS in
        "Ubuntu" | "Debian GNU/Linux")
            sudo apt install -y eza
            ;;
        "openSUSE Tumbleweed")
            sudo zypper install -y eza
            ;;
        "Fedora Linux")
            sudo dnf install -y eza
            ;;
        *)
            if command_exists cargo; then
                cargo install eza
            else
                echo "Neither package manager installation nor cargo is available for eza on $OS"
            fi
            ;;
        esac
        echo "eza installed successfully."
    else
        echo "eza is already installed."
    fi
}

install_lazygit() {
    if ! command_exists lazygit; then
        echo "Installing lazygit"
        OS=$(detect_os)
        case $OS in
        "Ubuntu" | "Debian GNU/Linux")
            LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | \grep -Po '"tag_name": *"v\K[^"]*')
            curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
            tar xf lazygit.tar.gz lazygit
            sudo install lazygit -D -t /usr/local/bin/
            ;;
        "openSUSE Tumbleweed")
            sudo zypper ar https://download.opensuse.org/repositories/devel:/languages:/go/openSUSE_Factory/devel:languages:go.repo
            sudo zypper ref && sudo zypper in lazygit
            ;;
        "Fedora Linux")
            sudo dnf copr enable atim/lazygit -y
            sudo dnf install lazygit
            ;;
        *)
            echo "No lazygit installation found for this distro $OS."
            ;;

        esac
        echo "Lazygit installed successfully."
    else
        echo "Lazygit already installed"
    fi
}

install_fzf_fd_bat() {
    if ! command_exists fzf; then
        echo "Installing fzf..."
        OS=$(detect_os)
        case $OS in
        "Ubuntu" | "Debian GNU/Linux")
            sudo apt install -y fzf
            ;;
        "openSUSE Tumbleweed")
            sudo zypper install -y fzf
            ;;
        "Fedora Linux")
            sudo dnf install -y fzf
            ;;
        *)
            echo "No fzf installation found for this distro $OS."
            ;;

        esac
        echo "fzf installed successfully."
    else
        echo "fzf already installed"
    fi

    if ! command_exists fd; then
        echo "Installing fd..."
        OS=$(detect_os)
        case $OS in
        "Ubuntu" | "Debian GNU/Linux")
            sudo apt install -y fd-find
            mkdir -p ~/.local/bin
            ln -sf /usr/bin/fdfind ~/.local/bin/fd
            ;;
        "openSUSE Tumbleweed")
            sudo zypper install -y fd
            ;;
        "Fedora Linux")
            sudo dnf install -y fd
            ;;
        *)
            echo "No fd installation found for this distro $OS."
            ;;

        esac
        echo "fd installed successfully."
    else
        echo "fd already installed"
    fi
    if ! command_exists bat; then
        echo "Installing bat..."
        OS=$(detect_os)
        case $OS in
        "Ubuntu" | "Debian GNU/Linux")
            sudo apt install -y bat
            mkdir -p ~/.local/bin
            ln -sf /usr/bin/batcat ~/.local/bin/bat
            ;;
        "openSUSE Tumbleweed")
            sudo zypper install -y bat
            ;;
        "Fedora Linux")
            sudo dnf install -y bat
            ;;
        *)
            echo "No bat installation found for this distro $OS."
            ;;

        esac
        echo "bat installed successfully."
    else
        echo "bat already installed"
    fi
    echo "fzf, fd and bat installed successfully."
}

install_zsh_autosuggestions() {
    if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
        echo "Installing zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
        echo "zsh-autosuggestions installed successfully."
    else
        echo "zsh-autosuggestions is already installed."
    fi
}

install_bottom() {
    if ! command_exists btm; then
        echo "Installing bottom..."
        OS=$(detect_os)
        case $OS in
        "Ubuntu" | "Debian GNU/Linux")
            # Get latest version from GitHub
            BOTTOM_VERSION=$(curl -s "https://api.github.com/repos/ClementTsang/bottom/releases/latest" | \grep -Po '"tag_name": *"\K[^"]*')
            if [ -z "$BOTTOM_VERSION" ]; then
                echo "Failed to get latest bottom version. Exiting installation."
                return 1
            fi
            echo "Installing bottom version ${BOTTOM_VERSION}..."
            curl -LO "https://github.com/ClementTsang/bottom/releases/download/${BOTTOM_VERSION}/bottom_${BOTTOM_VERSION}-1_amd64.deb"
            sudo dpkg -i "bottom_${BOTTOM_VERSION}-1_amd64.deb"
            rm "bottom_${BOTTOM_VERSION}-1_amd64.deb"
            ;;
        "openSUSE Tumbleweed")
            sudo zypper install -y bottom
            ;;
        "Fedora Linux")
            sudo dnf install -y bottom
            ;;
        *)
            echo "No package manager installation available for bottom on $OS"
            ;;
        esac

        # Create bottom config directory and file
        mkdir -p ~/.config/bottom
        echo "[flags]
basic = true
tree = true" >~/.config/bottom/bottom.toml

        echo "bottom installed and configured with basic tree view."
    else
        echo "bottom is already installed."
        # Add configuration even if bottom was already installed
        mkdir -p ~/.config/bottom
        echo "[flags]
basic = true
tree = true" >~/.config/bottom/bottom.toml
        echo "bottom configuration updated with basic tree view."
    fi
}

install_bunjs() {
    if ! command_exists bun; then
        echo "Installing bunjs..."
        curl -fsSL https://bun.sh/install | bash
        git restore .zshrc
        echo "bunjs installed successfully."
    else
        echo "bunjs is already installed."
    fi
}

install_java() {
    if ! command_exists java; then
        echo "Installing OpenJDK 21..."
        OS=$(detect_os)
        case $OS in
        "Ubuntu" | "Debian GNU/Linux")
            sudo apt update
            sudo apt install -y openjdk-21-jdk
            ;;
        "openSUSE Tumbleweed")
            sudo zypper refresh
            sudo zypper install -y java-21-openjdk-devel
            ;;
        "Fedora Linux")
            sudo dnf install -y java-21-openjdk-devel
            ;;
        *)
            echo "No specific Java installation defined for $OS."
            ;;
        esac
        echo "OpenJDK 21 installed successfully."
    else
        echo "Java is already installed."
    fi
}

install_python() {
    if ! command_exists python3; then
        echo "Installing Python..."
        OS=$(detect_os)
        case $OS in
        "Ubuntu" | "Debian GNU/Linux")
            sudo apt update
            sudo apt install -y python3 python3-pip python3-venv build-essential libssl-dev libffi-dev python3-dev
            ;;
        "openSUSE Tumbleweed")
            sudo zypper refresh
            sudo zypper install -y python3 python3-pip python3-devel
            ;;
        "Fedora Linux")
            sudo dnf install -y python3 python3-pip python3-devel
            ;;
        *)
            echo "No specific Python installation defined for $OS."
            ;;
        esac

        # Install pipx for managing Python applications in isolated environments
        if ! command_exists pipx; then
            echo "Installing pipx..."
            python3 -m pip install --user pipx
            python3 -m pipx ensurepath
        fi

        # Create useful aliases
        echo 'alias python=python3' >>~/.zshrc
        echo 'alias pip=pip3' >>~/.zshrc

        echo "Python installed successfully."
    else
        echo "Python is already installed."
    fi
}
echo "Starting installation of development tools..."

install_dev_tools
install_rust
install_nvm
install_go
install_node
install_nvim
install_tmux
install_lsbrelease
install_pnpm
install_ripgrep
install_ruby_dev
install_eza
install_lazygit
install_fzf_fd_bat
install_zsh_autosuggestions
install_bottom
install_bunjs
install_java
install_python

echo "Installation complete. Please restart your terminal or run 'source ~/.zshrc' to apply changes."
