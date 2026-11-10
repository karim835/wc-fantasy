# run.ps1 — launch the WC Fantasy app with the USB port-forward already set up.
#
# Use this INSTEAD of `flutter run`. It first wires `adb reverse` so a phone on
# USB can reach the backend at localhost:3000, then starts Flutter. On Chrome or
# Windows desktop there's no phone, so the adb step is a harmless no-op and
# localhost:3000 already points at the backend on this machine.
#
#   .\run.ps1                 # default device (your phone, if plugged in)
#   .\run.ps1 -d chrome       # run in Chrome
#   .\run.ps1 -d windows      # run as Windows desktop app
#
# Any arguments are forwarded straight to `flutter run`.

# Locate adb: prefer PATH, fall back to the standard Android SDK location.
$adb = (Get-Command adb -ErrorAction SilentlyContinue).Source
if (-not $adb) { $adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" }

if (Test-Path $adb) {
  & $adb reverse tcp:3000 tcp:3000 2>$null
  if ($LASTEXITCODE -eq 0) {
    Write-Host "[run] adb reverse set: phone localhost:3000 -> laptop:3000" -ForegroundColor Green
  } else {
    Write-Host "[run] no USB device for adb reverse (fine for Chrome/desktop)" -ForegroundColor DarkGray
  }
} else {
  Write-Host "[run] adb not found - skipping (fine for Chrome/desktop)" -ForegroundColor DarkGray
}

Write-Host "[run] starting: flutter run $args" -ForegroundColor Cyan
flutter run @args
