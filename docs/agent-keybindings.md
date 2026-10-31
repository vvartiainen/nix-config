# Agent CLI keybindings

The shared shortcuts use native CLI settings. In Kitty, **Alt means Right
Option**; Left Option remains available for keyboard-layout characters.

## Shortcut layers

| Layer | Purpose |
|---|---|
| Ctrl+Cmd+Z/K/C/O/M/E | Open or focus Zen / Kitty / Calendar / Obsidian / Mail / Finder |
| Ctrl+1–6 / Left / Right | yabai space selection / previous / next space |
| Ctrl+Alt+H/J/K/L | yabai directional window focus |
| Ctrl+Alt+P/N | yabai previous / next window, including stack navigation |
| Ctrl+Alt+Cmd | yabai swaps, window moves, layouts and space management; T opens the quick-access terminal |
| Cmd+Left Option+H/J/K/L | yabai window resizing |
| Right Cmd+Right Option+W (also Ctrl+Alt+W) | Window mode: H/J/K/L focus; Shift+H/J/K/L warp; Cmd+H/J/K/L resize |
| Right Cmd+Right Option+Space | Navigation mode for the focused app: Herdr in Kitty, Zen in Zen; press again to exit |
| Right Cmd+Right Option+R (also Ctrl+Alt+R) → H/J/K/L | yabai resize mode; Escape or Return exits |
| Cmd+Q twice within 500 ms | Quit Zen or Kitty; one press is swallowed in those apps |
| Ctrl+Shift (`kitty_mod`) | Kitty controls, including tabs 1–9 |
| F7 → key | Kitty sessions and tools |
| Right Option / Ctrl+B → key | Herdr direct shortcuts / prefix commands |

yabai leaves plain Alt+P/N available for CLI model selection and Herdr's new
tab action. Ctrl+Down has no skhd binding. Cmd+Tab intentionally cycles yabai
windows; Herdr keeps its Ctrl+B prefix. Kitty retains its other Cmd shortcuts,
and Zen uses Ctrl+Shift shortcuts in its own application context.

Resize mode captures unmatched keys until Escape or Return exits; the existing
Cmd+Left Option resize shortcuts remain available in normal mode. Other apps
retain single-press Cmd+Q. The skhd configuration defines `$window` as
Ctrl+Alt+Cmd, `$focus` as Ctrl+Alt, `$app` as Ctrl+Cmd and `$mode` as
Right Cmd+Right Option before loading the binding files.

The right-side Cmd+Option+W shortcut is reserved for window mode instead of
the native close-all-windows action; the left-side combination retains its
native behavior in normal mode. Right Cmd+Right Option+R also overrides that
combination's app-specific action to enter resize mode. In Kitty and Zen,
right-side Cmd+Option+Space enters navigation mode instead of Spotlight
search; it passes through in other apps, and the left-side combination
always opens Spotlight. No keyboard driver is needed for these
side-specific chords.

Window and resize modes stay active for repeated actions. A blue WINDOW or
orange RESIZE badge in SketchyBar shows a popup with the available keys.
In window mode, Cmd+H/J/K/L resizes directly by 100 pixels without changing
modes; Cmd+Shift+H/J/K/L uses fine 25-pixel steps. B balances the current
Space's tiled layout, F toggles zoom within the current Space (not native
fullscreen), and 1–6 moves the focused window to that Space and follows it.
Shift+B selects BSP layout and S selects stack layout; B still balances.
The number bindings reuse the existing move-and-follow script. All these
actions stay in window mode for repeated adjustments.

R still enters the plain-key resize mode, and W returns from there to
window mode. Right Cmd+Right Option+R switches from window to resize mode,
or exits when already resizing. Escape, Return, Ctrl+Alt+W or
Right Cmd+Right Option+W exits either mode directly to normal. Window mode uses yabai's `--warp` to rearrange
the focused tiled window beside a directional neighbour; the existing direct
Ctrl+Alt+Cmd+H/J/K/L bindings still swap windows.

After applying manually, reload SketchyBar. Check repeated focus, warp and
resize, all exits, and popup placement on your displays. Native default-mode
callbacks on startup and successful reload clear the indicator; a bar reload
restores it for a still-running mode, and a daemon exit hides it within two
seconds. The indicator stores only the mode and owning daemon PID under the user cache.
These modes require no grabber or keyboard driver.

