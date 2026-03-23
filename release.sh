#!/bin/bash

# Configuration
APP_NAME="Stickurr"
BUNDLE_ID="com.uluckaymak.Stickurr"
VERSION="0.7.7"
BUILD_DIR=".build/apple-bundle"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "================================================"
echo "      Stickurr - Professional Build Script      "
echo "================================================"

# 1. Clean and Build
echo "[1/5] Cleaning old artifacts and building arm64..."
cd Stickurr
rm -rf .build
swift build -c release --arch arm64 
cd ..

BINARY_PATH=$(cd Stickurr && swift build -c release --arch arm64 --show-bin-path)/$APP_NAME

if [ ! -f "$BINARY_PATH" ]; then
    echo "Error: Build failed! Binary not found at $BINARY_PATH"
    exit 1
fi

# 2. Create bundle structure
echo "[2/5] Creating app bundle structure..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 3. Copy files
echo "[3/5] Copying resources..."
cp "$BINARY_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "Info.plist" "$APP_BUNDLE/Contents/"
echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# İkonu kopyala ve adını Info.plist ile eşleştir
if [ -f "icon.icns" ]; then
    cp "icon.icns" "$APP_BUNDLE/Contents/Resources/icon.icns"
    echo "Icon copied successfully."
else
    echo "Warning: icon.icns not found in root directory!"
fi

# 4. Sign the app with Hardened Runtime
echo "[4/5] Signing with Hardened Runtime (Ad-hoc)..."
codesign --force --options runtime --deep --sign - "$APP_BUNDLE"

# 5. Refresh Icon Cache and Verification
echo "[5/5] Refreshing icon cache and verifying..."
# macOS'e dosyanın değiştiğini bildirmek için 'touch' kullanılır, böylece ikonu tekrar okur.
touch "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

echo "================================================"
echo " Success! Final App Bundle: $APP_BUNDLE"
echo "================================================"
