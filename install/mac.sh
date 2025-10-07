#!/bin/bash

set -e

APP_NAME="RabbitSync"
APP_DIR="$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
INSTALL_DIR="/Applications"
LOGO_PNG_PATH="../frontend/src/assets/images/RabbitSyncLogo.png"
LOGO_ICNS_PATH="../frontend/src/assets/images/RabbitSyncLogo.icns"

echo "🐰 Installing $APP_NAME for macOS..."

if ! command -v go &> /dev/null; then
    echo "❌ Go is not installed. Please install Go first."
    echo "Visit: https://golang.org/dl/"
    exit 1
fi

if ! command -v wails &> /dev/null; then
    echo "📦 Installing Wails..."
    go install github.com/wailsapp/wails/v2/cmd/wails@latest
    export PATH=$PATH:$(go env GOPATH)/bin
fi

echo "📦 Installing frontend dependencies..."
cd ..
cd frontend && npm install && cd ..

echo "🔨 Building application..."
wails build -platform darwin/universal

echo "🚀 Installing to Applications folder..."

# Wails builds the app in the build/bin directory
if [ -d "build/bin/file-sync-homelab.app" ]; then
    APP_BUILT="build/bin/file-sync-homelab.app"
    echo "✅ Found Wails built app at $APP_BUILT"
    
    # Rename to RabbitSync.app for consistency
    if [ -d "$INSTALL_DIR/$APP_DIR" ]; then
        echo "⚠️ Existing installation found. Removing..."
        rm -rf "$INSTALL_DIR/$APP_DIR"
    fi
    
    cp -r "$APP_BUILT" "$INSTALL_DIR/$APP_DIR"
    
    # Update the icon if we have a custom one
    if [ -f "$LOGO_ICNS_PATH" ]; then
        echo "🖼️ Updating app icon..."
        cp "$LOGO_ICNS_PATH" "$INSTALL_DIR/$APP_DIR/Contents/Resources/iconfile.icns" 2>/dev/null || true
    fi
else
    echo "❌ Build failed or app not found in build/bin/"
    echo "The Wails build may have failed. Please check the build output above."
    exit 1
fi

echo "✅ $APP_NAME has been installed to $INSTALL_DIR"
echo "🎉 You can now launch $APP_NAME from your Applications folder!"
echo ""
echo "To uninstall, simply delete $INSTALL_DIR/$APP_DIR"