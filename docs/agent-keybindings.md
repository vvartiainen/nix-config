# Agent CLI keybindings

These controls are configured inside the agent CLIs. In Kitty and Rex,
**Alt means Right Option**; Left Option keeps keyboard-layout characters.
Desktop, browser, terminal and Herdr navigation are in
[general keybindings](keybindings.md).

## Prompt and output

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

OpenCode keeps Ctrl+O for recent sessions/projects. Cursor keeps Ctrl+R for
reviewing changes. Mode, history, queueing and text editing otherwise follow
each CLI's native controls. Codex Ctrl+T remains a transcript alias; OpenCode's
leader shortcuts still open its editor and model picker.

## Model and reasoning effort

| CLI | Model | Effort |
|---|---|---|
| Codex | Alt+P → 0 recalls the `/model` preset | Alt+T raises effort; Alt+Shift+T lowers it |
| Claude Code | Alt+P opens the model picker | Alt+T opens `/effort`; Left/Right adjusts the level, Enter confirms, Esc cancels |
| Pi | Alt+P opens the model picker; Ctrl+L remains available | Alt+T cycles thinking effort |
| Copilot CLI | Ctrl+X → / opens draft-preserving command entry; run `/model` | Use the same model/effort picker |
| Cursor CLI | `/model` | Keep native model controls; no separate effort binding is configured |

OpenCode uses Alt+P for model selection. Codex effort stepping stops at the
supported boundary; Alt+, / Alt+. and Shift+Down / Shift+Up remain aliases.
Use `/model` for tiers requiring explicit selection. Codex Alt+P opens presets:
0 is Model (`/model`), 1 is Review (`/review`). Model selection preserves the draft.

Claude Alt+T opens effort controls; Pi Alt+T cycles effort. Claude's Shift+Tab
mode switching remains native.

## Claude navigation

| Context | Navigation |
|---|---|
| Lists and pickers | J/K next/previous, G G first, Shift+G last |
| Confirmation options | J/K next/previous |
| Tabs and attachments | H/L previous/next |
| Model picker and effort slider | H/L decrease/increase effort |
| Footer | H/J/K/L left/down/up/right |

Letters type normally in text fields. Autocomplete keeps arrow navigation so
J/K remain usable while entering commands and paths. Ctrl+G opens Neovim;
Vim prompt editing is not enabled. Alt+Y runs `/copy`.

## Reload changes

Restart Codex after changing settings. Claude reloads keybindings automatically;
Pi uses `/reload`. When testing model or effort controls, selection and
cancellation should preserve drafts and attachments without sending the prompt.

Configuration and detailed checks: Backlog **doc-8 — Agent project tooling and
configuration implementation**.
