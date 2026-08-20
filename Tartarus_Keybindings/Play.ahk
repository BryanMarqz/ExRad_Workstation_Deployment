#Requires AutoHotkey v2.0
CoordMode "Mouse", "Screen"

; Play - X: -1980, Y: 3465
MouseGetPos &posx, &posy
Sleep 50
Click -1980, 3465
Sleep 50
Click posx, posy
Sleep 500

ExitApp
