on run arguments
    set appName to item 1 of arguments
    set appPath to item 2 of arguments
    tell application "System Events"
        repeat with loginItem in login items
            if path of loginItem is appPath then return "present"
        end repeat
        make new login item at end with properties {name:appName, path:appPath, hidden:false}
    end tell
    return "added"
end run
