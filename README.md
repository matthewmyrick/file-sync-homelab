# File Sync Homelab

A bidirectional file synchronization application built with Wails (Go + JavaScript) that maintains real-time sync between a local folder and a remote homelab server via rsync over SSH. Features automatic conflict protection for files being edited in Neovim.

## Features

- **Bidirectional Sync**: 
  - **Push Sync**: Local changes automatically sync to remote server (local → remote)
  - **Pull Sync**: Periodic polling pulls remote changes to local folder (remote → local)
  - **Initial Sync**: Server overwrites local on startup (server is truth)
- **Real-time File Watching**: Monitors local folder for creates, modifications, deletions, and renames
- **Neovim Protection**: Automatically detects and protects files being edited in Neovim from being overwritten during pull sync
- **SSH Connection**: Connects to your homelab via SSH for secure file transfer
- **Ignore List**: Exclude specific files or patterns from syncing (supports wildcards)
- **Live Logs**: View real-time file changes and sync status across three tabs (Sync Status, Logs, Settings)
- **Persistent Settings**: Configuration saved to `~/.file-sync-homelab-config.json`
- **Connection Validation**: Tests SSH connection and verifies remote path exists before saving
- **Error Resilience**: Uses `--ignore-errors` to continue syncing even if some remote files are corrupted
- **Configurable Pull Interval**: Set how often to check for remote changes (default: 60 seconds)
- **Log Retention**: Configurable log retention time with automatic pruning

## Prerequisites

- Go 1.23 or higher
- Node.js (for frontend dependencies)
- Wails CLI: `go install github.com/wailsapp/wails/v2/cmd/wails@latest`
- `rsync` installed on both local and remote machines
- SSH access to your homelab server

## Installation

1. Clone the repository:
```bash
git clone https://github.com/matthewmyrick/file-sync-homelab.git
cd file-sync-homelab
```

2. Install frontend dependencies:
```bash
cd frontend
npm install
cd ..
```

3. Run in development mode:
```bash
wails dev
```

## Usage

### 1. Configure Settings

Navigate to the **Settings** tab and configure:

- **Local Watch Folder**: Select the folder you want to sync
- **Remote Connection**: SSH connection string (e.g., `user@192.168.1.100`)
- **Remote Sync Path**: Destination path on your homelab (e.g., `/home/user/sync`)
- **Ignore List** (optional): Add files or patterns to exclude (one per line):
  ```
  .DS_Store
  *.tmp
  node_modules
  ```
- **Log Retention Time**: How long to keep logs before pruning (in minutes, default: 15)
- **Pull Sync Interval**: How often to check for remote changes (in seconds, default: 60)

Click **Save Settings** to validate the connection and save your configuration.

### 2. Automatic Sync Operation

The application automatically starts watching when valid settings are detected:

1. **Initial Sync**: On startup, remote files overwrite local files (server is truth)
2. **Push Sync**: Local file changes are immediately synced to remote server
3. **Pull Sync**: Periodically checks for remote changes and syncs them locally
4. **Neovim Protection**: Files being edited in Neovim are automatically protected from overwrite

### 3. Monitor Sync Status

- **Sync Status Tab**: Overview of sync operations with success/failure counts
- **Logs Tab**: Real-time file changes and detailed sync operations
- **Settings Tab**: Configure all sync parameters and connection settings

## Configuration File

Settings are saved to `~/.file-sync-homelab-config.json`:

```json
{
  "localFolder": "/path/to/local/folder",
  "sshConnection": "user@hostname",
  "remotePath": "/path/to/remote/folder",
  "ignoreList": [
    ".DS_Store",
    "*.tmp"
  ],
  "logRetentionMinutes": 15,
  "pullSyncInterval": 60
}
```

## How It Works

### Push Sync (Local → Remote)
1. **File Watcher**: Uses `fsnotify` to monitor local folder recursively (including all subdirectories)
2. **Event Detection**: Detects CREATE, WRITE, REMOVE, and RENAME events (CHMOD events are ignored)
3. **Immediate Sync**: On any change, runs: `rsync -avz --delete --ignore-errors --exclude <patterns> <local>/ <remote>:<path>/`
4. **Directory Mirroring**: The `--delete` flag ensures remote directory exactly mirrors local (including deletions)

### Pull Sync (Remote → Local)
1. **Periodic Polling**: Checks for remote changes at configured intervals (default: 60 seconds)
2. **Neovim Detection**: Scans for Neovim swap files (.filename.swp, .swo, .swn, etc.) to identify files being edited
3. **Protected Sync**: Runs: `rsync -avz --delete --ignore-errors --exclude <patterns> --exclude <neovim-files> <remote>:<path>/ <local>/`
4. **Conflict Prevention**: Files being edited in Neovim are excluded from overwrite to prevent data loss

### Initial Sync
1. **Server Authority**: On application startup, remote server is considered the source of truth
2. **Local Overwrite**: Remote files overwrite local files during initial sync (remote → local)
3. **Neovim Protection**: Even during initial sync, files being edited in Neovim are protected

## Development

### Live Development

```bash
wails dev
```

This runs a Vite development server with hot reload at http://localhost:34115.

### Building

To build a production binary:

```bash
wails build
```

The compiled application will be in the `build/bin` directory.

## Tech Stack

- **Backend**: Go 1.23
  - Wails v2 (desktop framework)
  - fsnotify (file system notifications)
  - rsync (file synchronization)
- **Frontend**: Vanilla JavaScript
  - Vite (build tool)
  - Custom CSS

## Troubleshooting

### "rsync failed: exit status 23"

This usually means there's a corrupted or inaccessible file on the remote server. Add the problematic file to the **Ignore List** in Settings.

### "SSH connection failed"

Ensure:
- SSH is configured properly (try `ssh user@hostname` manually)
- SSH keys are set up for passwordless authentication
- The remote path exists and you have write permissions

### Changes not syncing

Check:
- The application auto-starts watching when valid settings are configured
- The file isn't in your Ignore List
- Logs tab for any error messages
- For remote changes: check the Pull Sync Interval setting

### Files being overwritten in Neovim

The application automatically detects Neovim swap files and protects them from being overwritten during pull sync. If you're still experiencing issues:
- Ensure Neovim is creating swap files (`:set swapfile` in Neovim)
- Check the Logs tab for "protected from overwrite" messages

## Contributing

Pull requests are welcome! Please ensure your code follows the existing style and includes appropriate tests.

## License

MIT License
