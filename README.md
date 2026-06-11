# Claude Code status line

A powerline status line for Claude Code, shared across the team. It shows:

![Status line preview](assets/statusline-preview.svg)

> Rendered with a Nerd Font in your terminal it looks like:
> `  my-repo   ⎇ main ✓2 ●1 ↑1   ◆ Opus 4.8 ⚡high   +128 -34   ███████░░ 640k/1M (64%)   5h 38%`

| Segment | Shows |
|---------|-------|
|  **repo** | repo name (` ` = worktree, ` ` = plain folder) |
|  **branch** | git branch + status — `✓` staged · `●` modified · `?` untracked · `↑`/`↓` ahead/behind |
|  **model** | model name + `⚡` reasoning-effort level |
|  **lines** | lines added / removed this session (hidden when zero) |
|  **context** | gradient bar (green → amber → rose) + **real `used / max` tokens** + `(%)` |
|  **5h limit** | Claude.ai 5-hour usage gauge (Pro/Max only) |

Empty segments auto-hide. If the row doesn't fit the terminal, it splits onto two rows.

## Requirements

- **PowerShell 7+ (`pwsh`)** — cross-platform; this is the only hard dependency.
  - Windows: already bundled / `winget install Microsoft.PowerShell`
  - macOS: `brew install powershell`
  - Linux: see https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux
- **git** (for the branch/status segment — optional, segment just hides if absent)
- **A Nerd Font** selected in your terminal, for the `` arrows and glyphs.
  Get one at https://www.nerdfonts.com (e.g. *CaskaydiaCove NF*, *MesloLGS NF*) and set it as your terminal font.
  No `jq` required.

## Install (per teammate)

The config is committed in this repo under `.claude/`, so it applies automatically once you have the requirements above — **no per-machine setup beyond installing `pwsh` + a Nerd Font.**

1. Make sure `.claude/settings.json` and `.claude/statusline.ps1` are committed at the **repo root**.
2. Install `pwsh` and a Nerd Font (see Requirements).
3. Restart Claude Code in the repo. The status line appears after the first message.

Project settings (`.claude/settings.json`) override each person's personal `~/.claude/settings.json` for the status line, so everyone gets the same bar.

The launch command walks up from your current directory to find `.claude/statusline.ps1`, so it works whether you start Claude at the repo root **or** in a subfolder (e.g. `apps/seeker`).

## Troubleshooting

- **Status line is blank** → `pwsh` isn't installed or isn't on `PATH`. Run `pwsh --version`.
- **Arrows/icons show as boxes (`▯`)** → your terminal font isn't a Nerd Font. Switch the terminal font.
- **No colors / garbled colors** → use a truecolor terminal (Windows Terminal, iTerm2, modern VS Code). Older consoles may not support 24-bit color.
- **Branch segment missing** → you're not in a git repo, or `git` isn't on `PATH`.

## Customize

Everything lives in `.claude/statusline.ps1`. Common tweaks near the top / segment section:

- **Palette** — the `bg`/`fg` RGB triples on each `$s_*` segment.
- **Glyphs** — the `$G_*` variables.
- **Add cost** — Claude Code also pipes `.cost.total_cost_usd`; add a segment for it.
- **Bar width** — the `$cells` value in the context section.
