#Requires AutoHotkey v2.0

; Razer Tartarus Pro mappings configured in Synapse as F13-F16.
CoordMode "Mouse", "Screen"

F13::
{
    MouseGetPos &posx, &posy
    Sleep 50
    Click 1024, 157
    Sleep 50
    Click posx, posy
    Sleep 500
}

F14::
{
    MouseGetPos &posx, &posy
    Sleep 50
    Click 1093, 147
    Sleep 50
    Click posx, posy
    Sleep 500
}

F15::
{
    MouseGetPos &posx, &posy
    Sleep 50
    Click 1150, 154
    Sleep 50
    Click posx, posy
    Sleep 500
}

F16::
{
    MouseGetPos &posx, &posy
    Sleep 50
    Click -1980, 3465
    Sleep 50
    Click posx, posy
    Sleep 500
}
