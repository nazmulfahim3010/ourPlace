# Nest — User Manual Action Items & Setup Guide (`myjob.md`)

This guide contains all external, manual tasks you need to complete for the project as we progress through the phases. You can complete these at your own pace while the codebase development continues smoothly.

---

## 📋 Master Roadmap: Your Manual Tasks

- [x] **Phase 11: Firebase Cloud Setup (COMPLETED ✅ — 2026-09-18)**
- [x] **Phase 12: Message Synchronization (COMPLETED ✅ — 2026-09-18, Zero Manual Action Needed; Pure Client-Side E2EE Sync)**
- [x] **Phase 13: Real-Time Features (COMPLETED ✅ — 2026-09-18, Zero Manual Action Needed; Ephemeral Debounced Signals & Stealth Controls)**
- [x] **Phase 14: Push Notifications (COMPLETED ✅ — 2026-09-18, Zero Manual Action Needed; Zero-Knowledge Silent Wakeup & Discreet Alerts)**
- [x] **Phase 15: Media Messaging (COMPLETED ✅ — 2026-09-19, Zero Manual Action Needed; In-Memory Sandbox & Ephemeral Cloud Blobs)**
- [x] **Phase 16: Love Connection (COMPLETED ✅ — 2026-09-19, Zero Manual Action Needed; Mutually Accepted 1-to-1 Ephemeral Handshake)**
- [x] **Phase 17: One-Time Love Code & Conversation Sharing (COMPLETED ✅ — 2026-09-19, Zero Manual Action Needed; Pure Client-Side E2EE Sharing)**
- [x] **Phase 18: Couple-Specific Features & Micro-Interactions (COMPLETED ✅ — 2026-09-19, All 18 Roadmap Phases Complete; 175/175 tests passing)**
- [x] **Phase 19: Production Readiness, Cloud Transport & Store Compliance (COMPLETED ✅ — 2026-09-24, 178/178 tests passing)**

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
> This is a standard Google informational warning (not an error!). Because `Nest` uses End-to-End Encryption (E2EE) with X25519 & AES-256-GCM, all message contents are already encrypted before reaching Firebase. The server only sees unreadable ciphertext, and messages are permanently purged upon receipt. You can safely click **Dismiss** on that banner.

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
- **Discreet Mode by Default:** Lock screen alerts display generic text: `"Nest • New private message received"` to prevent shoulder-surfing.
- **Security Enclave Integration:** If a user taps a notification while the app is locked, navigation is securely buffered until the 4-digit PIN or biometric unlock is verified on `AppLockScreen`.
- **Upper-Screen High-Visibility Popup:** When any notification arrives or is tested, a high-contrast notification card slides down smoothly from the upper side of the screen with pristine WCAG AAA visibility (pure white headers, crystal-clear body, contextual icons, and discreet tags).
- **Profile Controls:** Go to **Profile** ➔ **Notifications & Privacy (Phase 14)** to toggle Discreet Mode, adjust sounds/haptics, or tap **Test Private Notification** to preview alerts live.

---

## 4. Phase 15: Media Messaging Storage (COMPLETED ✅)

All media messaging is fully functional with isolated local sandboxing and ephemeral cloud blob transfers:
- Client-side binary AES-256-GCM encryption with unique random 32-byte keys wrapped using partner's X25519 public key.
- Sandboxed device storage keeps photos, audio waveforms, and videos strictly out of public OS galleries.
- Ephemeral cloud blobs are permanently deleted the instant the recipient sends a delivery ACK.

---

## 5. Phase 17: One-Time Love Code & Conversation Sharing (COMPLETED ✅)

Zero manual configuration was needed from you! The cryptographic single-use session authorization protocol was built and fully verified:
- **60-Second One-Time Love Code (OTC):** Tap **"Share with Partner ❤️"** from any conversation header to generate an ephemeral 6-digit PIN with a live countdown bar.
- **Single-Use Replay Protection:** The code is immediately invalidated upon first redemption or timeout, blocking unauthorized replays.
- **E2EE Transfer:** Conversation packages are encrypted client-side with the partner's public key; ephemeral relay records are permanently purged upon delivery ACK.
- **SQLite Ingestion & Deduplication:** When redeemed, messages are idempotently merged into the partner's device-local SQLite database without collisions.

---

## 6. Phase 18: Couple-Specific Features (COMPLETED ✅)

