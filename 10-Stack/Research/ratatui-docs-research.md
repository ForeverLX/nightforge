# Ratatui Documentation Research

> Comprehensive reference for building the GN Harness multi-pane TUI.

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Core Types](#2-core-types)
3. [Widget System](#3-widget-system)
4. [Layout System](#4-layout-system)
5. [Rendering Pipeline](#5-rendering-pipeline)
6. [Event Handling](#6-event-handling)
7. [Custom Widgets](#7-custom-widgets)
8. [Application Patterns](#8-application-patterns)
9. [Multi-Pane TUI Design](#9-multi-pane-tui-design)
10. [Keybinding Dispatch](#10-keybinding-dispatch)
11. [Terminal Backend Integration](#11-terminal-backend-integration)
12. [Code Examples for GN Harness](#12-code-examples-for-gn-harness)
13. [Key Takeaways](#13-key-takeaways)

---

## 1. Architecture Overview

Ratatui is an **immediate mode** retained-mode-hybrid terminal UI library for Rust. Each frame, the application describes the entire UI declaratively by rendering widgets into a `Frame`, and ratatui handles diffing the new state against the previous frame and flushing only the changed cells to the terminal.

### Core Loop

```
┌──────────────────────────────────────────────┐
│               Application Loop               │
│                                              │
│  1. Poll for events (crossterm::event::read) │
│  2. Update state based on events             │
│  3. terminal.draw(|frame| { render(frame) }) │
│     └─ Buffer diffing + backend flush        │
└──────────────────────────────────────────────┘
```

### Design Principles

- **Immediate mode**: You rebuild the entire UI description every frame. No retained widget tree, no layout invalidation, no diffing widget props. The diff happens at the cell level.
- **Backend agnostic**: Pluggable backends — crossterm (default, cross-platform), termion, termwiz. Swap with a trait object.
- **Widget composition**: Complex UIs built by composing simple widgets. `Block` wrapping `Paragraph`, `List` inside `Block`, etc.

---

## 2. Core Types

### `Terminal`

The top-level struct managing the terminal. Owns the backend, maintains double buffers (current + previous), and provides the `draw()` method.

```rust
use ratatui::backend::CrosstermBackend;
use ratatui::Terminal;

// Create terminal with crossterm backend
let backend = CrosstermBackend::new(stdout);
let mut terminal = Terminal::new(backend)?;

// Clear and initialize
terminal.clear()?;

// Draw a frame
terminal.draw(|frame| {
    // frame is &mut Frame — you render widgets into it here
})?;
```

**Key methods:**
- `Terminal::new(backend)` — create terminal
- `terminal.draw(|frame| { ... })` — render one frame
- `terminal.clear()` — clear entire screen
- `terminal.set_cursor(x, y)` — position cursor
- `terminal.autoresize = true` — auto-resize buffer on terminal resize

### `Frame`

A mutable view into the current buffer for a single draw call. This is where you place widgets. A `Frame` provides:
- `frame.size()` → `Rect` — current terminal dimensions
- `frame.render_widget(widget, area)` — render a widget into a `Rect`
- `frame.render_stateful_widget(widget, area, state)` — render widget with state
- `frame.set_cursor(x, y)` — show cursor
- `frame.buffer_mut()` — direct buffer access

```rust
terminal.draw(|frame| {
    let area = frame.size();  // Rect { x:0, y:0, width:120, width:40 }
    let block = Block::default().title("GN Harness").borders(Borders::ALL);
    frame.render_widget(block, area);
})?;
```

### `Buffer`

A 2D grid of `Cell` objects representing the terminal screen. Each cell holds a character, style (fg/bg/modifiers), and a set of `Modifier` flags.

- `Buffer::empty(area: Rect)` — create empty buffer
- `Buffer::init(area: Rect)` — create buffer initialized with spaces

Ratatui uses **double buffering**: it keeps the previous frame's buffer and only writes cells that changed. This is automatic — no application code needed.

### `Rect`

A simple rectangle: `{ x, y, width, height }`. Used everywhere for layout and widget placement.

```rust
let area = Rect {
    x: 0,
    y: 0,
    width: 120,
    height: 40,
};

// Rect methods
let inner = area.inner(Margin::new(1, 1));  // shrink by 1 on all sides
let chunks = area.split Layout::vertical(...);  // split into chunks
```

### `Style`

Describes visual appearance: foreground color, background color, modifiers (bold, italic, etc.).

```rust
use ratatui::style::{Color, Modifier, Style};

let style = Style::default()
    .fg(Color::Cyan)
    .bg(Color::DarkGray)
    .add_modifier(Modifier::BOLD);
```

### `Color`

Supported color models:
```rust
Color::Reset
Color::Black | Color::Red | Color::Green | Color::Yellow
Color::Blue | Color::Magenta | Color::Cyan | Color::White
Color::Gray | Color::DarkGray | Color::LightRed | ...
Color::Rgb(u8, u8, u8)      // True color (24-bit)
Color::Indexed(u8)          // 256-color palette
```

---

## 3. Widget System

### The `Widget` Trait

Every renderable thing implements `Widget`:

```rust
pub trait Widget {
    fn render(self, area: Rect, buf: &mut Buffer);
}
```

Note: `render` takes `self` by value, not reference. Widgets are consumed on render. To render a widget multiple times, clone it or re-create it.

### `StatefulWidget`

For widgets that need to track state (scroll position, selection, etc.):

```rust
pub trait StatefulWidget {
    type State;
    fn render(self, area: Rect, buf: &mut Buffer, state: &mut Self::State);
}
```

### Built-in Widgets

| Widget | Description | Stateful? |
|--------|-------------|-----------|
| `Block` | Container with borders, title, padding | No |
| `Paragraph` | Text (plain, wrapped, styled) | No |
| `List` | Vertical list with selection | Yes |
| `Table` | Columns and rows with selection | Yes |
| `Tabs` | Tab bar | Yes |
| `BarChart` | Horizontal bar chart | No |
| `Sparkline` | Sparkline graph | No |
| `Gauge` | Progress bar / gauge | No |
| `Gauge<'a>` | Gauge with optional label | No |
| `Wrap` | Word-wrap helper | N/A |
| `Scrollbar` | Scrollbar widget | Yes |

#### Block

The fundamental container. Every pane in a multi-pane layout uses `Block`.

```rust
Block::default()
    .title(" Pane 1 ")
    .title_alignment(Alignment::Center)
    .borders(Borders::ALL | Borders::TOP)
    .border_style(Style::default().fg(Color::Cyan))
    .border_type(BorderType::Rounded)  // or Plain, Double, Thick
    .style(Style::default().bg(Color::Black))
    .inner(Margin::new(1, 0))  // padding
```

**Borders**: `Borders::NONE | Borders::TOP | Borders::RIGHT | Borders::BOTTOM | Borders::LEFT | Borders::ALL`

**BorderType**: `BorderType::Plain`, `BorderType::Rounded`, `BorderType::Double`, `BorderType::Thick`

#### Paragraph

Render styled, wrapped text:

```rust
let text = vec![
    Line::from(vec![
        Span::styled("Error: ", Style::default().fg(Color::Red).add_modifier(Modifier::BOLD)),
        Span::raw("something went wrong"),
    ]),
    Line::raw("Details: ..."),
];

Paragraph::new(text)
    .style(Style::default().fg(Color::White))
    .alignment(Alignment::Left)
    .wrap(Wrap { trim: true })
    .scroll((scroll_offset, 0))  // vertical scroll
```

#### List

Vertical list with scrollable selection:

```rust
use ratatui::widgets::{List, ListItem, ListState};

let items: Vec<ListItem> = items.iter()
    .map(|i| ListItem::new(Span::raw(i.as_str())))
    .collect();

let list = List::new(items)
    .block(Block::default().borders(Borders::ALL).title(" Items "))
    .highlight_style(Style::default().add_modifier(Modifier::REVERSED))
    .highlight_symbol(">> ");

let mut state = ListState::default();
state.select(Some(0));  // select first item

frame.render_stateful_widget(list, area, &mut state);
```

#### Table

```rust
use ratatui::widgets::{Table, Row, Cell};

let rows = vec![
    Row::new(vec![
        Cell::from("col1"),
        Cell::from("col2"),
    ]),
];

let widths = [Constraint::Percentage(50), Constraint::Percentage(50)];

let table = Table::new(rows, widths)
    .block(Block::default().borders(Borders::ALL).title(" Table "))
    .header(Row::new(vec!["H1", "H2"]).style(Style::default().fg(Color::Yellow)))
    .highlight_style(Style::default().add_modifier(Modifier::REVERSED));

frame.render_stateful_widget(table, area, &mut state);
```

#### Tabs

```rust
use ratatui::widgets::{Tabs, Borders};

let titles = ["Tab1", "Tab2", "Tab3"];
let tabs = Tabs::new(titles)
    .block(Block::default().title(" Tabs ").borders(Borders::ALL))
    .select(0)
    .style(Style::default().fg(Color::White))
    .highlight_style(Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD))
    .divider("|");

frame.render_widget(tabs, area);
```

#### Gauge

```rust
Gauge::default()
    .block(Block::default().title("Progress"))
    .gauge_style(Style::default().fg(Color::Cyan).bg(Color::Black))
    .ratio(0.65)  // or .percent(65)
    .label(Span::styled("65%", Style::default().fg(Color::White)))
```

---

## 4. Layout System

### Direction and Constraint

Layout splits a `Rect` into sub-rects using `Constraint`s along a `Direction`.

```rust
use ratatui::layout::{Constraint, Direction, Layout, Rect, Margin};
```

### `Layout`

Static layout builder:

```rust
let chunks = Layout::default()
    .direction(Direction::Vertical)
    .constraints([
        Constraint::Length(3),    // 3 rows (e.g., top status bar)
        Constraint::Min(10),     // at least 10 rows (main content)
        Constraint::Length(3),    // 3 rows (e.g., bottom status bar)
    ])
    .split(area);

// chunks[0] = status bar area
// chunks[1] = main area
// chunks[2] = bottom bar area
```

#### Constraint Variants

| Constraint | Behavior |
|-----------|----------|
| `Constraint::Length(n)` | Exactly n rows/columns |
| `Constraint::Min(n)` | At least n, grows to fill remaining |
| `Constraint::Max(n)` | At most n, shrinks if space is tight |
| `Constraint::Percentage(n)` | n% of available space |
| `Constraint::Ratio(num, den)` | num/den fraction of available space |
| `Constraint::Fill(n)` | Fill with minimum n, grows to fill |

#### Chained Layouts (Multi-Pane)

```rust
// Horizontal split for panes
let horizontal_chunks = Layout::default()
    .direction(Direction::Horizontal)
    .constraints([
        Constraint::Percentage(50),
        Constraint::Percentage(50),
    ])
    .split(chunks[1]);  // split the main area

// Left pane
let left_pane = Block::default()
    .title(" Left ")
    .borders(Borders::ALL);
frame.render_widget(left_pane, horizontal_chunks[0]);

// Right pane with vertical split
let right_chunks = Layout::default()
    .direction(Direction::Vertical)
    .constraints([
        Constraint::Percentage(60),
        Constraint::Percentage(40),
    ])
    .split(horizontal_chunks[1]);
```

#### `Layout::horizontal` / `Layout::vertical` (shorthand)

```rust
// Equivalent to direction(Direction::Horizontal)
let chunks = Layout::horizontal([
    Constraint::Min(20),
    Constraint::Fill(1),
]).split(area);
```

### Dynamic Sizing

`Fill` constraint is best for content that should expand to fill available space:

```rust
let chunks = Layout::vertical([
    Constraint::Length(3),   // fixed header
    Constraint::Fill(1),     // fills remaining space
    Constraint::Length(1),   // fixed footer
]).split(area);
```

---

## 5. Rendering Pipeline

### How It Works

```
App calls terminal.draw(|frame| { ... })
  │
  ├─ 1. Frame creates view of current buffer
  │
  ├─ 2. App renders widgets into frame (Buffer writes)
  │     └─ Widgets write cells: char, style, modifiers
  │
  ├─ 3. Buffer diffing
  │     └─ Compare current buffer vs previous buffer
  │     └─ Only cells that changed are marked dirty
  │
  └─ 4. Backend flush
        └─ Backend writes only dirty cells to terminal
        └─ Cursor repositioned only if needed
```

### Drawing a Frame

```rust
terminal.draw(|frame| {
    let area = frame.size();

    // Layout
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),
            Constraint::Min(0),
            Constraint::Length(1),
        ])
        .split(area);

    // Top bar
    let top_bar = Block::default()
        .title(" GN Harness ")
        .borders(Borders::BOTTOM)
        .style(Style::default().fg(Color::Cyan).bg(Color::Black));
    frame.render_widget(top_bar, chunks[0]);

    // Main content
    let main_block = Block::default()
        .borders(Borders::ALL)
        .title(" Terminal ");
    frame.render_widget(main_block, chunks[1]);

    // Status bar
    let status = Paragraph::new("Ready")
        .style(Style::default().fg(Color::Green));
    frame.render_widget(status, chunks[2]);
})?;
```

### Cell-Level Rendering

For terminal emulation panes, you write directly to the buffer:

```rust
terminal.draw(|frame| {
    let buf = frame.buffer_mut();
    let area = frame.size();

    // Write a cell directly
    let cell = &mut buf[(x, y)];
    cell.set_char('A');
    cell.set_fg(Color::Red);
    cell.set_bg(Color::Black);
    cell.set_style(Style::default().fg(Color::Red));
})?;
```

This is how libghostty would integrate — each terminal emulation frame writes cell data directly into ratatui's buffer at the pane's area.

---

## 6. Event Handling

### Crossterm Backend Events

Ratatui uses crossterm for terminal I/O. Events are polled or read via `crossterm::event`:

```rust
use crossterm::event::{self, Event, KeyCode, KeyEvent, KeyModifiers};

// Blocking poll
if event::poll(Duration::from_millis(100))? {
    if let Event::Key(key) = event::read()? {
        match key.code {
            KeyCode::Char('q') => return Ok(()),
            KeyCode::Char('j') => app.next(),
            KeyCode::Char('k') => app.prev(),
            _ => {}
        }
    }
}

// Non-blocking poll
let timeout = Duration::from_millis(50);
if event::poll(timeout)? {
    let event = event::read()?;
    // handle event
}
```

### Event Types

```rust
Event::Key(KeyEvent {
    code: KeyCode,
    modifiers: KeyModifiers,
})

Event::Mouse(MouseEvent {
    kind: MouseEventKind,  // Down, Up, Drag, Moved, ScrollDown, ScrollUp, ...
    column: u16,
    row: u16,
    modifiers: KeyModifiers,
})

Event::Resize(u16, u16)  // terminal resized
```

### KeyCode Variants

```rust
KeyCode::Char(char)
KeyCode::Enter
KeyCode::Esc
KeyCode::Tab
KeyCode::BackTab  // Shift+Tab
KeyCode::Backspace
KeyCode::Up | Down | Left | Right
KeyCode::Home | End
KeyCode::PageUp | PageDown
KeyCode::F(u8)  // function keys F1-F12
KeyCode::Delete
KeyCode::Insert
KeyCode::Null  // unknown/unrecognized key
```

### KeyModifiers

```rust
KeyModifiers::CONTROL  // Ctrl
KeyModifiers::SHIFT    // Shift
KeyModifiers::ALT      // Alt
```

---

## 7. Custom Widgets

### Implementing the Widget Trait

For the GN Harness, you'll need custom widgets for pane chrome, status bars, and tab bars.

```rust
use ratatui::buffer::Buffer;
use ratatui::layout::Rect;
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, Widget};

/// A custom status bar widget
pub struct StatusBar<'a> {
    items: Vec<(&'a str, &'a str)>,  // (label, value) pairs
    style: Style,
}

impl<'a> StatusBar<'a> {
    pub fn new(items: Vec<(&'a str, &'a str)>) -> Self {
        Self {
            items,
            style: Style::default().fg(Color::White).bg(Color::DarkGray),
        }
    }
}

impl Widget for StatusBar<'_> {
    fn render(self, area: Rect, buf: &mut Buffer) {
        // Draw background
        for x in area.left()..area.right() {
            buf[(x, area.y)]
                .set_bg(self.style.bg.unwrap_or(Color::Reset));
        }

        // Build the status line
        let mut spans = Vec::new();
        for (i, (label, value)) in self.items.iter().enumerate() {
            if i > 0 {
                spans.push(Span::raw(" │ "));
            }
            spans.push(Span::styled(
                format!("{}: ", label),
                Style::default().fg(Color::Gray),
            ));
            spans.push(Span::raw(value.to_string()));
        }

        let line = Line::from(spans);
        // Render into the buffer area
        for (i, span) in line.iter().enumerate() {
            let x = area.x + i as u16;
            if x < area.right() {
                let cell = &mut buf[(x, area.y)];
                cell.set_str(span.content);
                cell.set_style(span.style);
            }
        }
    }
}
```

### Implementing StatefulWidget

For widgets with internal state (scrolling, selection):

```rust
use ratatui::widgets::StatefulWidget;

pub struct PaneState {
    pub scroll_offset: u16,
    pub cursor_visible: bool,
}

pub struct PaneWidget<'a> {
    pub title: &'a str,
    pub content: Vec<Line<'a>>,
}

impl StatefulWidget for PaneWidget<'_> {
    type State = PaneState;

    fn render(self, area: Rect, buf: &mut Buffer, state: &mut PaneState) {
        // Use state.scroll_offset to determine which lines to show
        // Render content into the buffer
        for (i, line) in self.content
            .iter()
            .skip(state.scroll_offset as usize)
            .enumerate()
        {
            let y = area.y + i as u16;
            if y >= area.bottom() {
                break;
            }
            // render line into buffer at y
        }
    }
}
```

### Custom Block with Title and Keybinds

```rust
/// A pane block that shows a title and optional keybind hint
pub struct PaneBlock<'a> {
    title: &'a str,
    keybind_hint: Option<&'a str>,
    is_focused: bool,
}

impl<'a> PaneBlock<'a> {
    pub fn new(title: &'a str) -> Self {
        Self {
            title,
            keybind_hint: None,
            is_focused: false,
        }
    }

    pub fn focused(mut self, focused: bool) -> Self {
        self.is_focused = focused;
        self
    }

    pub fn keybind_hint(mut self, hint: &'a str) -> Self {
        self.keybind_hint = Some(hint);
        self
    }
}

impl Widget for PaneBlock<'_> {
    fn render(self, area: Rect, buf: &mut Buffer) {
        let border_color = if self.is_focused {
            Color::Cyan
        } else {
            Color::DarkGray
        };

        let title = match self.keybind_hint {
            Some(hint) => format!(" {} [{hint}] ", self.title),
            None => format!(" {} ", self.title),
        };

        let block = Block::default()
            .title(title)
            .title_alignment(Alignment::Left)
            .borders(Borders::ALL)
            .border_type(if self.is_focused {
                BorderType::Thick
            } else {
                BorderType::Plain
            })
            .border_style(Style::default().fg(border_color));

        block.render(area, buf);
    }
}
```

---

## 8. Application Patterns

### Elm Architecture (TEA)

Ratatui recommends the Elm Architecture for structured apps:

```
┌─────────┐    Event    ┌─────────┐
│         │ ──────────→ │         │
│  Model  │             │ update  │
│         │ ←────────── │         │
└─────────┘             └─────────┘
     │
     │ view
     ▼
┌─────────┐
│ render  │
│(frame)  │
└─────────┘
```

```rust
// Model
struct App {
    // State
    focused_pane: usize,
    panes: Vec<Pane>,
    should_quit: bool,
}

// Init
impl App {
    fn new() -> Self {
        Self {
            focused_pane: 0,
            panes: vec![Pane::new("Shell"), Pane::new("Output")],
            should_quit: false,
        }
    }
}

// Update (handle event)
impl App {
    fn handle_key(&mut self, key: KeyEvent) {
        match key.code {
            KeyCode::Char('q') => self.should_quit = true,
            KeyCode::Tab => self.focused_pane = (self.focused_pane + 1) % self.panes.len(),
            KeyCode::Char('j') if key.modifiers.contains(KeyModifiers::CONTROL) => {
                self.focused_pane = (self.focused_pane + 1) % self.panes.len();
            }
            _ => {
                // Forward event to focused pane
                self.panes[self.focused_pane].handle_key(key);
            }
        }
    }
}

// View (render)
impl App {
    fn render(&self, frame: &mut Frame) {
        // Build layout and render widgets
    }
}
```

### Component Architecture (trait-based)

More modular than TEA — each pane is a self-contained component:

```rust
pub trait Component {
    fn init(&mut self) {}
    fn handle_event(&mut self, event: Event) -> Option<Action>;
    fn update(&mut self, action: Action) -> Option<Action>;
    fn render(&self, frame: &mut Frame, area: Rect);
}
```

```rust
// A component can return an Action to communicate with the app shell
pub enum Action {
    SwitchFocus(usize),
    KeybindingHint(String),
    Quit,
    // ...
}

// App shell orchestrates components
struct Harness {
    components: Vec<Box<dyn Component>>,
    focused: usize,
}

impl Harness {
    fn handle_event(&mut self, event: Event) {
        let action = self.components[self.focused].handle_event(event);
        if let Some(action) = action {
            self.process_action(action);
        }
    }

    fn process_action(&mut self, action: Action) {
        match action {
            Action::SwitchFocus(i) => self.focused = i,
            Action::Quit => self.should_quit = true,
            _ => {}
        }
    }
}
```

### Flux Architecture

Similar to React/Redux — unidirectional data flow with actions dispatched through a store:

```rust
pub trait Component {
    fn init(&mut self) -> Option<Action>;
    fn handle_event(&mut self, event: Event) -> Option<Action>;
    fn update(&mut self, action: Action) -> Option<Action>;
    fn render(&self, frame: &mut Frame, area: Rect);
}
```

---

## 9. Multi-Pane TUI Design

### Architecture for GN Harness

The GN Harness uses ratatui for chrome (borders, status bar, keybind hints, tab bar) and libghostty for terminal emulation per pane.

```
┌─────────────────────────────────────────────────────┐
│ GN Harness                                    [1/3] │  ← Top bar (ratatui)
├────────────────────────┬────────────────────────────┤
│                        │                            │
│   Pane 1 (Shell)       │   Pane 2 (Build)           │  ← Terminal panes
│                        │                            │     (libghostty → Buffer)
│   libghostty renders   │   libghostty renders       │
│   to ratatui Buffer    │   to ratatui Buffer        │
│                        │                            │
│                        ├────────────────────────────┤
│                        │                            │
│                        │   Pane 3 (Log)             │
│                        │                            │
│                        │                            │
├────────────────────────┴────────────────────────────┤
│ [Tab1] [Tab2] [Tab3]  │  Ctrl+Q Quit │ Ready     │  ← Status bar
└─────────────────────────────────────────────────────┘
```

### Key Design Decisions

1. **ratatui owns the full terminal buffer** — libghostty panes write into sub-areas of ratatui's buffer, not directly to the terminal.
2. **ratatui handles borders and chrome** — `Block` widgets draw pane borders, titles, and keybind hints.
3. **Focus tracking** — one pane is focused; focused pane gets keyboard input.
4. **Event routing** — key events go to the focused pane's handler; global keybinds (Ctrl+Q, Ctrl+N, Tab) intercepted at app level.

### Pane Management

```rust
pub struct Pane {
    pub title: String,
    pub is_focused: bool,
    pub ghostty_surface: Option<GhosttySurface>,  // libghostty handle
}

pub struct App {
    pub panes: Vec<Pane>,
    pub layout_mode: LayoutMode,
    pub focused_pane: usize,
}

pub enum LayoutMode {
    Single,
    HorizontalSplit,  // two panes side by side
    VerticalSplit,    // two panes stacked
    Grid,             // 2x2 grid
    Custom(Vec<Constraint>),
}
```

### Layout Computation

```rust
fn compute_layout(area: Rect, panes: &[Pane], mode: &LayoutMode) -> Vec<Rect> {
    match mode {
        LayoutMode::Single => vec![area],
        LayoutMode::HorizontalSplit => {
            Layout::horizontal([Constraint::Percentage(50), Constraint::Percentage(50)])
                .split(area)
                .to_vec()
        }
        LayoutMode::VerticalSplit => {
            Layout::vertical([Constraint::Percentage(50), Constraint::Percentage(50)])
                .split(area)
                .to_vec()
        }
        LayoutMode::Grid => {
            let rows = Layout::vertical([Constraint::Percentage(50), Constraint::Percentage(50)])
                .split(area);
            let top = Layout::horizontal([Constraint::Percentage(50), Constraint::Percentage(50)])
                .split(rows[0]);
            let bottom = Layout::horizontal([Constraint::Percentage(50), Constraint::Percentage(50)])
                .split(rows[1]);
            vec![top[0], top[1], bottom[0], bottom[1]]
        }
        LayoutMode::Custom(constraints) => {
            Layout::default()
                .constraints(constraints.as_slice())
                .split(area)
                .to_vec()
        }
    }
}
```

### Rendering Multi-Pane Layout

```rust
impl App {
    fn render(&self, frame: &mut Frame) {
        let area = frame.size();

        // Top bar + status bar
        let main_chunks = Layout::vertical([
            Constraint::Length(1),  // top bar
            Constraint::Min(0),    // main pane area
            Constraint::Length(1),  // status bar
        ]).split(area);

        // Top bar
        let top_bar = Paragraph::new(format!(
            " GN Harness  |  {} panes  |  {} mode ",
            self.panes.len(),
            match self.layout_mode {
                LayoutMode::Single => "single",
                LayoutMode::HorizontalSplit => "split-h",
                LayoutMode::VerticalSplit => "split-v",
                LayoutMode::Grid => "grid",
                LayoutMode::Custom(_) => "custom",
            }
        ))
        .style(Style::default().fg(Color::White).bg(Color::DarkGray));
        frame.render_widget(top_bar, main_chunks[0]);

        // Compute pane layout
        let pane_rects = compute_layout(main_chunks[1], &self.panes, &self.layout_mode);

        // Render each pane
        for (i, pane) in self.panes.iter().enumerate() {
            if let Some(rect) = pane_rects.get(i) {
                // Border/chrome via ratatui
                let block = PaneBlock::new(&pane.title)
                    .focused(i == self.focused_pane)
                    .keybind_hint(match i {
                        0 => Some("Ctrl+1"),
                        1 => Some("Ctrl+2"),
                        _ => None,
                    });
                frame.render_widget(block, *rect);

                // Terminal content via libghostty (inner area, inside borders)
                let inner = rect.inner(Margin::new(1, 1));
                if let Some(surface) = &pane.ghostty_surface {
                    // libghostty writes cells into ratatui buffer at `inner`
                    render_ghostty_to_frame(frame, surface, inner);
                }
            }
        }

        // Status bar
        let status_items = vec![
            ("Mode", match self.layout_mode {
                LayoutMode::Single => "single",
                LayoutMode::HorizontalSplit => "split-h",
                LayoutMode::VerticalSplit => "split-v",
                LayoutMode::Grid => "grid",
                LayoutMode::Custom(_) => "custom",
            }),
            ("Panes", &self.panes.len().to_string()),
            ("Focus", &self.focused_pane.to_string()),
        ];
        let status_bar = StatusBar::new(status_items);
        frame.render_widget(status_bar, main_chunks[2]);
    }
}
```

---

## 10. Keybinding Dispatch

### Pattern 1: Centralized Match

```rust
fn handle_key(&mut self, key: KeyEvent) -> bool {
    // Global keybinds first
    match (key.modifiers, key.code) {
        (KeyModifiers::CONTROL, KeyCode::Char('q')) => {
            self.should_quit = true;
            return true;
        }
        (KeyModifiers::CONTROL, KeyCode::Char('n')) => {
            self.add_pane();
            return true;
        }
        (KeyModifiers::CONTROL, KeyCode::Char('1')) => {
            self.focused_pane = 0;
            return true;
        }
        (KeyModifiers::CONTROL, KeyCode::Char('2')) => {
            self.focused_pane = 1;
            return true;
        }
        (KeyModifiers::NONE, KeyCode::Tab) => {
            self.focused_pane = (self.focused_pane + 1) % self.panes.len();
            return true;
        }
        _ => {}
    }

    // Forward to focused pane
    self.panes[self.focused_pane].handle_key(key);
    true
}
```

### Pattern 2: Keybinding Map (configurable)

```rust
use std::collections::HashMap;

pub struct Keybinding {
    pub key: KeyCode,
    pub modifiers: KeyModifiers,
    pub action: String,  // action name, looked up in handler
}

pub struct Keymap {
    bindings: Vec<Keybinding>,
}

impl Keymap {
    pub fn resolve(&self, key: KeyEvent) -> Option<&str> {
        self.bindings.iter()
            .find(|b| b.key == key.code && b.modifiers == key.modifiers)
            .map(|b| b.action.as_str())
    }
}

// In app:
fn handle_key(&mut self, key: KeyEvent) {
    if let Some(action) = self.keymap.resolve(key) {
        match action {
            "quit" => self.should_quit = true,
            "next_pane" => self.focused_pane = (self.focused_pane + 1) % self.panes.len(),
            "prev_pane" => { /* ... */ }
            _ => {}
        }
    } else {
        // Forward to focused pane
        self.panes[self.focused_pane].handle_key(key);
    }
}
```

### Pattern 3: Component-based Keybinding

Each component defines its own keybindings; the app shell dispatches to the focused component:

```rust
impl Component for TerminalPane {
    fn handle_event(&mut self, event: Event) -> Option<Action> {
        match event {
            Event::Key(key) => {
                // This pane handles all keys when focused
                // Forward to libghostty terminal emulator
                self.ghostty_surface.handle_key(key);
                None
            }
            _ => None,
        }
    }
}
```

---

## 11. Terminal Backend Integration

### Crossterm Backend

Ratatui ships with a crossterm backend. This is the recommended backend for cross-platform support.

```rust
use crossterm::{
    event::{self, Event, KeyCode},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::backend::CrosstermBackend;
use ratatui::Terminal;
use std::io;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Setup
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    // App loop
    let mut app = App::new();
    loop {
        terminal.draw(|frame| app.render(frame))?;

        if event::poll(std::time::Duration::from_millis(100))? {
            if let Event::Key(key) = event::read()? {
                app.handle_key(key);
                if app.should_quit {
                    break;
                }
            }
        }
    }

    // Cleanup
    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;
    Ok(())
}
```

### Alternate Screen

For apps that should restore the terminal on exit:

```rust
use crossterm::terminal::{EnterAlternateScreen, LeaveAlternateScreen};

// Enter alternate screen at start
execute!(stdout, EnterAlternateScreen)?;

// Leave alternate screen at end (restores original)
execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
```

### Integrating libghostty with ratatui

The key insight: libghostty renders terminal emulation into a buffer. You can map that buffer onto ratatui's `Buffer` sub-region:

```rust
/// Write libghostty cells into ratatui's buffer for a given area
fn render_ghostty_to_frame(
    frame: &mut Frame,
    ghostty_surface: &GhosttySurface,
    area: Rect,
) {
    let buf = frame.buffer_mut();

    for row in 0..ghostty_surface.height() {
        for col in 0..ghostty_surface.width() {
            let cell = ghostty_surface.cell_at(row, col);
            let x = area.x + col as u16;
            let y = area.y + row as u16;

            if x < area.right() && y < area.bottom() {
                let target = &mut buf[(x, y)];
                target.set_char(cell.character());
                target.set_fg(cell.fg_color());
                target.set_bg(cell.bg_color());
                // Handle modifiers (bold, italic, etc.)
            }
        }
    }
}
```

---

## 12. Code Examples for GN Harness

### Minimal Working App Skeleton

```rust
use crossterm::event::{self, Event, KeyCode, KeyModifiers};
use crossterm::terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen};
use crossterm::execute;
use ratatui::backend::CrosstermBackend;
use ratatui::layout::{Constraint, Layout, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, BorderType, Paragraph};
use ratatui::Terminal;
use std::io;

struct App {
    should_quit: bool,
    focused_pane: usize,
    pane_count: usize,
    layout: LayoutMode,
}

#[derive(Clone)]
enum LayoutMode {
    Single,
    Horizontal,
    Vertical,
    Grid,
}

impl App {
    fn new() -> Self {
        Self {
            should_quit: false,
            focused_pane: 0,
            pane_count: 2,
            layout: LayoutMode::Horizontal,
        }
    }

    fn handle_key(&mut self, key: KeyEvent) {
        match (key.modifiers, key.code) {
            (KeyModifiers::CONTROL, KeyCode::Char('q')) => self.should_quit = true,
            (KeyModifiers::CONTROL, KeyCode::Char('n')) => {
                self.pane_count = (self.pane_count + 1).min(4);
            }
            (KeyModifiers::CONTROL, KeyCode::Char('h')) => self.layout = LayoutMode::Horizontal,
            (KeyModifiers::CONTROL, KeyCode::Char('v')) => self.layout = LayoutMode::Vertical,
            (KeyModifiers::CONTROL, KeyCode::Char('g')) => self.layout = LayoutMode::Grid,
            (KeyModifiers::CONTROL, KeyCode::Char('1')) => self.focused_pane = 0,
            (KeyModifiers::CONTROL, KeyCode::Char('2')) => self.focused_pane = 1,
            (KeyModifiers::CONTROL, KeyCode::Char('3')) => self.focused_pane = 2,
            (KeyModifiers::CONTROL, KeyCode::Char('4')) => self.focused_pane = 3,
            (KeyModifiers::NONE, KeyCode::Tab) => {
                self.focused_pane = (self.focused_pane + 1) % self.pane_count;
            }
            _ => {}
        }
    }

    fn render(&self, frame: &mut Frame) {
        let area = frame.size();

        // Vertical split: top bar, main area, status bar
        let main = Layout::vertical([
            Constraint::Length(1),
            Constraint::Min(0),
            Constraint::Length(1),
        ]).split(area);

        // Top bar
        let top = Paragraph::new(format!(
            " GN Harness  |  {} panes  |  Ctrl+Q quit",
            self.pane_count
        ))
        .style(Style::default().fg(Color::White).bg(Color::DarkGray));
        frame.render_widget(top, main[0]);

        // Compute pane areas
        let pane_areas = self.compute_pane_layout(main[1]);

        // Render panes
        for i in 0..self.pane_count {
            if let Some(rect) = pane_areas.get(i) {
                let focused = i == self.focused_pane;
                let border_color = if focused { Color::Cyan } else { Color::DarkGray };
                let border_type = if focused { BorderType::Thick } else { BorderType::Plain };

                let block = Block::default()
                    .title(format!(" Pane {} [Ctrl+{}] ", i + 1, i + 1))
                    .borders(Borders::ALL)
                    .border_type(border_type)
                    .border_style(Style::default().fg(border_color));
                frame.render_widget(block, *rect);

                // Inner content area (inside borders)
                let inner = Rect {
                    x: rect.x + 1,
                    y: rect.y + 1,
                    width: rect.width.saturating_sub(2),
                    height: rect.height.saturating_sub(2),
                };

                let content = Paragraph::new(vec![
                    Line::from(Span::styled(
                        format!("Terminal emulation placeholder for pane {}", i + 1),
                        Style::default().fg(Color::Gray),
                    )),
                    Line::raw(""),
                    Line::from(Span::styled(
                        "libghostty would render here",
                        Style::default().fg(Color::DarkGray),
                    )),
                ]);
                frame.render_widget(content, inner);
            }
        }

        // Status bar
        let status_style = Style::default().fg(Color::White).bg(Color::DarkGray);
        let status_text = format!(
            " Pane {}/{}  |  Layout: {}  |  Tab: switch focus",
            self.focused_pane + 1,
            self.pane_count,
            match &self.layout {
                LayoutMode::Single => "single",
                LayoutMode::Horizontal => "split-h",
                LayoutMode::Vertical => "split-v",
                LayoutMode::Grid => "grid",
            }
        );
        let status = Paragraph::new(status_text).style(status_style);
        frame.render_widget(status, main[2]);
    }

    fn compute_pane_layout(&self, area: Rect) -> Vec<Rect> {
        match (&self.layout, self.pane_count) {
            (_, 1) | (LayoutMode::Single, _) => vec![area],
            (LayoutMode::Horizontal, n) => {
                let constraints: Vec<Constraint> = (0..n)
                    .map(|_| Constraint::Percentage(100 / n as u16))
                    .collect();
                Layout::horizontal(constraints).split(area).to_vec()
            }
            (LayoutMode::Vertical, n) => {
                let constraints: Vec<Constraint> = (0..n)
                    .map(|_| Constraint::Percentage(100 / n as u16))
                    .collect();
                Layout::vertical(constraints).split(area).to_vec()
            }
            (LayoutMode::Grid, n) => {
                let rows = (n as f64).sqrt().ceil() as usize;
                let cols = (n as f64 / rows as f64).ceil() as usize;
                let row_constraints: Vec<Constraint> = (0..rows)
                    .map(|_| Constraint::Percentage(100 / rows as u16))
                    .collect();
                let col_constraints: Vec<Constraint> = (0..cols)
                    .map(|_| Constraint::Percentage(100 / cols as u16))
                    .collect();

                let row_rects = Layout::vertical(row_constraints).split(area);
                let mut result = Vec::new();
                let mut count = 0;
                for row_rect in &row_rects {
                    let col_rects = Layout::horizontal(col_constraints.clone()).split(*row_rect);
                    for col_rect in &col_rects {
                        if count < n {
                            result.push(*col_rect);
                            count += 1;
                        }
                    }
                }
                result
            }
        }
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let mut app = App::new();

    loop {
        terminal.draw(|frame| app.render(frame))?;

        if event::poll(std::time::Duration::from_millis(100))? {
            if let Event::Key(key) = event::read()? {
                app.handle_key(key);
                if app.should_quit {
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
```

---

## 13. Key Takeaways

### Architecture

1. **ratatui is immediate mode** — rebuild UI description every frame, diff at cell level. No retained widget tree.
2. **Double buffering is automatic** — ratatui diffs current vs previous buffer and only flushes changed cells.
3. **Widgets are consumed on render** — `Widget::render(self, ...)` takes self by value. Clone or recreate for repeated use.

### Layout

4. **`Layout::horizontal()` / `Layout::vertical()`** are the primary layout primitives. Chain them for complex multi-pane layouts.
5. **`Constraint::Fill(1)`** is ideal for the pane that should grow to fill remaining space.
6. **Nested layouts** — split areas recursively. No flat layout API; composition via nested `Layout::split()`.

### Widgets

7. **`Block` is the pane container** — use it for borders, titles, and style. Every pane should be a `Block`.
8. **`Paragraph`** for text content. `List` and `Table` for structured data with selection.
9. **`StatefulWidget`** for any widget that tracks internal state (scroll, selection, cursor).

### Rendering

10. **`terminal.draw(|frame| { ... })`** is the single entry point for rendering. One call per frame.
11. **Direct buffer access** via `frame.buffer_mut()` for libghostty integration — write cells directly.
12. **Layout areas are `Rect`** — compute them once, render into them.

### Events

13. **crossterm events** via `event::poll()` + `event::read()`. Blocking with timeout is the standard pattern.
14. **Event routing**: global keybinds intercepted first, then forward to focused component.
15. **KeyModifiers** for Ctrl/Shift/Alt detection.

### Multi-Pane Design

16. **Focus model**: one pane focused at a time; keyboard input goes to focused pane.
17. **Pane state** tracked in app model; each pane has its own state (libghostty surface, scroll offset, etc.).
18. **Border chrome via ratatui, terminal content via libghostty** — clean separation of concerns.
19. **Layout modes** — single, horizontal split, vertical split, grid. Switch dynamically.

### For GN Harness Specifically

20. **ratatui owns the full terminal** — libghostty writes into ratatui's buffer, not directly to stdout.
21. **Component trait pattern** (init/handle_event/update/render) maps cleanly to pane lifecycle.
22. **Keybinding dispatch**: global app-level binds (Ctrl+Q, Ctrl+N, Tab) + per-pane binds (forwarded to libghostty).
23. **Status bar**: ratatui `Paragraph` or custom widget at bottom of frame.
24. **Tab bar**: ratatui `Tabs` widget at top of frame.
25. **Focusing**: highlighted border (Color::Cyan + BorderType::Thick) on focused pane; dim border on unfocused.

---

*Research compiled from ratatui.rs, docs.rs/ratatui, and ratatui GitHub documentation.*
*Last updated: 2026-07-22*
