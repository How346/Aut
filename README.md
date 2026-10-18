# Authly — Clean Authenticator UI

A Flutter-based, offline-first TOTP authenticator.

## UI refresh
- Simplified Google Authenticator-inspired blue-and-white styling.
- Added compact Home / Accounts / Settings bottom navigation.
- Cleaner account cards with readable codes, countdown rings, copy action, and overflow menu for edit/remove.
- Kept the shield-and-lock Authly brand asset.
- Simplified Settings header while retaining security, appearance, encrypted backup export/import, and About options.
- Existing account creation, QR scanning, gallery QR import, paste-link import, Google Authenticator migration, local storage, TOTP algorithms, biometric/device lock, and encrypted backup flows are retained.

## Build
Use Flutter stable and run:

```sh
flutter pub get
flutter analyze
flutter build apk --debug
```

The repository includes `.github/workflows/build.yml` for GitHub Actions APK builds.

Note: This UI update has not been compiled in this environment; run the analyzer and build workflow to validate against your exact Flutter SDK.
