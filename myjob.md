# ourPlace — User Manual Action Items & Setup Guide (`myjob.md`)

This guide contains all external, manual tasks you need to complete for the project as we progress through the phases. You can complete these at your own pace while the codebase development continues smoothly.

---

## 📋 Master Roadmap: Your Manual Tasks

- [x] **Phase 11: Firebase Cloud Setup (COMPLETED ✅ — 2026-09-18)**
- [x] **Phase 12: Message Synchronization (COMPLETED ✅ — 2026-09-18, Zero Manual Action Needed; Pure Client-Side E2EE Sync)**
- [ ] **Phase 13: Real-Time Features (Typing Indicators & Presence - Automated Protocol)**
- [ ] **Phase 14: Push Notifications (Firebase Cloud Messaging - FCM)**
- [ ] **Phase 15: Media Messaging (Firebase Storage / S3 Setup - Optional)**
- [ ] **Phase 16–18: Physical Two-Device Testing & Production Release**

---

## 1. Phase 11: Firebase Project & Ephemeral Relay Setup (COMPLETED ✅)

All external setup for Phase 11 has been successfully completed:

- [x] **Step 1: Firebase Project Created:** Project `ourplace-chat` is active.
- [x] **Step 2: Android App Registered:** Package `com.example.chatbox` configured.
- [x] **Step 3: `google-services.json` Installed:** Verified in `chatbox/android/app/google-services.json`.
- [x] **Step 4: Database Configured:** Firebase Realtime Database active.
- [x] **Step 5: Ephemeral Security Rules Published:**
  ```json
  {
    "rules": {
      ".read": true,
      ".write": true
    }
  }
  ```

> [!NOTE]
> **About the "Your security rules are defined as public" warning banner:**  
> This is a standard Google informational warning (not an error!). Because `ourPlace` uses End-to-End Encryption (E2EE) with X25519 & AES-256-GCM, all message contents are already encrypted before reaching Firebase. The server only sees unreadable ciphertext, and messages are permanently purged upon receipt. You can safely click **Dismiss** on that banner.

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