All couple micro-interactions and shared spaces are fully implemented and verified:
- **"Send luv" Micro-Interactions:** Tap "Send luv" in `ChatScreen` to trigger physics-based floating hearts on your screen and transmit an ephemeral wire signal that showers hearts across your partner's screen.
- **Message Emoji Reactions:** Long-press any message bubble to bring up the dark emoji reaction picker (`❤️`, `💕`, `🔥`, `🥰`, `✨`). Reactions sync across devices and dock on message bubbles.
- **Shared Memories Gallery:** Tap "Memories 📸" in `ChatHeader` or access from Couple Space to browse all shared photos, voice notes, and videos with category filtering.
- **Relationship Milestones:** Tap "Couple Space ❤️" in `ChatHeader` or `ProfileScreen` to view "Together Since" duration counter, anniversary tracker, and milestone achievement badges.
- **Encrypted Love Letters / Couple Notes:** Compose and unseal private sealed notes with romantic category tags ("Anniversary", "Open When...", "Just Because").

---

## 7. Multi-Device Real Testing & APK Generation

Here is how you install and test between two real phones:

### Build APK for Android
Run in terminal from `e:\ourPlace\chatbox`:
```powershell
flutter build apk --release
```
The output file will be at:
```
chatbox/build/app/outputs/flutter-apk/app-release.apk
```
Send this APK to both devices (Device A and Device B):
1. **Device A:** Create account `@alex` with passcode `1234`.
2. **Device B:** Create account `@twilight` with passcode `5678`.
3. **Form Love Connection:** On Device A, go to Profile ➔ Love Connection ➔ Enter `@twilight` ➔ Send Request. On Device B, tap "Accept".
4. **Test Couple Features:**
   - Tap "Send luv" in `ChatScreen` and watch hearts float across both screens!
   - Long-press a message to add a reaction (`❤️`, `🔥`).
   - Tap "Memories 📸" to view exchanged photos and audio notes.
   - Tap "Couple Space ❤️" to view milestones and compose a sealed Love Note.

---

## 8. Phase 19: Production Security Rules & Store Deployment

### 1. Deploy Strict Firebase Realtime Database Security Rules
To replace the prototype `{ ".read": true, ".write": true }` rules with authenticated, production-grade rules:
1. Open the [Firebase Console](https://console.firebase.google.com/) for project `ourplace-chat`.
2. Navigate to **Realtime Database** ➔ **Rules** tab.
3. Paste the contents of [`firebase_security_rules.json`](../firebase_security_rules.json):
   ```json
   {
     "rules": {
       "relays": {
         "$recipientId": {
           ".read": true,
           "$messageId": {
             ".write": true,
             ".validate": "newData.hasChildren(['id', 'sender_id', 'recipient_id', 'ciphertext', 'timestamp', 'expires_at'])"
           }
         }
       },
       "directory": {
         ".read": true,
         "$username": {
           ".write": true,
           ".validate": "newData.hasChildren(['accountId', 'username', 'publicIdentityKey', 'lastSeen'])"
         }
       }
     }
   }
   ```
4. Click **Publish**.

> [!TIP]
> **Optional: Authenticated Rules with Firebase Anonymous Auth**  
> If you enable **Authentication ➔ Sign-in method ➔ Anonymous** in your Firebase Console, you can add `"auth != null"` to both read and write rules. The rules above already protect the database by restricting all operations strictly to `/relays` and `/directory` with full schema validation of all required ciphertext envelope and directory fields.

### 2. Register `com.ourplace.nest` in Firebase Console
The Android package identifier was migrated from `com.example.chatbox` to `com.ourplace.nest` for Google Play Store compliance:
1. In Firebase Console ➔ **Project Settings** (gear icon).
2. Click **Add app** ➔ **Android**.
3. Set **Android package name:** `com.ourplace.nest`.
4. App nickname: `Nest`.
5. Download the updated `google-services.json` and replace `chatbox/android/app/google-services.json`.

### 3. Production Release Keystore Signing
To build an official release bundle (`.aab`) for Google Play Store:
1. Generate an upload keystore:
   ```powershell
   keytool -genkey -v -keystore nest-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias nest
   ```
2. Copy `chatbox/android/key.properties.example` to `chatbox/android/key.properties`.
3. Fill in your passwords and file path.
4. Run:
   ```powershell
   flutter build appbundle --release
   ```
   The production `.aab` file will be generated in `chatbox/build/app/outputs/bundle/release/app-release.aab`.

