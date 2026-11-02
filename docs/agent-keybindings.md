# Agent CLI keybindings

The shared shortcuts use native CLI settings. In Kitty, **Alt means Right
Option**; Left Option remains available for keyboard-layout characters.

## Shortcut layers

| Layer | Purpose |
|---|---|
| Ctrl+Cmd+Z/K/C/O/M/E | Open or focus Zen / Kitty / Calendar / Obsidian / Mail / Finder |
| Ctrl+Cmd+U | Toggle CodexBar's usage menu (CodexBar must be running) |
| Ctrl+Cmd+Shift+U | Toggle the persistent quick-access quota dashboard |
| Ctrl+1–6 / Left / Right | yabai space selection / previous / next space |
| Ctrl+Alt+H/J/K/L | yabai directional window focus |
| Ctrl+Alt+P/N | yabai previous / next window, including stack navigation |
| Ctrl+Alt+Cmd | yabai swaps, window moves, layouts and space management |
| Ctrl+Space | Toggle the quick-access terminal |
| Cmd+Left Option+H/J/K/L | yabai window resizing |
| Right Cmd+Right Option+W (also Ctrl+Alt+W) | Window mode: H/J/K/L focus; Shift+H/J/K/L warp; Cmd+H/J/K/L resize |
| Right Cmd+Right Option+Space | Navigation mode for the focused app: Herdr in a Herdr window, Kitty in other Kitty windows, Zen in Zen, Rex in Rex; press again to exit |
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
combination's app-specific action to enter resize mode. In Kitty, Zen and Rex,
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

## CodexBar quotas

**Ctrl+Cmd+U** toggles CodexBar's usage menu through its native global shortcut.
Quit CodexBar before applying the configuration manually, then relaunch it so
it registers the shortcut. To try the same binding immediately, record it in
**CodexBar Settings → General → Keyboard shortcut → Open menu**.

**Ctrl+Cmd+Shift+U** toggles a dedicated quick-access **Metrics** dashboard.
**Esc**, **Q**, **Ctrl+C**, or **Cmd+W** hides it immediately; clicking another
window also hides it. **R** requests a refresh, and **Ctrl+D** stops the dashboard.
The Ctrl+Space quick-access shell is a separate instance. `system-settings.nix`
disables macOS's “Select the previous input source” shortcut on activation to
reserve Ctrl+Space for this shell. This global binding also takes precedence
over app-specific Ctrl+Space actions such as editor completion.

macOS system shortcut overrides are declared through
`system.defaults.CustomUserPreferences."com.apple.symbolichotkeys".AppleSymbolicHotKeys`.
`system-settings.nix` declares the input-source override and `spotlight.nix`
adds the Spotlight overrides. Nix merges these entries into one dictionary;
activation replaces the saved dictionary, so additional system shortcut
customizations must also be declared there to persist.

The dashboard keeps each provider's last successful quota report in memory while
hidden. Reopening shows those reports immediately, including their ages, while
independent refreshes run every five minutes in separate processes. A refresh
times out after 30 seconds; one slow or failing provider does not block the other.
Errors keep that provider's last successful report visible and show the CLI's failure
details. If the first refresh produces only a partial report, its available
quotas are shown as incomplete. The first open after stopping
the dashboard or restarting Kitty needs a fresh fetch. No login daemon or quota
cache on disk is installed.

Quotas use the bundled CodexBar CLI's `cards` command. Codex uses
`--provider codex --source oauth`; Claude uses `--provider claude --source cli`.
Both sources were verified manually. Claude's own CLI avoids the recurring
CodexBar re-grant prompt when Claude Code rotates its OAuth Keychain item.
Claude's roughly two-second fetch runs in the background; it does not delay
showing the previous report. Codex needs its OAuth login and Claude Code must
be installed and signed in. Kitty's bundled Python runs the dashboard; no
separate Python or CodexBar CLI installation is needed. Only quotas
are shown for now; the persistent view can gain other metrics later.

