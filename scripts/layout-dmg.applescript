on run arguments
    set volumeName to item 1 of arguments
    set backgroundPath to item 2 of arguments
    set backgroundFile to POSIX file backgroundPath as alias

    tell application "Finder"
        set dmgDisk to disk (volumeName as text)
        tell dmgDisk
            open
            set dmgWindow to the container window
            set current view of dmgWindow to icon view
            set toolbar visible of dmgWindow to false
            set statusbar visible of dmgWindow to false
            set pathbar visible of dmgWindow to false
            set sidebar width of dmgWindow to 0
            set bounds of dmgWindow to {120, 120, 920, 720}

            set iconOptions to icon view options of dmgWindow
            set arrangement of iconOptions to not arranged
            set icon size of iconOptions to 112
            set text size of iconOptions to 13
            set shows item info of iconOptions to false
            set shows icon preview of iconOptions to true
            set background picture of iconOptions to backgroundFile

            set position of item "Ledge.app" to {185, 350}
            set position of item "Applications" to {615, 350}
            set position of item "安装说明.txt" to {680, 440}
            set extension hidden of item "安装说明.txt" to true

            update without registering applications
            delay 2
            close
            delay 3
        end tell
    end tell
end run
