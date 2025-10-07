import './style.css';
import './app.css';

import logo from './assets/images/logo-universal.png';
import {SelectFolder, StartWatching, StopWatching, SaveSettings, LoadSettings, TestConnection} from '../wailsjs/go/main/App';
import {EventsOn} from '../wailsjs/runtime/runtime';

document.querySelector('#app').innerHTML = `
    <div class="app-container">
        <div class="sidebar">
            <div class="sidebar-header">
                <img id="logo" class="logo-small">
                <h2>File Watcher</h2>
            </div>
            <div class="tabs-vertical">
                <button class="tab-btn-vertical active" data-tab="settings">
                    <span class="tab-icon">⚙️</span>
                    <span class="tab-label">Settings</span>
                </button>
                <button class="tab-btn-vertical" data-tab="logs">
                    <span class="tab-icon">📋</span>
                    <span class="tab-label">Logs</span>
                </button>
                <button class="tab-btn-vertical" data-tab="sync">
                    <span class="tab-icon">🔄</span>
                    <span class="tab-label">Sync Status</span>
                </button>
            </div>
        </div>
        <div class="main-content-area">
            <!-- Settings Content -->
            <div id="settings-content" class="content-view active">
                <div class="content-header">
                    <h1>Settings</h1>
                </div>
                <div class="content-body">
                    <div class="setting-section">
                        <h3>Local Watch Folder</h3>
                        <p class="help-text">This folder path will be used by all features</p>
                        <div class="folder-selector">
                            <input type="text" id="folderInput" class="folder-input" placeholder="No folder selected" readonly />
                            <button class="btn btn-small" id="browseFolderBtn">Browse</button>
                        </div>
                    </div>

                    <div class="setting-section">
                        <h3>Remote Connection</h3>
                        <p class="help-text">Connection string to your homelab (e.g., user@hostname or user@ip)</p>
                        <input type="text" id="sshConnectionInput" class="text-input" placeholder="user@hostname" />
                    </div>

                    <div class="setting-section">
                        <h3>Remote Sync Path</h3>
                        <p class="help-text">Destination path on your homelab server</p>
                        <input type="text" id="remotePathInput" class="text-input" placeholder="/path/to/sync" />
                    </div>

                    <div class="setting-section">
                        <h3>Ignore List</h3>
                        <p class="help-text">Files or patterns to exclude from sync (one per line)</p>
                        <textarea id="ignoreListInput" class="text-area" placeholder="1 Year Standard Limited Warrant.pdf&#10;*.tmp&#10;.DS_Store" rows="5"></textarea>
                    </div>

                    <div class="setting-section">
                        <button class="btn btn-primary" id="saveSettingsBtn">Save Settings</button>
                    </div>
                </div>
            </div>

            <!-- Logs Content -->
            <div id="logs-content" class="content-view">
                <div class="content-header">
                    <h1>File Change Logs</h1>
                </div>
                <div class="control-panel">
                    <div class="control-item">
                        <label>Watching Folder:</label>
                        <div id="logsWatchFolder" class="folder-display-inline">Not set</div>
                    </div>
                    <div class="control-actions">
                        <button class="btn btn-primary" id="startWatchingBtn" disabled>Start Watching</button>
                        <button class="btn btn-danger" id="stopWatchingBtn" disabled>Stop Watching</button>
                        <div id="status" class="status-indicator-inline">Not watching</div>
                    </div>
                </div>
                <div class="logs-container">
                    <div id="logs" class="logs-content"></div>
                </div>
            </div>

            <!-- Sync Status Content -->
            <div id="sync-content" class="content-view">
                <div class="content-header">
                    <h1>Sync Status</h1>
                </div>
                <div class="control-panel">
                    <div class="control-item">
                        <label>Monitoring Folder:</label>
                        <div id="syncWatchFolder" class="folder-display-inline">Not set</div>
                    </div>
                    <div class="control-actions">
                        <div id="syncSummary" class="sync-summary">
                            <span class="sync-stat">No sync data</span>
                        </div>
                    </div>
                </div>
                <div class="sync-container">
                    <div id="syncList" class="sync-list">
                        <div class="empty-state">No sync activity yet</div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    <div id="toast" class="toast"></div>
`;

