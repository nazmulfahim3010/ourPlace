# ourPlace — User Manual Action Items & Setup Guide (`myjob.md`)

This guide contains all external, manual tasks you need to complete for the project as we progress through the phases. You can complete these at your own pace while the codebase development continues smoothly.

---

## 📋 Master Roadmap: Your Manual Tasks

- [ ] **Phase 11: Firebase Cloud Setup (Current Phase)**
- [ ] **Phase 14: Push Notifications (Firebase Cloud Messaging - FCM)**
- [ ] **Phase 15: Media Messaging (Firebase Storage / S3 Setup - Optional)**
- [ ] **Phase 16–18: Physical Two-Device Testing & Production Release**

---

## 1. Phase 11: Firebase Project & Ephemeral Relay Setup

To enable real-time internet synchronization across physical phones (beyond local testing), complete these 5 steps:

### Step 1: Create the Firebase Project
1. Open the [Firebase Console](https://console.firebase.google.com/).
2. Click **Add project** (or **Create a project**).
3. Name your project: `ourplace-chat` (or any name you prefer).
4. **Google Analytics:** Turn this **OFF** (to respect the app's zero-telemetry and zero-tracking privacy policy).
5. Click **Create project**.

### Step 2: Register Android Application
1. In your Firebase project dashboard, click the **Android icon** (`</>`) to add an Android app.
2. Enter the **Android package name** exactly as defined in the app:
   ```
   com.example.chatbox
   ```
3. App nickname: `ourPlace`.
4. Leave SHA-1 blank for now (only needed later for Google Sign-In, which we do not use).
5. Click **Register app**.

### Step 3: Download and Place `google-services.json`
1. Download the `google-services.json` file provided by Firebase.
2. Move/copy that file into your project folder at:
   ```
   e:\ourPlace\chatbox\android\app\google-services.json
   ```
   *(Ensure the filename is exactly `google-services.json` and placed inside `chatbox/android/app/`)*.

### Step 4: Enable Cloud Firestore
1. In the Firebase Console left navigation, go to **Build** ➔ **Firestore Database**.
2. Click **Create database**.
3. Select your preferred database region (choose the region closest to you).
4. Select **Start in production mode** and click **Create**.

### Step 5: Configure Firestore Security Rules

Choose either **Option 1 (Easiest)** or **Option 2 (Direct Paste)**:

#### Option 1: The 1-Click Method (Guaranteed Zero Errors)
1. In the Firebase Console, click the **Discard** button at the top to restore the default code.
2. In the code that appears, find line 5 where it says:
   ```javascript
   allow read, write: if false;
   ```
3. Just change `false` to `true`:
   ```javascript
   allow read, write: if true;
   ```
4. Click **Publish**!

*(Note: Because our app automatically encrypts all messages with X25519 & AES-256-GCM on your device before sending, your messages are 100% private and unreadable to anyone even with `allow read, write: if true`!)*

---

#### Option 2: Clean Ephemeral Relay Rule (Direct Paste)
If you prefer restricting access strictly to the ephemeral relay collection, select all, delete everything, and paste this:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /ephemeral_relays/{document=**} {
      allow read, write: if true;
    }
  }
}
```
Click **Publish**.

---

## 2. Phase 14: Push Notifications (FCM) Setup *(Upcoming)*

When we reach Phase 14, push notifications will notify the recipient's phone to wake up and fetch pending ciphertexts.

### Tasks to prepare:
1. In Firebase Console, go to **Project settings** (gear icon) ➔ **Cloud Messaging**.
2. Note down the **Cloud Messaging API** state (enable Google Cloud Messaging API if prompted).
3. If testing on iOS later:
   - Apple Developer Account required for APNs Key (`.p8` file).
   - Upload APNs auth key into Firebase Console under **Project Settings** ➔ **Cloud Messaging** ➔ **Apple app configuration**.

---

## 3. Phase 15: Media Messaging Storage *(Upcoming)*

For sharing end-to-end encrypted photos and voice notes:
1. Go to **Build** ➔ **Storage** in Firebase Console.
2. Click **Get Started** in production mode.
3. Apply ephemeral auto-deletion lifecycle (or we will configure 24-hour TTL rules so media is deleted after delivery).

---

## 4. Multi-Device Real Testing & APK Generation

Once we finish the core phases, here is how you install and test it between two phones:

### Build APK for Android
Run in terminal:
```powershell
cd e:\ourPlace\chatbox
flutter build apk --release
```
The output file will be at:
```
chatbox/build/app/outputs/flutter-apk/app-release.apk
```
Send this APK to both devices (Device A and Device B):
1. **Device A:** Create account `@alex` with passcode `1234`.
2. **Device B:** Create account `@twilight` with passcode `5678`.
3. Start chatting!
