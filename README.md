# File Sync Homelab

A real-time file synchronization application built with Wails (Go + JavaScript) that watches a local folder and automatically syncs changes to a remote homelab server via rsync over SSH.

## Features

- **Real-time File Watching**: Monitors local folder for creates, modifications, deletions, and renames
- **Automatic Sync**: Uses rsync with `--delete` flag to mirror local changes to remote server
- **SSH Connection**: Connects to your homelab via SSH for secure file transfer
- **Ignore List**: Exclude specific files or patterns from syncing (supports wildcards)
- **Live Logs**: View real-time file changes and sync status
- **Persistent Settings**: Configuration saved to `~/.file-sync-homelab-config.json`
- **Connection Validation**: Tests SSH connection and verifies remote path exists before saving
- **Error Resilience**: Uses `--ignore-errors` to continue syncing even if some remote files are corrupted

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

Click **Save Settings** to validate the connection and save your configuration.

### 2. Start Watching

Navigate to the **Logs** tab and click **Start Watching** to begin monitoring your local folder. All file changes will be automatically synced to your homelab in real-time.

### 3. Monitor Sync Status

- **Logs Tab**: View real-time file changes and sync operations
- **Sync Status Tab**: See overall sync health and any failed operations

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
  ]
}
```

## How It Works

1. **File Watcher**: Uses `fsnotify` to monitor local folder recursively (including all subdirectories)
2. **Event Detection**: Detects CREATE, WRITE, REMOVE, and RENAME events (CHMOD events are ignored)
3. **Rsync Sync**: On any change, runs: `rsync -avz --delete --ignore-errors --exclude <patterns> <local>/ <remote>:<path>/`
4. **Directory Mirroring**: The `--delete` flag ensures remote directory exactly mirrors local (including deletions)

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
- "Start Watching" is enabled in the Logs tab
- The file isn't in your Ignore List
- Logs tab for any error messages

## Contributing

Pull requests are welcome! Please ensure your code follows the existing style and includes appropriate tests.

## License

MIT License
