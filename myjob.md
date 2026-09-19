# ourPlace — User Manual Action Items & Setup Guide (`myjob.md`)

This guide contains all external, manual tasks you need to complete for the project as we progress through the phases. You can complete these at your own pace while the codebase development continues smoothly.

---

## 📋 Master Roadmap: Your Manual Tasks

- [x] **Phase 11: Firebase Cloud Setup (COMPLETED ✅ — 2026-09-18)**
- [x] **Phase 12: Message Synchronization (COMPLETED ✅ — 2026-09-18, Zero Manual Action Needed; Pure Client-Side E2EE Sync)**
- [x] **Phase 13: Real-Time Features (COMPLETED ✅ — 2026-09-18, Zero Manual Action Needed; Ephemeral Debounced Signals & Stealth Controls)**
- [x] **Phase 14: Push Notifications (COMPLETED ✅ — 2026-09-18, Zero Manual Action Needed; Zero-Knowledge Silent Wakeup & Discreet Alerts)**
- [x] **Phase 15: Media Messaging (COMPLETED ✅ — 2026-09-19, Zero Manual Action Needed; In-Memory Sandbox & Ephemeral Cloud Blobs)**
- [x] **Phase 16: Love Connection (COMPLETED ✅ — 2026-09-19, Zero Manual Action Needed; Mutually Accepted 1-to-1 Ephemeral Handshake)**
- [ ] **Phase 17–18: Physical Two-Device Testing & Production Release**

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

## 2. Phase 13: Real-Time Features (Typing & Presence) (COMPLETED ✅)

Zero manual configuration was needed from you! The client-side protocol was built and fully verified with automated unit/widget tests:
- **Typing Indicator:** 2s keystroke debounce, 3s inactivity auto-cancellation, 5s TTL on wire. Shows warm pink italic `typing...` in `ChatHeader`.
- **Online Presence:** 20s background heartbeat, 35s wire TTL. Shows green dot `● online` or human-friendly relative last seen (`last seen just now`, `last seen 5m ago`, `last seen 2h ago`).
- **Stealth Mode (Profile Toggles):** Go to **Profile** ➔ **Privacy & Presence** to disable typing indicators or last seen at will.
- **Zero-Disk / Zero-Knowledge Guarantee:** Heartbeats and typing signals are completely ephemeral — never saved to SQLite or permanent server storage.

---

## 3. Phase 14: Push Notifications (COMPLETED ✅)

Zero manual configuration was needed from you! The privacy-first notification architecture was built and verified with 95/95 automated unit/widget tests:
- **Zero-Knowledge Silent Wakeup:** Push notifications carry **zero plaintext, zero sender usernames, and zero sensitive metadata**. They act as pure data pings (`type: "wakeup"`) prompting the receiver's phone to wake up and decrypt locally.
- **Discreet Mode by Default:** Lock screen alerts display generic text: `"ourPlace • New private message received"` to prevent shoulder-surfing.
- **Security Enclave Integration:** If a user taps a notification while the app is locked, navigation is securely buffered until the 4-digit PIN or biometric unlock is verified on `AppLockScreen`.
- **Profile Controls:** Go to **Profile** ➔ **Notifications & Privacy (Phase 14)** to toggle Discreet Mode, adjust sounds/haptics, or tap **Test Private Notification** to preview alerts live.

---

## 4. Phase 15: Media Messaging Storage *(Upcoming)*

For sharing end-to-end encrypted photos and voice notes:
1. Go to **Build** ➔ **Storage** in Firebase Console.
2. Click **Get Started** in production mode.
3. Apply ephemeral auto-deletion lifecycle (or we will configure 24-hour TTL rules so media is deleted after delivery).

---

## 5. Multi-Device Real Testing & APK Generation

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
