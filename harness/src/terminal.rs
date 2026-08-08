use anyhow::Result;
use crossterm::{
    event::{self, Event, KeyCode, KeyEvent},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph},
    Frame, Terminal,
};
use std::io;
use std::time::Duration;

use crate::config::Config;

pub fn run(config: Config) -> Result<()> {
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let mut app = AppState::new(&config);

    loop {
        terminal.draw(|f| ui(f, &mut app))?;

        if event::poll(Duration::from_millis(100))? {
            if let Event::Key(key) = event::read()? {
                if handle_key(key, &mut app) {
                    break;
                }
            }
        }
    }

    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;

    Ok(())
}

struct AppState {
    config: Config,
    should_quit: bool,
    active_pane: usize,
    panes: Vec<Pane>,
}

struct Pane {
    name: String,
    content: Vec<String>,
    scroll_offset: usize,
}

impl AppState {
    fn new(config: &Config) -> Self {
        let panes: Vec<Pane> = config.panes.default_layout
            .iter()
            .flat_map(|group| group.panes.clone())
            .map(|name| Pane {
                name,
                content: vec!["Welcome to GN Harness".to_string()],
                scroll_offset: 0,
            })
            .collect();

        AppState {
            config: config.clone(),
            should_quit: false,
            active_pane: 0,
            panes,
        }
    }
}

fn ui(f: &mut Frame, app: &mut AppState) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),
            Constraint::Min(0),
            Constraint::Length(3),
        ])
        .split(f.area());

    let header = Paragraph::new(Line::from(vec![
        Span::styled(" GN Harness ", Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD)),
        Span::raw(format!(" | {} panes | Active: {}", app.panes.len(), app.active_pane)),
    ]))
    .block(Block::default().borders(Borders::ALL).title("GN Harness"));
    f.render_widget(header, chunks[0]);

    let content_chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints(
            app.panes.iter()
                .map(|_| Constraint::Ratio(1, app.panes.len() as u32))
                .collect::<Vec<_>>()
        )
        .split(chunks[1]);

    for (i, pane) in app.panes.iter_mut().enumerate() {
        let style = if i == app.active_pane {
            Style::default().fg(Color::Yellow)
        } else {
            Style::default()
        };

        let content: Vec<Line> = pane.content
            .iter()
            .map(|line| Line::from(Span::raw(line.clone())))
            .collect();

        let widget = Paragraph::new(content)
            .block(Block::default().borders(Borders::ALL).title(pane.name.as_str()).style(style));

        f.render_widget(widget, content_chunks[i]);
    }

    let status = Paragraph::new(Line::from(vec![
        Span::styled(" Ctrl+Q: Quit ", Style::default().fg(Color::DarkGray)),
        Span::raw("| "),
        Span::styled("Ctrl+T: New Tab ", Style::default().fg(Color::DarkGray)),
        Span::raw("| "),
        Span::styled("Ctrl+W: Close Pane ", Style::default().fg(Color::DarkGray)),
    ]))
    .block(Block::default().borders(Borders::ALL));
    f.render_widget(status, chunks[2]);
}

fn handle_key(key: KeyEvent, app: &mut AppState) -> bool {
    match key.code {
        KeyCode::Char('q') if key.modifiers.contains(event::KeyModifiers::CONTROL) => {
            app.should_quit = true;
            true
        }
        KeyCode::Tab if key.modifiers.contains(event::KeyModifiers::CONTROL) => {
            app.active_pane = (app.active_pane + 1) % app.panes.len();
            false
        }
        _ => false,
    }
}
