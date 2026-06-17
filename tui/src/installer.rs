use std::fs;
use std::io::Write;
use std::path::PathBuf;
use std::process::{Command, ExitStatus, Output};

use crate::status::{self, Distro};

pub type Res = Result<String, String>;

pub struct Tool {
    pub name: &'static str,
    pub desc: &'static str,
    pub check: fn() -> bool,
    pub install: fn() -> Res,
}

fn ok(msg: impl Into<String>) -> Res {
    Ok(msg.into())
}

fn err(msg: impl Into<String>) -> Res {
    Err(msg.into())
}

fn run(p: &str, a: &[&str]) -> std::io::Result<ExitStatus> {
    Command::new(p).args(a).status()
}

fn sudo(a: &[&str]) -> std::io::Result<ExitStatus> {
    Command::new("sudo").args(a).status()
}

fn sh(s: &str) -> std::io::Result<ExitStatus> {
    Command::new("sh").arg("-c").arg(s).status()
}

fn sh_cap(s: &str) -> std::io::Result<Output> {
    Command::new("sh").arg("-c").arg(s).output()
}

fn check(status: std::io::Result<ExitStatus>, what: &str) -> Res {
    match status {
        Ok(s) if s.success() => ok(format!("{what} completed")),
        Ok(s) => err(format!("{what} failed (exit {:?})", s.code())),
        Err(e) => err(format!("{what} failed: {e}")),
    }
}

fn run_res(p: &str, a: &[&str], what: &str) -> Res {
    check(run(p, a), what)
}

fn sudo_res(a: &[&str], what: &str) -> Res {
    check(sudo(a), what)
}

fn sh_res(s: &str, what: &str) -> Res {
    check(sh(s), what)
}

fn exists(c: &str) -> bool {
    status::command_exists(c)
}

fn home() -> PathBuf {
    status::home_dir()
}

fn append_zshrc(line: &str) -> Res {
    let p = home().join(".zshrc");
    let mut f = fs::OpenOptions::new()
        .append(true)
        .create(true)
        .open(&p)
        .map_err(|e| format!("open ~/.zshrc: {e}"))?;
    writeln!(f, "{line}").map_err(|e| format!("write ~/.zshrc: {e}"))?;
    ok("updated ~/.zshrc")
}

fn pkg(packages: &[&str]) -> Res {
    match status::detect_os() {
        Distro::Ubuntu | Distro::Debian => {
            sudo_res(&["apt", "update"], "apt update")?;
            let mut a = vec!["apt", "install", "-y"];
            a.extend(packages);
            check(sudo(&a), "apt install")
        }
        Distro::OpenSuse => {
            sudo_res(&["zypper", "refresh"], "zypper refresh")?;
            let mut a = vec!["zypper", "install", "-y"];
            a.extend(packages);
            check(sudo(&a), "zypper install")
        }
        Distro::Fedora => {
            let mut a = vec!["dnf", "install", "-y"];
            a.extend(packages);
            check(sudo(&a), "dnf install")
        }
        Distro::Arch => {
            let mut a = vec!["pacman", "-S", "--noconfirm"];
            a.extend(packages);
            check(sudo(&a), "pacman install")
        }
        _ => err("unsupported distro for package install"),
    }
}

fn install_dev_tools() -> Res {
    match status::detect_os() {
        Distro::Ubuntu | Distro::Debian => pkg(&["build-essential", "unzip", "wget", "curl", "git", "jq"]),
        Distro::OpenSuse => {
            sudo_res(&["zypper", "refresh"], "zypper refresh")?;
            sudo_res(&["zypper", "install", "-y", "unzip", "jq"], "zypper install")?;
            sudo_res(
                &["zypper", "install", "-y", "-t", "pattern", "devel_basis", "devel_C_C++"],
                "zypper install patterns",
            )
        }
        Distro::Fedora => {
            sudo_res(
                &["dnf", "group", "install", "-y", "Development Tools", "C Development Tools and Libraries"],
                "dnf group install",
            )?;
            sudo_res(&["dnf", "install", "-y", "gcc", "gcc-c++", "make", "unzip", "jq"], "dnf install")
        }
        _ => err("no development tools install defined for this OS"),
    }
}

