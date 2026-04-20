# Firebase Setup Guide for MandarinMate UTM

## Overview
This guide will help you set up Firebase for the MandarinMate UTM application. The app requires Firebase Authentication and Cloud Firestore for user management.

## Prerequisites
- Firebase account (https://console.firebase.google.com/)
- FlutterFire CLI installed: `dart pub global activate flutterfire_cli`

## Step 1: Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Create a project"** or **"Add project"**
3. Enter project name: `MandarinMate UTM` (or your preferred name)
4. Follow the setup wizard
5. Enable Google Analytics (optional)
6. Click **"Create project"**

## Step 2: Configure Authentication

1. In Firebase Console, go to **Authentication** → **Sign-in method**
2. Enable **Email/Password** authentication
3. Disable **Google**, **Facebook**, etc. (optional, you can add later)

## Step 3: Create Firestore Database

1. In Firebase Console, go to **Firestore Database**
2. Click **"Create database"**
3. Select **"Start in production mode"** or **"Start in test mode"** (for development)
4. Choose region: **asia-southeast1** (Singapore, closest to Malaysia)
5. Click **"Create"**

## Step 4: Configure Firestore Security Rules

Replace the default security rules with these for development:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow read/write for authenticated users
    match /users/{uid} {
      allow read, write: if request.auth.uid == uid;
      allow read: if request.auth.uid != null; // Users can read other profiles
    }
    
    // Allow read/write for messages (implement proper rules later)
    match /chats/{document=**} {
      allow read, write: if request.auth.uid != null;
    }
    
    // Allow read/write for forum posts
    match /forum/{document=**} {
      allow read, write: if request.auth.uid != null;
    }
  }
}
```

## Step 5: Generate Firebase Configuration

### Using FlutterFire CLI (Recommended)

1. In your project directory, run:
```bash
flutterfire configure
```

2. Select your Firebase project
3. Select platforms (Android, iOS, Windows, macOS, etc.)
4. The CLI will automatically update your `lib/firebase_options.dart` file

### Manual Configuration

1. Go to Firebase Console → **Project Settings** (gear icon)
2. Go to **Your apps** section
3. For each platform:
   - Click the app
   - Copy the configuration details
   - Update `lib/firebase_options.dart` with the values

#### Android Configuration
- API Key: `android → apiKey`
- App ID: `android → appId`
- Messaging Sender ID: `android → messagingSenderId`
- Project ID: `android → projectId`
- Storage Bucket: `android → storageBucket`

#### iOS Configuration
- API Key: `ios → apiKey`
- App ID: `ios → appId`
- Messaging Sender ID: `ios → messagingSenderId`
- Project ID: `ios → projectId`
- Storage Bucket: `ios → storageBucket`
- Bundle ID: `ios → iosBundleId`

#### Windows/macOS Configuration
- API Key: `windows/macos → apiKey`
- App ID: `windows/macos → appId`
- Messaging Sender ID: `windows/macos → messagingSenderId`
- Project ID: `windows/macos → projectId`
- Storage Bucket: `windows/macos → storageBucket`
- Auth Domain: `windows/macos → authDomain`

## Step 6: Update pubspec.yaml

The project already includes Firebase dependencies in `pubspec.yaml`:
- `firebase_core`
- `firebase_auth`
- `cloud_firestore`
- `firebase_storage`

Run:
```bash
flutter pub get
```

## Step 7: Platform-Specific Setup

### Android Setup
1. Add the Google services JSON file
2. In Android, copy the JSON file from Firebase to `android/app/`
3. Update `build.gradle` files (FlutterFire CLI handles this)

### iOS Setup
1. In iOS, add the GoogleService-Info.plist file
2. Open `ios/Runner.xcworkspace` in Xcode
3. Add the plist file to the Runner project
4. Ensure "Copy items if needed" is checked

### Windows Setup
1. Copy the google-services.json file to the Windows project folder

## Step 8: Test the Setup

1. Run the Flutter app:
```bash
flutter run
```

2. Try registering a new user with a UTM email (ends with @student.utm.my or @utm.my)
3. Check if the user appears in Firebase Console → **Authentication**
4. Check if the user profile appears in **Firestore** → **users** collection

## Database Structure

### Users Collection
```
users/
  {uid}/
    - uid: string
    - email: string
    - username: string
    - firstName: string
    - lastName: string
    - role: "student" | "tutor" | "admin"
    - profileImageUrl: string
    - bio: string (optional)
    - avatar: emoji (optional)
    - level: number
    - xpPoints: number
    - currentStreak: number
    - createdAt: timestamp
    - updatedAt: timestamp
```

## Troubleshooting

### Firebase not initializing
- Verify API keys in `firebase_options.dart`
- Check internet connectivity
- Clear app cache and reinstall

### Authentication errors
- Ensure Email/Password auth is enabled in Firebase Console
- Check that the user exists in Firebase Authentication
- Verify security rules in Firestore

### Firestore permission denied
- Check security rules are updated
- Ensure user is authenticated
- Verify `request.auth.uid` matches document path

## Next Steps

1. Complete other sprint features (Communication, Learning, etc.)
2. Implement image uploads with Firebase Storage
3. Add more authentication methods (Google, Apple, etc.)
4. Implement Firebase Cloud Functions for backend logic
5. Set up Firebase Hosting for web deployment

## Resources

- [Firebase Documentation](https://firebase.google.com/docs)
- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [Firebase Security Rules](https://firebase.google.com/docs/rules)

---

**Note:** Keep your Firebase API keys private. Never commit them to version control.
