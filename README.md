# Authly — Professional Flutter Authenticator

Authly is an offline-first, privacy-focused, zero-telemetry two-factor authentication (2FA/TOTP) application built with Flutter, Material 3, and Android Keystore hardware-backed encryption.

## Key Features

- **Standard TOTP Engine (RFC 6238 / RFC 4226)**: Supports SHA-1, SHA-256, SHA-512, 6 or 8 digits, 30s or 60s periods.
- **Hardware-Backed Encryption**: Account secrets are stored securely via `flutter_secure_storage` utilizing the Android Keystore.
- **QR Code Scanning**: High-speed camera scanner using `mobile_scanner` with torch toggle and camera switching.
- **Encrypted Vault Backup & Restore**: Export and import password-protected, HMAC-authenticated backup files.
- **Material 3 UI**: Polished Deep Navy dark mode and clean light theme with live countdown rings and haptic feedback.
- **Zero Cloud Dependence**: 100% offline, zero network requests, zero ads, zero trackers.

## Highlights

- Brand logo (shield + padlock) used for the launcher icon, splash and in-app artwork.
- Codes use the bundled JetBrains Mono font (SIL OFL licence in `assets/fonts/`).

- Splash, 3-step onboarding, bottom navigation (Home / Accounts / Settings), account details, edit, empty state.
- Add accounts by camera scan, **QR from gallery**, setup key, popular-service shortcuts, pasted `otpauth://` link, or a Google Authenticator export QR.
- App lock with 4-digit PIN (PBKDF2-hashed, Android Keystore storage), biometric unlock, auto-lock timeout, hide-PIN option and attempt lockout.
- Light / dark / system theme with 5 accent colours.
- Encrypted `.authly` export / import (file, share sheet, clipboard) and "Clear all accounts".
- **Mask 2FA codes** (Settings or the eye in the home header): codes show as bullets until you tap the eye on a card (auto-hides after 10 s).
- Codes animate digit by digit when they refresh; the countdown ring sweeps smoothly and pulses in the last 5 seconds.
- Clipboard auto-clear after 30 s; screenshots blocked (`FLAG_SECURE`); no network permission.

## Automated Builds with GitHub Actions

The repository includes `.github/workflows/build.yml` configured to:
1. Use Flutter stable and Java 17.
2. Analyze and test the codebase.
3. Build both **Debug APK** and **Release APK**.
4. Automatically publish the APKs as downloadable workflow artifacts.

### How to Build Your APK on GitHub

1. Push this repository to GitHub.
2. Go to the **Actions** tab in your repository.
3. Select **Authly Android CI** and trigger it via `Run workflow` (or simply push to `main`).
4. Once completed, download the generated APK from the **Artifacts** section at the bottom of the run summary.

## Backups

Backups are `.authly` files: PBKDF2-HMAC-SHA256 (210,000 iterations, 32-byte salt) + AES-256-GCM (12-byte nonce, 16-byte tag). Keep the password safe; it cannot be recovered.

## Local setup

This archive has no Gradle wrapper jar or app icons. Run `flutter create . --platforms=android --project-name authly --org com.authly` once to generate them (existing files are kept), then `flutter run`.
