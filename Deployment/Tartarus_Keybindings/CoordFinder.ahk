#Requires AutoHotkey v2.0
CoordMode "Mouse", "Screen"
^+c::
{
    MouseGetPos &x, &y
    MsgBox "X: " x "`nY: " y
}
