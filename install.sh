#!/usr/bin/env bash
# Run each tool in a separate, strict subshell so failures cannot be masked by
# later commands, while the parent can continue with independent tools.

TOOLS=(dev-tools rust nvm go node nvim tmux lsb-release pnpm ripgrep eza lazygit fzf fd bat zsh-autosuggestions zsh-ai bottom bun sdkman python zoxide socket)

usage() {
    cat <<'HELP'
Usage: ./install.sh [--yes] [--dry-run] [--only TOOL,...] [--skip TOOL,...] [--tmux-sixel]

Install missing tools and update existing tools on Debian/Ubuntu, Fedora,
openSUSE, or Arch. Existing configuration is preserved. Failed tools are reported
at the end; independent installs continue. Rerun with --only to retry failures.

  --only LIST   Install/update only these tools (plus required dependencies)
  --skip LIST   Exclude tools; dependents are blocked if a dependency is missing
  --tmux-sixel Install/update selected tmux from source with SIXEL
               (installs to /usr/local; default uses the distro package)
  --dry-run     Show the offline plan; versions are checked during a real run
  -y, --yes     Accept the installation plan (sudo may still ask for a password)
  --list        List available tool names
  -h, --help    Show this help

Examples:
  ./install.sh --dry-run
  ./install.sh --only nvim,tmux,ripgrep
  ./install.sh --only tmux --tmux-sixel
  ./install.sh --yes --skip go,rust

Default tmux mode backs up an old /usr/local/bin/tmux source build and links
that path to /usr/bin/tmux, so the distro version takes precedence.

Logs: ${XDG_STATE_HOME:-~/.local/state}/dotfiles/install/<run>/
Exit status: 0 = success, 1 = failed/blocked tools, 2 = usage/preflight error.
HELP
}

has() { command -v "$1" >/dev/null 2>&1; }
contains() { [[ " $1 " == *" $2 "* ]]; }
fail() { printf 'Error: %s\n' "$*" >&2; return 1; }

# These paths also make reruns recognize tools installed in an earlier session.
setup_paths() {
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    export SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"
    export CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
    export PATH="$HOME/.local/bin:$CARGO_HOME/bin:${BUN_INSTALL:-$HOME/.bun}/bin:${PNPM_HOME:-$HOME/.local/share/pnpm}:/usr/local/go/bin:/opt/nvim-linux-x86_64/bin:/opt/nvim-linux-arm64/bin:$PATH"
    if [[ -s "$NVM_DIR/nvm.sh" ]]; then
        # shellcheck disable=SC1091
        . "$NVM_DIR/nvm.sh" || return 1
    fi
}

detect_platform() {
    [[ $(uname -s) == Linux && -r /etc/os-release ]] || {
        fail 'This installer supports Linux only.'; return 1;
    }
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_NAME=${PRETTY_NAME:-$ID}
    case " $ID ${ID_LIKE:-} " in
        *debian*|*ubuntu*) PM=apt-get ;;
        *fedora*) PM=dnf ;;
        *suse*) PM=zypper ;;
        *arch*) PM=pacman ;;
        *) fail "Unsupported distribution: $OS_NAME"; return 1 ;;
    esac
    has "$PM" || { fail "Missing package manager: $PM"; return 1; }
    case $(uname -m) in
        x86_64) ARCH=amd64; NVIM_ARCH=x86_64 ;;
        aarch64|arm64) ARCH=arm64; NVIM_ARCH=arm64 ;;
        *) ARCH=unsupported; NVIM_ARCH=unsupported ;;
    esac
}

admin() {
    if (( EUID == 0 )); then "$@"; else sudo "$@"; fi
}

packages() {
    case $PM in
        apt-get) admin env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" ;;
        dnf) admin dnf install -y "$@" ;;
        zypper) admin zypper --non-interactive install "$@" ;;
        pacman) admin pacman -S --needed --noconfirm "$@" ;;
    esac
}

download() {
    curl --fail --location --show-error --silent --retry 3 \
        --connect-timeout 20 --max-time 600 "$1" -o "$2"
}

upstream_script() {
    local url=$1
    shift
    download "$url" "$WORK_DIR/upstream.sh"
    "$@" "$WORK_DIR/upstream.sh"
}

