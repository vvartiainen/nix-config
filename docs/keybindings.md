# Desktop, browser and terminal keybindings

In Kitty and Rex, **Alt means Right Option**; Left Option keeps keyboard-layout
characters. Agent prompt controls are in [agent CLI keybindings](agent-keybindings.md).

## Global shortcuts

| Key | Action |
| --- | --- |
| Left Cmd+Option+Space | Open Spotlight |
| Ctrl+Cmd+Z / K / C / O / M / E | Open or focus Zen / Kitty / Calendar / Obsidian / Mail / Finder |
| Ctrl+Space | Toggle the quick-access terminal; Vicinae currently shares this binding (see [launcher setup](setup.md#vicinae-launcher-trial)) |
| Ctrl+Cmd+U | Toggle CodexBar's usage menu |
| Ctrl+Cmd+Shift+U | Toggle the quota dashboard |
| Ctrl+1–9 / Left / Right | Select Space / previous / next Space |
| Ctrl+Alt+H/J/K/L | Focus window left/down/up/right |
| Ctrl+Alt+P/N | Previous / next window, including stacks |
| Cmd+Tab | Cycle yabai windows |
| Cmd+Left Option+H/J/K/L | Resize the focused window |
| Cmd+Q twice within 500 ms | Quit Zen or Kitty; other apps keep single-press quit |
| Ctrl+N/P in Slack | Down / up in menus, search and message editing |
| Ctrl+Shift+J/K in Slack | Next / previous channel or DM |

Ctrl+Space takes precedence over app actions such as completion; the macOS
input-source shortcut is disabled to reserve it. Left Cmd+Option+Space keeps
Spotlight. CodexBar must be running for its menu shortcut.

## Window and resize modes

Press **Right Cmd+Right Option+W** (also Ctrl+Alt+W) for window mode.
Release the modifiers, then use:

| Key in window mode | Action |
| --- | --- |
| H / J / K / L | Focus left / down / up / right |
| Shift+H/J/K/L | Move the window beside its neighbour |
| Cmd+H/J/K/L | Resize by 100 pixels; add Shift for 25 pixels |
| B / Shift+B / S | Balance / BSP layout / stack layout |
| F | Zoom within the current Space |
| 1–6 | Move window to that Space and follow it |
| R | Switch to resize mode |

**Right Cmd+Right Option+R** (also Ctrl+Alt+R) enters resize mode; plain
H/J/K/L resizes and W returns to window mode. These modes stay active for
repeated actions. **Escape, Return, or the window-mode chord exits either**;
the resize chord also exits resize mode. SketchyBar shows the active mode and
key hints. Right-side Cmd+Option+W reserves the native close-all-windows chord;
the left-side combination retains its normal behavior.

Direct Ctrl+Alt+Cmd window/Space controls remain available; see
[the bindings](../dotfiles/skhd/yabai) for the full list.

## App navigation modes

With **Zen, Kitty or Rex** focused, press **Right Cmd+Right Option+Space**, then
release the modifiers. In Kitty, a Herdr window enters Herdr mode. SketchyBar
shows the app's mode and hints; keep it running for automatic exit on app switch.

**Escape, Return, or the entry chord exits**. Right Cmd+Right Option+W/R
switches to window/resize mode. Navigation, creation and layout actions generally
stay in mode; pickers and typing actions exit so they can receive text. Release
capture before answering a confirmation or clicking into a text field.

### Zen

| Key in Zen mode | Action |
|---|---|
| H / L | Previous / next horizontal workspace |
| J / K | Next / previous vertical tab |
| N | Exit mode and open a new tab |
| O | Exit mode and focus the address bar |
| F | Exit mode and find in the page |
| Cmd+T / Cmd+L / Cmd+K / Cmd+F | Exit mode and perform the native action |
| Escape / Return / Right Cmd+Right Option+Space | Exit mode |
| Right Cmd+Right Option+W / R | Switch to window / resize mode |

N/O/F and the listed native Cmd shortcuts release capture before opening a text
field. Clicking a field alone does not exit mode. Tab movement follows sequential
order; H/L changes workspaces.

### Kitty

| Key in Kitty mode | Action |
|---|---|
| H / L | Previous / next tab |
| J / K | Next / previous window in the tab |
| Shift+H / L | Move tab backward / forward |
| Shift+J / K | Move window forward / backward |
| Ctrl+H / J / K / L | Swap window with its neighbour in that direction |
| Cmd+H / J / K / L | Make window narrower / shorter / taller / wider; stay in mode |
| B | Reset window sizes in the tab |
| 1–9 | Jump to tab |
| O | Next layout |
| Z | Toggle stack layout |
| N / T | New window / tab in the current directory |
| Ctrl+N / Ctrl+T | Close window / tab; Kitty may ask to confirm closing a tab with running programs |
| F | Exit mode and open the fuzzy tab switcher |
| Escape / Return / Right Cmd+Right Option+Space | Exit mode |
| Right Cmd+Right Option+W / R | Switch to window / resize mode |

Resize behavior depends on the layout; stack has no visible split to resize.
Outside mode, Ctrl+Shift is Kitty's main modifier and **F7 → key** opens sessions
and tools. Font controls:

| Key | Action |
|---|---|
| Cmd+Plus / Cmd+Equal | Increase font size in the current OS window by 2 points |
| Cmd+Minus | Decrease font size in the current OS window by 2 points |
| Cmd+0 | Reset font size in the current OS window |
| Cmd+Shift+Plus / Cmd+Shift+Equal | Increase font size in all OS windows by 2 points |
| Cmd+Shift+Minus | Decrease font size in all OS windows by 2 points |
| Cmd+Shift+0 | Reset font size in all OS windows |

Cmd+Shift+/ also increases all-window font size for keyboard layouts where
Shift+Plus is intercepted. Restart Kitty after changing macOS menu shortcuts.

Kitty 0.50+ restores all running instances after logout or a computer restart,
including window geometry and scrollback, with fresh shells. Start Kitty normally
to restore; an explicit `--session` bypasses logout restore.

Press **F7 → R** and confirm to save, quit and automatically reopen the current
Kitty process with all its OS windows, tabs, layouts, working directories and
window geometry. Other Kitty processes remain running. Apply the configuration
manually once to link the restart helpers, then reload with **Ctrl+Shift+F5**.

This restart omits scrollback and live process state. Programs started inside
shells need to be resumed manually; commands launched directly by a session
can run again. Window placement remains subject to yabai. A failed save leaves
Kitty running. If reopening fails, inspect `~/.local/state/kitty/restart.log`;
the recovery snapshot is `~/.local/state/kitty/restart-<old-pid>.kitty-session`.
Reopen it from another terminal with `kitty --detach --session <snapshot>`.
**F7 → S** still saves a reviewed session file, including foreground commands.

### Rex

| Key in Rex mode | Action |
|---|---|
| K / J | Previous / next tab |
| H / L | Previous / next pane |
| Ctrl+H / J / K / L | Focus pane left / down / up / right |
| Cmd+H / J / K / L | Resize pane left / down / up / right by 5%; stay in mode |
| 1–9 | Jump to tab |
| T | New tab |
| N or V / Shift+V | Split right / down |
| Cmd+Enter / Cmd+Shift+Enter | Split right / down; stay in mode |
| Z / B | Zoom pane / balance splits |
| Ctrl+N or Ctrl+V / Ctrl+T | Close pane / tab; stay in mode for repeated closes |
| G or F / S | Exit mode and open command palette / session picker |
| Escape / Return / Right Cmd+Right Option+Space | Exit mode |
| Right Cmd+Right Option+W / R | Switch to window / resize mode |

Outside navigation mode:

| Key | Action |
|---|---|
| Ctrl+Shift+K / J | Previous / next tab |
| Ctrl+Shift+H / L | Previous / next pane |
| Ctrl+Shift+1–9 | Jump to tab |
| Cmd+1–9 | Jump to pane, counted in layout order (left/top first) |
| Ctrl+Shift+Z | Toggle pane zoom |
| Cmd+T | New tab |
| Cmd+Enter / Cmd+Shift+Enter | Split right / down, also in navigation mode |

Tab/pane closes retain capture; release it with Escape or Return before answering
Rex's confirmation. Remote hosts need the same Lua bindings. After configuration
changes, run `rex config reload`; GUI preference changes need an app restart.

### Herdr

| Key in Herdr mode | Action |
|---|---|
| H / L | Previous / next Herdr tab |
| J / K | Next / previous agent |
| Shift+J / K | Next / previous Herdr workspace |
| Ctrl+H / J / K / L | Swap pane with its neighbour in that direction |
| 1–9 | Jump to agent |
| Shift+1–9 | Jump to Herdr tab |
| T / W | Create a Herdr tab / workspace |
| V / Shift+V | Split the pane side by side / stacked |
| Ctrl+V / Ctrl+T | Close pane / tab, without confirmation |
| Ctrl+W | Exit mode and close the workspace after Herdr's confirmation |
| G | Exit mode and open searchable Go To picker |
| S | Exit mode and open workspace picker |
| Escape / Return / Right Cmd+Right Option+Space | Exit mode |
| Right Cmd+Right Option+W / R | Switch to window / resize mode |

These act on Herdr tabs and agents. Numbered agents follow the visible panel
order. Direct controls remain available outside mode:

| Action | Binding |
|---|---|
| Previous / next agent | Alt+K / Alt+J |
| Jump to agent 1–9 | Alt+1–9 |
| Go To picker | Alt+G |
| Workspace picker | Alt+W |
| Previous / next workspace | Alt+Shift+K / Alt+Shift+J |
| Jump to workspace 1–9 | Ctrl+B → Shift+1–9 |
| Previous / next tab | Alt+H / Alt+L; also Ctrl+B → P / Ctrl+B → N |
| New tab | Alt+N |
| New workspace | Alt+Shift+N |
| Clear pane / new conversation | Alt+C |
| Jump to tab 1–9 | Alt+Shift+1–9; also Ctrl+B → 1–9 |
| Focus pane | Ctrl+B → H/J/K/L |
| Swap pane | Ctrl+Alt+Shift+H/J/K/L; also Ctrl+B → Shift+H/J/K/L |
| Split side by side / stacked | Ctrl+Alt+V / Ctrl+Alt+Shift+V; also Ctrl+B → V / Ctrl+B → - |
| Close pane / tab | Ctrl+Alt+X / Ctrl+Alt+Shift+X; also Ctrl+B → X for panes |
| Close workspace | F16, with confirmation |
| Show active shortcuts | Ctrl+B → ? |

Alt+C requires an empty agent prompt and does nothing during a running turn.
It clears the shell, runs `/clear` in Claude, or `/new` in other agents.
In the Go To picker, `/` searches; b/w/i/d filters blocked/working/idle/done,
and a shows all terminals. Reload changes with `herdr server reload-config`.

For reloads, quotas and agent status indicators, see [maintenance](maintenance.md).
Implementation rationale and integration checks: Backlog **doc-5 — Desktop and
terminal integration details**.
