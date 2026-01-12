#!/usr/bin/env python3
"""
Session End Hook - Auto-sync sessions to iCloud
Runs automatically when any Claude Code session ends
"""

import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Tuple

def get_sync_paths() -> Tuple[Path, Path]:
    """Get the sync script path based on OS"""
    home = Path.home()
    platform = sys.platform

    if platform == "darwin":
        # macOS
        sync_dir = home / "Library/Mobile Documents/com~apple~CloudDocs/ClaudeSessions"
        sync_script = sync_dir / "scripts/claude-sync.sh"
    elif platform == "win32":
        # Windows
        sync_dir = home / "iCloudDrive/ClaudeSessions"
        sync_script = sync_dir / "scripts/claude-sync.ps1"
    else:
        # Linux - use a generic path
        sync_dir = home / "ClaudeSessions"
        sync_script = sync_dir / "scripts/claude-sync.sh"

    return sync_dir, sync_script

def get_log_file():
    """Get the log file path"""
    claude_dir = Path.home() / ".claude"
    claude_dir.mkdir(exist_ok=True)
    return claude_dir / "session-sync.log"

def log(message: str):
    """Append to log file"""
    log_file = get_log_file()
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(log_file, "a") as f:
        f.write(f"{timestamp} - {message}\n")

def main():
    try:
        # Read session info from stdin
        input_data = json.load(sys.stdin)
        session_id = input_data.get("session_id", "unknown")
        reason = input_data.get("reason", "unknown")

        log(f"Session {session_id} ended ({reason})")

        sync_dir, sync_script = get_sync_paths()

        # Check if sync is set up
        if not sync_dir.exists():
            log(f"Sync directory not found: {sync_dir}")
            print(json.dumps({}))
            sys.exit(0)

        if not sync_script.exists():
            log(f"Sync script not found: {sync_script}")
            print(json.dumps({}))
            sys.exit(0)

        # Run sync in background
        platform = sys.platform
        if platform == "win32":
            # Windows PowerShell
            subprocess.Popen(
                ["powershell", "-ExecutionPolicy", "Bypass", "-File", str(sync_script), "push"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                creationflags=subprocess.CREATE_NO_WINDOW  # type: ignore[attr-defined]
            )
        else:
            # macOS/Linux bash
            subprocess.Popen(
                [str(sync_script), "push"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True
            )

        log("Sync triggered in background")

        # Return empty response (don't block)
        print(json.dumps({}))

    except Exception as e:
        # Log error but don't block
        try:
            log(f"Error: {e}")
        except:
            pass
        print(json.dumps({}))

    sys.exit(0)

if __name__ == "__main__":
    main()
