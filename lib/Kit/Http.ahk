;================================================================================
; Http.ahk (kit) - one web request that never makes the script wait
;================================================================================
; r := KitHttp(url, {timeout: 10000, headers: Map(...), raw: true})
; then, on a timer:  if r.Poll() ...  - true once it has answered or given up.
;   r.Ok       an answer in the 200s        r.text   the answer, as UTF-8 text
;   r.status   the HTTP number              r.raw    the bytes, when raw was asked
;   r.err      why there was no answer      r.Why    r.err, or "HTTP 404"
;
; THE PROXY. WinHTTP, which this uses, ignores the Windows proxy setting by
; itself, so every request would go direct - and fail wherever a VPN app in
; "system proxy" mode is the only way out. So the Windows setting is followed,
; unless the script's .ini says otherwise:
;   [Network] Proxy=auto              follow Windows (the default, also when
;                                     the line is not there at all)
;   [Network] Proxy=127.0.0.1:10809   always this HTTP proxy
;   [Network] Proxy=none              always direct
;================================================================================
#Requires AutoHotkey v2.0

class KitHttp {
    __New(url, opts := "") {
        this.url := url, this.status := 0, this.text := "", this.err := "", this.done := false
        this.req := "", this.raw := ""
        o := IsObject(opts) ? opts : {}
        this.wantRaw := o.HasProp("raw") && o.raw
        timeout := o.HasProp("timeout") ? o.timeout : 8000
        this.deadline := A_TickCount + timeout
        try {
            r := ComObject("WinHttp.WinHttpRequest.5.1")
            r.Open(o.HasProp("method") ? o.method : "GET", url, true)
            if (px := KitHttp.Proxy())
                r.SetProxy(2, px[1], px[2])             ; HTTPREQUEST_PROXYSETTING_PROXY
            r.SetTimeouts(timeout, timeout, timeout, timeout)
            r.Option[0] := KitHttp.Agent()
            if o.HasProp("headers")
                for k, v in o.headers
                    r.SetRequestHeader(k, v)
            if o.HasProp("body")
                r.Send(o.body)
            else
                r.Send()
            this.req := r
        } catch as e {
            this.err := KitHttp.Short(e.Message), this.done := true
        }
    }

    Poll() {
        if this.done
            return true
        try {
            if !this.req.WaitForResponse(0) {
                if (A_TickCount < this.deadline)
                    return false
                try this.req.Abort()
                this.err := "timed out"
            } else {
                this.status := this.req.Status
                body := this.req.ResponseBody
                if this.wantRaw
                    this.raw := body
                else
                    this.text := KitHttp.Utf8(body)
            }
        } catch as e
            this.err := KitHttp.Short(e.Message)
        this.req := ""
        return this.done := true
    }

    ; gives up on a request still waiting - its answer is no longer wanted
    Abort() {
        if this.done
            return
        try this.req.Abort()
        this.req := "", this.err := "cancelled", this.done := true
    }

    Ok  => (this.err = "" && this.status >= 200 && this.status < 300)
    Why => (this.err != "") ? this.err : "HTTP " this.status

    ; what the request says it comes from: the script's name and version
    static Agent() {
        if (Kit.Opt("agent") != "")
            return Kit.Opt("agent")
        name := RegExReplace(Kit.name, "[^\w.\-]+", "-")
        return ((name != "") ? name : "AutoHotkey-script") ((Kit.version != "") ? "/" Kit.version : "")
    }

    ; read per request, so switching a VPN's mode takes effect at once
    static Proxy() {
        cfg := (Kit.ini != "") ? CfgStr(Kit.ini, "Network", "Proxy", "auto") : "auto"
        if (cfg = "none" || cfg = "direct")
            return ""
        if (cfg != "" && cfg != "auto")
            return [cfg, "<local>"]
        key := "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
        try {
            if RegRead(key, "ProxyEnable", 0) {
                s := RegRead(key, "ProxyServer", "")
                if (s != "")
                    return [s, RegRead(key, "ProxyOverride", "<local>")]
            }
        }
        return ""
    }

    ; ResponseText trusts the server's charset header; the raw bytes as UTF-8
    ; are right for everything asked here, headers or not.
    static Utf8(body) {
        if !IsObject(body)
            return ""
        n := body.MaxIndex() + 1
        if (n <= 0)
            return ""
        return StrGet(NumGet(ComObjValue(body), 8 + A_PtrSize, "ptr"), n, "UTF-8")
    }

    ; the bytes exactly as they arrived - for a zip, where text would ruin them
    static Write(body, path) {
        n := body.MaxIndex() + 1
        out := FileOpen(path, "w")
        if !out
            throw Error("cannot write " path)
        out.RawWrite(NumGet(ComObjValue(body), 8 + A_PtrSize, "ptr"), n)
        out.Close()
    }

    static Short(msg) {
        msg := Trim(StrSplit(msg, "`n")[1], " `t`r")
        msg := RegExReplace(msg, "^0x[0-9A-Fa-f]+ - ")
        msg := RegExReplace(msg, "^\((.*)\)$", "$1")
        return (StrLen(msg) > 60) ? SubStr(msg, 1, 57) "..." : msg
    }
}
