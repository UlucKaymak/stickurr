#!/bin/bash
# Prints the current Finder icon positions for a mounted DMG volume, so you can
# copy the exact x/y coordinates into the DMG_* variables at the top of release.sh.
#
# Usage: ./get-dmg-positions.sh "Stickurr Layout"
# (run after ./preview-dmg-layout.sh and dragging the icons where you want them —
#  the window must still be open when you run this)

VOLUME_NAME="$1"
APP_NAME="Stickurr"
FIX_SCRIPT="Fix_Error.command"
APPLICATIONS_LINK_NAME="Applications"

if [ -z "$VOLUME_NAME" ]; then
    echo "Usage: $0 \"Volume Name\""
    echo "Example: $0 \"Stickurr Layout\""
    exit 1
fi

osascript <<APPLESCRIPT
tell application "Finder"
    if not (exists disk "$VOLUME_NAME") then
        return "Error: disk \"$VOLUME_NAME\" is not mounted. Run ./preview-dmg-layout.sh first."
    end if

    set itemNames to {"$APP_NAME.app", "$APPLICATIONS_LINK_NAME", "$FIX_SCRIPT"}
    set output to ""

    repeat with itemName in itemNames
        set itemName to itemName as string
        set gotIt to false
        set attempt to 0
        repeat until gotIt
            try
                set p to position of item itemName of disk "$VOLUME_NAME"
                set output to output & itemName & "  ->  " & (item 1 of p as integer) & " " & (item 2 of p as integer) & linefeed
                set gotIt to true
            on error errMsg
                set attempt to attempt + 1
                if attempt > 5 then
                    set output to output & itemName & "  ->  could not read position (" & errMsg & ")" & linefeed
                    set gotIt to true
                else
                    delay 1
                end if
            end try
        end repeat
    end repeat

    return output
end tell
APPLESCRIPT
