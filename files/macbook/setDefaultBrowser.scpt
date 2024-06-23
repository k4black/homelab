# https://medium.com/@achhunna/set-macos-default-browser-using-cli-1f64102d9ed6
on run argv
 do shell script "defaultbrowser " & item 1 of argv
 try
  tell application "System Events"
   tell application process "CoreServicesUIAgent"
    tell window 1
     tell (first button whose name starts with "use")
      perform action "AXPress"
     end tell
    end tell
   end tell
  end tell
 end try
end run
