---
description: Show session sync status and configuration
allowed-tools: [Bash, Read, Glob]
---

# Session Sync Status

Show the current sync status, including local sessions, synced sessions, and configuration.

## Instructions

1. Determine the sync directory path based on OS:
   - **macOS**: `~/Library/Mobile Documents/com~apple~CloudDocs/ClaudeSessions`
   - **Windows**: `$env:USERPROFILE\iCloudDrive\ClaudeSessions`

2. Run the sync script:
   ```bash
   # macOS/Linux
   "${CLAUDE_PLUGIN_ROOT}/scripts/claude-sync.sh" status
   ```

   ```powershell
   # Windows
   & "${env:CLAUDE_PLUGIN_ROOT}\scripts\claude-sync.ps1" status
   ```

3. Also check and report:
   - Whether the SessionEnd hook is configured
   - Whether the sync directory exists and is accessible
   - Available device configurations in the `global/` directory
