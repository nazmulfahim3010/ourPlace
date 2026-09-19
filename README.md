# ourPlace — Privacy-First Messaging Application

> **Tagline:** *"The phones own the conversation. The server only helps the phones communicate."*  
> **Target Framework:** Flutter (Dart 3.11+)  
> **Design Aesthetic:** Minimalist High-Contrast Dark Mode (`#000000` pure black & `#383838` dark charcoal)  
> **Current Progress:** **Phase 15 Completed** (116/116 automated tests passing, 0 analyzer issues)

---

## 📚 Master Documentation & Setup Guides

Click any document title or direct link below to navigate directly to that document:

| Document | Description | Direct Clickable Link |
| :--- | :--- | :--- |
| **[📘 Master Project Documentation & Roadmap Tracker](./docts.md)** | Single source of truth: 18-phase roadmap, milestones, ADRs, schema history, and testing matrix | [Open `docts.md`](./docts.md) |
| **[📐 System Architecture & Visual Technical Diagrams](./diagram.md)** | 10 Mermaid diagrams covering topology, state machines, E2EE, and auto-lock flows | [Open `diagram.md`](./diagram.md) |
| **[📋 User Setup Guide & Manual Action Items](./myjob.md)** | Manual steps: Firebase setup, silent wakeups, Android APK release builds, and multi-device testing | [Open `myjob.md`](./myjob.md) |
| **[📜 Master Development Rules & Specifications Prompt](./Private%20Couple%20Chat%20App%20%E2%80%94%20Master%20Development%20Prompt.md)** | Core vision, development rules, privacy principles, and constraints | [Open `Master Prompt`](./Private%20Couple%20Chat%20App%20%E2%80%94%20Master%20Development%20Prompt.md) |
| **[🔗 Documentation Quick Redirect](./docs.md)** | Fast pointer to the primary project documentation | [Open `docs.md`](./docs.md) |
| **[🧪 Complete Automated Test Suite](./chatbox/test/widget_test.dart)** | 116 automated tests verifying crypto, storage, relay, sync, notifications, media, and UI | [Open `widget_test.dart`](./chatbox/test/widget_test.dart) |

---

## 🗺️ Visual Architecture & Diagram Quick Links

Jump directly to specific architectural diagrams inside [**`diagram.md`**](./diagram.md):

