# Marble Sort: one-shot developer setup for Windows 11.
# Installs Git and Flutter, connects Flutter to Android Studio's SDK,
# accepts the Android licences, and gets the game ready to run.
#
# Run in the Terminal app (not as administrator):
#   irm https://raw.githubusercontent.com/Jay7255/marble-sort/main/tool/setup_windows.ps1 | iex
#
# Safe to run again: every step skips itself if it's already done.

function Install-MarbleSort {
  $ErrorActionPreference = 'Stop'
  function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
  function Stop-With($msg) { Write-Host "`n$msg" -ForegroundColor Yellow; Write-Host 'Then run the same command again.' -ForegroundColor Yellow }

  # ---- 1. Android Studio's SDK must exist ----
  Step 'Checking Android Studio'
  $sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
  if (-not (Test-Path (Join-Path $sdk 'platform-tools'))) {
    Stop-With "The Android SDK isn't installed yet. Open Android Studio, choose 'Standard' in the setup wizard, and let it finish downloading."
    return
  }
  if (-not (Test-Path (Join-Path $sdk 'cmdline-tools'))) {
    Stop-With "One Android Studio component is missing. In Android Studio open Settings > Languages & Frameworks > Android SDK > 'SDK Tools' tab, tick 'Android SDK Command-line Tools' and 'Google USB Driver', and click Apply."
    return
  }
  Write-Host 'Android SDK found.'

  # ---- 2. Git ----
  Step 'Checking Git'
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host 'Installing Git (a Windows permission prompt may appear; click Yes)...'
    winget install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements
    $env:Path += ';C:\Program Files\Git\cmd'
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
      Stop-With 'Git did not install. Install it from https://git-scm.com/download/win with the default options.'
      return
    }
  }
  Write-Host "Git ready: $(git --version)"

  # ---- 3. Flutter SDK ----
  Step 'Checking Flutter'
  $flutterDir = 'C:\src\flutter'
  if (-not (Test-Path (Join-Path $flutterDir 'bin\flutter.bat'))) {
    Write-Host 'Downloading Flutter (a few hundred MB, this can take a while)...'
    New-Item -ItemType Directory -Force -Path 'C:\src' | Out-Null
    git clone https://github.com/flutter/flutter.git -b stable $flutterDir
  }
  $flutterBin = Join-Path $flutterDir 'bin'
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  if (($userPath -split ';') -notcontains $flutterBin) {
    [Environment]::SetEnvironmentVariable('Path', "$userPath;$flutterBin", 'User')
    Write-Host 'Added Flutter to your PATH.'
  }
  if (($env:Path -split ';') -notcontains $flutterBin) { $env:Path += ";$flutterBin" }
  flutter config --no-analytics --android-sdk $sdk | Out-Null
  flutter --version

  # ---- 4. Android licences ----
  Step 'Accepting Android licences'
  ('y' + "`n") * 20 | flutter doctor --android-licenses | Out-Null
  Write-Host 'Licences accepted.'

  # ---- 5. The game ----
  Step 'Getting the Marble Sort code'
  $project = Join-Path $env:USERPROFILE 'marble-sort'
  if (-not (Test-Path (Join-Path $project '.git'))) {
    git clone https://github.com/Jay7255/marble-sort.git $project
  } else {
    git -C $project pull --ff-only
  }
  Set-Location $project
  if (-not (Test-Path 'android')) {
    flutter create . --org com.jonathangames --project-name marble_sort --platforms android
  }
  dart run tool/configure.dart
  flutter pub get

  # ---- 6. Report ----
  Step 'Final check'
  flutter doctor
  Write-Host "`nAll set. The game is in: $project" -ForegroundColor Green
  Write-Host 'Next: plug in your Pixel (USB debugging on), then run:  cd ~\marble-sort ; flutter run' -ForegroundColor Green
  Write-Host "Or open that folder in Android Studio (File > Open) and press the green Run button." -ForegroundColor Green
}

Install-MarbleSort
