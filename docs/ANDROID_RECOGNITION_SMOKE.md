# Android release recognition regression

On 2026-10-16, Android release builds reproduced the tester's
`InputImageConverterError` with a `NullPointerException` invoking `Object.getClass()`.
The same NV21 bytes passed in a debug build. Release logcat showed
`NoSuchMethodException: <Registrar>.<init> []` for ML Kit's common, vision common,
barcode, and text component registrars. R8 had removed the no-argument constructors
used by manifest-based reflective discovery. The missing shared preferences
component then caused an exception inside ML Kit's image telemetry initialization.

The narrow keep rule in `android/app/proguard-rules.pro` retains those registrar
classes and constructors. It does not disable release minification.

## Native regression check

Use a dedicated Android emulator. This test replaces this application's APK on
that emulator, so do not use an emulator containing valuable app data. Supply the
normal release-signing environment described in `android-release-signing.md`.

```powershell
flutter build apk --release --target tool/recognition_native_smoke.dart
./scripts/test-android-recognition.ps1 -Serial emulator-5554
```

The script only accepts emulator devices. It requires an explicit `ALL_PASS`
marker from the current app process and fails on errors or a 30-second timeout.
The fixture is generated in memory: a valid EAN-13 (`4901234567894`) and Japanese
tax-inclusive price text. Both real ML Kit recognizers must decode it at 0, 90,
and 270 degrees. This covers native initialization and image conversion with R8
enabled, which Flutter unit tests and debug APK builds do not exercise.

The fixed release probe passed all three rotations on API 35 x86_64. This is not
physical-camera acceptance on the tester's Xiaomi device.

## Production artifact

The smoke APK has an alternate entry point. Never distribute it as the app.
Build the Play artifact explicitly from the application entry point:

```powershell
flutter build appbundle --release --target lib/main.dart
```