plugin_dir() { printf '%s/plugins/%s' "${ZSH_CUSTOM:-${ZSH:-$HOME/.oh-my-zsh}/custom}" "$1"; }

version_number() {
    local value
    value=$(cat)
    [[ $value =~ ([0-9]+\.[0-9]+(\.[0-9]+)?) ]] || { fail "Cannot parse version: $value"; return 1; }
    printf '%s\n' "${BASH_REMATCH[1]}"
}

current_release() {
    local current=$1 latest=$2 highest
    [[ -n $current ]] || return 1
    highest=$(printf '%s\n%s\n' "$current" "$latest" | sort -V | tail -n 1)
    if [[ $highest == "$current" ]]; then
        printf 'Current version %s is already at or ahead of release %s.\n' "$current" "$latest"
        return 0
    fi
    printf 'Update available: %s → %s\n' "$current" "$latest"
    return 1
}

latest_tag() {
    download "https://api.github.com/repos/$1/releases/latest" "$WORK_DIR/release.json" || return 1
    jq -er '.tag_name | select(test("^v?[0-9]+\\.[0-9]+(\\.[0-9]+)?$"))' "$WORK_DIR/release.json"
}

owned_package() {
    local path
    path=$(command -v "$1") || return 1
    path=$(readlink -f "$path") || return 1
    case $PM in
        apt-get) dpkg-query -S "$path" 2>/dev/null | sed -n '1s/: \/.*//p' ;;
        dnf|zypper) rpm -qf --qf '%{NAME}\n' "$path" 2>/dev/null ;;
        pacman) pacman -Qoq "$path" 2>/dev/null ;;
    esac
}

verify_distro_command() {
    local owner
    if owner=$(owned_package "$1") && [[ -n $owner ]]; then return; fi
    fail "The repository package was updated, but $(command -v "$1") is not distro-managed. Update or remove that overriding installation first."
}

# Stage a complete release beside its destination, retaining the previous
# directory until the replacement succeeds. Never unpack over an old release.
replace_directory() {
    local source=$1 destination=$2 stage
    admin mkdir -p "$(dirname "$destination")"
    stage=$(admin mktemp -d "${destination}.update.XXXXXX")
    if ! admin cp -a "$source" "$stage/new"; then
        admin rm -rf -- "$stage"
        return 1
    fi
    if [[ -e $destination || -L $destination ]]; then
        if ! admin mv -- "$destination" "$stage/old"; then
            admin rm -rf -- "$stage"
            return 1
        fi
    fi
    if ! admin mv -- "$stage/new" "$destination"; then
        if [[ -e $stage/old || -L $stage/old ]]; then
            admin mv -- "$stage/old" "$destination" || {
                fail "Restore failed; previous installation is at $stage/old"; return 1;
            }
        fi
        admin rm -rf -- "$stage"
        return 1
    fi
    admin rm -rf -- "$stage"
}

update_plugin() {
    local target=$1 url=$2 branch
    if [[ ! -e $target ]]; then
        git clone --depth 1 "$url" "$target"
        return
    fi
    [[ -d $target/.git ]] || { fail "$target is not a Git checkout; cannot update it safely."; return 1; }
    [[ -z $(git -C "$target" status --porcelain) ]] || { fail "$target has local changes; commit or stash them before updating."; return 1; }
    branch=$(git -C "$target" symbolic-ref --quiet --short HEAD)
    git -C "$target" fetch origin "$branch"
    git -C "$target" merge --ff-only FETCH_HEAD
}

installed() {
    case $1 in
        dev-tools) return 1 ;; # Also refreshes package metadata before installs.
        nvm) [[ -s "$NVM_DIR/nvm.sh" ]] ;;
        sdkman) [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] ;;
        zsh-autosuggestions|zsh-ai) [[ -s "$(plugin_dir "$1")/$1.plugin.zsh" ]] ;;
        rust) has rustc && has cargo ;;
        node) has node && has npm ;;
        python) has python3 && has pipx ;;
        ripgrep) has rg ;;
        bottom) has btm ;;
        lsb-release) has lsb_release ;;
        *) has "$1" ;;
    esac
}

dependencies() {
    case $1 in
        dev-tools) ;;
        node) printf 'dev-tools nvm' ;;
        pnpm|bun|socket) printf 'dev-tools node' ;;
        eza|bottom) printf 'dev-tools rust' ;;
        *) printf 'dev-tools' ;;
    esac
}

