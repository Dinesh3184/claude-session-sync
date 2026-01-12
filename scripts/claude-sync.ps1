# Claude Sessions Sync - Windows PowerShell
# Syncs Claude Code sessions across devices via iCloud/Git

param(
    [Parameter(Position=0)]
    [ValidateSet('push', 'pull', 'status', 'list', 'apply', 'settings')]
    [string]$Command = 'status',

    [Parameter(Position=1)]
    [string]$SourceDevice = ''
)

$ErrorActionPreference = "Stop"

# Paths - iCloud on Windows
$ClaudeDir = "$env:USERPROFILE\.claude"
$SyncDir = "$env:USERPROFILE\iCloudDrive\ClaudeSessions"  # Adjust if different
$DeviceName = $env:COMPUTERNAME
$SessionsDir = "$SyncDir\sessions"
$GlobalDir = "$SyncDir\global"
$IndexFile = "$SyncDir\index.md"

# Alternative iCloud paths to check
$iCloudPaths = @(
    "$env:USERPROFILE\iCloudDrive\ClaudeSessions",
    "$env:USERPROFILE\iCloud Drive\ClaudeSessions",
    "${env:ProgramFiles(x86)}\Common Files\Apple\Internet Services\iCloudDrive\ClaudeSessions"
)

# Find iCloud path
foreach ($path in $iCloudPaths) {
    if (Test-Path (Split-Path $path -Parent)) {
        $SyncDir = $path
        $SessionsDir = "$SyncDir\sessions"
        $GlobalDir = "$SyncDir\global"
        $IndexFile = "$SyncDir\index.md"
        break
    }
}

