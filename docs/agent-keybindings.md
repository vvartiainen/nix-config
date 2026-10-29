# Agent CLI keybindings

The shared shortcuts use native CLI settings. In Kitty, **Alt means Right
Option**; Left Option remains available for keyboard-layout characters.

## Shared actions

| Action | Binding | Coverage and exceptions |
|---|---|---|
| Send prompt | Enter | All six CLIs |
| Insert newline | Shift+Enter | All six; Ctrl+J is also available in Codex, Claude, OpenCode, Pi, and Cursor |
| Interrupt a running turn | Esc | Codex, Claude, OpenCode, and Pi; Copilot uses Esc twice, Cursor uses Ctrl+C |
| Edit prompt externally | Ctrl+G | Codex, Claude, OpenCode, Pi, and Copilot; no verified Cursor equivalent |
| Select model | Alt+P | Claude, OpenCode, and Pi; use `/model` in Codex, Copilot, and Cursor |
| Inspect output | Ctrl+O | Codex/Claude open the transcript, Pi expands tools, Copilot expands recent output with an empty prompt |
| Copy last response | Alt+Y | Codex only; moved from Ctrl+O |
| Cycle thinking effort | Alt+T | Pi only; replaces Shift+Tab |

OpenCode v2 keeps Ctrl+O for recent sessions/projects; it has no documented
equivalent to the other clients' output inspection action. Cursor's Ctrl+R
remains review changes. Pi's Alt+T cycles effort, while Claude's native Alt+T
toggles thinking on models that support it; these are different operations.
Mode, history, queueing, and text-editing behavior otherwise follow each CLI.

Existing aliases are retained: Codex Ctrl+T opens the transcript, Pi Ctrl+L
selects a model, and OpenCode's leader shortcuts still open the prompt editor
and model picker. OpenCode Ctrl+G now opens the prompt editor; Home and
Alt+Home still jump to the first message.

## Codex defaults

`@` completes filesystem paths only; use `$` for plugins and skills.
Web search uses live retrieval, and resumed sessions keep the directory where
Codex was launched. Notifications fire even while the terminal has focus so
background Herdr panes can request attention. `/presets` includes preset `1`,
**Review**, which runs `/review`.

These defaults live in `nix/modules/home/programs/ai/codex.nix` and merge into
the writable config during activation. They are supported by Codex 0.165.0:
see the [mention picker behavior](https://github.com/openai/codex/blob/rust-v0.165.0/codex-rs/tui/src/bottom_pane/chat_composer.rs#L28-L33)
and [configuration schema](https://github.com/openai/codex/blob/rust-v0.165.0/codex-rs/core/config.schema.json).
After applying manually and restarting Codex, check `@`, `/presets`, and
resuming from a different directory; notification delivery also depends on
the terminal's settings.

## Herdr

These shortcuts are handled by Herdr before the shell or CLI in its pane.
Numbered agent jumps follow the visible agent panel order.

| Action | Binding |
|---|---|
| Previous / next agent | Alt+K / Alt+J |
| Jump to agent 1–9 | Alt+1–9 |
| Go To picker | Alt+G |
| Workspace picker | Alt+W |
| Previous / next workspace | Alt+H / Alt+L |
| Jump to workspace 1–9 | Alt+Shift+1–9 |
| New tab | Alt+N |
| New workspace | Alt+Shift+N |
| Clear pane / new conversation | Alt+C |
| Previous / next tab | Ctrl+B → P / Ctrl+B → N |
| Jump to tab 1–9 | Ctrl+B → 1–9 |
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

Native overrides live in Codex's `tui.keymap.global`, Pi's
`~/.pi/agent/keybindings.json`, and OpenCode v2's
`~/.config/opencode/cli.json`. Codex settings are merged into its writable
config on activation; OpenCode loads its Nix settings as a separate Home
Manager layer. The legacy OpenCode `tui.json` remains generated for
compatibility. Claude, Copilot, and Cursor use their native defaults for
the shared actions; general remapping is unconfirmed for Copilot and Cursor.

After applying manually, check the bindings in Kitty through Herdr, including
with a nonempty prompt and in menus. Check that model/editor aliases work,
Codex Alt+Y copies, and Pi Alt+T changes effort. These checks should not submit
prompts. In particular, verify Shift+Enter and numbered shortcuts survive the
terminal layers. Restart or reload affected clients as needed; Pi uses
`/reload`, and Herdr's default config reload is Ctrl+B → Shift+R.
