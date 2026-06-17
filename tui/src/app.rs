use std::path::PathBuf;
use std::process::Command;

use ratatui::widgets::{ListState, TableState};

use crate::config;
use crate::installer::TOOLS;
use crate::symlink::{self, LinkState, Symlink};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Tab {
    Install,
    Symlinks,
    Configs,
    Status,
}

impl Tab {
    pub fn title(self) -> &'static str {
        match self {
            Tab::Install => "Install",
            Tab::Symlinks => "Symlinks",
            Tab::Configs => "Configs",
            Tab::Status => "Status",
        }
    }

    pub fn all() -> [Tab; 4] {
        [Tab::Install, Tab::Symlinks, Tab::Configs, Tab::Status]
    }

    pub fn next(self) -> Tab {
        match self {
            Tab::Install => Tab::Symlinks,
            Tab::Symlinks => Tab::Configs,
            Tab::Configs => Tab::Status,
            Tab::Status => Tab::Install,
        }
    }

    pub fn prev(self) -> Tab {
        match self {
            Tab::Install => Tab::Status,
            Tab::Symlinks => Tab::Install,
            Tab::Configs => Tab::Symlinks,
            Tab::Status => Tab::Configs,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Level {
    Info,
    Command,
    Success,
    Error,
}

#[derive(Debug, Clone)]
pub struct LogLine {
    pub text: String,
    pub level: Level,
}

impl LogLine {
    pub fn info(text: impl Into<String>) -> Self {
        Self { text: text.into(), level: Level::Info }
    }
    pub fn command(text: impl Into<String>) -> Self {
        Self { text: text.into(), level: Level::Command }
    }
    pub fn success(text: impl Into<String>) -> Self {
        Self { text: text.into(), level: Level::Success }
    }
    pub fn error(text: impl Into<String>) -> Self {
        Self { text: text.into(), level: Level::Error }
    }
}

#[derive(Debug)]
pub enum PendingAction {
    RunSelectedInstalls,
    CreateSymlink(usize),
    RemoveSymlink(usize),
    EditConfig(PathBuf),
    RefreshStatus,
}

pub struct App {
    pub tab: Tab,
    pub should_quit: bool,
    pub pending: Option<PendingAction>,

    pub install_state: ListState,
    pub install_checked: Vec<bool>,
    pub status: Vec<bool>,

    pub symlinks: Vec<Symlink>,
    pub symlink_state: ListState,
    pub symlink_states: Vec<LinkState>,

    pub config_state: ListState,
    pub config_preview: String,
    pub config_preview_path: Option<String>,

    pub status_state: TableState,

    pub log: Vec<LogLine>,
}

impl App {
    pub fn new() -> Self {
        let symlinks = symlink::definitions();
        let symlink_states = symlinks.iter().map(symlink::state_of).collect();
        let mut app = Self {
            tab: Tab::Install,
            should_quit: false,
            pending: None,
            install_state: ListState::default(),
            install_checked: vec![false; TOOLS.len()],
            status: vec![false; TOOLS.len()],
            symlinks,
            symlink_state: ListState::default(),
            symlink_states,
            config_state: ListState::default(),
            config_preview: String::new(),
            config_preview_path: None,
            status_state: TableState::default(),
            log: vec![LogLine::info(format!(
                "dotfiles-tui ready. OS: {}. Use Tab to switch, ? for help, q to quit.",
                crate::status::distro_name()
            ))],
        };
        app.install_state.select(Some(0));
        app.symlink_state.select(Some(0));
        app.config_state.select(Some(0));
        app.status_state.select(Some(0));
        app.refresh_status();
        app.load_config_preview(0);
        app
    }

    pub fn refresh_status(&mut self) {
        self.status = TOOLS.iter().map(|t| (t.check)()).collect();
        self.symlink_states = self.symlinks.iter().map(symlink::state_of).collect();
    }

    pub fn load_config_preview(&mut self, idx: usize) {
        if let Some(cf) = config::CONFIG_FILES.get(idx) {
            self.config_preview_path = Some(cf.rel.to_string());
            self.config_preview = match config::read(cf) {
                Ok(content) => content,
                Err(e) => format!("(error: {e})"),
            };
        }
    }

    fn list_len(&self) -> usize {
        match self.tab {
            Tab::Install => TOOLS.len(),
            Tab::Symlinks => self.symlinks.len(),
            Tab::Configs => config::CONFIG_FILES.len(),
            Tab::Status => TOOLS.len(),
        }
    }

    fn move_cursor(&mut self, delta: i32) {
        let len = self.list_len();
        if len == 0 {
            return;
        }
        let current = match self.tab {
            Tab::Install => self.install_state.selected().unwrap_or(0),
            Tab::Symlinks => self.symlink_state.selected().unwrap_or(0),
            Tab::Configs => self.config_state.selected().unwrap_or(0),
            Tab::Status => self.status_state.selected().unwrap_or(0),
        };
        let mut next = current as i32 + delta;
        if next < 0 {
            next = len as i32 - 1;
        }
        if next >= len as i32 {
            next = 0;
        }
        let n = next as usize;
        match self.tab {
            Tab::Install => self.install_state.select(Some(n)),
            Tab::Symlinks => self.symlink_state.select(Some(n)),
            Tab::Configs => {
                self.config_state.select(Some(n));
                self.load_config_preview(n);
            }
            Tab::Status => self.status_state.select(Some(n)),
        }
    }

    fn selected(&self) -> Option<usize> {
        match self.tab {
            Tab::Install => self.install_state.selected(),
            Tab::Symlinks => self.symlink_state.selected(),
            Tab::Configs => self.config_state.selected(),
            Tab::Status => self.status_state.selected(),
        }
    }

    pub fn handle_key(&mut self, key: crossterm::event::KeyEvent) {
        use crossterm::event::{KeyCode, KeyModifiers};

        if key.modifiers.contains(KeyModifiers::CONTROL) {
            if key.code == KeyCode::Char('c') {
                self.should_quit = true;
            }
            return;
        }

        match key.code {
            KeyCode::Char('q') => self.should_quit = true,
            KeyCode::Tab | KeyCode::Char('l') => self.tab = self.tab.next(),
            KeyCode::BackTab | KeyCode::Char('h') => self.tab = self.tab.prev(),
            KeyCode::Char('1') => self.tab = Tab::Install,
            KeyCode::Char('2') => self.tab = Tab::Symlinks,
            KeyCode::Char('3') => self.tab = Tab::Configs,
            KeyCode::Char('4') => self.tab = Tab::Status,
            KeyCode::Down | KeyCode::Char('j') => self.move_cursor(1),
            KeyCode::Up | KeyCode::Char('k') => self.move_cursor(-1),
            KeyCode::Home | KeyCode::Char('g') => {
                self.move_cursor_to(0);
            }
            KeyCode::End | KeyCode::Char('G') => {
                self.move_cursor_to(self.list_len().saturating_sub(1));
            }
            KeyCode::Char('r') => {
                if self.tab == Tab::Status {
                    self.log.push(LogLine::info("refreshing status..."));
                    self.refresh_status();
                    self.log.push(LogLine::success("status refreshed"));
                } else if self.tab == Tab::Symlinks {
                    self.refresh_status();
                    self.log.push(LogLine::success("symlink status refreshed"));
                } else {
                    self.pending = Some(PendingAction::RefreshStatus);
                }
            }
            KeyCode::Char('?') => {
                self.log.push(LogLine::info(
                    "Keys: Tab/1-4 switch tabs | j/k move | Space toggle | Enter action | \
                     a select all | n select none | i invert | c create link | r remove/refresh | \
                     e edit config | R refresh | q quit",
                ));
            }
            KeyCode::Char('R') => {
                self.refresh_status();
                self.log.push(LogLine::success("status refreshed"));
            }
            _ => self.handle_tab_key(key.code),
        }
    }

    fn move_cursor_to(&mut self, idx: usize) {
        match self.tab {
            Tab::Install => self.install_state.select(Some(idx)),
            Tab::Symlinks => self.symlink_state.select(Some(idx)),
            Tab::Configs => {
                self.config_state.select(Some(idx));
                self.load_config_preview(idx);
            }
            Tab::Status => self.status_state.select(Some(idx)),
        }
    }

    fn handle_tab_key(&mut self, code: crossterm::event::KeyCode) {
        use crossterm::event::KeyCode;
        match self.tab {
            Tab::Install => match code {
                KeyCode::Char(' ') => {
                    if let Some(i) = self.selected() {
                        self.install_checked[i] = !self.install_checked[i];
                    }
                }
                KeyCode::Enter => {
                    let any = self.install_checked.iter().any(|&b| b);
                    if any {
                        self.pending = Some(PendingAction::RunSelectedInstalls);
                    } else if let Some(i) = self.selected() {
                        self.install_checked[i] = true;
                        self.pending = Some(PendingAction::RunSelectedInstalls);
                    } else {
                        self.log.push(LogLine::error("no tool selected"));
                    }
                }
                KeyCode::Char('a') => {
                    for b in &mut self.install_checked {
                        *b = true;
                    }
                }
                KeyCode::Char('n') => {
                    for b in &mut self.install_checked {
                        *b = false;
                    }
                }
                KeyCode::Char('i') => {
                    for b in &mut self.install_checked {
                        *b = !*b;
                    }
                }
                _ => {}
            },
            Tab::Symlinks => match code {
                KeyCode::Enter | KeyCode::Char('c') => {
                    if let Some(i) = self.selected() {
                        self.pending = Some(PendingAction::CreateSymlink(i));
                    }
                }
                KeyCode::Char('r') => {
                    if let Some(i) = self.selected() {
                        self.pending = Some(PendingAction::RemoveSymlink(i));
                    }
                }
                _ => {}
            },
            Tab::Configs => match code {
                KeyCode::Enter | KeyCode::Char('e') => {
                    if let Some(i) = self.selected() {
                        let cf = &config::CONFIG_FILES[i];
                        self.pending = Some(PendingAction::EditConfig(config::path(cf)));
                    }
                }
                _ => {}
            },
            Tab::Status => if code == KeyCode::Enter {
                if let Some(i) = self.selected() {
                    self.tab = Tab::Install;
                    self.install_state.select(Some(i));
                    self.install_checked[i] = true;
                    self.log.push(LogLine::info(format!(
                        "marked '{}' for install; press Enter on Install tab to run",
                        TOOLS[i].name
                    )));
                }
            },
        }
    }

    pub fn editor_for(path: &std::path::Path) -> Command {
        let editor = std::env::var("EDITOR").unwrap_or_else(|_| "vi".into());
        let mut cmd = Command::new(editor);
        cmd.arg(path);
        cmd
    }
}

impl Default for App {
    fn default() -> Self {
        Self::new()
    }
}