Apply the configuration manually once to link the new `metrics.sh`,
`metrics.conf`, and `metrics.py` files, then reload skhd with `skhd --reload`.
After future dashboard changes, stop it with Ctrl+D and reopen it. Verify
repeated shortcut toggling, Esc/Q dismissal during a fetch, last-report
retention, refresh/error messages, display placement, and that the ordinary
quick-access shell still toggles independently.

For startup diagnostics, run `/bin/sh ~/.config/kitty/metrics.sh` in a terminal.
The launcher uses Kitty's foreground mode; skhd already runs its commands in
the background. Its named `metrics-dashboard` instance is separate from the
ordinary quick-access shell and the earlier `metrics`/`metrics-debug` instances.
Stop an older diagnostic dashboard with Ctrl+D before retesting the shortcut.

If native CodexBar repeatedly says **Claude Code credentials changed** and
requires Refresh, its documented cause is the lifecycle of Claude Code's
Keychain item and CodexBar's access policy. In **CodexBar Settings → Providers →
Claude**, select **Usage source → CLI** to use the same source tested for this
dashboard. This is a manual, local app setting. It avoids relying on repeated
foreign-Keychain re-grants; CLI usage may expose less detail than OAuth. See
[CodexBar's Claude source guidance](https://github.com/steipete/CodexBar/blob/v0.83.0/docs/claude.md#keychain-prompt-policy-claude-oauth).

Enable **Merge Icons** in CodexBar's menu bar settings to browse subscriptions
in one menu. CodexBar 0.83.0's tab shortcuts were reported to switch only
intermittently and then stop responding during manual testing. Use the terminal
shortcut above when that happens. The native defaults in the source are:

| Key | Action |
|---|---|
| Left / Right | Previous / next provider tab, wrapping at the ends |
| Cmd+1–9 | Select a switcher tab by position |
| Cmd+R | Refresh usage |
| Escape | Close the menu |

Overview participates in the tab order when enabled, so it occupies the first
position. These are CodexBar's native defaults, checked against
[0.83.0's switcher shortcuts](https://github.com/steipete/CodexBar/blob/v0.83.0/Sources/CodexBarCore/Config/ProviderSwitcherShortcuts.swift)
and [provider navigation](https://github.com/steipete/CodexBar/blob/v0.83.0/Sources/CodexBar/StatusItem/StatusItemController%2BProviderNavigation.swift).
The menu binding is configured in `nix/modules/darwin/programs/codexbar.nix`;
the dashboard lives in `dotfiles/kitty/metrics.*`, with its shortcut in
`dotfiles/skhd/hotkeys`. It uses Kitty's
[quick-access terminal](https://sw.kovidgoyal.net/kitty/kittens/quick-access-terminal/),
which manages a panel internally. The card command is
documented in [CodexBar's CLI reference](https://github.com/steipete/CodexBar/blob/v0.83.0/docs/cli.md).

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

## Kitty

With a Kitty window that is not running Herdr focused, press
**Right Cmd+Right Option+Space**, release the modifiers, then navigate
repeatedly. SketchyBar shows a green KITTY badge and key hints:

| Key in Kitty mode | Action |
|---|---|
| H / L | Previous / next tab |
| J / K | Next / previous window in the tab |
| Shift+H / L | Move tab backward / forward |
| Shift+J / K | Move window forward / backward |
| Ctrl+H / J / K / L | Swap window with its neighbour in that direction |
| 1–9 | Jump to tab |
| O | Next layout |
| Z | Toggle stack layout |
| N / T | New window / tab in the current directory |
| Ctrl+N / Ctrl+T | Close window / tab; Kitty may ask to confirm closing a tab with running programs |
| F | Exit mode and open the fuzzy tab switcher |
| Escape / Return / Right Cmd+Right Option+Space | Exit mode |
| Right Cmd+Right Option+W / R | Switch to window / resize mode |

The entry key runs `dotfiles/skhd/kitty.sh`, which reads the focused window's
title and posts F17 for Herdr mode or F18 for Kitty mode, because skhd selects
modes by application only. Tab and number keys forward the existing
Ctrl+Shift shortcuts; the other actions use Kitty remote control through the
`listen_on` socket of the focused Kitty process. SketchyBar exits the mode
when another app gains focus.

## Rex

With Rex or Rex Beta focused, press **Right Cmd+Right Option+Space**, release
the modifiers, then use the following keys. SketchyBar shows an orange REX
badge and exits capture when another app gains focus.

| Key in Rex mode | Action |
|---|---|
| K / J | Previous / next tab |
| H / L | Previous / next pane |
| Ctrl+H / J / K / L | Focus pane left / down / up / right |
| 1–9 | Jump to tab |
| T | New tab |
| N or V / Shift+V | Split right / down |
| Cmd+Enter / Cmd+Shift+Enter | Split right / down; stay in mode |
| Z / B | Zoom pane / balance splits |
| Ctrl+N or Ctrl+V / Ctrl+T | Close pane / tab; stay in mode for repeated closes |
| G or F / S | Exit mode and open command palette / session picker |
| Escape / Return / Right Cmd+Right Option+Space | Exit mode |
| Right Cmd+Right Option+W / R | Switch to window / resize mode |

Outside navigation mode, the direct shortcuts follow Kitty:

| Key | Action |
|---|---|
| Ctrl+Shift+K / J | Previous / next tab |
| Ctrl+Shift+H / L | Previous / next pane |
| Ctrl+Shift+1–9 | Jump to tab |
| Cmd+1–9 | Jump to pane, counted in layout order (left/top first) |
| Ctrl+Shift+Z | Toggle pane zoom |
| Cmd+T | New tab |
| Cmd+Enter / Cmd+Shift+Enter | Split right / down, also in navigation mode |

Cmd+1–9 uses the module's `pane_goto` action, since Rex has no built-in
action for a pane by number. These directions match vertical tabs and panes
arranged left to right; Ctrl+H/J/K/L in navigation mode still focuses panes
spatially (left/down/up/right).

The mode forwards Ctrl+Alt aliases defined in the Home Manager Rex module
to the focused client. For remote sessions, install the same Rex Lua bindings
on the server that reads the configuration. Apply manually, run
`rex config reload`, then reload skhd and SketchyBar. Verify tab/pane
navigation, splits, picker searching, close prompts, and exit on app switch.
Tab and pane closes keep capture active, as do creation, navigation and layout
actions in the other modes. If Rex asks for confirmation, press Escape or
Return to release capture before answering the prompt. Pickers and actions
that open text fields exit mode so their controls receive keys normally;
Herdr's workspace close also exits for its confirmation.

## Herdr

With Herdr focused inside Kitty, press **Right Cmd+Right Option+Space**, release
the modifiers, then navigate repeatedly with plain keys. SketchyBar shows a
teal HERDR badge and key hints:

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

The mode forwards the native right-Option bindings below to the focused
terminal client, so it also works with remote Herdr without selecting a
local socket/session. These are Herdr tabs, not Kitty tabs. Entry is scoped
to Kitty, and SketchyBar exits the mode when another app gains focus. Keep
SketchyBar running for this guard and visual feedback. The guard also exits
when the focused Kitty window's title loses the `herdr · ` prefix that
`window_title` in `herdr.nix` sets, which also covers remote Herdr. Keep that
prefix when changing the title format.

Creating tabs, workspaces and splits keeps the mode active for repeated
actions; new tabs skip Herdr's name prompt (`ui.prompt_new_tab_name`), which
also applies to Alt+N. Pickers release skhd capture before opening, so search
text and picker keys work normally. Native F19/F20 aliases open the Go To
and workspace pickers; unmodified keys avoid Option composing differences when
synthesized. Tabs, workspaces and splits use Ctrl+Alt aliases instead, because
skhd forwards function keys without the Fn flag and Kitty then sends raw
characters to the pane.
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
| Swap pane | Ctrl+Alt+Shift+H/J/K/L; also Ctrl+B → Shift+H/J/K/L |
| Split side by side / stacked | Ctrl+Alt+V / Ctrl+Alt+Shift+V; also Ctrl+B → V / Ctrl+B → - |
| Close pane / tab | Ctrl+Alt+X / Ctrl+Alt+Shift+X; also Ctrl+B → X for panes |
| Close workspace | F16, with confirmation |
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
Manager layer. Claude's keybindings file is generated by Home Manager.
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
