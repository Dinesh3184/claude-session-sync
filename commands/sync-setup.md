---
description: Initial setup for session sync on this device
allowed-tools: [Bash, Read, Write, Glob]
---

# Session Sync Setup

Set up session sync on this device, creating the necessary directories and configuring the auto-sync hook.

## Instructions

### 1. Determine paths based on OS

**macOS:**
- Sync directory: `~/Library/Mobile Documents/com~apple~CloudDocs/ClaudeSessions`
- Claude config: `~/.claude/`

**Windows:**
- Sync directory: `$env:USERPROFILE\iCloudDrive\ClaudeSessions`
- Claude config: `$env:USERPROFILE\.claude\`

### 2. Check iCloud Drive

Verify iCloud Drive is available:
- **macOS**: Check if `~/Library/Mobile Documents/com~apple~CloudDocs/` exists
- **Windows**: Check if `$env:USERPROFILE\iCloudDrive\` exists

If not available, inform the user they need to enable iCloud Drive first.

### 3. Create sync directory structure

```bash
mkdir -p "$SYNC_DIR"/{sessions,global,devices,scripts}
```

### 4. Copy sync scripts to the sync directory

Copy the scripts from the plugin to the sync directory so they're available on all devices:
```bash
cp "${CLAUDE_PLUGIN_ROOT}/scripts/claude-sync.sh" "$SYNC_DIR/scripts/"
cp "${CLAUDE_PLUGIN_ROOT}/scripts/claude-sync.ps1" "$SYNC_DIR/scripts/"
chmod +x "$SYNC_DIR/scripts/claude-sync.sh"
```

### 5. Set up SessionEnd hook (macOS only for now)

Create the hooks directory and hook script:
```bash
mkdir -p ~/.claude/hooks
```

Create `~/.claude/hooks/session-end-sync.sh`:
```bash
#!/bin/bash
SYNC_SCRIPT="$HOME/Library/Mobile Documents/com~apple~CloudDocs/ClaudeSessions/scripts/claude-sync.sh"
LOG_FILE="$HOME/.claude/sync.log"

input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // "unknown"' 2>/dev/null)

echo "$(date '+%Y-%m-%d %H:%M:%S') - Session $session_id ended" >> "$LOG_FILE"

if [[ -x "$SYNC_SCRIPT" ]]; then
    "$SYNC_SCRIPT" push >> "$LOG_FILE" 2>&1 &
fi

exit 0
```

Make it executable:
```bash
chmod +x ~/.claude/hooks/session-end-sync.sh
```

### 6. Add SessionEnd hook to settings.json

Read the current `~/.claude/settings.json` and add the SessionEnd hook if not present:
```json
{
  "hooks": {
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/session-end-sync.sh",
            "timeout": 30000
          }
        ]
      }
    ]
  }
}
```

### 7. Initialize git repo (optional but recommended)

```bash
cd "$SYNC_DIR"
git init
echo "*.jsonl" >> .gitignore
git add -A
git commit -m "Initial session sync setup"
```

### 8. Run initial sync

```bash
"$SYNC_DIR/scripts/claude-sync.sh" push
```

### 9. Report success

Tell the user:
- Setup complete
- How to sync manually: `/sync-push`, `/sync-pull`, `/sync-status`
- Sessions will auto-sync when they end (on macOS)
- To set up another device, enable iCloud Drive there and run `/sync-apply "THIS_DEVICE_NAME"`
