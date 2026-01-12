# Claude Session Sync Plugin

This is a Claude Code plugin for cross-device session and settings synchronization via iCloud Drive.

## Plugin Structure

- `.claude-plugin/plugin.json` - Plugin manifest
- `commands/` - Slash commands (/sync-push, /sync-pull, etc.)
- `hooks/` - SessionEnd hook for auto-sync
- `scripts/` - Bash and PowerShell sync scripts

## Key Paths

- **macOS iCloud**: `~/Library/Mobile Documents/com~apple~CloudDocs/ClaudeSessions`
- **Windows iCloud**: `$USERPROFILE\iCloudDrive\ClaudeSessions`

## Commands

- `/sync-setup` - Initial setup
- `/sync-push` - Export sessions and settings
- `/sync-pull` - Check other devices
- `/sync-apply [device]` - Apply settings from another device
- `/sync-status` - Show sync status

## Development

The sync scripts (`scripts/claude-sync.sh` and `scripts/claude-sync.ps1`) do the heavy lifting. The commands are instructions for Claude to invoke these scripts appropriately.
