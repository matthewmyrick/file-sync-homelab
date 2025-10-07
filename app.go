package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"github.com/fsnotify/fsnotify"
	"github.com/wailsapp/wails/v2/pkg/runtime"
)

// Config represents the app configuration
type Config struct {
	LocalFolder   string   `json:"localFolder"`
	SSHConnection string   `json:"sshConnection"`
	RemotePath    string   `json:"remotePath"`
	IgnoreList    []string `json:"ignoreList"`
}

// App struct
type App struct {
	ctx           context.Context
	watcher       *fsnotify.Watcher
	localFolder   string
	sshConnection string
	remotePath    string
	ignoreList    []string
}

// NewApp creates a new App application struct
func NewApp() *App {
	return &App{}
}

// startup is called when the app starts. The context is saved
// so we can call the runtime methods
func (a *App) startup(ctx context.Context) {
	a.ctx = ctx
}

// SelectFolder opens a folder selection dialog and returns the selected path
func (a *App) SelectFolder() (string, error) {
	folder, err := runtime.OpenDirectoryDialog(a.ctx, runtime.OpenDialogOptions{
		Title: "Select folder to watch",
	})
	if err != nil {
		return "", err
	}
	return folder, nil
}

// getConfigPath returns the path to the config file
func getConfigPath() (string, error) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return "", fmt.Errorf("failed to get home directory: %w", err)
	}
	return filepath.Join(homeDir, ".file-sync-homelab-config.json"), nil
}

// TestConnection tests the SSH connection and verifies the remote path exists
func (a *App) TestConnection(sshConnection, remotePath string) error {
	if sshConnection == "" {
		return fmt.Errorf("connection string is empty")
	}
	if remotePath == "" {
		return fmt.Errorf("remote path is empty")
	}

	// Test SSH connection and check if remote path exists
	// ssh <connection> "test -d <remotePath> && echo 'exists' || echo 'not found'"
	cmd := exec.Command("ssh", sshConnection, fmt.Sprintf("test -d %s && echo 'exists' || echo 'not found'", remotePath))
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("SSH connection failed: %w - %s", err, string(output))
	}

	result := string(output)
	if result != "exists\n" {
		return fmt.Errorf("remote path does not exist: %s", remotePath)
	}

	return nil
}

// SaveSettings saves the sync settings to memory and to config file
func (a *App) SaveSettings(localFolder, sshConnection, remotePath string, ignoreList []string) error {
	a.localFolder = localFolder
	a.sshConnection = sshConnection
	a.remotePath = remotePath
	a.ignoreList = ignoreList

	// Save to config file
	config := Config{
		LocalFolder:   localFolder,
		SSHConnection: sshConnection,
		RemotePath:    remotePath,
		IgnoreList:    ignoreList,
	}

	configPath, err := getConfigPath()
	if err != nil {
		return err
	}

	data, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal config: %w", err)
	}

	err = os.WriteFile(configPath, data, 0600)
	if err != nil {
		return fmt.Errorf("failed to write config file: %w", err)
	}

	log.Printf("Settings saved to %s", configPath)
	return nil
}

// LoadSettings loads the settings from the config file
func (a *App) LoadSettings() (*Config, error) {
	configPath, err := getConfigPath()
	if err != nil {
		return nil, err
	}

	// Check if config file exists
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		return &Config{}, nil // Return empty config if file doesn't exist
	}

	data, err := os.ReadFile(configPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read config file: %w", err)
	}

	var config Config
	err = json.Unmarshal(data, &config)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal config: %w", err)
	}

	// Load into app state
	a.localFolder = config.LocalFolder
	a.sshConnection = config.SSHConnection
	a.remotePath = config.RemotePath
	a.ignoreList = config.IgnoreList

	log.Printf("Settings loaded from %s", configPath)
	return &config, nil
}

// SyncFile syncs a specific file to the remote server using rsync over SSH
func (a *App) SyncFile(filePath string) error {
	if a.sshConnection == "" || a.remotePath == "" || a.localFolder == "" {
		return fmt.Errorf("sync settings not configured")
	}

	// Get relative path from local folder
	relPath, err := filepath.Rel(a.localFolder, filePath)
	if err != nil {
		return fmt.Errorf("failed to get relative path: %w", err)
	}

	// Build rsync command
	// rsync -avz --relative <local_file> <ssh_connection>:<remote_path>/
	cmd := exec.Command("rsync", "-avz", "--relative", relPath, fmt.Sprintf("%s:%s/", a.sshConnection, a.remotePath))
	cmd.Dir = a.localFolder

	// Run rsync
	output, err := cmd.CombinedOutput()
	if err != nil {
		log.Printf("rsync error: %s, output: %s", err, string(output))
		return fmt.Errorf("rsync failed: %w - %s", err, string(output))
	}

	log.Printf("Synced: %s", relPath)
	return nil
}

