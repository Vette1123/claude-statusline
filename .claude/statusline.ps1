# Claude Code custom status line (PowerShell 7+) - powerline style.
# Segments: repo/worktree > branch+git status > model > lines changed > context > 5h limit.
# Requires a Nerd Font for the powerline arrows and glyphs.
# Collapses onto a second powerline row when the terminal is too narrow.

$ErrorActionPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$e   = [char]27
$SEP = [char]0xE0B0   # powerline right arrow

# glyphs (Nerd Font)
$G_REPO = [char]0xF401   # repo
$G_DIR  = [char]0xF07B   # folder
$G_WT   = [char]0xF126   # code-fork / worktree
$G_BR   = [char]0xE0A0   # git branch
$G_MOD  = [char]0xF2DB   # microchip (model)
$G_DIFF = [char]0xF440   # diff (lines)
$G_CTX  = [char]0xF080   # bar chart (context)
$G_CLK  = [char]0xF017   # clock (rate limit)

function vlen($s) { ($s -replace "$e\[[0-9;]*m", '').Length }
function hz($n) {
    $n = [double]$n
    if ($n -ge 1000000) { return ('{0:0.#}M' -f ($n / 1000000)) }
    if ($n -ge 1000)    { return ('{0:0.#}k' -f ($n / 1000)) }
    return ('{0:0}' -f $n)
}
# render an ordered list of @{bg=@(r,g,b); fg=@(r,g,b); text='...'} as a powerline
function pl($segs) {
    $segs = @($segs | Where-Object { $_ })
    if (-not $segs.Count) { return '' }
    $o = ''
    for ($i = 0; $i -lt $segs.Count; $i++) {
        $s = $segs[$i]; $b = $s.bg; $f = $s.fg
        $o += "$e[48;2;$($b[0]);$($b[1]);$($b[2])m$e[38;2;$($f[0]);$($f[1]);$($f[2])m $($s.text) "
        if ($i -lt $segs.Count - 1) {
            $n = $segs[$i + 1].bg
            $o += "$e[48;2;$($n[0]);$($n[1]);$($n[2])m$e[38;2;$($b[0]);$($b[1]);$($b[2])m$SEP"
        } else {
            $o += "$e[0m$e[38;2;$($b[0]);$($b[1]);$($b[2])m$SEP$e[0m"
        }
    }
    return $o
}

# --- read the JSON Claude Code pipes in (pipeline input, else raw stdin) ---
$raw = (@($input) -join "`n")
if ([string]::IsNullOrWhiteSpace($raw)) { try { $raw = [Console]::In.ReadToEnd() } catch {} }
try { $d = $raw | ConvertFrom-Json } catch { return }
if (-not $d) { return }

$cwd = if ($d.cwd) { $d.cwd } elseif ($d.workspace.current_dir) { $d.workspace.current_dir } else { '.' }

# --- repo / worktree label ---
$wtName   = $d.worktree.name
$repoName = $d.workspace.repo.name
$isWt     = [bool]$d.workspace.git_worktree -or [bool]$wtName
$label    = if ($wtName) { $wtName } elseif ($repoName) { $repoName } else { Split-Path -Leaf $cwd }
$repoIcon = if ($isWt) { $G_WT } elseif ($repoName) { $G_REPO } else { $G_DIR }

# --- git: one call for branch + ahead/behind + dirty counts ---
$branch = $null; $ahead = 0; $behind = 0; $staged = 0; $modified = 0; $untracked = 0
$gs = @(git -C "$cwd" status --porcelain=v1 -b 2>$null)
if ($LASTEXITCODE -eq 0 -and $gs.Count -ge 1) {
    $head = $gs[0]
    if ($head -match 'no branch') {
        $sha = (git -C "$cwd" rev-parse --short HEAD) 2>$null
        $branch = if ($sha) { "$([char]0xF417)$sha" } else { 'detached' }   # tag glyph + sha
    } elseif ($head -match '^##\s+(.+?)(?:\.\.\.|\s|$)') {
        $branch = $matches[1]
    }
    if ($head -match 'ahead (\d+)')  { $ahead  = [int]$matches[1] }
    if ($head -match 'behind (\d+)') { $behind = [int]$matches[1] }
    for ($i = 1; $i -lt $gs.Count; $i++) {
        $l = $gs[$i]; if ($l.Length -lt 2) { continue }
        if ($l.StartsWith('??')) { $untracked++; continue }
        if ('MADRC'.Contains([string]$l[0])) { $staged++ }
        if ('MD'.Contains([string]$l[1]))    { $modified++ }
    }
}
$gitBits = @()
if ($staged)    { $gitBits += "$([char]0x2713)$staged" }   # ✓ staged
if ($modified)  { $gitBits += "$([char]0x25CF)$modified" } # ● modified
if ($untracked) { $gitBits += "?$untracked" }
if ($ahead)     { $gitBits += "$([char]0x2191)$ahead" }    # ↑
if ($behind)    { $gitBits += "$([char]0x2193)$behind" }   # ↓
$branchText = if ($branch) { "$G_BR $branch" + $(if ($gitBits.Count) { ' ' + ($gitBits -join ' ') } else { '' }) } else { $null }

