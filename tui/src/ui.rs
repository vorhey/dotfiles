use ratatui::layout::{Alignment, Constraint, Direction, Layout, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{
    Block, Borders, Cell, List, ListItem, Paragraph, Row, Table, Tabs, Wrap,
};
use ratatui::Frame;

use crate::app::{Level, LogLine, Tab};
use crate::config::CONFIG_FILES;
use crate::installer::TOOLS;
use crate::symlink::LinkState;
use crate::App;

pub fn draw(frame: &mut Frame, app: &mut App) {
    let area = frame.area();
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),
            Constraint::Min(5),
            Constraint::Length(10),
            Constraint::Length(1),
        ])
        .split(area);

    draw_tabs(frame, app, chunks[0]);
    draw_content(frame, app, chunks[1]);
    draw_log(frame, app, chunks[2]);
    draw_help(frame, app, chunks[3]);
}

fn draw_tabs(frame: &mut Frame, app: &mut App, area: Rect) {
    let titles: Vec<Line> = Tab::all()
        .iter()
        .map(|t| Line::from(format!(" {} ", t.title())))
        .collect();
    let tabs = Tabs::new(titles)
        .block(Block::default().borders(Borders::ALL).title("dotfiles-tui"))
        .select(app.tab as usize)
        .style(Style::default().fg(Color::Cyan))
        .highlight_style(Style::default().add_modifier(Modifier::BOLD).fg(Color::Yellow));
    frame.render_widget(tabs, area);
}

fn draw_content(frame: &mut Frame, app: &mut App, area: Rect) {
    match app.tab {
        Tab::Install => draw_install(frame, app, area),
        Tab::Symlinks => draw_symlinks(frame, app, area),
        Tab::Configs => draw_configs(frame, app, area),
        Tab::Status => draw_status(frame, app, area),
    }
}

fn draw_install(frame: &mut Frame, app: &mut App, area: Rect) {
    let items: Vec<ListItem> = TOOLS
        .iter()
        .enumerate()
        .map(|(i, t)| {
            let checked = app.install_checked[i];
            let installed = app.status.get(i).copied().unwrap_or(false);
            let box_span = Span::styled(
                if checked { "[x]" } else { "[ ]" },
                Style::default().fg(if checked { Color::Green } else { Color::DarkGray }),
            );
            let status_span = Span::styled(
                if installed { " ✓ " } else { " · " },
                Style::default().fg(if installed { Color::Green } else { Color::DarkGray }),
            );
            let name_span = Span::styled(
                t.name.to_string(),
                Style::default().add_modifier(Modifier::BOLD),
            );
            let desc_span = Span::styled(format!("  — {}", t.desc), Style::default().fg(Color::Gray));
            ListItem::new(Line::from(vec![box_span, Span::raw(" "), status_span, name_span, desc_span]))
        })
        .collect();
    let list = List::new(items)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .title(format!("Install  ({} tools)", TOOLS.len())),
        )
        .highlight_style(Style::default().bg(Color::DarkGray).add_modifier(Modifier::BOLD))
        .highlight_symbol("▶ ");
    frame.render_stateful_widget(list, area, &mut app.install_state);
}

fn draw_symlinks(frame: &mut Frame, app: &mut App, area: Rect) {
    let items: Vec<ListItem> = app
        .symlinks
        .iter()
        .enumerate()
        .map(|(i, s)| {
            let state = &app.symlink_states[i];
            let (label, color) = match state {
                LinkState::Correct => ("correct", Color::Green),
                LinkState::WrongTarget(_) => ("wrong target", Color::Red),
                LinkState::NotALink => ("not a symlink", Color::Red),
                LinkState::Missing => ("missing", Color::Yellow),
            };
            let name = Span::styled(s.name.to_string(), Style::default().add_modifier(Modifier::BOLD));
            let status = Span::styled(format!(" [{label}]"), Style::default().fg(color));
            let detail = Span::styled(
                format!("  {} -> {}", crate::symlink::target_str(s), crate::symlink::source_str(s)),
                Style::default().fg(Color::Gray),
            );
            ListItem::new(Line::from(vec![name, status, detail]))
        })
        .collect();
    let list = List::new(items)
        .block(Block::default().borders(Borders::ALL).title("Symlinks"))
        .highlight_style(Style::default().bg(Color::DarkGray).add_modifier(Modifier::BOLD))
        .highlight_symbol("▶ ");
    frame.render_stateful_widget(list, area, &mut app.symlink_state);
}