// SyncEntireFolder syncs the entire local folder to remote using rsync with --delete
// This ensures the remote matches local exactly (including deletions)
func (a *App) SyncEntireFolder() error {
	if a.sshConnection == "" || a.remotePath == "" || a.localFolder == "" {
		return fmt.Errorf("sync settings not configured")
	}

	// Build rsync command with exclude patterns
	args := []string{"-avz", "--delete", "--ignore-errors"}

	// Add exclude patterns from ignore list
	for _, pattern := range a.ignoreList {
		if pattern != "" {
			args = append(args, "--exclude", pattern)
		}
	}

	// Add source and destination
	args = append(args, a.localFolder+"/", fmt.Sprintf("%s:%s/", a.sshConnection, a.remotePath))

	cmd := exec.Command("rsync", args...)

	output, err := cmd.CombinedOutput()
	if err != nil {
		log.Printf("rsync --delete error: %s, output: %s", err, string(output))
		return fmt.Errorf("rsync failed: %w - %s", err, string(output))
	}

	log.Printf("Full sync completed with deletions")
	return nil
}

// StartWatching starts watching the specified folder for file changes
func (a *App) StartWatching(folderPath string) error {
	a.localFolder = folderPath
	// Stop existing watcher if any
	if a.watcher != nil {
		a.watcher.Close()
	}

	// Create new watcher
	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		return fmt.Errorf("failed to create watcher: %w", err)
	}
	a.watcher = watcher

	// Start watching in a goroutine
	go func() {
		for {
			select {
			case event, ok := <-watcher.Events:
				if !ok {
					return
				}

				// Get relative path for display
				relPath, err := filepath.Rel(folderPath, event.Name)
				if err != nil {
					relPath = filepath.Base(event.Name)
				}

				// Format the log message
				logMsg := fmt.Sprintf("[%s] %s - %s",
					time.Now().Format("15:04:05"),
					event.Op.String(),
					relPath)

				// Emit event to frontend
				runtime.EventsEmit(a.ctx, "fileChange", map[string]interface{}{
					"message":   logMsg,
					"operation": event.Op.String(),
					"path":      event.Name,
					"timestamp": time.Now().Unix(),
				})

				// If a directory is created, add it to the watcher
				if event.Op&fsnotify.Create == fsnotify.Create {
					info, err := os.Stat(event.Name)
					if err == nil && info.IsDir() {
						addSubdirectories(watcher, event.Name)
					}
				}

				// Skip CHMOD events - permission changes don't need syncing
				if event.Op&fsnotify.Chmod == fsnotify.Chmod {
					continue
				}

				// For any file operation (except CHMOD), do a full sync with --delete
				// This ensures remote always mirrors local (including deletions)
				go func(path string, op fsnotify.Op) {
					err := a.SyncEntireFolder()
					if err != nil {
						log.Printf("Failed to sync folder after %s on %s: %v", op.String(), path, err)
						runtime.EventsEmit(a.ctx, "syncStatus", map[string]interface{}{
							"path":      path,
							"success":   false,
							"error":     err.Error(),
							"operation": op.String(),
							"timestamp": time.Now().Unix(),
						})
					} else {
						runtime.EventsEmit(a.ctx, "syncStatus", map[string]interface{}{
							"path":      path,
							"success":   true,
							"operation": op.String(),
							"timestamp": time.Now().Unix(),
						})
					}
				}(event.Name, event.Op)

			case err, ok := <-watcher.Errors:
				if !ok {
					return
				}
				log.Println("watcher error:", err)
				runtime.EventsEmit(a.ctx, "fileChange", map[string]interface{}{
					"message":   fmt.Sprintf("[ERROR] %s", err.Error()),
					"operation": "ERROR",
					"path":      "",
					"timestamp": time.Now().Unix(),
				})
			}
		}
	}()

	// Add folder and all subdirectories to watcher
	err = addSubdirectories(watcher, folderPath)
	if err != nil {
		return fmt.Errorf("failed to watch folder: %w", err)
	}

	return nil
}

// addSubdirectories recursively adds all subdirectories to the watcher
func addSubdirectories(watcher *fsnotify.Watcher, root string) error {
	return filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			err = watcher.Add(path)
			if err != nil {
				log.Printf("failed to watch directory %s: %v", path, err)
			}
		}
		return nil
	})
}

// StopWatching stops the current file watcher
func (a *App) StopWatching() {
	if a.watcher != nil {
		a.watcher.Close()
		a.watcher = nil
	}
}
