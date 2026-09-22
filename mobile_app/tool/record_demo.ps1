<#
.SYNOPSIS
  Records the scripted demo tour (integration_test/demo_tour_test.dart) from a running Android emulator.

.DESCRIPTION
  Starts the tour, begins `adb shell screenrecord` when the tour logs DEMO_TOUR_START (so the build time is
  not recorded), stops it cleanly on DEMO_TOUR_END, and pulls the MP4 to build\demo\. Don't touch the
  emulator while it records. screenrecord caps a single recording at 3 minutes.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tool\record_demo.ps1
#>
param(
    [string]$Device = "emulator-5554",
    [string]$Output = "build\demo\ram-intellect-demo.mp4",
    [string]$Size = "720x1600",
    [int]$BitRate = 4000000
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root
$adb = if ($env:ANDROID_HOME) { Join-Path $env:ANDROID_HOME "platform-tools\adb.exe" } else { "adb" }
$remote = "/sdcard/ram-intellect-demo.mp4"
$log = Join-Path $env:TEMP "demo_tour.log"

& $adb -s $Device shell am force-stop com.ramintellect.learning_app
& $adb -s $Device logcat -c
& $adb -s $Device shell rm -f $remote

Write-Host "Building and starting the tour (first build takes a few minutes)..."
$tour = Start-Process -FilePath "flutter.bat" -ArgumentList "test", "integration_test/demo_tour_test.dart", "-d", $Device `
    -RedirectStandardOutput $log -RedirectStandardError "$log.err" -NoNewWindow -PassThru

function Wait-ForLog([string]$marker, [int]$timeoutSeconds) {
    $deadline = (Get-Date).AddSeconds($timeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if ((Test-Path $log) -and (Select-String -Path $log -Pattern $marker -Quiet)) { return $true }
        if ($tour.HasExited) { return $false }
        Start-Sleep -Milliseconds 500
    }
    return $false
}

# Start recording as soon as the tour app is running (its opening pause covers engine start-up).
$deadline = (Get-Date).AddSeconds(900)
$started = $false
while ((Get-Date) -lt $deadline -and -not $tour.HasExited) {
    $appPid = (& $adb -s $Device shell pidof com.ramintellect.learning_app 2>$null)
    if ($appPid -and ((& $adb -s $Device logcat -d -s flutter:I) -match "Dart VM service")) { $started = $true; break }
    Start-Sleep -Milliseconds 300
}
if (-not $started) {
    Get-Content $log -Tail 30
    throw "The tour did not start. See $log"
}

Write-Host "Recording..."
$recorder = Start-Process -FilePath $adb -ArgumentList "-s", $Device, "shell", "screenrecord", "--size", $Size, `
    "--bit-rate", $BitRate, "--time-limit", "180", $remote -NoNewWindow -PassThru

$tour.WaitForExit(240000) | Out-Null
$finished = Select-String -Path $log -Pattern "DEMO_TOUR_END" -Quiet
Start-Sleep -Seconds 1
# SIGINT lets screenrecord finalise the MP4 (killing adb would leave a broken file).
& $adb -s $Device shell pkill -INT screenrecord | Out-Null
$recorder.WaitForExit(15000) | Out-Null
$tour.WaitForExit(120000) | Out-Null

New-Item -ItemType Directory -Force (Split-Path $Output) | Out-Null
& $adb -s $Device pull $remote $Output | Out-Null
& $adb -s $Device shell rm -f $remote

Get-Content $log -Tail 3
if (-not $finished) { Write-Warning "The tour did not reach the end; the video may be cut short. See $log" }
Get-Item $Output | Select-Object FullName, @{ n = "MB"; e = { [math]::Round($_.Length / 1MB, 1) } }
