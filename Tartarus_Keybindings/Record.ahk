#Requires AutoHotkey v2.0

win := "ahk_exe RS1Dictate.exe"
btn := FindVisibleCtl(win, "TRScxButton", 183, 87)

if !btn {
    MsgBox "No visible button in that slot."
    ExitApp
}

ControlClick btn, win, , "Left", 1, "NA"

FindVisibleCtl(win, prefix, x, y, tol := 12) {
    if !WinExist(win)
        return ""
    for ctl in WinGetControls(win) {
        if !InStr(ctl, prefix)
            continue
        try {
            ControlGetPos &cx, &cy, , , ctl, win
            if (Abs(cx - x) > tol || Abs(cy - y) > tol)
                continue
            if !ControlGetVisible(ctl, win)
                continue
            return ctl
        }
    }
    return ""
}