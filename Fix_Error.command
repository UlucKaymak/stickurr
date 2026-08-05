#!/bin/bash
cd "$(dirname "$0")"

APP_NAME="Stickurr.app"
DEST="/Applications/$APP_NAME"

echo "================================================"
echo "      Stickurr - System Permission Helper       "
echo "================================================"

# Prefer an already-installed copy in /Applications; otherwise use whatever
# sits next to this script (e.g. still inside the mounted DMG).
SOURCE=""
if [ -d "$DEST" ]; then
    SOURCE="$DEST"
elif [ -d "$APP_NAME" ]; then
    SOURCE="$APP_NAME"
fi

if [ -z "$SOURCE" ]; then
    echo "Error: $APP_NAME not found here or in /Applications."
    echo "Make sure Stickurr.app is next to this script, or drag it to Applications first."
    echo ""
    read -p "Press Enter to exit..."
    exit 1
fi

# If it's still on the read-only DMG, xattr/codesign can't write to it —
# copy it out to /Applications first, then fix the copy.
if [ ! -w "$SOURCE" ]; then
    echo "$APP_NAME is on a read-only disk image — copying it to /Applications first..."
    rm -rf "$DEST" 2>/dev/null
    if ! cp -R "$SOURCE" "$DEST" 2>/dev/null; then
        echo "Need admin permission to copy into /Applications, asking for your password..."
        sudo cp -R "$SOURCE" "$DEST"
    fi
    SOURCE="$DEST"
    echo "Done. Now fixing the copy in /Applications."
fi

echo "Removing quarantine attributes..."
xattr -cr "$SOURCE"

echo "Ensuring binary is executable..."
chmod +x "$SOURCE/Contents/MacOS/Stickurr"

echo "Re-signing locally (Ad-hoc)..."
# This step is often required on macOS Sequoia and later
# to allow the app to run without developer verification.
codesign --force --deep --sign - "$SOURCE" 2>/dev/null

echo "------------------------------------------------"
echo " Done! Stickurr is ready to open from:"
echo " $SOURCE"
echo ""
echo " If you still see a 'Developer cannot be verified' error:"
echo " 1. Right-click Stickurr.app and select 'Open'."
echo " 2. Click 'Open' in the dialog that appears."
echo " 3. Or go to System Settings > Privacy & Security."
echo "------------------------------------------------"

echo ""
read -p "Press Enter to exit..."