install_dev_tools() {
    case $PM in
        apt-get)
            admin apt-get update
            packages build-essential curl wget git jq unzip zip ca-certificates ;;
        dnf)
            admin dnf makecache --refresh
            packages gcc gcc-c++ make curl wget git jq unzip zip ca-certificates ;;
        zypper)
            admin zypper --non-interactive --verbose refresh
            packages gcc gcc-c++ make curl wget git jq unzip zip ca-certificates ;;
        pacman)
            # Avoid Arch partial upgrades when refreshing the package database.
            admin pacman -Syu --needed --noconfirm base-devel curl wget git jq unzip zip ca-certificates ;;
    esac
}

use_distro_tmux() {
    local local_binary=/usr/local/bin/tmux distro_binary=/usr/bin/tmux backup
    [[ -x $distro_binary ]] || { fail "Distro tmux not found at $distro_binary"; return 1; }
    if [[ -e $local_binary || -L $local_binary ]]; then
        if [[ $(readlink -f "$local_binary") != "$distro_binary" ]]; then
            backup=$(admin mktemp -d /usr/local/bin/.tmux-source-backup.XXXXXX)
            admin cp -a -- "$local_binary" "$backup/tmux"
            admin ln -s "$distro_binary" "$backup/replacement"
            # Rename the prepared link over the old binary only after backup.
            admin mv -Tf -- "$backup/replacement" "$local_binary"
            printf 'Previous tmux saved to %s/tmux; using %s.\n' "$backup" "$distro_binary"
        fi
    fi
    hash -r
    verify_distro_command tmux
}

install_tmux() {
    if [[ ${TMUX_SIXEL:-0} != 1 ]]; then
        packages tmux
        use_distro_tmux
        return
    fi
    local commit fingerprint marker
    git clone --depth 1 https://github.com/tmux/tmux.git "$WORK_DIR/tmux"
    commit=$(git -C "$WORK_DIR/tmux" rev-parse HEAD)
    marker="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/tmux-source"
    if [[ -x /usr/local/bin/tmux && -f $marker ]]; then
        fingerprint=$(sha256sum /usr/local/bin/tmux)
        if [[ $(cat "$marker") == "$commit $fingerprint" ]]; then
            printf 'Tmux source build is up to date (%s).\n' "$commit"
            return
        fi
    fi
    case $PM in
        apt-get) packages bison autoconf automake pkg-config libevent-dev libncurses-dev libutempter-dev libgd-dev ;;
        dnf|zypper) packages bison autoconf automake pkg-config libevent-devel ncurses-devel libutempter-devel libgd-devel ;;
        pacman) packages bison autoconf automake pkgconf libevent ncurses libutempter libgd ;;
    esac
    cd "$WORK_DIR/tmux"
    sh autogen.sh
    ./configure --prefix=/usr/local --enable-sixel
    make -j"$(getconf _NPROCESSORS_ONLN)"
    admin make install
    /usr/local/bin/tmux -V
    fingerprint=$(sha256sum /usr/local/bin/tmux)
    mkdir -p "$(dirname "$marker")"
    printf '%s %s\n' "$commit" "$fingerprint" > "$marker"
}

