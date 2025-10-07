#!/bin/bash

set -e

APP_NAME="RabbitSync"
APP_NAME_LOWER="rabbitsync"
INSTALL_DIR="/opt/$APP_NAME_LOWER"
DESKTOP_FILE="/usr/share/applications/$APP_NAME_LOWER.desktop"
ICON_DIR="/usr/share/icons/hicolor"
LOGO_PNG_PATH="../frontend/src/assets/images/RabbitSyncLogo.png"
LOGO_ICO_PATH="../frontend/src/assets/images/RabbitSyncLogo.ico"

echo "🐰 Installing $APP_NAME for Linux..."

if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js first."
    echo "Install with: sudo apt-get install nodejs npm (Debian/Ubuntu)"
    echo "         or: sudo yum install nodejs npm (RHEL/CentOS)"
    echo "         or: sudo pacman -S nodejs npm (Arch)"
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed. Please install npm first."
    exit 1
fi

echo "📦 Installing dependencies..."
cd ..
npm install

echo "🔨 Building application..."
npm run build 2>/dev/null || npm run build:frontend

echo "📁 Creating installation directory..."
sudo rm -rf "$INSTALL_DIR"
sudo mkdir -p "$INSTALL_DIR"

echo "📋 Copying application files..."
if [ -d "backend" ]; then
    sudo cp -r backend "$INSTALL_DIR/"
fi
if [ -d "dist" ]; then
    sudo cp -r dist "$INSTALL_DIR/"
fi
if [ -d "frontend/dist" ]; then
    sudo mkdir -p "$INSTALL_DIR/frontend"
    sudo cp -r frontend/dist "$INSTALL_DIR/frontend/"
fi
if [ -f "package.json" ]; then
    sudo cp package.json "$INSTALL_DIR/"
fi
if [ -d "node_modules" ]; then
    echo "📦 Copying node_modules (this may take a while)..."
    sudo cp -r node_modules "$INSTALL_DIR/"
fi

if [ -f "$LOGO_PNG_PATH" ]; then
    echo "🖼️ Installing application icons..."
    
    for size in 16 32 48 64 128 256 512; do
        ICON_PATH="$ICON_DIR/${size}x${size}/apps"
        sudo mkdir -p "$ICON_PATH"
        
        if command -v convert &> /dev/null; then
            sudo convert "$LOGO_PNG_PATH" -resize ${size}x${size} "$ICON_PATH/$APP_NAME_LOWER.png" 2>/dev/null || {
                echo "⚠️ Failed to create ${size}x${size} icon"
            }
        fi
    done
    
    sudo cp "$LOGO_PNG_PATH" "$INSTALL_DIR/$APP_NAME.png"
    
    if [ -f "$LOGO_ICO_PATH" ]; then
        sudo cp "$LOGO_ICO_PATH" "$INSTALL_DIR/$APP_NAME.ico"
    fi
else
    echo "⚠️ Logo not found"
fi

echo "📝 Creating startup script..."
sudo tee "$INSTALL_DIR/$APP_NAME_LOWER" > /dev/null << 'EOF'
#!/bin/bash

cd "$(dirname "$0")"

if [ -f "backend/server.js" ]; then
    exec node backend/server.js "$@"
elif [ -f "dist/server.js" ]; then
    exec node dist/server.js "$@"
elif [ -f "server.js" ]; then
    exec node server.js "$@"
else
    zenity --error --text="Could not find server files.\nPlease rebuild the application." 2>/dev/null || \
    kdialog --error "Could not find server files.\nPlease rebuild the application." 2>/dev/null || \
    notify-send -u critical "$APP_NAME Error" "Could not find server files"
    exit 1
fi
EOF

sudo chmod +x "$INSTALL_DIR/$APP_NAME_LOWER"

echo "🖥️ Creating desktop entry..."
sudo tee "$DESKTOP_FILE" > /dev/null << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$APP_NAME
Comment=File Sync Homelab Application
Icon=$APP_NAME_LOWER
Exec=$INSTALL_DIR/$APP_NAME_LOWER
Terminal=false
Categories=Network;Utility;
StartupNotify=true
EOF

echo "🔗 Creating command-line shortcut..."
sudo ln -sf "$INSTALL_DIR/$APP_NAME_LOWER" "/usr/local/bin/$APP_NAME_LOWER"

echo "🔄 Updating desktop database..."
if command -v update-desktop-database &> /dev/null; then
    sudo update-desktop-database 2>/dev/null || true
fi

if command -v gtk-update-icon-cache &> /dev/null; then
    sudo gtk-update-icon-cache "$ICON_DIR" 2>/dev/null || true
fi

echo "🎨 Creating systemd service (optional)..."
sudo tee "/etc/systemd/system/$APP_NAME_LOWER.service" > /dev/null << EOF
[Unit]
Description=$APP_NAME File Sync Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/$APP_NAME_LOWER
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo ""
echo "✅ $APP_NAME has been installed to $INSTALL_DIR"
echo ""
echo "🎉 You can launch $APP_NAME by:"
echo "   - Clicking the application icon in your desktop menu"
echo "   - Running: $APP_NAME_LOWER"
echo "   - Starting as service: sudo systemctl enable --now $APP_NAME_LOWER"
echo ""
echo "To uninstall:"
echo "   sudo rm -rf $INSTALL_DIR"
echo "   sudo rm $DESKTOP_FILE"
echo "   sudo rm /usr/local/bin/$APP_NAME_LOWER"
echo "   sudo rm /etc/systemd/system/$APP_NAME_LOWER.service"
echo "   sudo rm -rf $ICON_DIR/*/apps/$APP_NAME_LOWER.png"