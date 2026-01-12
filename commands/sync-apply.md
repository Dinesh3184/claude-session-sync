---
description: Apply settings and plugins from another synced device
argument-hint: [device-name]
allowed-tools: [Bash, Read, Write, Glob]
---

# Session Sync Apply

Apply settings (permissions, model, plugins) from another device to this machine.

## Arguments

$ARGUMENTS

If no device name is provided, list available devices.

## Instructions

1. Determine the sync directory path based on OS:
   - **macOS**: `~/Library/Mobile Documents/com~apple~CloudDocs/ClaudeSessions`
   - **Windows**: `$env:USERPROFILE\iCloudDrive\ClaudeSessions`

2. If no device name provided, list available configs:
   ```bash
   ls "$SYNC_DIR/global/"
   ```

3. If device name provided, run the apply command:
   ```bash
   # macOS/Linux
   "${CLAUDE_PLUGIN_ROOT}/scripts/claude-sync.sh" apply "DEVICE_NAME"
   ```

   ```powershell
   # Windows
   & "${env:CLAUDE_PLUGIN_ROOT}\scripts\claude-sync.ps1" apply "DEVICE_NAME"
   ```

4. Report what was applied:
   - Settings copied (model, permissions)
   - Plugins installed
   - Any errors encountered

5. Remind the user to restart Claude Code to apply changes.

## What Gets Applied

- **Portable settings** - Permissions, model preference, enabled plugins
- **Plugins** - Automatically installed from the source device's list
- **Local hooks are preserved** - Your device-specific hooks won't be overwritten