fn install_rust() -> Res {
    if exists("rustc") {
        return ok("rust already installed");
    }
    sh_res(
        "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y",
        "rustup install",
    )?;
    ok("rust installed")
}

fn install_nvm() -> Res {
    if home().join(".nvm").exists() {
        return ok("nvm already installed");
    }
    sh_res(
        "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash",
        "nvm install",
    )?;
    ok("nvm installed")
}

fn install_go() -> Res {
    if exists("go") {
        return ok("go already installed");
    }
    let out = sh_cap("curl -sL 'https://go.dev/VERSION?m=text' | grep -o 'go[0-9.]*' | head -n1")
        .map_err(|e| format!("fetch go version: {e}"))?;
    let ver = String::from_utf8_lossy(&out.stdout).trim().to_string();
    if ver.is_empty() {
        return err("could not determine latest go version");
    }
    let file = format!("{ver}.linux-amd64.tar.gz");
    sh_res(&format!("curl -O https://dl.google.com/go/{file}"), "download go")?;
    sh_res(
        &format!("sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf {file}"),
        "extract go",
    )?;
    sh_res(&format!("rm -f {file}"), "cleanup go tarball")?;
    append_zshrc("export PATH=$PATH:/usr/local/go/bin")?;
    ok("go installed")
}

fn install_node() -> Res {
    if exists("node") {
        return ok("node already installed");
    }
    sh_res(". ~/.nvm/nvm.sh && nvm install --lts", "nvm install node")?;
    ok("node installed")
}

fn install_nvim() -> Res {
    if exists("nvim") {
        return ok("nvim already installed");
    }
    match status::detect_os() {
        Distro::Fedora => sudo_res(&["dnf", "install", "-y", "neovim", "python3-neovim"], "dnf install nvim"),
        _ => {
            sh_res(
                "curl -LO https://github.com/neovim/neovim/releases/download/stable/nvim-linux-x86_64.tar.gz",
                "download nvim",
            )?;
            sh_res(
                "sudo rm -rf /opt/nvim && sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz",
                "extract nvim",
            )?;
            sh_res("rm -f nvim-linux-x86_64.tar.gz", "cleanup nvim tarball")?;
            append_zshrc("export PATH=\"$PATH:/opt/nvim-linux-x86_64/bin\"")?;
            ok("nvim installed")
        }
    }
}

fn install_tmux() -> Res {
    if exists("tmux") {
        return ok("tmux already installed");
    }
    match status::detect_os() {
        Distro::Ubuntu | Distro::Debian => {
            pkg(&[
                "git", "build-essential", "autoconf", "automake", "pkg-config", "libevent-dev",
                "libncurses-dev", "libutempter-dev", "libgd-dev",
            ])?;
        }
        Distro::OpenSuse => {
            pkg(&[
                "git", "gcc", "make", "autoconf", "automake", "pkg-config", "libevent-devel",
                "ncurses-devel", "libutempter-devel", "libgd-devel",
            ])?;
        }
        Distro::Fedora => {
            pkg(&[
                "git", "gcc", "make", "autoconf", "automake", "pkgconfig", "libevent-devel",
                "ncurses-devel", "libutempter-devel", "libgd-devel",
            ])?;
        }
        Distro::Arch => {
            pkg(&[
                "git", "base-devel", "ncurses", "libevent", "libutempter", "pkgconf", "libgd",
            ])?;
        }
        _ => return err("no tmux source install defined for this OS"),
    }
    sh_res(
        "set -e; TMP=$(mktemp -d); git clone https://github.com/tmux/tmux.git \"$TMP/tmux\"; \
         ( cd \"$TMP/tmux\" && sh autogen.sh && ./configure --enable-sixel && make -j\"$(nproc)\" && sudo make install ); \
         rm -rf \"$TMP\"",
        "build tmux from source",
    )?;
    ok("tmux built from source with sixel support")
}

fn install_lsbrelease() -> Res {
    match status::detect_os() {
        Distro::Ubuntu | Distro::Debian => pkg(&["lsb-release"]),
        Distro::OpenSuse => pkg(&["lsb-release"]),
        Distro::Fedora => pkg(&["redhat-lsb-core"]),
        Distro::Arch => pkg(&["lsb-release"]),
        _ => err("no lsb-release install defined for this OS"),
    }
}

