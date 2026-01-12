# Claude Session Sync

A Claude Code plugin for cross-device synchronization of sessions and settings via iCloud Drive.

## Features

- **Session sync** - Export session metadata and previews to markdown
- **Settings sync** - Sync `~/.claude/settings.json` across devices (permissions, model, plugins)
- **Plugin sync** - Automatically install the same plugins on all devices
- **Auto-sync** - Sessions sync automatically when they end (via SessionEnd hook)
- **Cross-platform** - Works on macOS and Windows

## Installation

```bash
claude plugin install github:rodchristiansen/claude-session-sync
```

## Quick Start

### 1. Initial Setup

Run the setup command to create the sync directory and configure auto-sync:

```
/sync-setup
```

This will:
- Create the ClaudeSessions directory in your iCloud Drive
- Set up the SessionEnd hook for automatic syncing
- Run an initial sync of your settings

### 2. Sync to Another Device

On your second device:

1. Install the plugin:
   ```bash
   claude plugin install github:rodchristiansen/claude-session-sync
   ```

2. Wait for iCloud to sync the ClaudeSessions folder

3. Apply settings from your main device:
   ```
   /sync-apply "Your Main Device Name"
   ```

## Commands

| Command | Description |
|---------|-------------|
| `/sync-setup` | Initial setup on this device |
| `/sync-push` | Manually sync sessions and settings to iCloud |
| `/sync-pull` | Check what's available from other devices |
| `/sync-apply [device]` | Apply settings and plugins from another device |
| `/sync-status` | Show sync status and configuration |

## What Gets Synced

### Sessions
- Session ID and metadata
- Project path
- Date and message count
- First message preview
- Source file location

Sessions are exported as markdown files, organized by project path.

### Settings
- **Full settings** (`settings.json`) - Complete config including hooks
- **Portable settings** (`settings-portable.json`) - Settings without device-specific hooks
- **Installed plugins** (`installed_plugins.json`) - List for reinstallation

### What's Preserved
- Local hooks are preserved when applying settings from another device
- Device-specific paths are not overwritten

## Directory Structure

After setup, your iCloud Drive will contain:

```
ClaudeSessions/
├── sessions/
│   └── {project-path}/
│       └── {session-id}.md
├── global/
│   └── {device-name}/
│       ├── settings.json
│       ├── settings-portable.json
│       └── installed_plugins.json
├── devices/
│   └── {device}.json
├── scripts/
│   ├── claude-sync.sh
│   └── claude-sync.ps1
└── index.md
```

## Platform Paths

| Platform | iCloud Path | Claude Config |
|----------|-------------|---------------|
| macOS | `~/Library/Mobile Documents/com~apple~CloudDocs/ClaudeSessions` | `~/.claude/` |
| Windows | `%USERPROFILE%\iCloudDrive\ClaudeSessions` | `%USERPROFILE%\.claude\` |

## Requirements

- **iCloud Drive** enabled and syncing
- **macOS** or **Windows** with iCloud for Windows
- **jq** (for macOS hook script): `brew install jq`

## Manual Sync (without plugin)

If you prefer to use the scripts directly:

### macOS/Linux
```bash
SYNC="$HOME/Library/Mobile Documents/com~apple~CloudDocs/ClaudeSessions/scripts/claude-sync.sh"

$SYNC push      # Sync sessions and settings
$SYNC pull      # Check other devices
$SYNC status    # Show status
$SYNC apply     # Apply settings from another device
```

### Windows PowerShell
```powershell
cd $env:USERPROFILE\iCloudDrive\ClaudeSessions\scripts

.\claude-sync.ps1 push
.\claude-sync.ps1 pull
.\claude-sync.ps1 status
.\claude-sync.ps1 apply "Device Name"
```

## Troubleshooting

### iCloud not syncing
- Ensure iCloud Drive is enabled in System Settings (macOS) or iCloud control panel (Windows)
- Check available storage in iCloud
- On macOS, run `brctl log --wait` to monitor iCloud activity

### Settings not applying
- Restart Claude Code after applying settings
- Verify plugins installed: `claude plugin list`

### Hook not running
- Check the log: `cat ~/.claude/session-sync.log`
- Ensure jq is installed (macOS): `brew install jq`
- Verify hook is executable: `chmod +x ~/.claude/hooks/session-end-sync.sh`

### Sync directory not found
- Run `/sync-setup` to create it
- Verify iCloud Drive path exists on your system

## Contributing

Contributions welcome! Please open an issue or PR on GitHub.

## License

MIT
