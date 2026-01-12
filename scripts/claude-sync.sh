#!/bin/bash
# Claude Sessions Sync - macOS/Linux
# Syncs Claude Code sessions across devices via iCloud/Git

set -e

# Paths
CLAUDE_DIR="$HOME/.claude"
SYNC_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/ClaudeSessions"
DEVICE_NAME="${CLAUDE_DEVICE_NAME:-$(scutil --get ComputerName 2>/dev/null || hostname)}"
SESSIONS_DIR="$SYNC_DIR/sessions"
GLOBAL_DIR="$SYNC_DIR/global"
INDEX_FILE="$SYNC_DIR/index.md"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get project name from path
get_project_name() {
    local path="$1"
    echo "$path" | sed 's/-Users-[^-]*-//' | tr '-' '/' | sed 's|^/||'
}

# Export a single session to markdown
export_session() {
    local session_file="$1"
    local project_dir="$(dirname "$session_file")"
    local project_path="$(basename "$project_dir")"
    local session_id="$(basename "$session_file" .jsonl)"
    local project_name="$(get_project_name "$project_path")"

    # Skip agent sessions and empty files
    [[ "$session_id" == agent-* ]] && return
    [[ ! -s "$session_file" ]] && return

    # Create output directory
    local out_dir="$SESSIONS_DIR/$project_path"
    mkdir -p "$out_dir"

    # Extract session metadata
    local first_line=$(head -1 "$session_file" 2>/dev/null)
    local last_line=$(tail -1 "$session_file" 2>/dev/null)
    local line_count=$(wc -l < "$session_file" | tr -d ' ')
    local file_date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$session_file" 2>/dev/null || date -r "$session_file" "+%Y-%m-%d %H:%M")
    local file_size=$(du -h "$session_file" | cut -f1)

    # Try to extract first user message for summary
    local first_msg=$(grep -o '"content":"[^"]*"' "$session_file" 2>/dev/null | head -1 | cut -d'"' -f4 | head -c 100)
    [[ -z "$first_msg" ]] && first_msg="(no preview available)"

    # Generate markdown summary
    local out_file="$out_dir/${session_id}.md"
    cat > "$out_file" << EOF
# Session: $session_id

## Metadata
- **Device:** $DEVICE_NAME
- **Project:** $project_name
- **Date:** $file_date
- **Size:** $file_size
- **Messages:** ~$line_count

## Preview
\`\`\`
${first_msg}...
\`\`\`

## Source
\`$session_file\`

---
*Exported $(date "+%Y-%m-%d %H:%M") from $DEVICE_NAME*
EOF

    echo "$out_file"
}

# Sync global settings
sync_global_settings() {
    log_info "Syncing global settings..."

    local device_dir="$GLOBAL_DIR/$DEVICE_NAME"
    mkdir -p "$device_dir"

    # Copy settings.json (remove hooks section to avoid device-specific paths)
    if [[ -f "$CLAUDE_DIR/settings.json" ]]; then
        # Copy full settings for reference
        cp "$CLAUDE_DIR/settings.json" "$device_dir/settings.json"

        # Create a portable version without device-specific hooks
        jq 'del(.hooks)' "$CLAUDE_DIR/settings.json" > "$device_dir/settings-portable.json" 2>/dev/null || \
            cp "$CLAUDE_DIR/settings.json" "$device_dir/settings-portable.json"
    fi

    # Copy installed plugins list
    if [[ -f "$CLAUDE_DIR/plugins/installed_plugins.json" ]]; then
        cp "$CLAUDE_DIR/plugins/installed_plugins.json" "$device_dir/installed_plugins.json"
    fi

    # Copy custom commands (if any exist at user level)
    if [[ -d "$CLAUDE_DIR/commands" ]]; then
        cp -r "$CLAUDE_DIR/commands" "$device_dir/" 2>/dev/null || true
    fi

    # Copy hooks (for reference)
    if [[ -d "$CLAUDE_DIR/hooks" ]]; then
        cp -r "$CLAUDE_DIR/hooks" "$device_dir/" 2>/dev/null || true
    fi

    # Create a summary of this device's config
    cat > "$device_dir/README.md" << EOF
# Claude Config: $DEVICE_NAME

**Last synced:** $(date "+%Y-%m-%d %H:%M")
**Platform:** $(uname -s)

## Enabled Plugins
\`\`\`json
$(jq '.enabledPlugins' "$CLAUDE_DIR/settings.json" 2>/dev/null || echo "{}")
\`\`\`

## Permissions
\`\`\`json
$(jq '.permissions' "$CLAUDE_DIR/settings.json" 2>/dev/null || echo "{}")
\`\`\`

## To apply this config on another device:
\`\`\`bash
# Copy portable settings
cp "$GLOBAL_DIR/$DEVICE_NAME/settings-portable.json" ~/.claude/settings.json

# Install same plugins
cat "$GLOBAL_DIR/$DEVICE_NAME/installed_plugins.json" | jq -r '.plugins | keys[]' | while read plugin; do
    claude plugin install "\$plugin"
done
\`\`\`
EOF

    log_success "Global settings synced"
}

# Push: Export all sessions to sync directory
cmd_push() {
    log_info "Exporting sessions from $DEVICE_NAME..."

    local count=0
    local projects_dir="$CLAUDE_DIR/projects"

    if [[ ! -d "$projects_dir" ]]; then
        log_error "No projects directory found at $projects_dir"
        exit 1
    fi

    # Export each session
    for project_dir in "$projects_dir"/*; do
        [[ -d "$project_dir" ]] || continue

        for session_file in "$project_dir"/*.jsonl; do
            [[ -f "$session_file" ]] || continue

            result=$(export_session "$session_file")
            if [[ -n "$result" ]]; then
                ((count++))
            fi
        done
    done

    log_success "Exported $count sessions"

    # Sync global settings
    sync_global_settings

    # Update index
    update_index

    # Git commit if in repo
    if [[ -d "$SYNC_DIR/.git" ]]; then
        cd "$SYNC_DIR"
        git add -A
        if ! git diff --cached --quiet; then
            git commit -m "Sync from $DEVICE_NAME - $(date '+%Y-%m-%d %H:%M')"
            log_success "Committed to git"
        else
            log_info "No changes to commit"
        fi
    fi
}

# Pull: List available sessions from other devices
cmd_pull() {
    log_info "Checking for sessions from other devices..."

    if [[ -d "$SYNC_DIR/.git" ]]; then
        cd "$SYNC_DIR"
        # Don't actually pull - iCloud handles sync
        # Just show what's available
    fi

    # List sessions not from this device
    local other_sessions=$(grep -r "Device:" "$SESSIONS_DIR" 2>/dev/null | grep -v "$DEVICE_NAME" | wc -l | tr -d ' ')
    log_info "Found $other_sessions sessions from other devices"

    # Show recent sessions from other devices
    echo ""
    echo "Recent sessions from other devices:"
    echo "------------------------------------"
    find "$SESSIONS_DIR" -name "*.md" -mtime -7 -exec grep -l "Device:" {} \; 2>/dev/null | while read f; do
        device=$(grep "Device:" "$f" | head -1 | sed 's/.*Device:\*\* //')
        if [[ "$device" != "$DEVICE_NAME" ]]; then
            project=$(grep "Project:" "$f" | head -1 | sed 's/.*Project:\*\* //')
            date=$(grep "Date:" "$f" | head -1 | sed 's/.*Date:\*\* //')
            echo "  [$device] $project - $date"
        fi
    done
}

# Status: Show sync status
cmd_status() {
    echo "Claude Sessions Sync Status"
    echo "============================"
    echo ""
    echo "Device:     $DEVICE_NAME"
    echo "Claude Dir: $CLAUDE_DIR"
    echo "Sync Dir:   $SYNC_DIR"
    echo ""

    # Count local sessions
    local local_sessions=$(find "$CLAUDE_DIR/projects" -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')
    echo "Local sessions: $local_sessions"

    # Count synced sessions
    local synced_sessions=$(find "$SESSIONS_DIR" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    echo "Synced sessions: $synced_sessions"

    # Git status
    if [[ -d "$SYNC_DIR/.git" ]]; then
        echo ""
        echo "Git status:"
        cd "$SYNC_DIR"
        git status -s
    fi
}

# Update master index
update_index() {
    log_info "Updating session index..."

    cat > "$INDEX_FILE" << EOF
# Claude Sessions Index

*Last updated: $(date "+%Y-%m-%d %H:%M") from $DEVICE_NAME*

## Sessions by Project

EOF

    # Group sessions by project
    for project_dir in "$SESSIONS_DIR"/*; do
        [[ -d "$project_dir" ]] || continue
        local project_name="$(basename "$project_dir")"
        local display_name="$(get_project_name "$project_name")"

        echo "### $display_name" >> "$INDEX_FILE"
        echo "" >> "$INDEX_FILE"

        for session_file in "$project_dir"/*.md; do
            [[ -f "$session_file" ]] || continue
            local session_name="$(basename "$session_file" .md)"
            local device=$(grep "Device:" "$session_file" 2>/dev/null | head -1 | sed 's/.*Device:\*\* //')
            local date=$(grep "Date:" "$session_file" 2>/dev/null | head -1 | sed 's/.*Date:\*\* //')
            echo "- [$session_name](sessions/$project_name/$session_name.md) - $device - $date" >> "$INDEX_FILE"
        done

        echo "" >> "$INDEX_FILE"
    done

    log_success "Index updated"
}

# List all sessions
cmd_list() {
    echo "All Claude Sessions"
    echo "==================="
    echo ""

    find "$SESSIONS_DIR" -name "*.md" -exec stat -f "%m %N" {} \; 2>/dev/null | \
        sort -rn | head -20 | while read ts file; do
        device=$(grep "Device:" "$file" 2>/dev/null | head -1 | sed 's/.*Device:\*\* //')
        project=$(grep "Project:" "$file" 2>/dev/null | head -1 | sed 's/.*Project:\*\* //')
        date=$(grep "Date:" "$file" 2>/dev/null | head -1 | sed 's/.*Date:\*\* //')
        echo "[$device] $project"
        echo "    $date"
        echo "    $(basename "$file")"
        echo ""
    done
}

# Apply settings from another device
cmd_apply() {
    local source_device="${2:-}"

    if [[ -z "$source_device" ]]; then
        echo "Available device configs:"
        ls -1 "$GLOBAL_DIR" 2>/dev/null | while read d; do
            [[ -d "$GLOBAL_DIR/$d" ]] && echo "  - $d"
        done
        echo ""
        echo "Usage: claude-sync apply <device-name>"
        return 1
    fi

    local source_dir="$GLOBAL_DIR/$source_device"
    if [[ ! -d "$source_dir" ]]; then
        log_error "No config found for device: $source_device"
        return 1
    fi

    log_info "Applying settings from $source_device..."

    # Backup current settings
    if [[ -f "$CLAUDE_DIR/settings.json" ]]; then
        cp "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR/settings.json.backup"
        log_info "Backed up current settings to settings.json.backup"
    fi

    # Apply portable settings (preserves local hooks)
    if [[ -f "$source_dir/settings-portable.json" ]]; then
        # Merge: keep local hooks, apply everything else from source
        if [[ -f "$CLAUDE_DIR/settings.json" ]]; then
            local_hooks=$(jq '.hooks // {}' "$CLAUDE_DIR/settings.json")
            jq --argjson hooks "$local_hooks" '. + {hooks: $hooks}' "$source_dir/settings-portable.json" > "$CLAUDE_DIR/settings.json.tmp"
            mv "$CLAUDE_DIR/settings.json.tmp" "$CLAUDE_DIR/settings.json"
        else
            cp "$source_dir/settings-portable.json" "$CLAUDE_DIR/settings.json"
        fi
        log_success "Applied settings"
    fi

    # Install plugins from source device
    if [[ -f "$source_dir/installed_plugins.json" ]]; then
        log_info "Installing plugins from $source_device..."
        jq -r '.plugins | keys[]' "$source_dir/installed_plugins.json" 2>/dev/null | while read plugin; do
            log_info "  Installing $plugin..."
            claude plugin install "$plugin" 2>/dev/null || log_warn "  Failed to install $plugin"
        done
        log_success "Plugins synced"
    fi

    log_success "Settings applied from $source_device"
    log_info "Restart Claude Code to apply changes"
}

# Main
case "${1:-status}" in
    push)   cmd_push ;;
    pull)   cmd_pull ;;
    status) cmd_status ;;
    list)   cmd_list ;;
    index)  update_index ;;
    apply)  cmd_apply "$@" ;;
    settings) sync_global_settings ;;
    *)
        echo "Usage: claude-sync [push|pull|status|list|apply|settings]"
        echo ""
        echo "Commands:"
        echo "  push        Export sessions and settings to sync directory"
        echo "  pull        Check for sessions from other devices"
        echo "  status      Show sync status"
        echo "  list        List all synced sessions"
        echo "  apply       Apply settings from another device"
        echo "  settings    Sync only global settings (no sessions)"
        exit 1
        ;;
esac