Application shortcuts use macOS `open` with bundle identifiers to activate an
existing app or launch it when closed. E means Explorer/Finder; Ctrl+Cmd+F
remains available for fullscreen. These shortcuts work independently of
Raycast. After reloading skhd, test each app with Raycast stopped, then remove
the old Raycast application assignments manually. Their original bindings
have not been inventoried; this is the replacement scheme. H/L and J/K retain
their existing spatial navigation behavior in Zen and Kitty.

## Shared actions

| Action | Binding | Coverage and exceptions |
|---|---|---|
| Send prompt | Enter | All six CLIs |
| Insert newline | Shift+Enter | All six; Ctrl+J is also available in Codex, Claude, OpenCode, Pi, and Cursor |
| Interrupt a running turn | Esc | Codex, Claude, OpenCode, and Pi; Copilot uses Esc twice, Cursor uses Ctrl+C |
| Edit prompt externally | Ctrl+G | Codex, Claude, OpenCode, Pi, and Copilot; no verified Cursor equivalent |
| Select model | Alt+P | Claude, OpenCode, and Pi; Codex uses Alt+P → 0; Copilot and Cursor retain native controls below |
| Inspect output | Ctrl+O | Codex/Claude open the transcript, Pi expands tools, Copilot expands recent output with an empty prompt |
| Copy last response | Alt+Y | Codex and Claude; Claude runs `/copy` |
| Change reasoning effort | Alt+T | Codex raises effort, Claude opens `/effort`, Pi cycles effort; Copilot and Cursor retain native controls below |
| Lower reasoning effort | Alt+Shift+T | Codex only |

OpenCode v2 keeps Ctrl+O for recent sessions/projects; it has no documented
equivalent to the other clients' output inspection action. Cursor's Ctrl+R
remains review changes. Claude's Alt+T override opens effort controls instead
of toggling extended thinking. Pi's Alt+T cycles effort instead of Shift+Tab.
Mode, history, queueing, and text-editing behavior otherwise follow each CLI.

Existing aliases are retained: Codex Ctrl+T opens the transcript, Pi Ctrl+L
selects a model, and OpenCode's leader shortcuts still open the prompt editor
and model picker. OpenCode Ctrl+G now opens the prompt editor; Home and
Alt+Home still jump to the first message.

## Native model and effort controls

These bindings are configured inside the CLIs, with no Kitty or Herdr
translation layer. Use them from the main prompt while composing a draft.

| CLI | Model | Effort |
|---|---|---|
| Codex | Alt+P → 0 recalls the `/model` preset | Alt+T raises effort; Alt+Shift+T lowers it |
| Claude Code | Alt+P opens the model picker | Alt+T opens `/effort`; Left/Right adjusts the level, Enter confirms, Esc cancels |
| Pi | Alt+P opens the model picker; Ctrl+L remains available | Alt+T cycles thinking effort |
| Copilot CLI | Ctrl+X → / opens draft-preserving command entry; run `/model` | Use the same model/effort picker |
| Cursor CLI | `/model` | Keep native model controls; no separate effort binding is configured |

Codex effort stepping stops at the supported boundary rather than wrapping.
Alt+, / Alt+. and Shift+Down / Shift+Up still lower / raise effort. Advanced
tiers that require explicit selection remain available through `/model`.
Recalling the model preset preserves the existing composer draft.