# --- model + effort ---
$model     = $d.model.display_name
$effort    = $d.effort.level
$modelText = "$G_MOD $model" + $(if ($effort) { " $([char]0x26A1)$effort" } else { '' })

# --- lines changed ---
$add = [int]$d.cost.total_lines_added
$rem = [int]$d.cost.total_lines_removed
$linesText = if ($add -or $rem) { "$G_DIFF +$add -$rem" } else { $null }

# --- context: bar + used/max (bg encodes pressure) ---
$cw   = $d.context_window
$used = $cw.total_input_tokens
if ($null -eq $used -and $cw.current_usage) {
    $u = $cw.current_usage
    $used = [double]$u.input_tokens + [double]$u.cache_read_input_tokens + [double]$u.cache_creation_input_tokens
}
$max = $cw.context_window_size
$pct = $cw.used_percentage
if ($null -eq $pct -and $used -and $max) { $pct = ($used / $max) * 100 }

$ctxSeg = $null
if ($null -ne $pct) {
    $p = [math]::Max(0, [math]::Min(100, [double]$pct))
    if     ($p -lt 50) { $cbg = @(22,101,68);  $cfg = @(209,250,229) }   # emerald
    elseif ($p -lt 80) { $cbg = @(161,98,7);   $cfg = @(254,243,199) }   # amber
    else               { $cbg = @(159,18,57);  $cfg = @(254,226,226) }   # rose
    $dim   = @([int]($cbg[0]*0.45), [int]($cbg[1]*0.45)+40, [int]($cbg[2]*0.45)+40)
    $cells = 8
    $fill  = [int][math]::Round($p / 100 * $cells)
    $bar = ''
    for ($i = 0; $i -lt $cells; $i++) {
        if ($i -lt $fill) { $bar += "$e[38;2;$($cfg[0]);$($cfg[1]);$($cfg[2])m$([char]0x2588)" }
        else              { $bar += "$e[38;2;$($dim[0]);$($dim[1]);$($dim[2])m$([char]0x2588)" }
    }
    $bar += "$e[38;2;$($cfg[0]);$($cfg[1]);$($cfg[2])m"   # restore fg for the text that follows
    $nums = if ($used -and $max) { "$(hz $used)/$(hz $max)" } elseif ($used) { "$(hz $used)" } else { '' }
    $ctxText = "$G_CTX $bar $nums ({0:0}%)" -f $p
    $ctxSeg = @{ bg = $cbg; fg = $cfg; text = $ctxText }
}

# --- 5h rate limit ---
$rl5 = $d.rate_limits.five_hour.used_percentage
$rateSeg = $null
if ($null -ne $rl5) {
    $rateSeg = @{ bg = @(67,56,202); fg = @(224,231,255); text = ("$G_CLK 5h {0:0}%" -f [double]$rl5) }
}

# --- segments ---
$sRepo   = @{ bg = @(14,165,233);  fg = @(8,15,25);    text = "$repoIcon $label" }
$sBranch = if ($branchText) { @{ bg = @(139,92,246); fg = @(24,12,45);  text = $branchText } } else { $null }
$sModel  = @{ bg = @(51,65,85);    fg = @(226,232,240); text = $modelText }
$sLines  = if ($linesText) { @{ bg = @(15,118,110); fg = @(204,251,241); text = $linesText } } else { $null }

$group1 = @(@($sRepo, $sBranch)                  | Where-Object { $_ })
$group2 = @(@($sModel, $sLines, $ctxSeg, $rateSeg) | Where-Object { $_ })
$all    = $group1 + $group2

$single = pl $all

# --- width: collapse to two powerline rows if the single row won't fit ---
$width = 0
try { $width = [Console]::WindowWidth } catch {}
if ($width -le 0) { try { $width = $Host.UI.RawUI.WindowSize.Width } catch {} }
if ($width -le 0 -and $env:COLUMNS) { $width = [int]$env:COLUMNS }
if ($width -le 0) { $width = 120 }

if ((vlen $single) -le ($width - 2)) {
    $single
} else {
    (pl $group1) + "`n" + (pl $group2)
}
