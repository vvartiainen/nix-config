# Agent CLI keybindings

The shared shortcuts use native CLI settings. In Kitty, **Alt means Right
Option**; Left Option remains available for keyboard-layout characters.

## Shortcut layers

| Layer | Purpose |
|---|---|
| Ctrl+1–6 / Left / Right | yabai space selection / previous / next space |
| Ctrl+Alt+H/J/K/L | yabai directional window focus |
| Ctrl+Alt+P/N | yabai previous / next window, including stack navigation |
| Ctrl+Alt+Cmd | yabai swaps, window moves, layouts and space management; T opens the quick-access terminal |
| Cmd+Left Option+H/J/K/L | yabai window resizing |
| Ctrl+Shift (`kitty_mod`) | Kitty controls, including tabs 1–9 |
| F7 → key | Kitty sessions and tools |
| Right Option / Ctrl+B → key | Herdr direct shortcuts / prefix commands |

yabai leaves plain Alt+P/N available for CLI model selection and Herdr's new
tab action. Ctrl+Down has no skhd binding. Cmd+Tab intentionally cycles yabai
windows; Herdr keeps its Ctrl+B prefix. Kitty also retains its Cmd shortcuts,
and Zen uses Ctrl+Shift shortcuts in its own application context.

## Shared actions

| Action | Binding | Coverage and exceptions |
|---|---|---|
| Send prompt | Enter | All six CLIs |
| Insert newline | Shift+Enter | All six; Ctrl+J is also available in Codex, Claude, OpenCode, Pi, and Cursor |
| Interrupt a running turn | Esc | Codex, Claude, OpenCode, and Pi; Copilot uses Esc twice, Cursor uses Ctrl+C |
| Edit prompt externally | Ctrl+G | Codex, Claude, OpenCode, Pi, and Copilot; no verified Cursor equivalent |
| Select model | Alt+P | Claude, OpenCode, and Pi; Codex uses Alt+P → 0; Copilot and Cursor retain native controls below |
| Inspect output | Ctrl+O | Codex/Claude open the transcript, Pi expands tools, Copilot expands recent output with an empty prompt |
| Copy last response | Alt+Y | Codex only; moved from Ctrl+O |
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

## Herdr

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

Also check existing model/editor aliases, Codex Alt+Y copying, and Pi Alt+T
cycling. When using Herdr, verify Shift+Enter and numbered shortcuts survive
the terminal layers. Restart Codex after changing its settings; Claude reloads
keybindings automatically, Pi uses `/reload`, and Herdr's default config
reload is Ctrl+B → Shift+R.
