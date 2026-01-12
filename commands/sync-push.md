---
description: Export sessions and settings to iCloud sync directory
allowed-tools: [Bash, Read, Write, Glob]
---

# Session Sync Push

Export Claude Code sessions and settings to the iCloud sync directory for cross-device access.

## What Gets Synced

1. **Session summaries** - Markdown exports with metadata and previews
2. **Global settings** - `~/.claude/settings.json` (permissions, model, plugins)
3. **Installed plugins list** - For reinstallation on other devices

## Instructions

1. Determine the sync directory path based on OS:
   - **macOS**: `~/Library/Mobile Documents/com~apple~CloudDocs/ClaudeSessions`
   - **Windows**: `$env:USERPROFILE\iCloudDrive\ClaudeSessions`

2. Run the sync script:
   ```bash
   # macOS/Linux
   "${CLAUDE_PLUGIN_ROOT}/scripts/claude-sync.sh" push
   ```

   ```powershell
   # Windows
   & "${env:CLAUDE_PLUGIN_ROOT}\scripts\claude-sync.ps1" push
   ```

3. Report the results to the user, including:
   - Number of sessions exported
   - Settings synced
   - Any git commit made (if the sync directory is a git repo)

## First-Time Setup

If the sync directory doesn't exist, inform the user they need to run `/sync-setup` first.
