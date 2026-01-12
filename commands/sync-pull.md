---
description: Check for sessions available from other devices
allowed-tools: [Bash, Read, Glob, Grep]
---

# Session Sync Pull

Check what sessions and settings are available from other synced devices.

## Instructions

1. Determine the sync directory path based on OS:
   - **macOS**: `~/Library/Mobile Documents/com~apple~CloudDocs/ClaudeSessions`
   - **Windows**: `$env:USERPROFILE\iCloudDrive\ClaudeSessions`

2. Run the sync script:
   ```bash
   # macOS/Linux
   "${CLAUDE_PLUGIN_ROOT}/scripts/claude-sync.sh" pull
   ```

   ```powershell
   # Windows
   & "${env:CLAUDE_PLUGIN_ROOT}\scripts\claude-sync.ps1" pull
   ```

3. Report to the user:
   - Sessions from other devices
   - Recent activity from each device
   - Any settings available to apply

## Note

This command shows what's available. To apply settings from another device, use `/sync-apply`.
