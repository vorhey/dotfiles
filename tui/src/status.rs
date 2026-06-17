use std::path::{Path, PathBuf};
use std::process::Command;
use std::{env, fs};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Distro {
    Ubuntu,
    Debian,
    OpenSuse,
    Fedora,
    Arch,
    Macos,
    Other,
}

pub fn detect_os() -> Distro {
    if cfg!(target_os = "macos") {
        return Distro::Macos;
    }
    let content = fs::read_to_string("/etc/os-release").unwrap_or_default();
    let mut id = String::new();
    let mut id_like = String::new();
    for line in content.lines() {
        if let Some(v) = line.strip_prefix("ID=") {
            id = v.trim_matches('"').to_string();
        } else if let Some(v) = line.strip_prefix("ID_LIKE=") {
            id_like = v.trim_matches('"').to_string();
        }
    }
    match id.as_str() {
        "ubuntu" => return Distro::Ubuntu,
        "debian" => return Distro::Debian,
        s if s.starts_with("opensuse") || s.starts_with("suse") => return Distro::OpenSuse,
        "fedora" => return Distro::Fedora,
        "arch" | "archlinux" => return Distro::Arch,
        _ => {}
    }
    for like in id_like.split_whitespace() {
        match like {
            "ubuntu" => return Distro::Ubuntu,
            "debian" => return Distro::Debian,
            "fedora" => return Distro::Fedora,
            "arch" | "archlinux" => return Distro::Arch,
            s if s.contains("suse") => return Distro::OpenSuse,
            _ => {}
        }
    }
    Distro::Other
}

pub fn distro_name() -> String {
    let content = fs::read_to_string("/etc/os-release").unwrap_or_default();
    if let Some(p) = content
        .lines()
        .find_map(|l| l.strip_prefix("PRETTY_NAME=").map(|v| v.trim_matches('"').to_string()))
    {
        return p;
    }
    match detect_os() {
        Distro::Ubuntu => "Ubuntu".into(),
        Distro::Debian => "Debian GNU/Linux".into(),
        Distro::OpenSuse => "openSUSE Tumbleweed".into(),
        Distro::Fedora => "Fedora Linux".into(),
        Distro::Arch => "Arch Linux".into(),
        Distro::Macos => "macOS".into(),
        Distro::Other => "Unknown".into(),
    }
}

pub fn command_exists(cmd: &str) -> bool {
    Command::new("sh")
        .arg("-c")
        .arg(format!("command -v {cmd} >/dev/null 2>&1"))
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

pub fn home_dir() -> PathBuf {
    env::var("HOME").map(PathBuf::from).unwrap_or_else(|_| PathBuf::from("/"))
}

pub fn dotfiles_dir() -> PathBuf {
    if let Ok(d) = env::var("DOTFILES_DIR") {
        return PathBuf::from(d);
    }
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .map(PathBuf::from)
        .unwrap_or_else(|| home_dir().join("dotfiles"))
}
