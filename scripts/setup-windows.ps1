<#
.SYNOPSIS
  Installs the Ram Intellect mobile toolchain on Windows: Flutter SDK, Android SDK and an Android emulator.

.DESCRIPTION
  Safe to re-run: every step is skipped if already done. Installs into paths WITHOUT spaces
  (Flutter's build hooks break on paths like "C:\Users\First Last").

  Prerequisites you install yourself (see SETUP.md): Git, JDK 17+ (IntelliJ's bundled JDK is fine).

  Running this script downloads ~4 GB from github.com and dl.google.com, and accepts the
  Android SDK License Agreement (https://developer.android.com/studio/terms) on your behalf.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\setup-windows.ps1
  powershell -ExecutionPolicy Bypass -File scripts\setup-windows.ps1 -JavaHome "C:\Program Files\Java\jdk-21"
#>
param(
    [string]$FlutterDir = "C:\src\flutter",
    [string]$AndroidSdk = "C:\src\android-sdk",
    [string]$JavaHome = $env:JAVA_HOME,
    [string]$AvdName = "Pixel_8_API_35",
    [string]$SystemImage = "system-images;android-35;google_apis_playstore;x86_64"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Update both when Google publishes a new build: https://developer.android.com/studio#command-line-tools-only
$CmdlineToolsZip = "commandlinetools-win-15859902_latest.zip"
$CmdlineToolsSha256 = "90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a"

function Step($text) { Write-Host "`n==> $text" -ForegroundColor Cyan }

# --- Java -------------------------------------------------------------------
Step "Checking Java"
if (-not $JavaHome) {
    $candidate = Get-ChildItem "$env:USERPROFILE\.jdks" -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path "$($_.FullName)\bin\java.exe" } | Select-Object -First 1
    if ($candidate) { $JavaHome = $candidate.FullName }
}
if (-not $JavaHome -or -not (Test-Path "$JavaHome\bin\java.exe")) {
    throw "No JDK found. Install JDK 17+ and re-run with -JavaHome <path>."
}
$env:JAVA_HOME = $JavaHome
Write-Host "Using JAVA_HOME=$JavaHome"

# --- Flutter ----------------------------------------------------------------
Step "Flutter SDK -> $FlutterDir"
if (Test-Path "$FlutterDir\bin\flutter.bat") {
    Write-Host "Already installed."
} else {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "Git is required: https://git-scm.com/download/win" }
    New-Item -ItemType Directory -Force (Split-Path $FlutterDir) | Out-Null
    git clone --depth 1 -b stable https://github.com/flutter/flutter.git $FlutterDir
}
$flutter = "$FlutterDir\bin\flutter.bat"

# --- Android command-line tools --------------------------------------------
Step "Android SDK -> $AndroidSdk"
$sdkmanager = "$AndroidSdk\cmdline-tools\latest\bin\sdkmanager.bat"
if (Test-Path $sdkmanager) {
    Write-Host "Command-line tools already installed."
} else {
    $zip = Join-Path $env:TEMP $CmdlineToolsZip
    Invoke-WebRequest "https://dl.google.com/android/repository/$CmdlineToolsZip" -OutFile $zip
    $hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
    if ($hash -ne $CmdlineToolsSha256) { Remove-Item $zip; throw "Checksum mismatch for $CmdlineToolsZip" }
    New-Item -ItemType Directory -Force "$AndroidSdk\cmdline-tools" | Out-Null
    Expand-Archive $zip -DestinationPath "$AndroidSdk\cmdline-tools" -Force
    Rename-Item "$AndroidSdk\cmdline-tools\cmdline-tools" "latest"
    Remove-Item $zip
}

Step "Accepting Android SDK licences and installing packages (~3 GB)"
$env:ANDROID_HOME = $AndroidSdk
"y`n" * 20 | & $sdkmanager --licenses | Out-Null
& $sdkmanager --install "platform-tools" "emulator" "platforms;android-36" "build-tools;36.0.0" $SystemImage
if ($LASTEXITCODE -ne 0) { throw "sdkmanager failed" }

# --- Emulator ---------------------------------------------------------------
Step "Android emulator '$AvdName'"
$avdmanager = "$AndroidSdk\cmdline-tools\latest\bin\avdmanager.bat"
$existing = & $avdmanager list avd -c
if ($existing -contains $AvdName) {
    Write-Host "Already exists."
} else {
    # avdmanager may print "Could not load devices ... devices.xml" yet still create the AVD; check the result instead.
    "no" | & $avdmanager create avd --name $AvdName --package $SystemImage --device "pixel_8" 2>&1 | Out-Null
    if ((& $avdmanager list avd -c) -notcontains $AvdName) { throw "Failed to create emulator $AvdName" }
    # Host GPU for smooth rendering, PC keyboard input, and enough RAM for Play services.
    $config = "$env:USERPROFILE\.android\avd\$AvdName.avd\config.ini"
    (Get-Content $config) `
        -replace '^hw.gpu.enabled=.*', 'hw.gpu.enabled=yes' `
        -replace '^hw.gpu.mode=.*', 'hw.gpu.mode=host' `
        -replace '^hw.keyboard=.*', 'hw.keyboard=yes' `
        -replace '^hw.ramSize=.*', 'hw.ramSize=4G' | Set-Content $config -Encoding ascii
}

# --- Wire Flutter to the SDK and put tools on PATH (current user only) ------
Step "Configuring Flutter and user PATH"
& $flutter config --android-sdk $AndroidSdk | Out-Null
[Environment]::SetEnvironmentVariable("ANDROID_HOME", $AndroidSdk, "User")
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
foreach ($dir in @("$FlutterDir\bin", "$AndroidSdk\platform-tools", "$AndroidSdk\emulator")) {
    if (($userPath -split ";") -notcontains $dir) { $userPath = "$userPath;$dir" }
}
[Environment]::SetEnvironmentVariable("Path", $userPath.Trim(";"), "User")

Step "Checking hardware acceleration"
& "$AndroidSdk\emulator\emulator.exe" -accel-check

Step "flutter doctor"
& $flutter doctor

Write-Host "`nDone. Open a NEW terminal so PATH changes apply, then:" -ForegroundColor Green
Write-Host "  flutter emulators --launch $AvdName"
Write-Host "  cd mobile_app; flutter run"