fn draw_configs(frame: &mut Frame, app: &mut App, area: Rect) {
    let horizontal = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(35), Constraint::Percentage(65)])
        .split(area);

    let items: Vec<ListItem> = CONFIG_FILES
        .iter()
        .map(|cf| ListItem::new(Line::from(format!(" {} ", cf.name))))
        .collect();
    let list = List::new(items)
        .block(Block::default().borders(Borders::ALL).title("Configs"))
        .highlight_style(Style::default().bg(Color::DarkGray).add_modifier(Modifier::BOLD))
        .highlight_symbol("▶ ");
    frame.render_stateful_widget(list, horizontal[0], &mut app.config_state);

    let title = app
        .config_preview_path
        .clone()
        .unwrap_or_else(|| "(no file)".into());
    let preview = Paragraph::new(app.config_preview.clone())
        .block(Block::default().borders(Borders::ALL).title(format!("Preview: {}", title)))
        .wrap(Wrap { trim: false })
        .alignment(Alignment::Left)
        .style(Style::default().fg(Color::White));
    frame.render_widget(preview, horizontal[1]);
}

fn draw_status(frame: &mut Frame, app: &mut App, area: Rect) {
    let header = Row::new(vec![
        Cell::from(Span::styled("Tool", Style::default().add_modifier(Modifier::BOLD))),
        Cell::from(Span::styled("Status", Style::default().add_modifier(Modifier::BOLD))),
        Cell::from(Span::styled("Detected via", Style::default().add_modifier(Modifier::BOLD))),
    ])
    .height(1)
    .bottom_margin(0);

    let rows: Vec<Row> = TOOLS
        .iter()
        .enumerate()
        .map(|(i, t)| {
            let installed = app.status.get(i).copied().unwrap_or(false);
            let status = if installed { "installed" } else { "not installed" };
            let color = if installed { Color::Green } else { Color::Yellow };
            Row::new(vec![
                Cell::from(t.name.to_string()),
                Cell::from(Span::styled(status, Style::default().fg(color))),
                Cell::from(Span::styled(t.desc.to_string(), Style::default().fg(Color::Gray))),
            ])
        })
        .collect();

    let table = Table::new(
        rows,
        [Constraint::Length(22), Constraint::Length(14), Constraint::Min(10)],
    )
    .header(header)
    .block(
        Block::default()
            .borders(Borders::ALL)
            .title(format!("System status  (OS: {})", crate::status::distro_name())),
    )
    .row_highlight_style(Style::default().bg(Color::DarkGray).add_modifier(Modifier::BOLD))
    .highlight_symbol("▶ ");
    frame.render_stateful_widget(table, area, &mut app.status_state);
}

fn draw_log(frame: &mut Frame, app: &mut App, area: Rect) {
    let lines: Vec<Line> = app
        .log
        .iter()
        .rev()
        .take(area.height.saturating_sub(2) as usize)
        .map(line_to_line)
        .collect();
    let paragraph = Paragraph::new(lines)
        .block(Block::default().borders(Borders::ALL).title("Log"))
        .wrap(Wrap { trim: false });
    frame.render_widget(paragraph, area);
}

fn line_to_line(l: &LogLine) -> Line<'static> {
    let color = match l.level {
        Level::Info => Color::White,
        Level::Command => Color::Cyan,
        Level::Success => Color::Green,
        Level::Error => Color::Red,
    };
    Line::from(Span::styled(l.text.clone(), Style::default().fg(color)))
}

fn draw_help(frame: &mut Frame, app: &mut App, area: Rect) {
    let hint = match app.tab {
        Tab::Install => "Space toggle  |  Enter install selected  |  a all  |  n none  |  i invert",
        Tab::Symlinks => "Enter/c create  |  r remove  |  R refresh",
        Tab::Configs => "j/k browse  |  Enter/e edit in $EDITOR",
        Tab::Status => "r/R refresh  |  Enter mark for install",
    };
    let global = "Tab switch  |  1-4 tabs  |  ? help  |  q quit";
    let text = Line::from(vec![
        Span::styled(format!(" {hint}  "), Style::default().fg(Color::Yellow)),
        Span::styled(global, Style::default().fg(Color::DarkGray)),
    ]);
    frame.render_widget(Paragraph::new(text), area);
}
