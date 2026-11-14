<#
  run-tests.ps1 - check Daybook before a release

  1. AutoHotkey's syntax check of Daybook.ahk and everything it includes,
     and of lib\Kit\Updater.ahk (the update helper), which runs on its own.
     Warnings count too: a local variable that has the name of a global one
     is how a v2 function quietly fails to change what it means to.
  2. every *.test.ahk beside this file - the rules. No panel, no tray, no
     key; nothing shows on screen except, for a moment far off it, the
     journal window being built.
  3. where the kit's master is beside this folder (the author's PC): this
     copy of lib\Kit must be the same as the master

    .\run-tests.ps1                  everything
    .\run-tests.ps1 -Ahk <path>      a particular AutoHotkey64.exe (v2)

  Exit code 0 when everything passed.
#>
param([string]$Ahk = "")

$here = $PSScriptRoot
$root = Split-Path $here -Parent

if (-not $Ahk) {
    $candidates = @($env:AHK_EXE,
        "$root\AutoHotkey64.exe",
        "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe",
        "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe")
    $Ahk = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}
if (-not $Ahk -or -not (Test-Path $Ahk)) { Write-Host "AutoHotkey v2 not found - pass -Ahk <path to AutoHotkey64.exe>"; exit 2 }
Write-Host "AutoHotkey: $Ahk"

$failed = 0

# 1. syntax, and the warnings of Daybook's own files
$warn = Join-Path $here "warn.ahk"
Set-Content $warn "#Warn All, StdOut`r`n#Include `"$root\Daybook.ahk`"" -Encoding UTF8
foreach ($f in @($warn, "$root\lib\Kit\Updater.ahk")) {
    $p = Start-Process $Ahk -ArgumentList "/Validate /ErrorStdOut `"$f`"" -PassThru -NoNewWindow -Wait `
        -RedirectStandardError "$here\validate.err" -RedirectStandardOutput "$here\validate.out"
    $err = (Get-Content "$here\validate.err" -Raw -ErrorAction SilentlyContinue) +
           ((Get-Content "$here\validate.out" -ErrorAction SilentlyContinue |
             Where-Object { $_ -match '^\S' -and $_ -notmatch '\\lib\\Kit\\' }) -join "`n")
    $name = if ($f -eq $warn) { "Daybook.ahk" } else { Split-Path $f -Leaf }
    if ($p.ExitCode -eq 0 -and -not $err.Trim()) { Write-Host "PASS syntax: $name" }
    else { Write-Host "FAIL syntax: $name`n$err"; $failed++ }
}
Remove-Item "$here\validate.err", "$here\validate.out", $warn -ErrorAction SilentlyContinue

# 2. the tests
foreach ($t in Get-ChildItem $here -Filter *.test.ahk | Sort-Object Name) {
    $name = $t.Name -replace "\.test\.ahk$", ""
    $out = "$here\results-$name.txt"
    Remove-Item $out -ErrorAction SilentlyContinue
    $p = Start-Process $Ahk -ArgumentList "/ErrorStdOut `"$($t.FullName)`"" -PassThru
    if (-not $p.WaitForExit(180000)) { $p.Kill(); Write-Host "FAIL $name : did not finish in 3 minutes"; $failed++; continue }
    if (-not (Test-Path $out)) { Write-Host "FAIL $name : wrote no results"; $failed++; continue }
    $lines = Get-Content $out -Encoding UTF8
    $bad = @($lines | Where-Object { $_ -like "FAIL*" })
    $n = @($lines | Where-Object { $_ -like "PASS*" }).Count
    if ($bad.Count -or $lines -notcontains "DONE") {
        Write-Host "--- $name : $n passed, $($bad.Count) failed"
        $lines | Where-Object { $_ -notlike "PASS*" -and $_ -ne "DONE" } | ForEach-Object { Write-Host "  $_" }
        if ($lines -notcontains "DONE") { Write-Host "  stopped before the end" }
        $failed += [Math]::Max(1, $bad.Count)
    } else {
        Write-Host "PASS $name ($n checks)"
    }
}

# 3. the kit copy against its master, where there is one
$master = Join-Path (Split-Path $root -Parent) "lib\Kit"
if (Test-Path "$master\Kit.ahk") {
    $diff = @()
    foreach ($f in Get-ChildItem $master -Filter *.ahk -File) {
        $copy = Join-Path "$root\lib\Kit" $f.Name
        if (-not (Test-Path $copy) -or (Get-FileHash $copy).Hash -ne (Get-FileHash $f.FullName).Hash) { $diff += $f.Name }
    }
    foreach ($f in Get-ChildItem "$root\lib\Kit" -Filter *.ahk -File) {
        if (-not (Test-Path (Join-Path $master $f.Name))) { $diff += "$($f.Name) (not in the master)" }
    }
    if ($diff) { Write-Host "FAIL kit copy differs from the master: $($diff -join ', ') - run Tools\Sync-Kit.ps1"; $failed++ }
    else { Write-Host "PASS kit copy is the master's" }
}

Write-Host ""
if ($failed) { Write-Host "$failed FAILED"; exit 1 }
Write-Host "ALL PASSED"; exit 0
