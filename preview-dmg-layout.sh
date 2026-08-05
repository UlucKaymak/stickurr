#!/bin/bash
# Opens a WRITABLE, uncompressed test DMG whose Finder window is configured
# EXACTLY like the one create-dmg will produce for the real build (same
# window bounds, same icon/text size, toolbar+sidebar hidden, no auto-arrange).
# This matters: toolbar/sidebar visibility shifts Finder's icon coordinate
# origin, so if the preview window doesn't match the final window's chrome,
# whatever position you read back will be off in the real DMG.
#
# Usage:
#   ./release.sh                  # build the app at least once first
#   ./preview-dmg-layout.sh       # opens the layout test DMG in Finder
#   (drag Stickurr.app, Applications, and Fix_Error.command wherever you like)
#   ./get-dmg-positions.sh "Stickurr Layout"
#   # copy the printed numbers into the DMG_* variables at the top of release.sh
#   ./release.sh                  # rebuild the real DMG with the new layout

set -e

APP_NAME="Stickurr"
BUILD_DIR=".build/apple-bundle"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
FIX_SCRIPT="Fix_Error.command"
DIST_DIR="dist"
VOLUME_NAME="Stickurr Layout"
PREVIEW_DMG="$DIST_DIR/stickurr-layout-preview.dmg"
STAGE="$DIST_DIR/layout-stage"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: $APP_BUNDLE not found. Run ./release.sh at least once first so there's an app to preview."
    exit 1
fi

if [ ! -f "release.sh" ]; then
    echo "Error: run this from the project root (where release.sh lives)."
    exit 1
fi

# Pull the exact same layout constants release.sh will use for the real DMG,
# so the preview window matches the final one 1:1.
eval "$(grep -E '^DMG_(WINDOW_POS|WINDOW_SIZE|ICON_SIZE|TEXT_SIZE)=' release.sh)"

read -r WIN_X WIN_Y <<< "$DMG_WINDOW_POS"
read -r WIN_W WIN_H <<< "$DMG_WINDOW_SIZE"
WIN_RIGHT=$((WIN_X + WIN_W))
WIN_BOTTOM=$((WIN_Y + WIN_H))

mkdir -p "$DIST_DIR"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP_BUNDLE" "$STAGE/"
if [ -f "$FIX_SCRIPT" ]; then
    cp "$FIX_SCRIPT" "$STAGE/"
    chmod +x "$STAGE/$FIX_SCRIPT"
fi
ln -s /Applications "$STAGE/Applications"

if [ -f "dmg-background.png" ]; then
    mkdir -p "$STAGE/.background"
    cp "dmg-background.png" "$STAGE/.background/bg.png"
fi

# Eject any previous preview mount so we don't collide
if [ -d "/Volumes/$VOLUME_NAME" ]; then
    hdiutil detach "/Volumes/$VOLUME_NAME" -quiet || true
fi

rm -f "$PREVIEW_DMG"
hdiutil create -volname "$VOLUME_NAME" -srcfolder "$STAGE" -fs HFS+ -format UDRW -ov "$PREVIEW_DMG" -quiet
rm -rf "$STAGE"

echo "Mounting the layout preview..."
hdiutil attach "$PREVIEW_DMG" -quiet

# Give Finder a moment to register the freshly-mounted volume before we
# script it — querying it too soon is the classic cause of AppleScript
# error -1728 ("Can't get disk ..." / "Can't get item 1 of disk ...").
sleep 2

echo "Setting up the window to match the final DMG exactly (this is what makes the coordinates line up)..."

osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOLUME_NAME"
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
        update without registering applications
    end tell
end tell
APPLESCRIPT

echo ""
echo "------------------------------------------------------------"
echo " Window is now byte-for-byte the same as the final DMG will"
echo " be: same size ($WIN_W x $WIN_H), same icon size ($DMG_ICON_SIZE),"
echo " no toolbar/sidebar, no auto-arrange."
echo ""
echo " Drag Stickurr.app, Applications, and Fix_Error.command to"
echo " where you want them. Don't resize or move the window."
echo ""
echo " When done, run:"
echo "   ./get-dmg-positions.sh \"$VOLUME_NAME\""
echo " and paste the printed numbers into the DMG_APP_ICON_POS /"
echo " DMG_APPLICATIONS_POS / DMG_FIX_SCRIPT_POS variables at the"
echo " top of release.sh, then run ./release.sh to rebuild for real."
echo ""
echo " When finished, eject with:"
echo "   hdiutil detach \"/Volumes/$VOLUME_NAME\""
echo "------------------------------------------------------------"
