#!/bin/bash

# Configuration
APP_NAME="Stickurr"
BUNDLE_ID="com.uluckaymak.Stickurr"
BUILD_DIR=".build/apple-bundle"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

# 0. Increment Version in Info.plist
CURRENT_VERSION=$(plutil -extract CFBundleShortVersionString xml1 -o - Info.plist | sed -n 's/.*<string>\(.*\)<\/string>.*/\1/p')
IFS='.' read -r major minor patch <<< "$CURRENT_VERSION"
NEW_PATCH=$((patch + 1))
VERSION="$major.$minor.$NEW_PATCH"

echo "Updating version from $CURRENT_VERSION to $VERSION"
plutil -replace CFBundleShortVersionString -string "$VERSION" Info.plist

DIST_DIR="dist"
FIX_SCRIPT="Fix_Error.command"

# DMG window/icon layout — tune these by running ./preview-dmg-layout.sh,
# dragging icons to where you want them, then reading exact coords with
# ./get-dmg-positions.sh and pasting the numbers back in here.
DMG_WINDOW_POS="200 120"
DMG_WINDOW_SIZE="660 400"
DMG_ICON_SIZE=80
DMG_TEXT_SIZE=11
DMG_APP_ICON_POS="399 258"
DMG_APPLICATIONS_POS="570 255"
DMG_FIX_SCRIPT_POS="311 108"

echo "================================================"
echo "      Stickurr - Professional Build Script      "
echo "      Version: $VERSION"
echo "================================================"

# 1. Clean and Build
echo "[1/6] Cleaning old artifacts and building arm64..."
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
echo "[2/6] Creating app bundle structure..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 3. Copy files
echo "[3/6] Copying resources..."
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
echo "[4/6] Signing with Hardened Runtime (Ad-hoc)..."
codesign --force --options runtime --deep --sign - "$APP_BUNDLE"

# 5. Refresh Icon Cache and Verification
echo "[5/6] Refreshing icon cache and verifying..."
# macOS'e dosyanın değiştiğini bildirmek için 'touch' kullanılır, böylece ikonu tekrar okur.
touch "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

# 6. Package for distribution (zip + dmg), bundling the Gatekeeper fix script
echo "[6/6] Packaging for distribution (zip + dmg)..."

if [ ! -f "$FIX_SCRIPT" ]; then
    echo "Warning: $FIX_SCRIPT not found in project root, skipping its inclusion."
fi

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# --- ZIP ---
ZIP_STAGE="$DIST_DIR/$APP_NAME-$VERSION"
mkdir -p "$ZIP_STAGE"
cp -R "$APP_BUNDLE" "$ZIP_STAGE/"
if [ -f "$FIX_SCRIPT" ]; then
    cp "$FIX_SCRIPT" "$ZIP_STAGE/"
    chmod +x "$ZIP_STAGE/$FIX_SCRIPT"
fi

( cd "$DIST_DIR" && zip -r -y -q "$APP_NAME-$VERSION.zip" "$APP_NAME-$VERSION" )
rm -rf "$ZIP_STAGE"

# --- DMG (nice layout + small size) ---
# Note: we don't use the create-dmg tool here. Its official script closes and
# reopens the Finder window to force settings to persist, and on modern macOS
# that reopen brings the toolbar/sidebar back (it only re-hides the status bar,
# not the toolbar) — which shrinks the visible content area, making icons look
# oversized and cropping the bottom of the background image. Our own AppleScript
# below is the exact same one used by preview-dmg-layout.sh (already verified to
# lay out correctly), with no close/reopen step — we just wait for .DS_Store to
# be written to disk instead.
DMG_STAGE="$DIST_DIR/dmg-stage"
rm -rf "$DMG_STAGE"
mkdir -p "$DMG_STAGE"
cp -R "$APP_BUNDLE" "$DMG_STAGE/"
if [ -f "$FIX_SCRIPT" ]; then
    cp "$FIX_SCRIPT" "$DMG_STAGE/"
    chmod +x "$DMG_STAGE/$FIX_SCRIPT"
fi
ln -s /Applications "$DMG_STAGE/Applications"
if [ -f "dmg-background.png" ]; then
    mkdir -p "$DMG_STAGE/.background"
    cp "dmg-background.png" "$DMG_STAGE/.background/bg.png"
fi

DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
rm -f "$DMG_PATH"

DMG_VOLNAME="$APP_NAME $VERSION"
TMP_DMG="$DIST_DIR/rw-$APP_NAME-$VERSION.dmg"
rm -f "$TMP_DMG"

read -r WIN_X WIN_Y <<< "$DMG_WINDOW_POS"
read -r WIN_W WIN_H <<< "$DMG_WINDOW_SIZE"
WIN_RIGHT=$((WIN_X + WIN_W))
WIN_BOTTOM=$((WIN_Y + WIN_H))
read -r APP_ICON_X APP_ICON_Y <<< "$DMG_APP_ICON_POS"
read -r APPLICATIONS_X APPLICATIONS_Y <<< "$DMG_APPLICATIONS_POS"
read -r FIX_ICON_X FIX_ICON_Y <<< "$DMG_FIX_SCRIPT_POS"

# Eject any leftover mount with the same name first
if [ -d "/Volumes/$DMG_VOLNAME" ]; then
    hdiutil detach "/Volumes/$DMG_VOLNAME" -quiet || true
fi

hdiutil create -volname "$DMG_VOLNAME" -srcfolder "$DMG_STAGE" -fs HFS+ -format UDRW -ov "$TMP_DMG" -quiet
hdiutil attach "$TMP_DMG" -quiet
sleep 2

osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$DMG_VOLNAME"
        open
        tell container window
            set current view to icon view
            set toolbar visible to false
            set statusbar visible to false
            set the bounds to {$WIN_X, $WIN_Y, $WIN_RIGHT, $WIN_BOTTOM}
        end tell
        set opts to the icon view options of container window
        tell opts
            set icon size to $DMG_ICON_SIZE
            set text size to $DMG_TEXT_SIZE
            set arrangement to not arranged
        end tell
        try
            set background picture of opts to file ".background:bg.png"
        end try
        try
            set the extension hidden of item "$APP_NAME.app" to true
        end try
        set position of item "$APP_NAME.app" to {$APP_ICON_X, $APP_ICON_Y}
        set position of item "Applications" to {$APPLICATIONS_X, $APPLICATIONS_Y}
        try
            set position of item "$FIX_SCRIPT" to {$FIX_ICON_X, $FIX_ICON_Y}
        end try
        update without registering applications
    end tell
end tell
APPLESCRIPT

# Wait for Finder to actually flush .DS_Store before we detach, otherwise the
# layout can silently fail to persist into the final image.
MOUNT_POINT="/Volumes/$DMG_VOLNAME"
WAITED=0
while [ ! -f "$MOUNT_POINT/.DS_Store" ] && [ "$WAITED" -lt 15 ]; do
    sleep 1
    WAITED=$((WAITED + 1))
done

hdiutil detach "$MOUNT_POINT" -quiet || hdiutil detach "$MOUNT_POINT" -force -quiet

hdiutil convert "$TMP_DMG" -format UDBZ -imagekey bzip2-level=9 -ov -o "$DMG_PATH"
rm -f "$TMP_DMG"
rm -rf "$DMG_STAGE"

echo "================================================"
echo " Success! Final App Bundle: $APP_BUNDLE"
echo " Distribution ZIP: $DIST_DIR/$APP_NAME-$VERSION.zip"
echo " Distribution DMG: $DMG_PATH"
echo "================================================"
