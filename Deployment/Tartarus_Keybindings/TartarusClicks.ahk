#Requires AutoHotkey v2.0

; ============================================================
;  TartarusClicks.ahk — Razer Tartarus Pro Button Mappings
;  Razer Synapse 3 key assignments: F13–F16
; ============================================================
;  F13  →  Folder Forward   X: 1024   Y: 157
;  F14  →  Folder Accept    X: 1093   Y: 147
;  F15  →  Folder Reject    X: 1150   Y: 154
;  F16  →  Play             X: 4466   Y: 142
; ============================================================

CoordMode "Mouse", "Screen"

; F13 — Folder Forward
F13::
{
	MouseGetPos &posx, &posy
	Sleep 50
	Click 1024, 157
	Sleep 50
	Click posx, posy
	Sleep 500
}

; F14 — Folder Accept
F14::
{
	MouseGetPos &posx, &posy
	Sleep 50
	Click 1093, 147
	Sleep 50
	Click posx, posy
	Sleep 500
}

; F15 — Folder Reject
F15::
{
	MouseGetPos &posx, &posy
	Sleep 50
	Click 1150, 154
	Sleep 50
	Click posx, posy
	Sleep 500
}

; F16 — Play
F16::
{
	MouseGetPos &posx, &posy
	Sleep 50
	Click -1980, 3465
	Sleep 50
	Click posx, posy
	Sleep 500
}