- [1. High-Level System Topology & Privacy Boundary](./diagram.md#1-high-level-system-topology--privacy-boundary)
- [2. Three-Tier Credential Separation Model](./diagram.md#2-three-tier-credential-separation-model)
- [3. App Launch & Authentication Gate State Machine](./diagram.md#3-app-launch--authentication-gate-state-machine)
- [4. App Lifecycle & Background Auto-Lock Flow](./diagram.md#4-app-lifecycle--background-auto-lock-flow)
- [5. Clean Architecture Layer Dependencies](./diagram.md#5-clean-architecture-layer-dependencies)
- [6. End-to-End Encryption & Ephemeral Relay Protocol](./diagram.md#6-end-to-end-encryption--ephemeral-relay-protocol)
- [7. Multi-User Navigation & Screen Hierarchy](./diagram.md#7-multi-user-navigation--screen-hierarchy)
- [8. Love Connection & One-Time Love Code Sharing Flow](./diagram.md#8-love-connection--one-time-love-code-sharing-flow)
- [9. Local Database Schema & Entity Relationships](./diagram.md#9-local-database-schema--entity-relationships)
- [10. Security Enclave & Cryptographic Trust Boundaries](./diagram.md#10-security-enclave--cryptographic-trust-boundaries)

---

## 📂 Source Code Quick Links

### 🚪 App Entry & Navigation Flow
- [**`main.dart`**](./chatbox/lib/main.dart) — Application entrypoint with dark theme and dependency wiring
- [**`auth_gate.dart`**](./chatbox/lib/screens/auth/auth_gate.dart) — Session & device lock coordinator with background auto-lock

### 📱 Screens (`lib/screens/`)
- [**`home_screen.dart`**](./chatbox/lib/screens/home_screen.dart) — Main authenticated shell hosting Inbox and Profile navigation
- [**`inbox_screen.dart`**](./chatbox/lib/screens/inbox/inbox_screen.dart) — Inbox with real-time search, Love Connection section, and conversations list
- [**`chat_screen.dart`**](./chatbox/lib/screens/chat_screen.dart) — Conversation view with SQLite persistence, media attachments, voice notes, and "Send luv"
- [**`profile_screen.dart`**](./chatbox/lib/screens/profile/profile_screen.dart) — User profile card, Security & Passcode, Recovery Key backup, Privacy toggles & Audit Log
- [**`auth_screen.dart`**](./chatbox/lib/screens/auth/auth_screen.dart) — Anonymous registration, login, rate limiting, and 12-word recovery key reset
- [**`app_lock_screen.dart`**](./chatbox/lib/screens/auth/app_lock_screen.dart) — Device lock with tactile keypad, biometrics, attempt warnings, and 60s lockout countdown
- [**`passcode_setup_screen.dart`**](./chatbox/lib/screens/auth/passcode_setup_screen.dart) — Multi-step 4-digit PIN creation and biometric enrollment
- [**`private_media_viewer_screen.dart`**](./chatbox/lib/screens/media/private_media_viewer_screen.dart) — Fullscreen dark media viewer with pinch-to-zoom, audio player & E2EE audit

### 🧩 UI Design System & Reusable Widgets (`lib/widgets/`)
- [**`conversation_tile.dart`**](./chatbox/lib/widgets/conversation_tile.dart) — Conversation tile with Love Connection badge (`❤️`) and unread counters
- [**`numeric_keypad.dart`**](./chatbox/lib/widgets/numeric_keypad.dart) — Charcoal tactile 70x70 numeric keypad with haptics & biometric button
- [**`passcode_dots.dart`**](./chatbox/lib/widgets/passcode_dots.dart) — 4-digit animated indicator dots with shake feedback on error
- [**`chat_header.dart`**](./chatbox/lib/widgets/chat_header.dart) — Floating pill-shaped header with partner info, online status, and typing indicators
- [**`chat_input_field.dart`**](./chatbox/lib/widgets/chat_input_field.dart) — Reactive input bar with Send/Mic dynamic toggle, attachment button & voice recording
- [**`message_bubble.dart`**](./chatbox/lib/widgets/message_bubble.dart) — Message bubble supporting text, E2EE image cards, waveform voice notes, and videos
- [**`date_divider.dart`**](./chatbox/lib/widgets/date_divider.dart) — Sticky date divider ("Today", "Yesterday", or formatted date)
- [**`timestamp_indicator.dart`**](./chatbox/lib/widgets/timestamp_indicator.dart) — Subdued timestamp indicator

### 🔒 Security, Cryptography & Services (`lib/services/`)
- [**`crypto_key_utils.dart`**](./chatbox/lib/core/utils/crypto_key_utils.dart) — X25519 key exchange, HKDF-SHA256 derivation, text & binary AES-256-GCM AEAD
- [**`recovery_key_utils.dart`**](./chatbox/lib/core/utils/recovery_key_utils.dart) — BIP-39 12-word recovery mnemonic generator, validator, normalizer, and verifier
- [**`hash_utils.dart`**](./chatbox/lib/core/utils/hash_utils.dart) — Cryptographic salt generation (32 bytes), SHA-256 verifiers, username validation
- [**`encryption_service.dart`**](./chatbox/lib/services/encryption_service.dart) — StandardE2EEEncryptionService (X25519 + AES-256-GCM) with hardware key storage
- [**`media_encryption_service.dart`**](./chatbox/lib/services/media_encryption_service.dart) — Binary media encryption service with asymmetric key wrapping
- [**`media_storage_service.dart`**](./chatbox/lib/services/media_storage_service.dart) — Isolated device sandbox storage keeping media out of public galleries
- [**`media_relay_service.dart`**](./chatbox/lib/services/media_relay_service.dart) — Ephemeral cloud media blob relay with 24-hour TTL and delivery ACK purge
- [**`relay_service.dart`**](./chatbox/lib/services/relay_service.dart) — Ephemeral message envelope relay with delivery ACK permanent purge
- [**`sync_service.dart`**](./chatbox/lib/services/sync_service.dart) — Offline queueing, receipts, inbound E2EE decryption, and media downloads
- [**`realtime_service.dart`**](./chatbox/lib/services/realtime_service.dart) — Debounced typing signals, online presence heartbeats & stealth privacy controls
- [**`notification_service.dart`**](./chatbox/lib/services/notification_service.dart) — Zero-knowledge silent wakeups and privacy-preserving Discreet Mode
- [**`access_throttling_service.dart`**](./chatbox/lib/services/access_throttling_service.dart) — Exponential backoff & login rate-limiting service (10s, 30s, 2m, 5m)
- [**`auth_security_service.dart`**](./chatbox/lib/services/auth_security_service.dart) — Zero-knowledge challenge-response protocol engine (HMAC-SHA256 proofs)
- [**`app_lock_service.dart`**](./chatbox/lib/services/app_lock_service.dart) — Local app lock manager (PIN throttling, 60s lockout, biometrics, state broadcast)
- [**`secure_storage_service.dart`**](./chatbox/lib/services/secure_storage_service.dart) — Hardware Keystore abstraction (`flutter_secure_storage`)
- [**`auth_service.dart`**](./chatbox/lib/services/auth_service.dart) — Session service with reactive `currentUserStream`, recovery resets & audit logs
- [**`chat_service.dart`**](./chatbox/lib/services/chat_service.dart) — Transport service coordinating with ephemeral relay

### 🗄️ Repositories (`lib/repositories/`)
- [**`auth_repository.dart`**](./chatbox/lib/repositories/auth_repository.dart) — Authentication repository contract, recovery key & throttling methods
- [**`conversation_repository.dart`**](./chatbox/lib/repositories/conversation_repository.dart) — Multi-user conversations and Love Connection seed data
- [**`chat_repository.dart`**](./chatbox/lib/repositories/chat_repository.dart) — Message sending, retrieval, media coordination, and status management

### 💾 Local Database & Persistence (`lib/database/`)
- [**`local_database.dart`**](./chatbox/lib/database/local_database.dart) — Singleton database manager with reactive queries, recovery keys, and CRUD
- [**`app_database.dart`**](./chatbox/lib/database/app_database.dart) — Drift SQLite schema v4 (`Messages`, `UserAccounts`, and `SecurityLogs` tables)
- [**`app_database.g.dart`**](./chatbox/lib/database/app_database.g.dart) — Generated Drift database code

### 📦 Domain Models (`lib/models/`)
- [**`user.dart`**](./chatbox/lib/models/user.dart) — Public anonymous User model
- [**`user_account.dart`**](./chatbox/lib/models/user_account.dart) — Private account entity with salted credentials & recovery key verification logic
- [**`security_log.dart`**](./chatbox/lib/models/security_log.dart) — Device-local security event audit model
- [**`conversation.dart`**](./chatbox/lib/models/conversation.dart) — Conversation domain model with Love Connection support
- [**`message.dart`**](./chatbox/lib/models/message.dart) — `ChatMessage` model, `MessageType`, `MessageStatus`, and `MediaAttachment` embedding
- [**`encrypted_payload.dart`**](./chatbox/lib/models/encrypted_payload.dart) — E2EE ciphertext envelope (version, pubKey, nonce, ct, mac)
- [**`ephemeral_relay_envelope.dart`**](./chatbox/lib/models/ephemeral_relay_envelope.dart) — Ephemeral wire envelope (id, sender, recipient, ct, ttl)
- [**`user_presence.dart`**](./chatbox/lib/models/user_presence.dart) — User online status, relative last seen, and formatting
- [**`push_wakeup_signal.dart`**](./chatbox/lib/models/push_wakeup_signal.dart) — Zero-knowledge silent background wakeup signal
- [**`media_attachment.dart`**](./chatbox/lib/models/media_attachment.dart) — Encrypted media metadata, Base64 keys, waveforms, and file sizes

### 🛠️ Core Infrastructure & Tokens (`lib/core/`)
- [**`app_theme.dart`**](./chatbox/lib/core/theme/app_theme.dart) — Centralized dark theme tokens (`#000000` / `#383838`)
- [**`app_constants.dart`**](./chatbox/lib/core/constants/app_constants.dart) — Credential constraints & app constants
- [**`app_exception.dart`**](./chatbox/lib/core/errors/app_exception.dart) — Centralized exception hierarchy (SecurityException, StorageException)

### 🧪 Automated Tests (`test/`)
- [**`widget_test.dart`**](./chatbox/test/widget_test.dart) — Complete test suite with 116 passing unit, crypto, security, relay, media, and widget tests (100% pass rate)

---

## ⚡ Quick Start & Development Commands

All commands should be executed from the `chatbox/` directory:

```bash
cd chatbox

# Check code health & analyze linting (0 issues)
flutter analyze

# Run the complete automated test suite (116 tests)
flutter test

# Generate Drift database code (if schema changes)
dart run build_runner build --delete-conflicting-outputs

# Run application on a connected device/emulator
flutter run
```

---

## 🛡️ Core Security Architecture Highlights

1. **Zero Personally Identifiable Information (PII):**
   - Accounts require only a unique `@username` and password.
   - Never asks for email, phone number, real name, contact lists, or location.

2. **Three-Tier Credential Separation + Offline Recovery:**
   - **Account Password:** Remote authentication; stored locally as salted SHA-256 verifier.
   - **Local App Passcode:** Device-only 4-digit PIN stored in Android Keystore / iOS Keychain; never sent to Firebase or remote servers.
   - **Account Recovery Key:** 12-word offline BIP-39 mnemonic phrase allowing self-sovereign password resets without customer support or cloud PII.
   - **One-Time Love Code:** 60-second single-use authorization code for selective conversation sharing (Phase 17).

3. **End-to-End Encryption (E2EE) with Zero Server Knowledge:**
   - Text messages and media attachments are encrypted on device using X25519 key exchange and authenticated AES-256-GCM.
   - Remote servers see only opaque ciphertext and ephemeral routing headers.

4. **Ephemeral Relay & Delivery ACK Purge Protocol:**
   - Ciphertext envelopes and media blobs live on the relay for a maximum of 24–48 hours.
   - The moment the recipient's device receives and decrypts a message or media blob, an immediate delivery ACK permanently purges the cloud record (relay count drops to 0).

5. **Private Sandboxed Media Storage:**
   - Photos, voice notes, and videos are stored inside the app's private sandbox (`app_sandbox/media/`).
   - Media never automatically leaks into public Android/iOS photo galleries without explicit user export.

6. **Brute-Force & Rate-Limiting Protection:**
   - Account logins enforce exponential backoff (10s, 30s, 2m, 5m).
   - 5 incorrect device PIN attempts triggers a 60-second hardware interface lockout with real-time countdown timer.

7. **Background Privacy & Auto-Lock Protection:**
   - App automatically locks on minimization, app-switching, or screen lock via `WidgetsBindingObserver`.
   - Conversations and messages are never left exposed in task switchers.