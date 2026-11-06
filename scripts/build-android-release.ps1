param([string]$Sdk = "$env:LOCALAPPDATA\Android\Sdk")
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$env:RUSTUP_TOOLCHAIN = '1.95.0'
$env:ANDROID_HOME = $Sdk
$env:NDK_HOME = Join-Path $Sdk 'ndk\27.2.12479018'
$bin = Join-Path $env:NDK_HOME 'toolchains\llvm\prebuilt\windows-x86_64\bin'
$env:PATH = "$bin;$env:PATH"
$env:CC_aarch64_linux_android = Join-Path $bin 'aarch64-linux-android24-clang.cmd'
$env:AR_aarch64_linux_android = Join-Path $bin 'llvm-ar.exe'
$env:CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER = $env:CC_aarch64_linux_android
$signDir = Join-Path $env:USERPROFILE '.android\backsight-release'
$key = Join-Path $signDir 'backsight-release.jks'
$password = Join-Path $signDir 'password.txt'
if (!(Test-Path $key) -or !(Test-Path $password)) { throw 'Release signing key or password is missing. Restore your private backup.' }
$version = (Get-Content app\src-tauri\tauri.conf.json -Raw | ConvertFrom-Json).version
$packageVersion = (Get-Content app\package.json -Raw | ConvertFrom-Json).version
$cargoText = Get-Content Cargo.toml -Raw
if ($version -notmatch '^(\d+)\.(\d+)\.(\d+)$') { throw 'Use a numeric major.minor.patch version.' }
$major=[int]$Matches[1]; $minor=[int]$Matches[2]; $patch=[int]$Matches[3]
if ($major -gt 999 -or $minor -gt 999 -or $patch -gt 999) { throw 'Version component too large.' }
if ($packageVersion -ne $version -or $cargoText -notmatch "(?m)^version = `"$([regex]::Escape($version))`"\r?$") { throw 'Set the same version in package.json, tauri.conf.json and the workspace Cargo.toml.' }
$code = $major * 1000000 + $minor * 1000 + $patch
if (!(Test-Path 'app\src-tauri\gen\android\tauri.settings.gradle')) { throw 'Initialize the Tauri Android project on this machine first; see docs/ANDROID-PORT.md.' }
[IO.File]::WriteAllText((Join-Path $root 'app\src-tauri\gen\android\app\tauri.properties'), "tauri.android.versionName=$version`ntauri.android.versionCode=$code`n")
Push-Location app
try { npm ci; if ($LASTEXITCODE) { throw 'npm ci failed' }; npm run build; if ($LASTEXITCODE) { throw 'Frontend build failed' } } finally { Pop-Location }
cargo rustc -p backsight --lib --release --target aarch64-linux-android --features tauri/custom-protocol
if ($LASTEXITCODE) { throw 'Android Rust build failed' }
New-Item -ItemType Directory -Force -Path app\src-tauri\gen\android\app\src\main\jniLibs\arm64-v8a | Out-Null
Copy-Item target\aarch64-linux-android\release\libbacksight_lib.so app\src-tauri\gen\android\app\src\main\jniLibs\arm64-v8a\libbacksight_lib.so -Force
Push-Location app\src-tauri\gen\android
try { .\gradlew.bat assembleArm64Release -x rustBuildArm64Release --no-daemon --no-watch-fs; if ($LASTEXITCODE) { throw 'Android packaging failed' } } finally { Pop-Location }
$tools = Join-Path $Sdk 'build-tools\36.0.0'
$unsigned = Join-Path $root 'app\src-tauri\gen\android\app\build\outputs\apk\arm64\release\app-arm64-release-unsigned.apk'
$aligned = Join-Path $env:TEMP 'backsight-release-aligned.apk'
$out = Join-Path $root 'app\src-tauri\gen\android\app\build\outputs\apk\arm64\release\backsight-android-arm64.apk'
try {
  & "$tools\zipalign.exe" -f -P 16 4 $unsigned $aligned; if ($LASTEXITCODE) { throw 'Alignment failed' }
  $env:BACKSIGHT_KEY_PASSWORD = [IO.File]::ReadAllText($password)
  & "$tools\apksigner.bat" sign --ks $key --ks-key-alias backsight --ks-pass env:BACKSIGHT_KEY_PASSWORD --key-pass env:BACKSIGHT_KEY_PASSWORD --out $out $aligned
  if ($LASTEXITCODE) { throw 'Signing failed' }
  & "$tools\apksigner.bat" verify $out; if ($LASTEXITCODE) { throw 'Signature verification failed' }
  & "$tools\zipalign.exe" -c -P 16 4 $out; if ($LASTEXITCODE) { throw 'Alignment verification failed' }
} finally { Remove-Item Env:BACKSIGHT_KEY_PASSWORD -ErrorAction SilentlyContinue; Remove-Item $aligned -ErrorAction SilentlyContinue }
Write-Output "Signed APK: $out"
