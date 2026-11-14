;================================================================================
; Presence
;================================================================================
#Requires AutoHotkey v2.0

; Windows' own display-state notification. Registering delivers the current
; value immediately, so DisplayOn is correct from the first second.
WatchDisplay() {
    g := Buffer(16, 0)
    DllCall("ole32\CLSIDFromString", "wstr", "{6FE69556-704A-47A0-8F24-C28D936FDA47}", "ptr", g)
    DllCall("RegisterPowerSettingNotification", "ptr", PanelHwnd, "ptr", g, "uint", 0, "ptr")
    OnMessage(0x218, OnPowerBroadcast)        ; WM_POWERBROADCAST
}

OnPowerBroadcast(wParam, lParam, msg, hwnd) {
    global DisplayOn
    if (wParam != 0x8013)                     ; PBT_POWERSETTINGCHANGE
        return
    ; POWERBROADCAST_SETTING: GUID(16) + DWORD DataLength(4) + Data
    DisplayOn := (NumGet(lParam, 20, "uchar") != 0)     ; 0 off, 1 on, 2 dimmed
}

; What ENDS a declared break: the keyboard, mouse CLICKS and mouse SCROLL - but
; NOT mouse movement, because nudging the mouse to stop the monitor sleeping
; during a walk must not look like sitting down again.
;
; A_TimeIdlePhysical cannot express that: it lumps every hooked device
; together, movement included. So the keyboard is read from A_TimeIdleKeyboard,
; and clicks and wheel events are timestamped by the pass-through hotkeys in
; Keys.ahk. Presence itself (Present) goes through SeenMs() below.
IdleMs() {
    k := A_TimeIdleKeyboard
    if (!LastClickTick)
        return k
    m := A_TickCount - LastClickTick
    return (k < m) ? k : m
}

; How long since you last did anything that says "I am at the desk". With
; MouseMovementCounts on (the default) that is any input at all, movement
; included - reading with a hand on the mouse is sitting. Off, it is keys,
; clicks and scrolling only, the same as what ends a declared break.
SeenMs() {
    return CountMouseMove ? A_TimeIdlePhysical : IdleMs()
}

; How long you have really been gone, once Daybook decides you are: since the
; last thing that said you were here - your last touch, or the last sound while
; sound counts. Without the sound, a film watched for an hour without touching
; anything looked like an hour away the moment it ended, and the first touch
; after it cleared the clock as if that hour had been a break.
GoneMs() {
    gone := SeenMs()
    if (AudioCapMin > 0 && LastSoundAt) {
        heard := A_TickCount - LastSoundAt
        if (heard < gone)
            gone := heard
    }
    return gone
}

Present() {
    ; A break you declared yourself outranks every sensor in here. This is the
    ; whole point of it: no signal can tell "walking round the room doing squats
    ; while a video plays" from "sitting watching a video", and nudging the
    ; mouse to stop the monitor sleeping makes it worse. So you get a switch.
    if (BreakMode)
        return false
    capped := (SeenMs() < AudioCapMin * 60000)
    ; The screen being dark is the strongest "you are gone" there is, and it is
    ; Windows' own judgement, arrived at by the same rule that decides whether
    ; a film should keep the monitor awake.
    if (!DisplayOn || Locked() || ScreensaverOn())
        return false
    ; Sound playing with no input means you are watching something, so you are
    ; still sitting - capped, because an app that pins the display awake for
    ; audio-only playback would otherwise hold presence up all evening.
    if (AudioCapMin > 0 && AudioPlaying())
        return capped
    ; Otherwise it is simply: five minutes since you last touched anything.
    ; One number, and you can feel it.
    return (SeenMs() < BreakLenMin * 60000)
}

; Coming back ends the absence there and then. How long you were gone decides
; what it was - see CreditBreak.
ReturnFromAway() {
    global Away, AwaySec, AwayIdleMs
    took := AwayIdleMs // 1000
    if (took < AwaySec)
        took := AwaySec
    CreditBreak(took)
    Away := 0, AwaySec := 0, AwayIdleMs := 0
}

; A whole break (BreakLenMin or more) gives you a clean 45 minutes. Anything
; shorter was a pause, not a break: the clock carries on from where it was, so a
; lock screen or a quick coffee never wipes the time you have built up - and a
; red bar stays red until you actually take the whole five. Coming back early
; while overdue is flagged, so the digits can say so. See UpdateTimerText().
CreditBreak(tookSec) {
    global SitSec, CutShort
    if (tookSec >= BreakLenMin * 60) {
        SitSec := 0
        CutShort := 0
    } else if (SitSec >= SitBreakMin * 60)
        CutShort := 1
}

; OpenInputDesktop fails while the workstation is locked. One call, and nothing
; to keep in sync the way a session-notification subscription would need.
Locked() {
    h := DllCall("OpenInputDesktop", "uint", 0, "int", false, "uint", 0x0100, "ptr")
    if (!h)
        return true
    DllCall("CloseDesktop", "ptr", h)
    return false
}

ScreensaverOn() {
    r := Buffer(4, 0)
    DllCall("SystemParametersInfo", "uint", 114, "uint", 0, "ptr", r, "uint", 0)
    return NumGet(r, 0, "int")
}

; Peak level on EVERY active playback device, not just the default one: Discord,
; games and browsers can each send sound to their own device (the headset, the
; monitor's speakers, a virtual cable), and the default one hears none of it.
; A single reading is one instant, so a pause in a conversation read as
; silence; sound now counts for SoundHoldS after it was last heard. Re-bound once
; a minute so it follows devices coming and going, and on any failure.
AudioPlaying() {
    global MeterAt, LastSoundAt
    if (!Meters.Length || A_TickCount - MeterAt > 60000)
        BindMeters()
    for m in Meters {
        p := 0.0
        try ComCall(3, m, "float*", &p)         ; IAudioMeterInformation::GetPeakValue
        catch {
            MeterAt := 0                        ; gone - rebind on the next call
            continue
        }
        if (p > 0.0005) {
            LastSoundAt := A_TickCount
            break
        }
    }
    return (LastSoundAt && A_TickCount - LastSoundAt < SoundHoldS * 1000)
}

BindMeters() {
    global Meters, MeterAt
    MeterAt := A_TickCount
    for m in Meters
        try ObjRelease(m)
    Meters := []
    try en := ComObject("{BCDE0395-E52F-467C-8E3D-C4579291692E}"
                      , "{A95664D2-9614-4F35-A746-DE8DB63617E6}")
    catch
        return
    ; IMMDeviceEnumerator::EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE)
    col := 0
    try ComCall(3, en, "uint", 0, "uint", 1, "ptr*", &col)
    if (!col)
        return
    n := 0
    try ComCall(3, col, "uint*", &n)                            ; GetCount
    iid := Buffer(16, 0)
    DllCall("ole32\CLSIDFromString", "wstr", "{C02216F6-8C67-4B5B-9D00-D008E73E0064}", "ptr", iid)
    loop n {
        dev := 0
        try ComCall(4, col, "uint", A_Index - 1, "ptr*", &dev)  ; Item
        if (!dev)
            continue
        m := 0                                 ; IMMDevice::Activate(IAudioMeterInformation)
        try ComCall(3, dev, "ptr", iid, "uint", 1, "ptr", 0, "ptr*", &m)
        ObjRelease(dev)
        if (m)
            Meters.Push(m)
    }
    ObjRelease(col)
}
