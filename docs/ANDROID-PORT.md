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