document.getElementById('logo').src = logo;

// DOM Elements
const tabBtns = document.querySelectorAll('.tab-btn-vertical');
const contentViews = document.querySelectorAll('.content-view');
const browseFolderBtn = document.getElementById('browseFolderBtn');
const startWatchingBtn = document.getElementById('startWatchingBtn');
const stopWatchingBtn = document.getElementById('stopWatchingBtn');
const saveSettingsBtn = document.getElementById('saveSettingsBtn');
const folderInput = document.getElementById('folderInput');
const sshConnectionInput = document.getElementById('sshConnectionInput');
const remotePathInput = document.getElementById('remotePathInput');
const ignoreListInput = document.getElementById('ignoreListInput');
const logsWatchFolder = document.getElementById('logsWatchFolder');
const syncWatchFolder = document.getElementById('syncWatchFolder');
const statusDiv = document.getElementById('status');
const logsDiv = document.getElementById('logs');

let globalFolder = '';
let sshConnection = '';
let remotePath = '';
let ignoreList = [];
let isWatching = false;

// Track original settings to detect changes
let originalSettings = {
    folder: '',
    connection: '',
    path: '',
    ignoreList: ''
};

// Check if settings have changed
function hasSettingsChanged() {
    return globalFolder !== originalSettings.folder ||
           sshConnectionInput.value.trim() !== originalSettings.connection ||
           remotePathInput.value.trim() !== originalSettings.path ||
           ignoreListInput.value.trim() !== originalSettings.ignoreList;
}

// Update save button state
function updateSaveButtonState() {
    const hasChanges = hasSettingsChanged();
    saveSettingsBtn.disabled = !hasChanges;
}

// Toast notification
function showToast(message, type = 'success') {
    const toast = document.getElementById('toast');
    toast.textContent = message;
    toast.className = `toast toast-${type} show`;

    setTimeout(() => {
        toast.className = 'toast';
    }, 3000);
}

// Load settings on startup
async function loadInitialSettings() {
    try {
        const config = await LoadSettings();
        if (config.localFolder) {
            globalFolder = config.localFolder;
            folderInput.value = config.localFolder;
            logsWatchFolder.textContent = config.localFolder;
            syncWatchFolder.textContent = config.localFolder;
        }
        if (config.sshConnection) {
            sshConnection = config.sshConnection;
            sshConnectionInput.value = config.sshConnection;
        }
        if (config.remotePath) {
            remotePath = config.remotePath;
            remotePathInput.value = config.remotePath;
        }
        if (config.ignoreList && config.ignoreList.length > 0) {
            ignoreList = config.ignoreList;
            ignoreListInput.value = config.ignoreList.join('\n');
        }

        // Enable start watching if all settings are present
        if (globalFolder && sshConnection && remotePath) {
            startWatchingBtn.disabled = false;
        }

        // Update original settings for change detection
        originalSettings = {
            folder: globalFolder,
            connection: sshConnection,
            path: remotePath,
            ignoreList: ignoreListInput.value
        };

        // Initial button state
        saveSettingsBtn.disabled = true;
    } catch (err) {
        console.error('Error loading settings:', err);
    }
}

// Load settings when app starts
loadInitialSettings();

// Listen for input changes to enable/disable save button
sshConnectionInput.addEventListener('input', updateSaveButtonState);
remotePathInput.addEventListener('input', updateSaveButtonState);
ignoreListInput.addEventListener('input', updateSaveButtonState);

// Tab switching
tabBtns.forEach(btn => {
    btn.addEventListener('click', () => {
        const tabName = btn.getAttribute('data-tab');

        // Update active tab button
        tabBtns.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');

        // Update active content view
        contentViews.forEach(view => view.classList.remove('active'));
        document.getElementById(`${tabName}-content`).classList.add('active');
    });
});

// Browse for folder in Settings tab
browseFolderBtn.addEventListener('click', async () => {
    try {
        const folder = await SelectFolder();
        if (!folder) return;

        globalFolder = folder;
        folderInput.value = folder;

        updateSaveButtonState();
        addLog(`Local folder selected: ${folder}`, 'info');
    } catch (err) {
        console.error('Error selecting folder:', err);
        addLog(`Error: ${err}`, 'error');
    }
});

