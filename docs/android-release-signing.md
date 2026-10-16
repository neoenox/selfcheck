# Android release signing

Release artifacts must never fall back to the Android debug key.

## Required environment variables

Before running a release build, provide all four values through the local shell or the protected CI secret store:

- `SELFCHECK_KEYSTORE_PATH` — path to the release keystore file
- `SELFCHECK_KEYSTORE_PASSWORD` — keystore password
- `SELFCHECK_KEY_ALIAS` — signing key alias
- `SELFCHECK_KEY_PASSWORD` — signing key password

The Gradle configuration fails before a release build when any value is missing. Debug builds do not require these values.

Example command after the environment has been configured:

```bash
flutter build appbundle --release
```

Do not pass passwords as command-line arguments, print them in logs, add them to tracked property files, or commit keystore files. `.jks`, `.keystore`, and `key.properties` are ignored by Git.

## CI

Use a protected secret-bearing environment/job. Materialize a keystore only for the release job, point `SELFCHECK_KEYSTORE_PATH` at that temporary file, and delete it after the build. Untrusted pull-request code must not receive signing secrets.

This repository does not create, rotate, or distribute signing credentials. Those privileged operations require a separate operator decision.

## Authorized local internal-test release

The user authorized creation of a dedicated upload key on 2026-10-14. Existing
local material is stored outside the repository:

- Keystore: `%USERPROFILE%\.selfcheck-upload.jks`, alias `upload`.
- Password: `%USERPROFILE%\.selfcheck-upload-password.dpapi`, encrypted for the
  current Windows user. Trim the file's trailing newline before converting it
  back to a SecureString. Load password environment variables only in the build
  process and clear them in `finally`.
- Upload certificate SHA-256:
  `73:F5:3A:7E:13:61:69:19:52:06:AB:2F:86:A4:02:27:B2:17:B4:02:2D:99:3A:F6:86:99:72:2E:44:5D:D6:C9`.

Back up both local signing files securely; do not recreate or overwrite the key
for an update. Verify Play's upload certificate and highest versionCode before
building subsequent releases.

Release shrinking uses `proguard-rules.pro` to suppress only the six optional
Chinese, Devanagari and Korean recognizer classes referenced by the Flutter
plugin. The application invokes the bundled Japanese recognizer. Other missing
classes continue to fail the build; shrinking is not disabled.