fn install_pnpm() -> Res {
    if exists("pnpm") {
        return ok("pnpm already installed");
    }
    sh_res("curl -fsSL https://get.pnpm.io/install.sh | sh -", "install pnpm")?;
    ok("pnpm installed")
}

fn install_ripgrep() -> Res {
    pkg(&["ripgrep"])
}

fn install_eza() -> Res {
    if exists("eza") {
        return ok("eza already installed");
    }
    match status::detect_os() {
        Distro::Ubuntu => pkg(&["eza"]),
        Distro::Debian => {
            sudo_res(&["apt", "update"], "apt update")?;
            sudo_res(&["apt", "install", "-y", "gpg"], "install gpg")?;
            sh_res(
                "sudo mkdir -p /etc/apt/keyrings && \
                 wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | \
                 sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg",
                "add eza signing key",
            )?;
            sh_res(
                "echo 'deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main' | \
                 sudo tee /etc/apt/sources.list.d/gierens.list",
                "add eza apt repo",
            )?;
            sh_res(
                "sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list",
                "chmod eza repo files",
            )?;
            sudo_res(&["apt", "update"], "apt update")?;
            sudo_res(&["apt", "install", "-y", "eza"], "install eza")
        }
        Distro::OpenSuse => pkg(&["eza"]),
        Distro::Fedora => pkg(&["eza"]),
        _ => {
            if exists("cargo") {
                run_res("cargo", &["install", "eza"], "cargo install eza")
            } else {
                err("no eza install for this OS (cargo missing)")
            }
        }
    }
}

fn install_lazygit() -> Res {
    if exists("lazygit") {
        return ok("lazygit already installed");
    }
    match status::detect_os() {
        Distro::Ubuntu | Distro::Debian => {
            let out = sh_cap(
                "curl -s \"https://api.github.com/repos/jesseduffield/lazygit/releases/latest\" | \
                 grep -Po '\"tag_name\": \"v\\K[^\"]*'",
            )
            .map_err(|e| format!("fetch lazygit version: {e}"))?;
            let v = String::from_utf8_lossy(&out.stdout).trim().to_string();
            if v.is_empty() {
                return err("could not determine latest lazygit version");
            }
            let script = format!(
                "curl -Lo lazygit.tar.gz \"https://github.com/jesseduffield/lazygit/releases/download/v{v}/lazygit_{v}_Linux_x86_64.tar.gz\" && \
                 tar xf lazygit.tar.gz lazygit && sudo install lazygit -D -t /usr/local/bin/ && \
                 rm -f lazygit lazygit.tar.gz"
            );
            sh_res(&script, "install lazygit")
        }
        Distro::OpenSuse => {
            sudo_res(
                &["zypper", "ar", "https://download.opensuse.org/repositories/devel:/languages:/go/openSUSE_Factory/devel:languages:go.repo"],
                "add lazygit repo",
            )?;
            sudo_res(&["zypper", "ref"], "zypper refresh")?;
            sudo_res(&["zypper", "in", "lazygit"], "install lazygit")
        }
        Distro::Fedora => {
            sudo_res(&["dnf", "copr", "enable", "atim/lazygit", "-y"], "enable lazygit copr")?;
            sudo_res(&["dnf", "install", "lazygit"], "install lazygit")
        }
        Distro::Arch => pkg(&["lazygit"]),
        _ => err("no lazygit install defined for this OS"),
    }
}

fn install_fzf_fd_bat() -> Res {
    if !exists("fzf") {
        pkg(&["fzf"])?;
    }
    if !exists("fd") {
        match status::detect_os() {
            Distro::Ubuntu | Distro::Debian => {
                pkg(&["fd-find"])?;
                let local = home().join(".local/bin");
                fs::create_dir_all(&local).map_err(|e| format!("mkdir {}: {e}", local.display()))?;
                std::os::unix::fs::symlink("/usr/bin/fdfind", local.join("fd"))
                    .map_err(|e| format!("symlink fd: {e}"))?;
            }
            _ => { pkg(&["fd"])?; }
        }
    }
    if !exists("bat") {
        match status::detect_os() {
            Distro::Ubuntu | Distro::Debian => {
                pkg(&["bat"])?;
                let local = home().join(".local/bin");
                fs::create_dir_all(&local).map_err(|e| format!("mkdir {}: {e}", local.display()))?;
                std::os::unix::fs::symlink("/usr/bin/batcat", local.join("bat"))
                    .map_err(|e| format!("symlink bat: {e}"))?;
            }
            _ => { pkg(&["bat"])?; }
        }
    }
    ok("fzf, fd and bat ready")
}