install_go() {
    local owner version current=''
    if has go && owner=$(owned_package go) && [[ -n $owner ]]; then
        packages "$owner"
        return
    fi
    [[ $ARCH != unsupported ]] || { fail 'Go downloads require x86_64 or ARM64.'; return 1; }
    if has go; then current=$(go version | version_number); fi
    download 'https://go.dev/VERSION?m=text' "$WORK_DIR/version"
    read -r version < "$WORK_DIR/version"
    [[ $version =~ ^go[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || { fail 'Invalid Go release response.'; return 1; }
    if current_release "$current" "${version#go}"; then return; fi
    if has go && [[ $(readlink -f "$(command -v go)") != /usr/local/go/bin/go ]]; then
        fail 'Go is managed outside /usr/local/go; update it with its original installer.'; return 1
    fi
    if [[ -e /usr/local/go && ! -x /usr/local/go/bin/go ]]; then
        fail '/usr/local/go is not a recognized Go installation.'; return 1
    fi
    download "https://go.dev/dl/$version.linux-$ARCH.tar.gz" "$WORK_DIR/go.tar.gz"
    tar -xzf "$WORK_DIR/go.tar.gz" -C "$WORK_DIR"
    "$WORK_DIR/go/bin/go" version
    replace_directory "$WORK_DIR/go" /usr/local/go
}

install_nvim() {
    local owner tag current=''
    if has nvim && owner=$(owned_package nvim) && [[ -n $owner ]]; then
        packages "$owner"
        return
    fi
    [[ $NVIM_ARCH != unsupported ]] || { fail 'Neovim downloads require x86_64 or ARM64.'; return 1; }
    local destination="/opt/nvim-linux-$NVIM_ARCH"
    tag=$(latest_tag neovim/neovim)
    if has nvim; then current=$(nvim --version | sed -n '1p' | version_number); fi
    if current_release "$current" "${tag#v}"; then return; fi
    if [[ -e $destination && ! -x $destination/bin/nvim ]]; then
        fail "$destination is not a recognized Neovim installation."; return 1
    fi
    if [[ -e /usr/local/bin/nvim || -L /usr/local/bin/nvim ]]; then
        [[ -L /usr/local/bin/nvim && $(readlink /usr/local/bin/nvim) == "$destination/bin/nvim" ]] || {
            fail '/usr/local/bin/nvim is not the managed symlink; refusing to overwrite it.'; return 1;
        }
    fi
    download "https://github.com/neovim/neovim/releases/download/$tag/nvim-linux-$NVIM_ARCH.tar.gz" "$WORK_DIR/nvim.tar.gz"
    tar -xzf "$WORK_DIR/nvim.tar.gz" -C "$WORK_DIR"
    "$WORK_DIR/nvim-linux-$NVIM_ARCH/bin/nvim" --version
    admin mkdir -p /opt /usr/local/bin
    replace_directory "$WORK_DIR/nvim-linux-$NVIM_ARCH" "$destination"
    if [[ ! -L /usr/local/bin/nvim ]]; then admin ln -s "$destination/bin/nvim" /usr/local/bin/nvim; fi
}

install_lazygit() {
    local owner current=''
    if has lazygit && owner=$(owned_package lazygit) && [[ -n $owner ]]; then
        packages "$owner"
        return
    fi
    [[ $ARCH != unsupported ]] || { fail 'Lazygit downloads require x86_64 or ARM64.'; return 1; }
    local version asset_arch staged_binary
    version=$(latest_tag jesseduffield/lazygit)
    version=${version#v}
    [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { fail 'Invalid Lazygit release response.'; return 1; }
    if has lazygit; then current=$(lazygit --version | sed -n 's/.*version=\([^, ]*\).*/\1/p' | version_number); fi
    if current_release "$current" "$version"; then return; fi
    asset_arch=$NVIM_ARCH
    download "https://github.com/jesseduffield/lazygit/releases/download/v$version/lazygit_${version}_Linux_${asset_arch}.tar.gz" "$WORK_DIR/lazygit.tar.gz"
    tar -xzf "$WORK_DIR/lazygit.tar.gz" -C "$WORK_DIR" lazygit
    "$WORK_DIR/lazygit" --version
    mkdir -p "$HOME/.local/bin"
    staged_binary=$(mktemp "$HOME/.local/bin/.lazygit.XXXXXX")
    if ! install -m755 "$WORK_DIR/lazygit" "$staged_binary"; then
        rm -f -- "$staged_binary"
        return 1
    fi
    mv -f -- "$staged_binary" "$HOME/.local/bin/lazygit"
}

install_tool() {
    local tool=$1 target tag current='' owner binary
    case $tool in
        dev-tools) install_dev_tools ;;
        rust)
            if has rustup; then rustup update
            elif has rustc && owner=$(owned_package rustc) && [[ -n $owner ]]; then packages "$owner" cargo
            else
                download https://sh.rustup.rs "$WORK_DIR/rustup.sh"
                sh "$WORK_DIR/rustup.sh" -y --no-modify-path
            fi ;;
        nvm)
            tag=$(latest_tag nvm-sh/nvm)
            if has nvm; then current=$(nvm --version | version_number); fi
            if current_release "$current" "${tag#v}"; then return; fi
            if [[ -d $NVM_DIR/.git && -n $(git -C "$NVM_DIR" status --porcelain) ]]; then
                fail "$NVM_DIR has local changes; commit or stash them before updating."; return 1
            fi
            mkdir -p "$NVM_DIR"
            upstream_script "https://raw.githubusercontent.com/nvm-sh/nvm/$tag/install.sh" env PROFILE=/dev/null bash ;;
        node)
            if has node; then
                current=$(node --version | version_number)
                tag=$(nvm version-remote --lts)
                target=$(printf '%s' "$tag" | version_number)
                if current_release "$current" "$target"; then return; fi
                nvm install --lts --reinstall-packages-from=current || return 1
            else nvm install --lts || return 1; fi
            nvm alias default 'lts/*' || return 1 ;;
        go) install_go ;;
        nvim) install_nvim ;;
        tmux) install_tmux ;;
        lsb-release)
            if [[ $PM == dnf ]]; then packages redhat-lsb-core; else packages lsb-release; fi
            verify_distro_command lsb_release ;;
        bun)
            # Bun's own installer leaves a standalone binary that precedes
            # ~/.local/bin on PATH; update it instead of shadowing it via npm,
            # and drop the npm copy it shadows so only one Bun remains.
            binary=${BUN_INSTALL:-$HOME/.bun}/bin/bun
            if [[ -x $binary ]]; then
                "$binary" upgrade
                if [[ -d $HOME/.local/lib/node_modules/bun ]]; then
                    npm uninstall --global --prefix "$HOME/.local" bun
                fi
            else npm install --global --prefix "$HOME/.local" bun@latest; fi ;;
        pnpm|socket) npm install --global --prefix "$HOME/.local" "$tool@latest" ;;
        ripgrep|fzf)
            packages "$tool"
            binary=$tool
            [[ $tool != ripgrep ]] || binary=rg
            verify_distro_command "$binary" ;;
        eza|bottom)
            binary=$tool
            [[ $tool != bottom ]] || binary=btm
            if has "$binary" && [[ $(command -v "$binary") == "$CARGO_HOME/bin/$binary" ]]; then
                cargo install --locked "$tool"
            elif packages "$tool"; then verify_distro_command "$binary"
            else cargo install --locked "$tool"; fi ;;
        lazygit) install_lazygit ;;
        fd|bat)
            if [[ $PM == apt-get ]]; then
                if [[ $tool == fd ]]; then
                    packages fd-find
                    target=$(command -v fdfind)
                else
                    packages bat
                    target=$(command -v batcat)
                fi
                mkdir -p "$HOME/.local/bin"
                if [[ ! -e $HOME/.local/bin/$tool && ! -L $HOME/.local/bin/$tool ]]; then
                    ln -s "$target" "$HOME/.local/bin/$tool"
                fi
            else packages "$tool"; fi
            verify_distro_command "$tool" ;;
        zsh-autosuggestions|zsh-ai)
            target=$(plugin_dir "$tool")
            if [[ $tool == zsh-ai ]]; then
                update_plugin "$target" https://github.com/matheusml/zsh-ai
            else update_plugin "$target" https://github.com/zsh-users/zsh-autosuggestions; fi ;;
        sdkman)
            if installed sdkman; then
                # SDKMAN's shell functions are not compatible with errexit.
                bash -o pipefail -c '. "$SDKMAN_DIR/bin/sdkman-init.sh" && sdk selfupdate'
            else upstream_script 'https://get.sdkman.io?rcupdate=false' bash; fi ;;
        python)
            case $PM in
                apt-get) packages python3 python3-pip python3-venv pipx ;;
                dnf) packages python3 python3-pip pipx ;;
                zypper) packages python3 python3-pip python3-pipx ;;
                pacman) packages python python-pip python-pipx ;;
            esac
            verify_distro_command python3
            verify_distro_command pipx ;;
        zoxide)
            if has zoxide && owner=$(owned_package zoxide) && [[ -n $owner ]]; then
                packages "$owner"
            else
                tag=$(latest_tag ajeetdsouza/zoxide)
                if has zoxide; then current=$(zoxide --version | version_number); fi
                if current_release "$current" "${tag#v}"; then return; fi
                upstream_script https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh sh
            fi ;;
    esac
}

