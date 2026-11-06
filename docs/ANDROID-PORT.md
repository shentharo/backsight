# Android development build

This is an experimental Android port of Backsight. It uses the existing Tapo
camera backend, stores credentials in Android's Keystore-backed credential
store, and has initial small-screen layout changes. Camera compatibility,
video playback, exports and lifecycle behavior must be verified on a device
before treating it as a production release.

The generated Android project is in `app/src-tauri/gen/android`. Build with
Node.js 22+, JDK 21, Rust 1.95, Android SDK platform 36 and NDK 27.2. Set
`ANDROID_HOME` and `NDK_HOME`, install the Rust `aarch64-linux-android` target,
then run `npm ci` in `app` and `npm run tauri -- android build --debug --target
aarch64`. The workspace Cargo configuration aligns the native library for
Android devices using 16 KB memory pages.

On Windows without symbolic-link privileges, the Tauri build may successfully
compile `target/aarch64-linux-android/debug/libbacksight_lib.so` but fail while
linking it into the Android project. Copy that file into
`app/src-tauri/gen/android/app/src/main/jniLibs/arm64-v8a/`, then run
`gradlew.bat assembleArm64Debug -x rustBuildArm64Debug --no-watch-fs` from
`app/src-tauri/gen/android`. Rebuild the Rust library and frontend before
repeating this workaround after source changes. This creates a debug-signed
APK, not a release for distribution.

The existing desktop export directory and file-reveal behavior are not yet
adapted to Android's scoped storage. Automatic discovery and actual camera
models also need device testing. Camera firmware that only supports TPAP,
battery cameras and hubs remain outside the upstream project's support.

On a Pixel 10 running GrapheneOS, a simulated C200 camera was added and its
live test video and recording thumbnails displayed successfully. This does not
verify authentication, playback or compatibility with a physical camera.

## Updating the source and the installed app

The Android work is on `codex/android-port` in your fork. To download changes
made to that branch, commit or stash any local work first, then run:

```sh
git switch codex/android-port
git pull --ff-only origin codex/android-port
```

To bring in changes from the original project, fetch `upstream` and merge its
`main` branch into your Android branch; resolve any conflicts before building:

```sh
git fetch upstream
git merge upstream/main
```

If `upstream` is not configured in a fresh clone, add it once with
`git remote add upstream https://github.com/AlphaNumeric99/backsight.git`.
After editing or merging, rebuild as described above and install the APK with
`adb install -r path/to/app-arm64-debug.apk`. The existing installation and
app data can be retained only when the new APK has the same application ID
and signing key. Debug keys are usually specific to the machine that built
the APK, so a build from a different machine may not install over this one.
Git updates the source. The signed Android app checks this fork's public
GitHub releases at startup and offers a link to a newer Android release. In
Settings → About, "Check for Android updates" checks on demand. Download the
APK from GitHub and confirm installation in Android; the app does not install
silently. Only published releases tagged `android-vMAJOR.MINOR.PATCH` with a
`backsight-android-arm64.apk` asset are considered.

## Creating a signed Android release on this PC

The signing key and its password are in `%USERPROFILE%\.android\backsight-release`.
Keep a private backup of **both files** somewhere safe, separate from GitHub.
Losing the key prevents future builds from updating this installed app; anyone
who obtains both files can sign updates as you. Do not commit or publish them.
The signed app has a separate application ID from the earlier debug test app,
so both can remain installed and their app data are separate.

For each release, increment the same numeric version in `Cargo.toml` (workspace
package), `app/package.json`, `app/package-lock.json`, and
`app/src-tauri/tauri.conf.json`. Commit and push the source, then run
`powershell -ExecutionPolicy Bypass -File scripts/build-android-release.ps1`.
The script needs the Android SDK, NDK, Rust target and generated Tauri Android
files described above, plus the signing key. It builds an arm64 APK and verifies
its signature and 16 KB alignment. Review and test it on the Pixel, then create
a GitHub release from that exact commit using a tag such as `android-v0.1.1` and
attach the APK as `backsight-android-arm64.apk`. The app only sees published,
non-prerelease releases. Keep the version code increasing and always use the
same signing key.