fn install_zsh_autosuggestions() -> Res {
    let p = home().join(".oh-my-zsh/custom/plugins/zsh-autosuggestions");
    if p.exists() {
        return ok("zsh-autosuggestions already installed");
    }
    sh_res(
        &format!("git clone https://github.com/zsh-users/zsh-autosuggestions {}", p.display()),
        "clone zsh-autosuggestions",
    )?;
    ok("zsh-autosuggestions installed")
}

fn install_zsh_ai() -> Res {
    let p = home().join(".oh-my-zsh/custom/plugins/zsh-ai");
    if p.exists() {
        return ok("zsh-ai already installed");
    }
    sh_res(
        &format!("git clone https://github.com/matheusml/zsh-ai {}", p.display()),
        "clone zsh-ai",
    )?;
    ok("zsh-ai installed")
}

fn install_bottom() -> Res {
    if !exists("btm") {
        match status::detect_os() {
            Distro::Ubuntu | Distro::Debian => {
                let out = sh_cap(
                    "curl -s \"https://api.github.com/repos/ClementTsang/bottom/releases/latest\" | \
                     grep -Po '\"tag_name\": \"\\K[^\"]*'",
                )
                .map_err(|e| format!("fetch bottom version: {e}"))?;
                let v = String::from_utf8_lossy(&out.stdout).trim().to_string();
                if v.is_empty() {
                    return err("could not determine latest bottom version");
                }
                let deb = format!("bottom_{v}-1_amd64.deb");
                let script = format!(
                    "curl -LO \"https://github.com/ClementTsang/bottom/releases/download/{v}/{deb}\" && \
                     sudo dpkg -i {deb} && rm -f {deb}"
                );
                sh_res(&script, "install bottom")?;
            }
            Distro::OpenSuse => { sudo_res(&["zypper", "install", "-y", "bottom"], "install bottom")?; }
            Distro::Fedora => {
                sudo_res(&["dnf", "copr", "enable", "atim/bottom", "-y"], "enable bottom copr")?;
                sudo_res(&["dnf", "install", "-y", "bottom"], "install bottom")?;
            }
            Distro::Arch => { pkg(&["bottom"])?; }
            _ => return err("no bottom install defined for this OS"),
        }
    }
    let cfg_dir = home().join(".config/bottom");
    fs::create_dir_all(&cfg_dir).map_err(|e| format!("mkdir {}: {e}", cfg_dir.display()))?;
    fs::write(cfg_dir.join("bottom.toml"), "[flags]\nbasic = true\ntree = true\n")
        .map_err(|e| format!("write bottom.toml: {e}"))?;
    ok("bottom installed and configured")
}

fn install_bunjs() -> Res {
    if exists("bun") {
        return ok("bun already installed");
    }
    sh_res("curl -fsSL https://bun.sh/install | bash", "install bun")?;
    ok("bun installed")
}

fn install_sdkman() -> Res {
    if home().join(".sdkman").exists() {
        return ok("sdkman already installed");
    }
    sh_res("curl -s \"https://get.sdkman.io\" | bash", "install sdkman")?;
    ok("sdkman installed")
}

