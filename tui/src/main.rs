mod app;
mod config;
mod installer;
mod status;
mod symlink;
mod ui;

use std::io::{self, Stdout, Write};
use std::time::Duration;

use crossterm::event::{self, Event};
use crossterm::terminal::{
    disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen,
};
use crossterm::execute;
use ratatui::backend::CrosstermBackend;
use ratatui::Terminal;

use app::{App, LogLine, PendingAction};

type Backend = CrosstermBackend<Stdout>;

fn main() -> std::io::Result<()> {
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = Backend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let mut app = App::new();
    let result = run(&mut terminal, &mut app);

    restore(&mut terminal)?;
    result
}

fn run(terminal: &mut Terminal<Backend>, app: &mut App) -> std::io::Result<()> {
    while !app.should_quit {
        terminal.draw(|f| ui::draw(f, app))?;

        if event::poll(Duration::from_millis(250))? {
            if let Event::Key(key) = event::read()? {
                app.handle_key(key);
            }
        }

        if let Some(action) = app.pending.take() {
            execute_action(terminal, app, action);
            app.refresh_status();
        }
    }
    Ok(())
}

fn execute_action(terminal: &mut Terminal<Backend>, app: &mut App, action: PendingAction) {
    match action {
        PendingAction::RunSelectedInstalls => run_installs(terminal, app),
        PendingAction::CreateSymlink(i) => {
            let s = &app.symlinks[i];
            app.log.push(LogLine::command(format!(
                "ln -s {} {}",
                s.source.display(),
                s.target.display()
            )));
            match symlink::create(s) {
                Ok(_) => app.log.push(LogLine::success(format!("created symlink: {}", s.name))),
                Err(e) => app.log.push(LogLine::error(e)),
            }
        }
        PendingAction::RemoveSymlink(i) => {
            let s = &app.symlinks[i];
            match symlink::remove(s) {
                Ok(_) => app.log.push(LogLine::success(format!("removed symlink: {}", s.name))),
                Err(e) => app.log.push(LogLine::error(e)),
            }
        }
        PendingAction::EditConfig(path) => edit_config(terminal, app, path),
        PendingAction::RefreshStatus => {
            app.refresh_status();
            app.log.push(LogLine::success("status refreshed"));
        }
    }
}

fn run_installs(terminal: &mut Terminal<Backend>, app: &mut App) {
    let selected: Vec<usize> = app
        .install_checked
        .iter()
        .enumerate()
        .filter(|(_, &b)| b)
        .map(|(i, _)| i)
        .collect();
    if selected.is_empty() {
        app.log.push(LogLine::error("no tools selected"));
        return;
    }

    let names: Vec<&str> = selected.iter().map(|&i| installer::TOOLS[i].name).collect();
    app.log
        .push(LogLine::command(format!("installing: {}", names.join(", "))));

    let _ = suspend(terminal);
    println!();
    println!("==== Running installs (output streamed below) ====");
    println!();

    let mut results: Vec<(&str, bool, String)> = Vec::new();
    for &i in &selected {
        let tool = &installer::TOOLS[i];
        println!();
        println!(">>> Installing {}", tool.name);
        match (tool.install)() {
            Ok(msg) => {
                println!("OK: {msg}");
                results.push((tool.name, true, msg));
            }
            Err(e) => {
                println!("FAILED: {e}");
                results.push((tool.name, false, e));
            }
        }
    }

    println!();
    println!("==== Done. Press Enter to return to the TUI. ====");
    let _ = io::stdout().flush();
    let mut buf = String::new();
    let _ = io::stdin().read_line(&mut buf);

    let _ = resume(terminal);

    for (name, ok, msg) in results {
        if ok {
            app.log.push(LogLine::success(format!("[{name}] {msg}")));
        } else {
            app.log.push(LogLine::error(format!("[{name}] {msg}")));
        }
    }
    for &i in &selected {
        app.install_checked[i] = false;
    }
}

fn edit_config(terminal: &mut Terminal<Backend>, app: &mut App, path: std::path::PathBuf) {
    let _ = suspend(terminal);
    let status = App::editor_for(&path).status();
    let _ = resume(terminal);
    match status {
        Ok(s) if s.success() => {
            if let Some(idx) = app.config_state.selected() {
                app.load_config_preview(idx);
            }
            app.log.push(LogLine::success(format!("edited {}", path.display())));
        }
        Ok(s) => app.log.push(LogLine::error(format!("editor exited with status {:?}", s.code()))),
        Err(e) => app.log.push(LogLine::error(format!("failed to launch editor: {e}"))),
    }
}

fn suspend(terminal: &mut Terminal<Backend>) -> io::Result<()> {
    let mut stdout = io::stdout();
    execute!(stdout, LeaveAlternateScreen)?;
    disable_raw_mode()?;
    terminal.clear()?;
    Ok(())
}

fn resume(terminal: &mut Terminal<Backend>) -> io::Result<()> {
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    enable_raw_mode()?;
    terminal.clear()?;
    Ok(())
}

fn restore(terminal: &mut Terminal<Backend>) -> io::Result<()> {
    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;
    Ok(())
}
