# Firebase Configuration Setup Guide

## Overview

Firebase configuration files (`firebase_options.dart` and `google-services.json`) contain sensitive API keys and should **NEVER** be committed to Git.

Instead, each developer regenerates these files locally using the `flutterfire` CLI tool.

## Setup Steps (One-Time)

### 1. Ensure You Have FlutterFire CLI Installed

```bash
dart pub global activate flutterfire_cli
```

### 2. Generate Firebase Configuration Files

Navigate to your project root and run:

```bash
cd mandarinmate
flutterfire configure
```

This command will:
- Ask you to sign in to your Firebase account
- Display available Firebase projects
- Generate `lib/firebase_options.dart`
- Update `android/app/google-services.json`
- Generate `ios/Runner/GoogleService-Info.plist` (if building for iOS)

### 3. Select the Correct Firebase Project

When prompted, select: **mandarinmate-utm**

### 4. Verify the Configuration

Check that the files were generated:
```bash
ls -la lib/firebase_options.dart
ls -la android/app/google-services.json
```

## Files Generated

These files are **gitignored** and won't be committed:

| File | Platform | Purpose |
|------|----------|---------|
| `lib/firebase_options.dart` | All | Contains API keys for all platforms |
| `android/app/google-services.json` | Android | Android-specific Firebase config |
| `ios/Runner/GoogleService-Info.plist` | iOS | iOS-specific Firebase config |

## Development Workflow

### New Developer Setup

```bash
# Clone the repository
git clone <repo-url>
cd mandarinmate

# Install dependencies
flutter pub get

# Generate Firebase configuration
flutterfire configure

# Run the app
flutter run
```

### After Updating Firebase Project

If you change Firebase settings (add new services, update keys, etc.):

```bash
# Regenerate the configuration files
flutterfire configure

# The command will update the existing files
```

## For CI/CD (GitHub Actions, etc.)

For automated builds, you have two options:

### Option 1: Store Firebase Config as Secrets

Store the Firebase config files as base64-encoded GitHub Secrets:

```bash
# Encode the file
base64 -i android/app/google-services.json

# Add to GitHub Secrets as FIREBASE_CONFIG_ANDROID
```

### Option 2: Use Environment Variables

Use `firebase_core` with environment-based initialization (requires custom implementation).

## Troubleshooting

### Error: "No Firebase project found"

Make sure you're signed into Firebase:
```bash
dart pub global run flutterfire_cli:flutterfire login
```

### Error: "This app is not registered in Firebase"

Regenerate the configuration:
```bash
flutterfire configure
```

### Build Fails: "google-services.json not found"

Run:
```bash
flutterfire configure
```

This regenerates the file locally.

## Security Best Practices

✅ **DO:**
- Generate files locally with `flutterfire configure`
- Add Firebase config files to `.gitignore`
- Use environment variables for sensitive data in CI/CD
- Rotate API keys regularly

❌ **DON'T:**
- Commit `firebase_options.dart` to Git
- Commit `google-services.json` to Git
- Share API keys via email or chat
- Expose API keys in client-side code (they're semi-public in Flutter)

## Reference

- [FlutterFire CLI Documentation](https://firebase.flutter.dev/docs/cli/)
- [Firebase Console](https://console.firebase.google.com/)
- [Firebase Security Best Practices](https://firebase.google.com/docs/rules/best-practices)