fn install_python() -> Res {
    if exists("python3") {
        return ok("python already installed");
    }
    match status::detect_os() {
        Distro::Ubuntu | Distro::Debian => {
            pkg(&[
                "python3", "python3-pip", "python3-venv", "build-essential", "libssl-dev", "libffi-dev",
                "python3-dev",
            ])?;
        }
        Distro::OpenSuse => { pkg(&["python3", "python3-pip", "python3-devel"])?; }
        Distro::Fedora => { pkg(&["python3", "python3-pip", "python3-devel"])?; }
        Distro::Arch => { pkg(&["python"])?; }
        _ => return err("no python install defined for this OS"),
    }
    if !exists("pipx") {
        sh_res(
            "python3 -m pip install --user pipx && python3 -m pipx ensurepath",
            "install pipx",
        )?;
    }
    append_zshrc("alias python=python3")?;
    append_zshrc("alias pip=pip3")?;
    ok("python installed")
}

fn install_zoxide() -> Res {
    if exists("zoxide") {
        return ok("zoxide already installed");
    }
    sh_res(
        "curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh",
        "install zoxide",
    )?;
    ok("zoxide installed")
}

fn install_socket() -> Res {
    if exists("socket") {
        return ok("socket already installed");
    }
    run_res("npm", &["install", "-g", "socket"], "install socket.dev CLI")?;
    ok("socket.dev CLI installed")
}

fn check_dev_tools() -> bool {
    exists("gcc") || exists("make")
}
fn check_nvm() -> bool {
    home().join(".nvm").exists()
}
fn check_zsh_autosuggestions() -> bool {
    home().join(".oh-my-zsh/custom/plugins/zsh-autosuggestions").exists()
}
fn check_zsh_ai() -> bool {
    home().join(".oh-my-zsh/custom/plugins/zsh-ai").exists()
}
fn check_sdkman() -> bool {
    home().join(".sdkman").exists()
}
fn check_fzf_fd_bat() -> bool {
    exists("fzf") && exists("fd") && exists("bat")
}

pub static TOOLS: &[Tool] = &[
    Tool { name: "dev-tools", desc: "Build tools, curl, git, jq (OS packages)", check: check_dev_tools, install: install_dev_tools },
    Tool { name: "rust", desc: "Rust toolchain via rustup", check: || exists("rustc"), install: install_rust },
    Tool { name: "nvm", desc: "Node Version Manager", check: check_nvm, install: install_nvm },
    Tool { name: "go", desc: "Go toolchain (official tarball)", check: || exists("go"), install: install_go },
    Tool { name: "node", desc: "Node.js LTS via nvm", check: || exists("node"), install: install_node },
    Tool { name: "nvim", desc: "Neovim stable", check: || exists("nvim"), install: install_nvim },
    Tool { name: "tmux", desc: "tmux built from source (sixel)", check: || exists("tmux"), install: install_tmux },
    Tool { name: "lsb-release", desc: "lsb-release distro metadata", check: || exists("lsb_release"), install: install_lsbrelease },
    Tool { name: "pnpm", desc: "pnpm package manager", check: || exists("pnpm"), install: install_pnpm },
    Tool { name: "ripgrep", desc: "ripgrep (rg)", check: || exists("rg"), install: install_ripgrep },
    Tool { name: "eza", desc: "Modern ls replacement", check: || exists("eza"), install: install_eza },
    Tool { name: "lazygit", desc: "TUI for git", check: || exists("lazygit"), install: install_lazygit },
    Tool { name: "fzf+fd+bat", desc: "fuzzy finder, fd, bat", check: check_fzf_fd_bat, install: install_fzf_fd_bat },
    Tool { name: "zsh-autosuggestions", desc: "zsh autosuggestions plugin", check: check_zsh_autosuggestions, install: install_zsh_autosuggestions },
    Tool { name: "zsh-ai", desc: "zsh-ai plugin", check: check_zsh_ai, install: install_zsh_ai },
    Tool { name: "bottom", desc: "System monitor (btm)", check: || exists("btm"), install: install_bottom },
    Tool { name: "bun", desc: "Bun JavaScript runtime", check: || exists("bun"), install: install_bunjs },
    Tool { name: "sdkman", desc: "SDKMAN! for JVM SDKs", check: check_sdkman, install: install_sdkman },
    Tool { name: "python", desc: "Python 3 + pipx", check: || exists("python3"), install: install_python },
    Tool { name: "zoxide", desc: "Smarter cd", check: || exists("zoxide"), install: install_zoxide },
    Tool { name: "socket", desc: "socket.dev CLI", check: || exists("socket"), install: install_socket },
];