configure_tool() {
    local target
    case $1 in
        eza)
            target="${EZA_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/eza}/theme.yml"
            if [[ ! -e $target && ! -L $target ]]; then
                download https://raw.githubusercontent.com/benward2301/fzf-navigator/main/theme.yml "$WORK_DIR/theme.yml"
                mkdir -p "$(dirname "$target")"
                cp "$WORK_DIR/theme.yml" "$target"
            fi ;;
        bottom)
            target="${XDG_CONFIG_HOME:-$HOME/.config}/bottom/bottom.toml"
            if [[ ! -e $target && ! -L $target ]]; then
                mkdir -p "$(dirname "$target")"
                printf '[flags]\nbasic = true\ntree = true\n' > "$target"
            fi ;;
    esac
}

# Do not invoke this function through `if`, `!`, or `&&`: those contexts
# disable Bash errexit inside functions and would hide installation failures.
run_tool() (
    set -Ee -o pipefail
    WORK_DIR=$(mktemp -d)
    trap 'rm -rf -- "$WORK_DIR"' EXIT
    trap 'printf "Failed at line %s: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR
    setup_paths
    install_tool "$1"
    setup_paths
    if [[ $1 != dev-tools ]]; then
        installed "$1" || { fail "$1 finished but could not be verified."; exit 1; }
    fi
    configure_tool "$1"
)

