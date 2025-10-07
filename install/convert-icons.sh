#!/bin/bash

set -e

SOURCE_LOGO="../frontend/src/assets/images/RabbitSyncLogo.png"
ASSETS_DIR="../frontend/src/assets/images"

echo "🎨 Converting RabbitSync logo to platform-specific formats..."

if [ ! -f "$SOURCE_LOGO" ]; then
    echo "❌ Source logo not found at $SOURCE_LOGO"
    exit 1
fi

mkdir -p "$ASSETS_DIR"

if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "🍎 Creating .icns file for macOS..."
    
    ICONSET_DIR="/tmp/RabbitSyncLogo.iconset"
    rm -rf "$ICONSET_DIR"
    mkdir -p "$ICONSET_DIR"
    
    sips -z 16 16     "$SOURCE_LOGO" --out "$ICONSET_DIR/icon_16x16.png" 2>/dev/null
    sips -z 32 32     "$SOURCE_LOGO" --out "$ICONSET_DIR/icon_16x16@2x.png" 2>/dev/null
    sips -z 32 32     "$SOURCE_LOGO" --out "$ICONSET_DIR/icon_32x32.png" 2>/dev/null
    sips -z 64 64     "$SOURCE_LOGO" --out "$ICONSET_DIR/icon_32x32@2x.png" 2>/dev/null
    sips -z 128 128   "$SOURCE_LOGO" --out "$ICONSET_DIR/icon_128x128.png" 2>/dev/null
    sips -z 256 256   "$SOURCE_LOGO" --out "$ICONSET_DIR/icon_128x128@2x.png" 2>/dev/null
    sips -z 256 256   "$SOURCE_LOGO" --out "$ICONSET_DIR/icon_256x256.png" 2>/dev/null
    sips -z 512 512   "$SOURCE_LOGO" --out "$ICONSET_DIR/icon_256x256@2x.png" 2>/dev/null
    sips -z 512 512   "$SOURCE_LOGO" --out "$ICONSET_DIR/icon_512x512.png" 2>/dev/null
    sips -z 1024 1024 "$SOURCE_LOGO" --out "$ICONSET_DIR/icon_512x512@2x.png" 2>/dev/null
    
    iconutil -c icns "$ICONSET_DIR" -o "$ASSETS_DIR/RabbitSyncLogo.icns"
    
    rm -rf "$ICONSET_DIR"
    echo "✅ Created RabbitSyncLogo.icns"
fi

if command -v convert &> /dev/null; then
    echo "🪟 Creating .ico file for Windows using ImageMagick..."
    
    convert "$SOURCE_LOGO" \
        \( -clone 0 -resize 16x16 \) \
        \( -clone 0 -resize 32x32 \) \
        \( -clone 0 -resize 48x48 \) \
        \( -clone 0 -resize 64x64 \) \
        \( -clone 0 -resize 128x128 \) \
        \( -clone 0 -resize 256x256 \) \
        -delete 0 \
        "$ASSETS_DIR/RabbitSyncLogo.ico"
    
    echo "✅ Created RabbitSyncLogo.ico"
elif command -v png2ico &> /dev/null; then
    echo "🪟 Creating .ico file for Windows using png2ico..."
    
    mkdir -p /tmp/ico_temp
    convert "$SOURCE_LOGO" -resize 16x16 /tmp/ico_temp/16.png 2>/dev/null
    convert "$SOURCE_LOGO" -resize 32x32 /tmp/ico_temp/32.png 2>/dev/null
    convert "$SOURCE_LOGO" -resize 48x48 /tmp/ico_temp/48.png 2>/dev/null
    convert "$SOURCE_LOGO" -resize 256x256 /tmp/ico_temp/256.png 2>/dev/null
    
    png2ico "$ASSETS_DIR/RabbitSyncLogo.ico" /tmp/ico_temp/16.png /tmp/ico_temp/32.png /tmp/ico_temp/48.png /tmp/ico_temp/256.png
    
    rm -rf /tmp/ico_temp
    echo "✅ Created RabbitSyncLogo.ico"
else
    echo "⚠️ Neither ImageMagick nor png2ico is installed."
    echo "   Install ImageMagick with: brew install imagemagick (macOS) or apt-get install imagemagick (Linux)"
    echo "   Or install png2ico for .ico conversion"
fi

echo ""
echo "📁 Icon files location:"
echo "   Original PNG: $SOURCE_LOGO"
if [ -f "$ASSETS_DIR/RabbitSyncLogo.icns" ]; then
    echo "   macOS icon:  $ASSETS_DIR/RabbitSyncLogo.icns"
fi
if [ -f "$ASSETS_DIR/RabbitSyncLogo.ico" ]; then
    echo "   Windows icon: $ASSETS_DIR/RabbitSyncLogo.ico"
fi
echo ""
echo "💡 Run this script whenever you update the logo to regenerate platform-specific formats."