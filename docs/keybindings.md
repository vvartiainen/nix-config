# Desktop, browser and terminal keybindings

In Kitty and Rex, **Alt means Right Option**; Left Option keeps keyboard-layout
characters. Agent prompt controls are in [agent CLI keybindings](agents/keybindings.md).

**Cmd+´** (the Finnish **´** key without Shift) toggles Zen's sidebar and
Kitty's tab bar, also in navigation mode; **Cmd+S** still works.

## Global shortcuts

| Key | Action |
| --- | --- |
| Left Cmd+Option+Space | Open Spotlight |
| Ctrl+Cmd+Z / K / C / O / M / E | Open or focus Zen / Kitty / Calendar / Obsidian / Mail / Finder |
| Ctrl+Shift+Space | Toggle the quick-access terminal |
| Cmd+Space | Toggle Vicinae (see [Vicinae](programs/desktop.md#vicinae)) |
| Ctrl+Cmd+U | Toggle CodexBar's usage menu |
| Ctrl+Cmd+Shift+U | Toggle the quota dashboard |
| Ctrl+Cmd+Shift+M | Toggle microphone input volume between zero and its previous level (requires SketchyBar) |
| Ctrl+1–9 / Left / Right | Select Space / previous / next Space |
| Ctrl+Alt+H/J/K/L | Focus window left/down/up/right |
| Ctrl+Alt+P/N | Previous / next window, including stacks |
| Cmd+Tab | Cycle yabai windows |
| Cmd+Left Option+H/J/K/L | Resize the focused window |
| Cmd+Q twice within 500 ms | Quit Zen or Kitty; other apps keep single-press quit |
| Ctrl+N/P in Vicinae | Next / previous result |
| Ctrl+N/P in Slack | Down / up in menus, search and message editing |
| Ctrl+Shift+J/K in Slack | Next / previous channel or DM |
| Right Option+1–9 in Kitty (including the quick-access window) or Rex | Jump to tab; other apps and Left Option keep typing characters |

Global shortcuts override app shortcuts, so Ctrl+Shift+Space blocks
JetBrains smart completion. Ctrl+Space reaches apps; macOS input-source
shortcuts are disabled.

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

**Right Cmd+Right Option+R** (also Ctrl+Alt+R) enters resize mode: H/J/K/L
resizes and W returns to window mode. Modes stay active until **Escape,
Return or the entry chord**. SketchyBar shows the mode and key hints. Direct
Ctrl+Alt+Cmd controls are in [the bindings](../dotfiles/skhd/yabai).

## App navigation modes

With **Zen, Kitty or Rex** focused (including the Kitty quick-access window),
press **Right Cmd+Right Option+Space**, then release the modifiers. A Herdr
window in Kitty enters Herdr mode. **Escape, Return or the entry chord**
exits; Right Cmd+Right Option+W/R switches to window/resize mode. Pickers and
typing actions exit the mode; exit it before answering a confirmation or
clicking a text field. SketchyBar must run for automatic exit on app switch.

### Zen

| Key in Zen mode | Action |
| --- | --- |
| H / L | Previous / next horizontal workspace |
| J / K | Next / previous vertical tab |
| N | Exit mode and open a new tab |
| O | Exit mode and focus the address bar |
| F | Exit mode and find in the page |
| Cmd+T / Cmd+L / Cmd+K / Cmd+F | Exit mode and perform the native action |
| Escape / Return / Right Cmd+Right Option+Space | Exit mode |
| Right Cmd+Right Option+W / R | Switch to window / resize mode |

### Kitty

| Key in Kitty mode | Action |
| --- | --- |
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

Outside mode:

| Key | Action |
| --- | --- |
| Ctrl+Shift+J / K | Next / previous tab (in the current session; F7 → F reaches all) |
| Ctrl+Shift+L / H | Move tab down / up |
| Cmd+S | Toggle the tab bar in the current OS window |
| Cmd+Plus / Minus / 0 | Font size up / down / reset in the current OS window; add Shift for all windows |
| F7 → key | Sessions and tools; F7 → R [restarts Kitty](programs/terminal.md#restore-and-restart-kitty), F7 → S saves a session |

### Rex

| Key in Rex mode | Action |
| --- | --- |
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
| --- | --- |
| Ctrl+Shift+K / J | Previous / next tab |
| Ctrl+Shift+H / L | Previous / next pane |
| Ctrl+Shift+1–9 | Jump to tab |
| Cmd+1–9 | Jump to pane, counted in layout order (left/top first) |
| Ctrl+Shift+Z | Toggle pane zoom |
| Cmd+T | New tab |
| Cmd+K | Clear the pane, including scrollback; this replaces Rex's default session picker shortcut |
| Cmd+Enter / Cmd+Shift+Enter | Split right / down, also in navigation mode |

Exit the mode before answering Rex's close confirmation. Remote hosts need
the same Lua bindings.

### Herdr

| Key in Herdr mode | Action |
| --- | --- |
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

Numbered agents follow the panel order. Outside the mode:

| Action | Binding |
| --- | --- |
| Previous / next agent | Alt+K / Alt+J |
| Jump to agent 1–9 | Herdr mode 1–9; in Kitty, skhd turns Alt+1–9 into tab jumps |
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

Alt+C needs an empty prompt and an idle agent; it runs `/clear` in Claude
and `/new` in other agents. In the Go To picker, `/` searches, B/W/I/D filters
blocked/working/idle/done and A shows all.

To load changed bindings, see the reload steps for the
[desktop](programs/desktop.md#reload-after-changes),
[terminal](programs/terminal.md#reload-changes) and [Rex](programs/rex.md#reload).
