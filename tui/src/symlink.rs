use std::fs;
use std::path::{Path, PathBuf};

use crate::status;

pub struct Symlink {
    pub name: &'static str,
    pub source: PathBuf,
    pub target: PathBuf,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum LinkState {
    Correct,
    WrongTarget(String),
    NotALink,
    Missing,
}

pub fn definitions() -> Vec<Symlink> {
    let home = status::home_dir();
    let df = status::dotfiles_dir();
    vec![
        Symlink {
            name: "nvim config",
            source: home.join(".config/nvim"),
            target: df.join("nvim"),
        },
        Symlink {
            name: ".zshrc",
            source: df.join(".zshrc"),
            target: home.join(".zshrc"),
        },
        Symlink {
            name: ".tmux.conf",
            source: df.join(".tmux.conf"),
            target: home.join(".tmux.conf"),
        },
        Symlink {
            name: "light-colors theme",
            source: df.join("light-colors.zsh-theme"),
            target: home.join(".oh-my-zsh/themes/light-colors.zsh-theme"),
        },
    ]
}

pub fn state_of(s: &Symlink) -> LinkState {
    let meta = match fs::symlink_metadata(&s.target) {
        Ok(m) => m,
        Err(_) => return LinkState::Missing,
    };
    if !meta.file_type().is_symlink() {
        return LinkState::NotALink;
    }
    match fs::read_link(&s.target) {
        Ok(p) if p == s.source => LinkState::Correct,
        Ok(p) => LinkState::WrongTarget(p.display().to_string()),
        Err(_) => LinkState::Missing,
    }
}

pub fn create(s: &Symlink) -> Result<(), String> {
    if let Some(parent) = s.target.parent() {
        fs::create_dir_all(parent).map_err(|e| format!("mkdir {}: {e}", parent.display()))?;
    }
    if s.target.exists() || s.target.is_symlink() {
        remove(s)?;
    }
    std::os::unix::fs::symlink(&s.source, &s.target)
        .map_err(|e| format!("symlink {} -> {}: {e}", s.target.display(), s.source.display()))
}

pub fn remove(s: &Symlink) -> Result<(), String> {
    let meta = fs::symlink_metadata(&s.target);
    match meta {
        Ok(m) if m.file_type().is_symlink() => {
            fs::remove_file(&s.target).map_err(|e| format!("remove {}: {e}", s.target.display()))
        }
        Ok(_) => Err(format!("{} exists but is not a symlink (refusing to remove)", s.target.display())),
        Err(_) => Err(format!("{} does not exist", s.target.display())),
    }
}

pub fn target_str(s: &Symlink) -> String {
    pretty(s.target.strip_prefix(status::home_dir()).unwrap_or(&s.target), &s.target)
}

pub fn source_str(s: &Symlink) -> String {
    pretty(s.source.strip_prefix(status::home_dir()).unwrap_or(&s.source), &s.source)
}

fn pretty(short: &Path, full: &Path) -> String {
    if short == full {
        full.display().to_string()
    } else {
        format!("~/{}", short.display())
    }
}
