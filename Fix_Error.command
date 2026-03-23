#!/bin/bash
cd "$(dirname "$0")"

APP_NAME="Stickurr.app"

echo "================================================"
echo "      Stickurr - System Permission Helper       "
echo "================================================"

if [ -d "$APP_NAME" ]; then
    echo "[1/3] Removing quarantine attributes..."
    xattr -cr "$APP_NAME"
    
    echo "[2/3] Ensuring binary is executable..."
    chmod +x "$APP_NAME/Contents/MacOS/Stickurr"
    
    echo "[3/3] Re-signing locally (Ad-hoc)..."
    # This step is often required on macOS Sequoia and later
    # to allow the app to run without developer verification.
    codesign --force --deep --sign - "$APP_NAME" 2>/dev/null
    
    echo "------------------------------------------------"
    echo " Done! The app should now be ready to open."
    echo ""
    echo " If you still see a 'Developer cannot be verified' error:"
    echo " 1. Right-click '$APP_NAME' and select 'Open'."
    echo " 2. Click 'Open' in the dialog that appears."
    echo " 3. Or go to System Settings > Privacy & Security."
    echo "------------------------------------------------"
else
    echo "Error: $APP_NAME not found in this directory!"
    echo "Please ensure you have extracted all files correctly."
fi

echo ""
read -p "Press Enter to exit..."