function Write-Info { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Blue }
function Write-Success { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

function Get-ProjectName {
    param([string]$path)
    $path -replace '-Users-[^-]*-', '' -replace '-', '/'
}

function Export-Session {
    param([string]$sessionFile)

    $projectDir = Split-Path $sessionFile -Parent
    $projectPath = Split-Path $projectDir -Leaf
    $sessionId = [System.IO.Path]::GetFileNameWithoutExtension($sessionFile)
    $projectName = Get-ProjectName $projectPath

    # Skip agent sessions
    if ($sessionId -like "agent-*") { return $null }

    # Skip empty files
    if ((Get-Item $sessionFile).Length -eq 0) { return $null }

    # Create output directory
    $outDir = Join-Path $SessionsDir $projectPath
    if (-not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    # Get file info
    $fileInfo = Get-Item $sessionFile
    $fileDate = $fileInfo.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
    $fileSize = "{0:N2} KB" -f ($fileInfo.Length / 1KB)
    $lineCount = (Get-Content $sessionFile | Measure-Object -Line).Lines

    # Try to get first message preview
    $firstMsg = "(no preview available)"
    try {
        $firstLine = Get-Content $sessionFile -First 1
        if ($firstLine -match '"content":"([^"]{1,100})') {
            $firstMsg = $matches[1]
        }
    } catch {}

    # Generate markdown
    $outFile = Join-Path $outDir "$sessionId.md"
    $content = @"
# Session: $sessionId

## Metadata
- **Device:** $DeviceName
- **Project:** $projectName
- **Date:** $fileDate
- **Size:** $fileSize
- **Messages:** ~$lineCount

## Preview
``````
$firstMsg...
``````

## Source
``$sessionFile``

---
*Exported $(Get-Date -Format "yyyy-MM-dd HH:mm") from $DeviceName*
"@

    $content | Out-File -FilePath $outFile -Encoding utf8
    return $outFile
}

function Sync-GlobalSettings {
    Write-Info "Syncing global settings..."

    $deviceDir = Join-Path $GlobalDir $DeviceName
    if (-not (Test-Path $deviceDir)) {
        New-Item -ItemType Directory -Path $deviceDir -Force | Out-Null
    }

    # Copy settings.json
    $settingsFile = Join-Path $ClaudeDir "settings.json"
    if (Test-Path $settingsFile) {
        Copy-Item $settingsFile (Join-Path $deviceDir "settings.json") -Force

        # Create portable version without hooks
        try {
            $settings = Get-Content $settingsFile -Raw | ConvertFrom-Json
            $settings.PSObject.Properties.Remove('hooks')
            $settings | ConvertTo-Json -Depth 10 | Out-File (Join-Path $deviceDir "settings-portable.json") -Encoding utf8
        } catch {
            Copy-Item $settingsFile (Join-Path $deviceDir "settings-portable.json") -Force
        }
    }

    # Copy installed plugins
    $pluginsFile = Join-Path $ClaudeDir "plugins\installed_plugins.json"
    if (Test-Path $pluginsFile) {
        Copy-Item $pluginsFile (Join-Path $deviceDir "installed_plugins.json") -Force
    }

    # Create README
    $readme = @"
# Claude Config: $DeviceName

**Last synced:** $(Get-Date -Format "yyyy-MM-dd HH:mm")
**Platform:** Windows

## To apply this config on another device:
```powershell
# Run: .\claude-sync.ps1 apply "$DeviceName"
```
"@
    $readme | Out-File (Join-Path $deviceDir "README.md") -Encoding utf8

    Write-Success "Global settings synced"
}

function Invoke-Push {
    Write-Info "Exporting sessions from $DeviceName..."

    $projectsDir = Join-Path $ClaudeDir "projects"
    if (-not (Test-Path $projectsDir)) {
        Write-Err "No projects directory found at $projectsDir"
        exit 1
    }

    $count = 0
    Get-ChildItem $projectsDir -Directory | ForEach-Object {
        Get-ChildItem $_.FullName -Filter "*.jsonl" | ForEach-Object {
            $result = Export-Session $_.FullName
            if ($result) { $count++ }
        }
    }

    Write-Success "Exported $count sessions"

    # Sync global settings
    Sync-GlobalSettings

    # Git commit if available
    if (Test-Path (Join-Path $SyncDir ".git")) {
        Push-Location $SyncDir
        git add -A
        $changes = git diff --cached --quiet; $hasChanges = -not $?
        if ($hasChanges) {
            git commit -m "Sync from $DeviceName - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
            Write-Success "Committed to git"
        } else {
            Write-Info "No changes to commit"
        }
        Pop-Location
    }
}

function Invoke-Pull {
    Write-Info "Checking for sessions from other devices..."

    $otherSessions = Get-ChildItem $SessionsDir -Recurse -Filter "*.md" | ForEach-Object {
        $content = Get-Content $_.FullName -Raw
        if ($content -match '\*\*Device:\*\* (.+)' -and $matches[1] -ne $DeviceName) {
            $_
        }
    }

    Write-Info "Found $($otherSessions.Count) sessions from other devices"

    Write-Host ""
    Write-Host "Recent sessions from other devices:"
    Write-Host "------------------------------------"

    $otherSessions | Sort-Object LastWriteTime -Descending | Select-Object -First 10 | ForEach-Object {
        $content = Get-Content $_.FullName -Raw
        if ($content -match '\*\*Device:\*\* (.+)') { $device = $matches[1] }
        if ($content -match '\*\*Project:\*\* (.+)') { $project = $matches[1] }
        if ($content -match '\*\*Date:\*\* (.+)') { $date = $matches[1] }
        Write-Host "  [$device] $project - $date"
    }
}

function Invoke-Status {
    Write-Host "Claude Sessions Sync Status"
    Write-Host "============================"
    Write-Host ""
    Write-Host "Device:     $DeviceName"
    Write-Host "Claude Dir: $ClaudeDir"
    Write-Host "Sync Dir:   $SyncDir"
    Write-Host ""

    $localSessions = (Get-ChildItem "$ClaudeDir\projects" -Recurse -Filter "*.jsonl" -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-Host "Local sessions: $localSessions"

    $syncedSessions = (Get-ChildItem $SessionsDir -Recurse -Filter "*.md" -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-Host "Synced sessions: $syncedSessions"

    if (Test-Path (Join-Path $SyncDir ".git")) {
        Write-Host ""
        Write-Host "Git status:"
        Push-Location $SyncDir
        git status -s
        Pop-Location
    }
}

function Invoke-List {
    Write-Host "All Claude Sessions"
    Write-Host "==================="
    Write-Host ""

    Get-ChildItem $SessionsDir -Recurse -Filter "*.md" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 20 |
        ForEach-Object {
            $content = Get-Content $_.FullName -Raw
            if ($content -match '\*\*Device:\*\* (.+)') { $device = $matches[1] }
            if ($content -match '\*\*Project:\*\* (.+)') { $project = $matches[1] }
            if ($content -match '\*\*Date:\*\* (.+)') { $date = $matches[1] }
            Write-Host "[$device] $project"
            Write-Host "    $date"
            Write-Host "    $($_.Name)"
            Write-Host ""
        }
}

function Invoke-Apply {
    param([string]$Device)

    if ([string]::IsNullOrEmpty($Device)) {
        Write-Host "Available device configs:"
        Get-ChildItem $GlobalDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Host "  - $($_.Name)"
        }
        Write-Host ""
        Write-Host "Usage: .\claude-sync.ps1 apply <device-name>"
        return
    }

    $sourceDir = Join-Path $GlobalDir $Device
    if (-not (Test-Path $sourceDir)) {
        Write-Err "No config found for device: $Device"
        return
    }

    Write-Info "Applying settings from $Device..."

    # Backup current settings
    $settingsFile = Join-Path $ClaudeDir "settings.json"
    if (Test-Path $settingsFile) {
        Copy-Item $settingsFile "$settingsFile.backup" -Force
        Write-Info "Backed up current settings to settings.json.backup"
    }

    # Apply portable settings (preserves local hooks)
    $portableSettings = Join-Path $sourceDir "settings-portable.json"
    if (Test-Path $portableSettings) {
        if (Test-Path $settingsFile) {
            # Merge: keep local hooks, apply everything else from source
            try {
                $localSettings = Get-Content $settingsFile -Raw | ConvertFrom-Json
                $sourceSettings = Get-Content $portableSettings -Raw | ConvertFrom-Json

                # Preserve local hooks if they exist
                if ($localSettings.hooks) {
                    $sourceSettings | Add-Member -NotePropertyName 'hooks' -NotePropertyValue $localSettings.hooks -Force
                }

                $sourceSettings | ConvertTo-Json -Depth 10 | Out-File $settingsFile -Encoding utf8
            } catch {
                Copy-Item $portableSettings $settingsFile -Force
            }
        } else {
            # No local settings, just copy
            if (-not (Test-Path $ClaudeDir)) {
                New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null
            }
            Copy-Item $portableSettings $settingsFile -Force
        }
        Write-Success "Applied settings"
    }

    # Install plugins from source device
    $pluginsFile = Join-Path $sourceDir "installed_plugins.json"
    if (Test-Path $pluginsFile) {
        Write-Info "Installing plugins from $Device..."
        try {
            $pluginsData = Get-Content $pluginsFile -Raw | ConvertFrom-Json
            if ($pluginsData.plugins) {
                $pluginsData.plugins.PSObject.Properties.Name | ForEach-Object {
                    $plugin = $_
                    Write-Info "  Installing $plugin..."
                    try {
                        claude plugin install $plugin 2>&1 | Out-Null
                        Write-Success "  Installed $plugin"
                    } catch {
                        Write-Warn "  Failed to install $plugin (may already be installed)"
                    }
                }
            }
        } catch {
            Write-Warn "Could not parse installed_plugins.json"
        }
        Write-Success "Plugins synced"
    }

    Write-Success "Settings applied from $Device"
    Write-Info "Restart Claude Code to apply changes"
}

function Invoke-Settings {
    Sync-GlobalSettings
}

# Main
switch ($Command) {
    'push'     { Invoke-Push }
    'pull'     { Invoke-Pull }
    'status'   { Invoke-Status }
    'list'     { Invoke-List }
    'apply'    { Invoke-Apply -Device $SourceDevice }
    'settings' { Invoke-Settings }
    default    {
        Write-Host "Usage: .\claude-sync.ps1 [push|pull|status|list|apply|settings]"
        Write-Host ""
        Write-Host "Commands:"
        Write-Host "  push        Export local sessions to sync directory"
        Write-Host "  pull        Check for sessions from other devices"
        Write-Host "  status      Show sync status"
        Write-Host "  list        List all synced sessions"
        Write-Host "  apply       Apply settings from another device"
        Write-Host "  settings    Sync only global settings (no sessions)"
    }
}