Claude's binding uses its native
[`command:effort` action](https://code.claude.com/docs/en/keybindings#chat-actions).
Copilot retains its native
[mid-prompt command entry](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference#global-shortcuts-in-the-interactive-interface).

## Claude navigation

Right Option+Y runs `/copy` to copy Claude's last response. Prompt editing
keeps the standard keys; Ctrl+G opens Neovim. Vim editor mode is not enabled.

| Context | Navigation |
|---|---|
| Lists and pickers | J/K next/previous, G G first, Shift+G last |
| Confirmation options | J/K next/previous |
| Tabs and attachments | H/L previous/next |
| Model picker and effort slider | H/L decrease/increase effort |
| Footer | H/J/K/L left/down/up/right |

These are contextual [native keybindings](https://code.claude.com/docs/en/keybindings).
Letters still type normally in dialog text fields. Autocomplete keeps arrow
navigation so J/K remain available while typing a command or path. Conversation
scrolling retains Claude's defaults; these bindings do not capture prompt letters.

## Codex defaults

`@` completes filesystem paths only; use `$` for plugins and skills.
Web search uses live retrieval, and resumed sessions keep the directory where
Codex was launched. Notifications fire even while the terminal has focus so
background Herdr panes can request attention. Alt+P opens `/presets`: preset
`0`, **Model**, runs `/model`; preset `1`, **Review**, runs `/review`.

These defaults live in `nix/modules/home/programs/ai/codex.nix` and merge into
the writable config during activation. They are supported by Codex 0.165.0:
see the [mention picker behavior](https://github.com/openai/codex/blob/rust-v0.165.0/codex-rs/tui/src/bottom_pane/chat_composer.rs#L28-L33)
and [configuration schema](https://github.com/openai/codex/blob/rust-v0.165.0/codex-rs/core/config.schema.json).
After applying manually and restarting Codex, check `@`, `/presets`, and
resuming from a different directory; notification delivery also depends on
the terminal's settings.

## Zen

With Zen focused, press **Right Cmd+Right Option+Space**, release the modifiers,
then navigate repeatedly. SketchyBar shows a purple ZEN badge and key hints:

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

Workspace movement forwards the existing native Ctrl+Shift+H/L shortcuts;
tab movement uses Ctrl+Tab/Ctrl+Shift+Tab with the existing sequential tab
order setting. Typing actions release capture first so the address bar,
new-tab UI and search fields accept text normally. Existing native shortcuts
remain unchanged. Entry is limited to Zen; in Kitty the same chord
enters Herdr mode, and it passes through in other apps. SketchyBar exits the mode when focus leaves Zen,
including after a bar restart; keep it running for this guard and the hints.

Reload skhd and SketchyBar after applying manually. Verify workspace/tab
order, N/O/F, native search shortcuts, mode exits and switching apps. Mouse
clicks into a text field inside Zen do not automatically exit capture; press
Escape or Return first, or use the address/search shortcuts above.

## Herdr

With Herdr focused inside Kitty, press **Right Cmd+Right Option+Space**, release
the modifiers, then navigate repeatedly with plain keys. SketchyBar shows a
teal HERDR badge and key hints:

| Key in Herdr mode | Action |
|---|---|
| H / L | Previous / next Herdr tab |
| J / K | Next / previous agent |
| Shift+J / K | Next / previous Herdr workspace |
| 1–9 | Jump to agent |
| Shift+1–9 | Jump to Herdr tab |
| G | Exit mode and open searchable Go To picker |
| S | Exit mode and open workspace picker |
| Escape / Return / Right Cmd+Right Option+Space | Exit mode |
| Right Cmd+Right Option+W / R | Switch to window / resize mode |

The mode forwards the native right-Option bindings below to the focused
terminal client, so it also works with remote Herdr without selecting a
local socket/session. These are Herdr tabs, not Kitty tabs. Entry is scoped
to Kitty, and SketchyBar exits the mode when another app gains focus. Keep
SketchyBar running for this guard and visual feedback. The guard cannot
distinguish Herdr from another program inside Kitty; only enter the mode
with Herdr focused.

Pickers release skhd capture before opening, so search text and picker keys
work normally. Native F19/F20 aliases open the Go To/workspace pickers;
unmodified keys avoid Option composing differences when synthesized.
Apply the Herdr config change manually, reload its configuration with
`herdr server reload-config`, then reload skhd and SketchyBar. Verify local
and remote navigation, numbered jumps, picker searching, all exits and
switching away from Kitty. No underlying native shortcuts are removed.

These shortcuts are handled by Herdr before the shell or CLI in its pane.
Numbered agent jumps follow the visible agent panel order.

Hold Right Option: J/K switches agents, H/L switches tabs within the current
workspace, and Shift+J/K switches workspaces. For direct jumps, Option+1–9
selects agents and Option+Shift+1–9 selects tabs. Use Ctrl+B, release it,
then Shift+1–9 to select a workspace by number.

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
| Show active shortcuts | Ctrl+B → ? |

The sidebar groups agents by workspace, with separate agent, machine/workspace,
and session-title lines. Blank rows separate entries; a brighter background marks
the active row. Agent labels also appear on split-pane borders, and the outer
terminal title includes the server hostname, workspace, tab, and pane.

Alt+C sends Ctrl+L to a shell, `/clear` to Claude, and `/new` to the other
agents. It does nothing while an agent turn is running, and it assumes the
agent prompt is empty.

The native Go To picker lists individual agents and terminal panes. Press `/`
to search names, agents, workspaces, branches, tabs, or paths. Outside search,
`b`, `w`, `i`, and `d` filter blocked, working, idle, and done agents; `a` shows
all terminals. No custom picker is needed. See the
[Herdr keyboard guide](https://herdr.dev/docs/keyboard/) and
[action reference](https://herdr.dev/docs/config-reference/).

## Upstream comparison

This records upstream defaults researched on 2026-10-21, before the overrides
above. Context matters: shortcuts in a picker may differ from prompt shortcuts.
`L` below means OpenCode's Ctrl+X leader, followed by the displayed key.

| Action | Codex | Claude Code | OpenCode v2 | Pi | Copilot CLI | Cursor CLI |
|---|---|---|---|---|---|---|
| Send | Enter | Enter | Enter | Enter | Enter | Enter |
| Newline | Shift+Enter / Ctrl+J | Shift+Enter / Ctrl+J | Shift+Enter / Ctrl+J | Shift+Enter / Ctrl+J | Shift+Enter / Alt+Enter | Shift+Enter / Ctrl+J |
| Interrupt turn | Esc | Esc / Ctrl+C | Esc | Esc | Esc twice | Ctrl+C |
| Prompt editor | Ctrl+G | Ctrl+G | L → E | Ctrl+G | Ctrl+G | Not documented |
| Model picker | `/model` | Alt+P | L → M | Ctrl+L | `/model` | `/model` |
| Shift+Tab | No mode binding in inspected keymap | Permission modes, including Plan | Cycle agent | Thinking effort | Standard / Plan / Autopilot | Agent / Plan / Ask |
| Ctrl+O | Copy response | Transcript viewer | Recent sessions/projects | Expand tools | Expand recent output (empty prompt) | Unverified |
| Ctrl+T | Transcript | Task checklist | Model variant | Show/hide thinking | Show/hide reasoning | Unverified |
| Ctrl+R | History search | History search | Rename session (picker) | Rename session (picker) | History search | Review changes |
| New conversation | `/new` | `/clear` | L → N | `/new` | `/new` | `/new` |
| Resume conversation | `/resume` | `/resume` | L → L | `/resume` | `/resume` | `/resume` |

References:
[Codex 0.163.0 keymap](https://github.com/openai/codex/blob/rust-v0.163.0/codex-rs/tui/src/keymap.rs),
[Claude interactive mode](https://code.claude.com/docs/en/interactive-mode),
[OpenCode v2 keybinds](https://dev.opencode.ai/v2/docs/cli/keybinds/),
[Pi keybindings](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/keybindings.md),
[Copilot CLI reference](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference),
[Cursor input](https://cursor.com/docs/cli/using), and
[Cursor commands](https://cursor.com/docs/cli/reference/slash-commands).

Native overrides live in Codex's `tui.keymap.global` and `tui.keymap.chat`,
Claude's `~/.claude/keybindings.json`, Pi's `~/.pi/agent/keybindings.json`, and
OpenCode v2's `~/.config/opencode/cli.json`. Codex settings are merged into its writable
config on activation; OpenCode loads its Nix settings as a separate Home
Manager layer. The legacy OpenCode `tui.json` remains generated for
compatibility. Claude's keybindings file is generated by Home Manager.
Copilot and Cursor retain their native controls; general remapping is
unconfirmed for those two clients.

After applying manually, check model and effort controls directly in each CLI
with empty and multiline drafts, pasted content, and attachments. In Codex,
check Alt+P → 0, effort stepping at both boundaries, and the retained aliases.
In Claude, confirm Alt+T opens effort controls and Esc cancels. Verify drafts
and attachments survive both selection and cancellation, and that no prompt
is submitted. Check Copilot's command entry returns to the original draft.

Also check existing model/editor aliases, Codex and Claude Alt+Y copying, and Pi Alt+T
cycling. When using Herdr, verify Shift+Enter and numbered shortcuts survive
the terminal layers. Restart Codex after changing its settings; Claude reloads
keybindings automatically, Pi uses `/reload`, and Herdr's default config
reload is Ctrl+B → Shift+R.
