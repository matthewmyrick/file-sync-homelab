#!/bin/bash

set -e

APP_NAME="RabbitSync"
INSTALL_DIR="$HOME/AppData/Local/$APP_NAME"
DESKTOP_DIR="$HOME/Desktop"
START_MENU="$HOME/AppData/Roaming/Microsoft/Windows/Start Menu/Programs"
LOGO_PNG_PATH="../frontend/src/assets/images/RabbitSyncLogo.png"
LOGO_ICO_PATH="../frontend/src/assets/images/RabbitSyncLogo.ico"

echo "🐰 Installing $APP_NAME for Windows..."
echo "Note: This script is for Git Bash or WSL. For native Windows, use windows.ps1"

if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js first."
    echo "Download from: https://nodejs.org/"
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
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

echo "📋 Copying application files..."
if [ -d "backend" ]; then
    cp -r backend "$INSTALL_DIR/"
fi
if [ -d "dist" ]; then
    cp -r dist "$INSTALL_DIR/"
fi
if [ -d "frontend/dist" ]; then
    mkdir -p "$INSTALL_DIR/frontend"
    cp -r frontend/dist "$INSTALL_DIR/frontend/"
fi
if [ -f "package.json" ]; then
    cp package.json "$INSTALL_DIR/"
fi
if [ -d "node_modules" ]; then
    echo "📦 Copying node_modules (this may take a while)..."
    cp -r node_modules "$INSTALL_DIR/"
fi

if [ -f "$LOGO_ICO_PATH" ]; then
    echo "🖼️ Using pre-converted .ico file..."
    cp "$LOGO_ICO_PATH" "$INSTALL_DIR/$APP_NAME.ico"
elif [ -f "$LOGO_PNG_PATH" ]; then
    echo "🖼️ Copying PNG logo and attempting to convert to .ico..."
    cp "$LOGO_PNG_PATH" "$INSTALL_DIR/$APP_NAME.png"
    
    if command -v convert &> /dev/null; then
        echo "🎨 Creating .ico file..."
        convert "$LOGO_PNG_PATH" -resize 256x256 "$INSTALL_DIR/$APP_NAME.ico" 2>/dev/null || {
            echo "⚠️ Could not create .ico file, using PNG instead"
        }
    else
        echo "⚠️ ImageMagick not installed, using PNG format"
    fi
else
    echo "⚠️ Logo not found"
fi

cat > "$INSTALL_DIR/$APP_NAME.bat" << EOF
@echo off
title $APP_NAME
cd /d "%~dp0"

if exist "backend\\server.js" (
    node backend\\server.js
) else if exist "dist\\server.js" (
    node dist\\server.js
) else if exist "server.js" (
    node server.js
) else (
    echo Error: Could not find server files.
    echo Please rebuild the application.
    pause
    exit /b 1
)
EOF

cat > "$INSTALL_DIR/Start-$APP_NAME.vbs" << EOF
Set WshShell = CreateObject("WScript.Shell")
WshShell.CurrentDirectory = "$INSTALL_DIR"
WshShell.Run "cmd /c $APP_NAME.bat", 0, False
EOF

echo "🖥️ Creating desktop shortcut..."
cat > "$DESKTOP_DIR/$APP_NAME.lnk.txt" << EOF
[InternetShortcut]
URL=file:///$INSTALL_DIR/Start-$APP_NAME.vbs
IconIndex=0
IconFile=$INSTALL_DIR/$APP_NAME.ico
EOF

if command -v powershell &> /dev/null; then
    powershell -Command "
    \$WshShell = New-Object -ComObject WScript.Shell
    \$Shortcut = \$WshShell.CreateShortcut('$DESKTOP_DIR\\$APP_NAME.lnk')
    \$Shortcut.TargetPath = '$INSTALL_DIR\\Start-$APP_NAME.vbs'
    \$Shortcut.WorkingDirectory = '$INSTALL_DIR'
    \$Shortcut.IconLocation = '$INSTALL_DIR\\$APP_NAME.ico,0'
    \$Shortcut.Description = '$APP_NAME Application'
    \$Shortcut.Save()
    " 2>/dev/null || echo "⚠️ Could not create desktop shortcut"
fi

echo "📂 Creating Start Menu entry..."
mkdir -p "$START_MENU"
if command -v powershell &> /dev/null; then
    powershell -Command "
    \$WshShell = New-Object -ComObject WScript.Shell
    \$Shortcut = \$WshShell.CreateShortcut('$START_MENU\\$APP_NAME.lnk')
    \$Shortcut.TargetPath = '$INSTALL_DIR\\Start-$APP_NAME.vbs'
    \$Shortcut.WorkingDirectory = '$INSTALL_DIR'
    \$Shortcut.IconLocation = '$INSTALL_DIR\\$APP_NAME.ico,0'
    \$Shortcut.Description = '$APP_NAME Application'
    \$Shortcut.Save()
    " 2>/dev/null || echo "⚠️ Could not create Start Menu entry"
fi

echo "✅ $APP_NAME has been installed to $INSTALL_DIR"
echo "🎉 You can launch $APP_NAME from:"
echo "   - Desktop shortcut"
echo "   - Start Menu"
echo "   - Run: $INSTALL_DIR/$APP_NAME.bat"
echo ""
echo "To uninstall, delete the folder: $INSTALL_DIR"