add_to_plan() {
    local tool=$1 dep
    contains "$EXCLUDED" "$tool" && return 0
    contains "${PLAN[*]}" "$tool" && return 0
    for dep in $(dependencies "$tool"); do add_to_plan "$dep"; done
    PLAN+=("$tool")
}

validate_list() {
    local item
    [[ -n $1 && $1 != ,* && $1 != *, && $1 != *,,* ]] || { fail 'Expected a comma-separated tool list.'; return 1; }
    for item in ${1//,/ }; do
        contains "${TOOLS[*]}" "$item" || { fail "Unknown tool: $item (see --list)"; return 1; }
    done
}

show_progress() {
    # A single output writer keeps the spinner below incoming log lines.
    # Leave redirected output plain, with no animation or escape sequences.
    if [[ ! -t 1 || ${TERM:-dumb} == dumb ]]; then cat; return; fi
    local tool=$1 frames="|/-\\" frame=0 line pending='' read_status
    trap 'printf "\r\033[2K"' EXIT
    while :; do
        printf '\r\033[2K[%s] %s' "${frames:frame:1}" "$tool"
        frame=$(( (frame + 1) % 4 ))
        line=''
        if IFS= read -r -t 0.1 line; then read_status=0; else read_status=$?; fi
        pending+=$line
        if (( read_status == 0 )); then
            printf '\r\033[2K%s\n' "$pending"
            pending=''
        elif (( read_status > 128 )); then
            # read retains partial lines on timeout; keep them for the next read.
            continue
        else
            printf '\r\033[2K'
            [[ -z $pending ]] || printf '%s\n' "$pending"
            break
        fi
    done
}

main() {
    local only='' skip='' yes=0 dry_run=0 tool dep status log answer blocked
    local TMUX_SIXEL=0
    local -a PLAN=() completed=() failed=() skipped=() pipeline_status=()
    while (( $# )); do
        case $1 in
            --help|-h) usage; return 0 ;;
            --list) printf '%s\n' "${TOOLS[@]}"; return 0 ;;
            --yes|-y) yes=1 ;;
            --dry-run) dry_run=1 ;;
            --tmux-sixel) TMUX_SIXEL=1 ;;
            --only|--skip)
                [[ $# -ge 2 ]] || { fail "$1 needs a tool list."; return 2; }
                validate_list "$2" || return 2
                if [[ $1 == --only ]]; then only=${2//,/ }; else skip=${2//,/ }; fi
                shift ;;
            *) fail "Unknown option: $1 (see --help)"; return 2 ;;
        esac
        shift
    done
    detect_platform || return 2
    setup_paths || { fail 'Could not load the existing NVM environment.'; return 2; }
    EXCLUDED=$skip
    for tool in ${only:-${TOOLS[*]}}; do add_to_plan "$tool"; done
    (( ${#PLAN[@]} )) || { printf 'Nothing selected.\n'; return 0; }
    printf 'Development tools — %s\n\n' "$OS_NAME"
    for tool in "${PLAN[@]}"; do
        if [[ $tool == tmux && $TMUX_SIXEL == 1 ]]; then
            status='check source updates / build with SIXEL → /usr/local/bin/tmux'
        elif [[ $tool == dev-tools ]]; then status='refresh repositories and install/update prerequisites'
        elif installed "$tool"; then status='check for updates and apply if available'
        elif [[ $tool == tmux ]]; then status='install distro package'
        else status='install'; fi
        printf '  %-22s %s\n' "$tool" "$status"
    done
    if [[ $PM == pacman ]] && contains "${PLAN[*]}" dev-tools; then
        printf '\nArch preparation includes a full system upgrade (pacman -Syu).\n'
    fi
    (( dry_run )) && return 0
    if (( ! yes )); then
        [[ -t 0 ]] || { fail 'Use --yes for a noninteractive run, or --dry-run to preview.'; return 2; }
        read -r -p $'\nProceed? [y/N] ' answer
        [[ $answer == y || $answer == Y || $answer == yes ]] || { printf 'Cancelled.\n'; return 0; }
    fi
    if (( EUID != 0 )); then
        has sudo || { fail 'sudo is required for system packages.'; return 2; }
        sudo -v || return 2
    fi
    local log_root="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/install"
    mkdir -p "$log_root" || return 2
    LOG_DIR=$(mktemp -d "$log_root/$(date +%Y%m%d-%H%M%S).XXXXXX") || return 2
    printf '\nLogs: %s\n' "$LOG_DIR"
    trap 'printf "\nInterrupted. Logs: %s\n" "$LOG_DIR"; exit 130' INT
    trap 'printf "\nTerminated. Logs: %s\n" "$LOG_DIR"; exit 143' TERM
    for tool in "${PLAN[@]}"; do
        blocked=''
        for dep in $(dependencies "$tool"); do
            if contains "${failed[*]} ${skipped[*]}" "$dep" ||
                { contains "$EXCLUDED" "$dep" && ! installed "$dep"; }; then
                blocked=$dep
                break
            fi
        done
        if [[ -n $blocked ]]; then
            printf '[BLOCKED] %s: dependency %s is unavailable\n' "$tool" "$blocked"
            skipped+=("$tool")
            continue
        fi
        log="$LOG_DIR/$tool.log"
        printf '[RUN] %s (output: %s)\n' "$tool" "$log"
        # Keep this pipeline outside a conditional so run_tool retains errexit.
        # Capture all statuses immediately: output handling must not hide a
        # failed install, and a log write failure must also be reported.
        run_tool "$tool" 2>&1 | tee "$log" | show_progress "$tool"
        pipeline_status=("${PIPESTATUS[@]}")
        status=${pipeline_status[0]}
        if (( pipeline_status[1] != 0 )); then
            printf '[FAILED] Could not write the complete log: %s\n' "$log" >&2
            (( status != 0 )) || status=${pipeline_status[1]}
        fi
        if (( pipeline_status[2] != 0 )); then
            printf '[FAILED] Could not display output for %s\n' "$tool" >&2
            (( status != 0 )) || status=${pipeline_status[2]}
        fi
        if (( status == 0 )); then
            printf '[OK] %s\n' "$tool"
            completed+=("$tool")
        else
            printf '[FAILED] %s (exit %s)\n' "$tool" "$status"
            failed+=("$tool")
        fi
    done
    printf '\nFinished: %s successful, %s failed, %s blocked.\n' "${#completed[@]}" "${#failed[@]}" "${#skipped[@]}"
    printf 'Logs: %s\n' "$LOG_DIR"
    if (( ${#failed[@]} + ${#skipped[@]} )); then
        local retry
        retry=$(IFS=,; printf '%s' "${failed[*]}${failed[*]:+,}${skipped[*]}")
        retry=${retry%,}
        printf 'After resolving the errors, retry: ./install.sh --only %s' "$retry"
        if (( TMUX_SIXEL )) && contains "${failed[*]} ${skipped[*]}" tmux; then
            printf ' --tmux-sixel'
        fi
        printf '\n'
        return 1
    fi
    printf 'Open a new terminal. Ensure ~/.local/bin and ~/.cargo/bin are on your PATH.\n'
}

# Parse the invocation and exit together before main starts. If this file is
# edited during an install, Bash must not resume reading at a stale offset.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; exit $?; fi
