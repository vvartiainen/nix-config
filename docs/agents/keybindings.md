# Agent CLI keybindings

These controls are configured inside the agent CLIs. In Kitty and Rex,
**Alt means Right Option**; Left Option keeps keyboard-layout characters.
Desktop, browser, terminal and Herdr navigation are in
[general keybindings](../keybindings.md).

## Prompt and output

| Action | Binding | Coverage and exceptions |
| --- | --- | --- |
| Send prompt | Enter | All six CLIs |
| Insert newline | Shift+Enter | All six; Ctrl+J is also available in Codex, Claude, OpenCode, Pi, and Cursor |
| Interrupt a running turn | Esc | Codex, Claude, OpenCode, and Pi; Copilot uses Esc twice, Cursor uses Ctrl+C |
| Edit prompt externally | Ctrl+G | Codex, Claude, OpenCode, Pi, and Copilot; no verified Cursor equivalent |
| Inspect output | Ctrl+O | Codex/Claude open the transcript, Pi expands tools, Copilot expands recent output with an empty prompt |
| Copy last response | Alt+Y | Codex and Claude; Claude runs `/copy` |

Other controls follow each CLI's defaults.

## Model and reasoning effort

| CLI | Model | Effort |
| --- | --- | --- |
| Codex | Alt+P → 0 recalls the `/model` preset | Alt+T raises effort; Alt+Shift+T lowers it |
| OpenCode | Alt+P opens the model picker | Keep native effort controls |
| Claude Code | Alt+P opens the model picker | Alt+T opens `/effort`; Left/Right adjusts the level, Enter confirms, Esc cancels |
| Pi | Alt+P opens the model picker; Ctrl+L remains available | Alt+T cycles thinking effort |
| Copilot CLI | Ctrl+X → / opens draft-preserving command entry; run `/model` | Use the same model/effort picker |
| Cursor CLI | `/model` | Keep native model controls; no separate effort binding is configured |

Codex Alt+P presets: 0 `/model`, 1 `/review`, 2 `/subagents`.

## Claude navigation

| Context | Navigation |
| --- | --- |
| Lists and pickers | J/K next/previous, G G first, Shift+G last |
| Confirmation options | J/K next/previous |
| Tabs and attachments | H/L previous/next |
| Model picker and effort slider | H/L decrease/increase effort |
| Footer | H/J/K/L left/down/up/right |

Letters type normally in text fields, and autocomplete keeps arrow keys.

## Subagents

Claude lists subagents in a panel below the prompt; Codex runs each subagent
in its own thread.

| Action | Claude Code | Codex |
| --- | --- | --- |
| Open subagent list | Alt+A runs `/tasks` | Alt+P → 2 runs `/subagents` |
| Move between agents | Up/Down or J/K in the panel below the prompt | Alt+Left / Alt+Right with an empty prompt |
| Open selected agent | Enter opens its transcript; messages go to that agent | Select it in the picker |
| Return to the prompt | Esc | Alt+Left/Right or the picker back to the main thread |
| Background running work | Ctrl+X Ctrl+B; Ctrl+B outside Herdr | Subagents always run in the background |
| Stop | X stops the selected row; Ctrl+X Ctrl+K twice stops all | Ask the main agent |
| Side chat | `/btw` | Ctrl+/ switches between `/side` and its parent |

In Codex approval prompts from another thread, O opens that thread.

## T3 Code

Nix manages these shortcuts in `~/.t3/userdata/keybindings.json`:

| Action | Binding |
| --- | --- |
| Next / previous thread | Ctrl+Shift+J / K |
| Model picker | Option+P |
| Increase / decrease effort | Option+T / Option+Shift+T |
| Stop current turn | Ctrl+Shift+X |

Both Option keys work in T3. Other actions keep T3's defaults, such as
Cmd+K for the command palette, Cmd+J for the terminal and Cmd+D for the diff.
If typing a question choice's number goes to the composer, Tab to the choice
and press Space.

## Reload changes

Restart Codex after changing settings. Claude reloads keybindings automatically;
Pi uses `/reload`.
