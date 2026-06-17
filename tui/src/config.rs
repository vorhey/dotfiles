use std::fs;
use std::path::PathBuf;

use crate::status;

pub struct ConfigFile {
    pub name: &'static str,
    pub rel: &'static str,
}

pub static CONFIG_FILES: &[ConfigFile] = &[
    ConfigFile { name: ".zshrc", rel: ".zshrc" },
    ConfigFile { name: ".tmux.conf", rel: ".tmux.conf" },
    ConfigFile { name: "install.sh", rel: "install.sh" },
    ConfigFile { name: "symlink.sh", rel: "symlink.sh" },
    ConfigFile { name: ".zsh_history_ignore", rel: ".zsh_history_ignore" },
    ConfigFile { name: "light-colors.zsh-theme", rel: "light-colors.zsh-theme" },
    ConfigFile { name: "fzf-theme-dark.zsh", rel: "fzf-theme-dark.zsh" },
    ConfigFile { name: "fzf-theme-light.zsh", rel: "fzf-theme-light.zsh" },
    ConfigFile { name: "get_distro_icon.sh", rel: "get_distro_icon.sh" },
    ConfigFile { name: "get_process_icon.sh", rel: "get_process_icon.sh" },
    ConfigFile { name: "get_project_root.sh", rel: "get_project_root.sh" },
    ConfigFile { name: "tmux-grid.sh", rel: "tmux-grid.sh" },
];

pub fn path(cf: &ConfigFile) -> PathBuf {
    status::dotfiles_dir().join(cf.rel)
}

pub fn read(cf: &ConfigFile) -> Result<String, String> {
    fs::read_to_string(path(cf)).map_err(|e| format!("read {}: {e}", cf.rel))
}