// Save settings
saveSettingsBtn.addEventListener('click', async () => {
    const newConnection = sshConnectionInput.value.trim();
    const newRemotePath = remotePathInput.value.trim();
    const ignoreListText = ignoreListInput.value.trim();

    // Parse ignore list - split by newlines and filter empty lines
    const newIgnoreList = ignoreListText
        .split('\n')
        .map(line => line.trim())
        .filter(line => line.length > 0);

    // Validate all fields are filled
    if (!globalFolder || !newConnection || !newRemotePath) {
        showToast(`⚠ Please fill in all required fields`, 'warning');
        return;
    }

    try {
        // Disable button during validation
        saveSettingsBtn.disabled = true;
        saveSettingsBtn.textContent = 'Testing Connection...';

        // Test SSH connection and verify remote path exists
        await TestConnection(newConnection, newRemotePath);

        // Connection successful, save settings
        sshConnection = newConnection;
        remotePath = newRemotePath;
        ignoreList = newIgnoreList;

        await SaveSettings(globalFolder, sshConnection, remotePath, ignoreList);

        // Update other tabs with the settings
        logsWatchFolder.textContent = globalFolder;
        syncWatchFolder.textContent = globalFolder;

        // Update original settings
        originalSettings = {
            folder: globalFolder,
            connection: sshConnection,
            path: remotePath,
            ignoreList: ignoreListText
        };

        // Enable start watching
        startWatchingBtn.disabled = false;

        const ignoreMsg = ignoreList.length > 0 ? ` (${ignoreList.length} patterns ignored)` : '';
        showToast(`✓ Settings saved successfully to ~/.file-sync-homelab-config.json${ignoreMsg}`, 'success');
        addLog(`✓ Settings saved - Connected to ${sshConnection}:${remotePath}`, 'info');

        // Reset button text
        saveSettingsBtn.textContent = 'Save Settings';
    } catch (err) {
        console.error('Error saving settings:', err);
        showToast(`✗ Failed: ${err}`, 'error');
        addLog(`✗ Error: ${err}`, 'error');

        // Re-enable button to try again
        saveSettingsBtn.textContent = 'Save Settings';
        updateSaveButtonState();
    }
});

// Start watching in Logs tab
startWatchingBtn.addEventListener('click', async () => {
    if (!globalFolder) return;

    try {
        await StartWatching(globalFolder);
        isWatching = true;
        startWatchingBtn.disabled = true;
        stopWatchingBtn.disabled = false;
        statusDiv.textContent = `Watching: ${globalFolder}`;
        statusDiv.className = 'status-indicator-inline status-active';

        addLog(`Started watching: ${globalFolder}`, 'info');
    } catch (err) {
        console.error('Error starting watcher:', err);
        addLog(`Error: ${err}`, 'error');
    }
});

// Stop watching in Logs tab
stopWatchingBtn.addEventListener('click', async () => {
    try {
        await StopWatching();
        isWatching = false;
        startWatchingBtn.disabled = globalFolder ? false : true;
        stopWatchingBtn.disabled = true;
        statusDiv.textContent = 'Not watching';
        statusDiv.className = 'status-indicator-inline';

        addLog('Stopped watching', 'info');
    } catch (err) {
        console.error('Error stopping watcher:', err);
    }
});

// Listen for file change events from Go
EventsOn('fileChange', (data) => {
    const type = data.operation === 'ERROR' ? 'error' : 'log';
    addLog(data.message, type);
});

// Listen for sync status events from Go
EventsOn('syncStatus', (data) => {
    const relPath = data.path.replace(globalFolder, '').replace(/^\//, '');

    if (data.success) {
        addLog(`✓ Synced [${data.operation}]: ${relPath}`, 'info');
    } else {
        addLog(`✗ Sync failed [${data.operation}]: ${relPath} - ${data.error}`, 'error');
    }
});

// Add log entry to the logs pane
function addLog(message, type = 'log') {
    const logEntry = document.createElement('div');
    logEntry.className = `log-entry log-${type}`;
    logEntry.textContent = message;
    logsDiv.appendChild(logEntry);

    // Auto-scroll to bottom
    logsDiv.scrollTop = logsDiv.scrollHeight;
}
