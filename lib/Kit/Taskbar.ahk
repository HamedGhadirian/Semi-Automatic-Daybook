;================================================================================
; Taskbar.ahk (kit) - a taskbar button of a script's own
;================================================================================
; Windows puts every window of one program file under one taskbar button, and
; every v2 script runs on the same AutoHotkey64.exe - so two scripts' windows
; would land behind one button. A window that carries an app id
; (AppUserModelID, the name tag the taskbar groups by) gets a button of its
; own; windows with the same id share one.
;
; Call it on the new, still hidden window, before its first Show: the taskbar
; reads the id when it makes the button. Pass "" as the id to take it off.
;
; Not when compiled: the .exe has its own button already, and a shortcut
; pinned to it only matches windows WITHOUT an id.
;================================================================================
#Requires AutoHotkey v2.0

class KitTaskbar {
    ; the id every window of this script shares: the script's own "appId", or
    ; one made from its name
    static Default() => Kit.Opt("appId", "Kit." RegExReplace(Kit.name, "[^\w]+", ""))

    static Id(hwnd, id := unset) {
        if A_IsCompiled
            return false
        if !IsSet(id)
            id := KitTaskbar.Default()
        ok := false, ps := 0
        try {
            iid := Buffer(16), pk := Buffer(20, 0), pv := Buffer(24, 0)
            DllCall("ole32\CLSIDFromString", "wstr", "{886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99}", "ptr", iid)   ; IPropertyStore
            DllCall("shell32\SHGetPropertyStoreForWindow", "ptr", hwnd, "ptr", iid, "ptr*", &ps, "HRESULT")
            DllCall("ole32\CLSIDFromString", "wstr", "{9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3}", "ptr", pk)
            NumPut("uint", 5, pk, 16)                                       ; PKEY_AppUserModel_ID
            if (id != "")
                NumPut("ushort", 31, pv, 0), NumPut("ptr", StrPtr(id), pv, 8)   ; VT_LPWSTR; left empty takes it off
            ComCall(6, ps, "ptr", pk, "ptr", pv)                            ; SetValue
            ComCall(7, ps)                                                  ; Commit
            ok := true
        }
        if ps
            ObjRelease(ps)
        return ok
    }
}
