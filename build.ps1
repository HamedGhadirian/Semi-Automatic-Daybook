<#
  build.ps1 - make the two downloads into dist\

    Daybook-<version>.zip               the script, for people with AutoHotkey v2
    Daybook-<version>-portable.zip      the same plus AutoHotkey64.exe, its
                                        licence and "Start Daybook.bat"
    manifest.json                       the size and SHA-256 of both zips and of
                                        every file in them - what the script
                                        checks a download against before it
                                        updates itself (lib\Kit\Install.ahk)
    notes.md                            this version's section of CHANGELOG.md,
                                        the release notes

  The version comes from DaybookVersion in lib\Config.ahk. On GitHub the
  tag that started the build must match it (v0.2.0 for "0.2.0"), or nothing
  is built - a release can never carry the wrong number.

  .\build.ps1 -AhkDir <folder with AutoHotkey64.exe and its license.txt>
#>
param([Parameter(Mandatory = $true)][string]$AhkDir)

$ErrorActionPreference = "Stop"
$name = "Daybook"            # the folder inside the zips, and the manifest's name
$main = "Daybook.ahk"
$root = $PSScriptRoot
$dist = Join-Path $root "dist"

$m = Select-String -Path (Join-Path $root "lib\Config.ahk") -Pattern 'DaybookVersion := "([^"]+)"'
if (-not $m) { throw "DaybookVersion not found in lib\Config.ahk" }
$version = $m.Matches[0].Groups[1].Value
if ($env:GITHUB_REF_NAME -and $env:GITHUB_REF_NAME -like "v*" -and $env:GITHUB_REF_NAME -ne "v$version") {
    throw "Tag $($env:GITHUB_REF_NAME) does not match DaybookVersion $version in lib\Config.ahk"
}

# the release notes: this version's section of CHANGELOG.md, from its "## "
# heading to the next one. A version without notes is not built.
$log = Get-Content (Join-Path $root "CHANGELOG.md") -Encoding UTF8
$start = -1
for ($i = 0; $i -lt $log.Count; $i++) { if ($log[$i] -match "^## \[?$([regex]::Escape($version))\]?(\s|$)") { $start = $i; break } }
if ($start -lt 0) { throw "CHANGELOG.md has no section for $version" }
$end = $log.Count
for ($i = $start + 1; $i -lt $log.Count; $i++) { if ($log[$i] -match "^## ") { $end = $i; break } }
$notes = ($log[($start + 1)..($end - 1)] -join "`n").Trim()
# GitHub shows every line break in release notes as a break, so a line
# wrapped in CHANGELOG.md joins the one before it
$notes = $notes -replace '\n[ \t]+(?=\S)(?![-*] )', ' '

$exe = Join-Path $AhkDir "AutoHotkey64.exe"
$lic = @("license.txt", "AutoHotkey license.txt") | % { Join-Path $AhkDir $_ } | ? { Test-Path $_ } | Select-Object -First 1
if (-not (Test-Path $exe)) { throw "No AutoHotkey64.exe in $AhkDir" }
if (-not $lic) { throw "No AutoHotkey licence (license.txt) in $AhkDir" }

if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
New-Item -ItemType Directory $dist | Out-Null
# the release page starts with which zip to take (the same two lines in
# every app of the family); the app's own update window leaves them out
$which = "**Which zip?** Most people: **Daybook-$version-portable.zip** - unzip it anywhere and run **Start Daybook.bat**, nothing to install.`n" +
    "Already have AutoHotkey v2? **Daybook-$version.zip**, then run **Daybook.ahk**.`n`n---`n`n"
$notes = $which + $notes
[IO.File]::WriteAllText((Join-Path $dist "notes.md"), $notes + "`n", (New-Object Text.UTF8Encoding $false))
$stage = Join-Path $dist "stage\$name"
New-Item -ItemType Directory -Force (Join-Path $stage "lib\Kit") | Out-Null

# the script: what a user needs, nothing of tests\
Copy-Item (Join-Path $root $main), (Join-Path $root "icon.png"), (Join-Path $root "README.md"), (Join-Path $root "LICENSE") $stage
# the tray's own 16 px picture, when there is one (the kit packs it with the big one)
$twin = Join-Path $root "icon_16x16.png"
if (Test-Path $twin) { Copy-Item $twin $stage }
Copy-Item (Join-Path $root "lib\*.ahk") (Join-Path $stage "lib")
Copy-Item (Join-Path $root "lib\Kit\*.ahk") (Join-Path $stage "lib\Kit")

function Describe($path, $name) {
    $f = Get-Item $path
    [ordered]@{ path = $name; size = $f.Length; sha256 = (Get-FileHash $f.FullName -Algorithm SHA256).Hash.ToLower() }
}
function FilesIn($dir) {
    Get-ChildItem $dir -Recurse -File | Sort-Object FullName | ForEach-Object {
        Describe $_.FullName $_.FullName.Substring($dir.Length + 1).Replace("\", "/")
    }
}

$files = @(FilesIn $stage)
$plain = Join-Path $dist "$name-$version.zip"
Compress-Archive -Path $stage -DestinationPath $plain

Copy-Item $exe $stage
Copy-Item $lic (Join-Path $stage "AutoHotkey license.txt")
Copy-Item (Join-Path $root "portable\Start Daybook.bat") $stage
$extras = @(FilesIn $stage | Where-Object { $p = $_.path; -not ($files | Where-Object { $_.path -eq $p }) })
$portable = Join-Path $dist "$name-$version-portable.zip"
Compress-Archive -Path $stage -DestinationPath $portable

# files: the script (both zips); portable: what only the portable zip adds;
# zips: each zip whole. Written without a BOM.
$manifest = [ordered]@{
    name     = $name
    version  = $version
    files    = $files
    portable = $extras
    zips     = [ordered]@{ plain = (Describe $plain (Split-Path $plain -Leaf)); portable = (Describe $portable (Split-Path $portable -Leaf)) }
}
[IO.File]::WriteAllText((Join-Path $dist "manifest.json"), ($manifest | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding $false))

Remove-Item (Join-Path $dist "stage") -Recurse -Force
Get-ChildItem $dist | ForEach-Object { "{0,-40} {1,10:N0} bytes" -f $_.Name, $_.Length }
