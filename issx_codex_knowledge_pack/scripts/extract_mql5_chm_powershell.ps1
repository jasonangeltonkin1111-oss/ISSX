$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ChmPath = Join-Path $ScriptDir "..\knowledge\raw\mql5.chm"
$OutDir = Join-Path $ScriptDir "..\knowledge\extracted_mql5_docs"
if (!(Test-Path $ChmPath)) { throw "CHM not found: $ChmPath" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$hh = Join-Path $env:WINDIR "hh.exe"
if (!(Test-Path $hh)) { throw "hh.exe not found at $hh" }
Start-Process -FilePath $hh -ArgumentList "-decompile`"$OutDir`" `"$ChmPath`"" -Wait
Write-Host "Extracted to $OutDir"
