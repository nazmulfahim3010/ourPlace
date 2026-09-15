# ourPlace — Master Project Documentation & Task Tracking Context
> **Document Version:** 3.1.0  
> **Last Updated:** 2026-09-15  
> **Target Application:** Privacy-First Anonymous Multi-User Messaging Application with Couple Subsystem (`ourPlace`)  
> **Lead Framework:** Flutter (Dart 3.11+)

---

## 1. Executive Summary & Vision

**`ourPlace`** is an ultra-private, anonymous messaging application designed around local-first storage, end-to-end encryption (E2EE), and user-controlled sharing.

### Core Philosophy
> *"The phones own the conversation. The server only helps the phones communicate."*

Unlike conventional messaging platforms that harvest user metadata and persist conversations on remote cloud servers, `ourPlace` enforces an **uncompromising privacy architecture**:

- **Zero Personally Identifiable Information (PII):** Users never provide Gmail/email, phone numbers, real names, contact lists, or location data.
- **Three-Tier Credential Separation:**
  1. **Account Password:** Authenticates the user's `ourPlace` account (registration/login). Stored and verified strictly using salted cryptographic hashes (never plaintext, never logged).
  2. **Local App Passcode:** Protects and unlocks the application on the local physical device. Stored locally; never sent to Firebase or remote servers. (Not required repeatedly during an active session; separate from account password).
  3. **One-Time Love Code:** Random, single-use 6-digit code valid for exactly 60 seconds to temporarily authorize sharing of specific conversations with a Love Connection. Never used as an encryption key.
- **Multi-User Foundation with Love Connection:** Supports conversations with multiple users (User A, User B, User C) alongside a prominent **Love Connection** section (0 or 1 mutually accepted couple connection). The Love Connection does *not* automatically gain surveillance or access to other conversations.
- **Permanent Chat History:** Resides exclusively in the local database (SQLite/Drift) on physical user devices.
- **Remote Infrastructure (Firebase):** Restricted to identity routing, signaling, push notifications, and ephemeral ciphertext relays (purged immediately upon delivery).
- **Aesthetic:** Minimalist, sleek, high-contrast dark theme (pure black `#000000` with dark charcoal `#383838` containers and white typography).

---

## 2. Project Development Status & Roadmap Tracker

In accordance with the **Master Development Rules**, progress is tracked strictly against the 18 defined phases. Phases must be completed sequentially without skipping ahead.
### Current Status Dashboard

| Metric | Status |
| :--- | :--- |
| **Current Phase** | **Phase 9 — Account & Access Security** |
| **Current Status** | **COMPLETED** (Ready for Phase 10: End-to-End Encryption Layer) |
| **Completed Phases** | **Phase 1** (UI Prototypes), **Phase 2** (Message Architecture), **Phase 3** (Functional Local Chat), **Phase 4** (Local Database), **Phase 5** (Application Architecture), **Phase 6** (Inbox & Multi-Conversation UI), **Phase 7** (Anonymous Account Authentication), **Phase 8** (Local App Passcode & Device Lock), **Phase 9** (Account & Access Security) |
| **Next Phase** | **Phase 10 — End-to-End Encryption (E2EE) Layer** |

---

### Phase-by-Phase Roadmap Matrix (18 Phases)

```
[Phase 1: UI Prototype]  ──►  [Phase 2: Message Model]  ──►  [Phase 3: Local Chat]
       (COMPLETED)                     (COMPLETED)                     (COMPLETED)
                                                                          │
                                                                          ▼
[Phase 6: Inbox UI]      ◄──  [Phase 5: Clean Arch]     ◄──  [Phase 4: Local DB]
       (COMPLETED)                     (COMPLETED)                     (COMPLETED)
          │
          ▼
[Phase 7: Anonymous Auth]──►  [Phase 8: App Passcode]   ──►  [Phase 9: Access Security]
       (COMPLETED)                     (COMPLETED)                     (COMPLETED)
                                                                          │
                                                                          ▼
[Phase 12: Message Sync] ◄──  [Phase 11: Temp Relay]    ◄──  [Phase 10: E2EE Layer]
       (PLANNED)                       (PLANNED)                         (NEXT)
          │
          ▼
[Phase 13: Real-Time]    ──►  [Phase 14: Push Notifs]   ──►  [Phase 15: Media]
       (PLANNED)                       (PLANNED)                     (PLANNED)
                                                                          │
                                                                          ▼
[Phase 18: Couple Feat.] ◄──  [Phase 17: Love Code/Share]◄── [Phase 16: Love Connection]
       (PLANNED)                       (PLANNED)                     (PLANNED)
```

#### Detailed Phase Progress Breakdown

- [x] **Phase 1 — Existing UI Foundation**
  - [x] Pure black `#000000` background and dark charcoal `#383838` message bubbles
  - [x] Floating pill-shaped header with avatar, partner name, and "Send luv" button
  - [x] Sent (right-aligned) and received (left-aligned) message bubbles
  - [x] Timestamp indicators (formatted `HH:mm`)
  - [x] Bottom text input field with send button
  - [x] Initial monolithic proof-of-concept screen

- [x] **Phase 2 — Message Architecture**
  - [x] Define `MessageType` enum (`text`, `image`, `audio`, `video`, `system`)
  - [x] Define `MessageStatus` enum (`sending`, `sent`, `delivered`, `read`, `failed`)
  - [x] Implement immutable `ChatMessage` class (`id`, `senderId`, `recipientId`, `text`, `timestamp`, `type`, `status`)
  - [x] JSON serialization & deserialization (`toJson`, `ChatMessage.fromJson`)
  - [x] Model utilities (`copyWith`, `copyWithStatus`, `isSent`, `isSentBy`, UI compatibility getters)
  - [x] Modularize monolithic UI into standalone reusable widgets (`widgets/`)
  - [x] Replace mock string messages with structured `ChatMessage` objects

- [x] **Phase 3 — Functional Local Chat**
  - [x] Typing message into input field updates controller
  - [x] Pressing Send creates structured `ChatMessage` object
  - [x] Input field clears upon send
  - [x] Messages render dynamically in reversed scrollable `ListView`
  - [x] Empty messages blocked from sending
  - [x] Messages maintain timestamps and status lifecycle indicators
  - [x] Sent/received alignment works with 75% max width
  - [x] Message grouping by date with `DateDivider` ("Today", "Yesterday", or formatted date)
  - [x] Consecutive message grouping (tighter spacing and hidden redundant timestamps for bursts)
  - [x] Smooth auto-scroll behavior on send (`ScrollController.animateTo(0.0)`)
  - [x] Keyboard dismiss / inset handling improvements (tap outside to unfocus, `TextInputAction.send` on submit)
  - [x] Passing widget test suite (`flutter test`) verifies UI, sending messages, and quick actions

- [x] **Phase 4 — Local Database (Drift / SQLite)**
  - [x] Added `drift: ^2.34.4`, `drift_flutter: ^0.3.1`, `drift_dev: ^2.34.0`, and `build_runner: ^2.15.1`
  - [x] Created `Messages` table schema in `chatbox/lib/database/app_database.dart`
  - [x] Generated `app_database.g.dart` using `build_runner`
  - [x] Implemented `LocalDatabase` singleton with full CRUD (`saveMessage`, `getMessagesForPartner`, `updateMessageStatus`, `deleteMessage`, `searchMessages`, `watchMessagesForPartner`)
  - [x] Connected `ChatScreen` to automatically load persisted history on startup and save newly sent messages
  - [x] Initial seed history persists on first run, remaining available across app restarts
  - [x] Added in-memory SQLite unit test suite verifying persistence and query operations

- [x] **Phase 5 — Application Architecture Refactoring**
  - [x] Created `core/theme/app_theme.dart`, `core/constants/app_constants.dart`, `core/errors/app_exception.dart`
  - [x] Created `models/user.dart` and `models/conversation.dart` domain models
  - [x] Implemented `repositories/chat_repository.dart` (`LocalChatRepository`) and `repositories/auth_repository.dart`
  - [x] Established service layer contracts (`auth_service.dart`, `encryption_service.dart`, `notification_service.dart`)
  - [x] Decoupled `ChatScreen` to interact strictly with `ChatRepository` instead of raw database queries
  - [x] Wired `main.dart` with `AppTheme.darkTheme` and centralized constants
  - [x] 100% test coverage for `ChatRepository` and `ChatScreen`

- [x] **Phase 6 — Inbox & Multi-Conversation UI**
  - [x] Upgraded application primary screen from a single chat to an **Inbox**
  - [x] Enhanced `Conversation` domain model with `isLoveConnection`, `unreadCount`, `lastMessageAt`, and formatted timestamps
  - [x] Created reusable `ConversationTile` component with Love Connection badge (`❤️`), avatar, snippet, unread counter, and dark charcoal design
  - [x] Created `ConversationRepository` contract and `LocalConversationRepository` with seed data (Love Connection `@twilight`, and users `@sarah`, `@rahim`, `@elena`)
  - [x] Built `InboxScreen` with floating header, realtime search bar, Love Connection section, multi-conversation list, empty state, and new chat dialog
  - [x] Built `ProfileScreen` with anonymous `@username` identity card, Love Connection status with profile visibility toggle, privacy overview, and sign-out action
  - [x] Created `HomeScreen` coordinating Inbox and Profile navigation
  - [x] Added back button navigation to `ChatHeader` so tapping back in any conversation returns smoothly to the Inbox
  - [x] Integrated `AuthGate` to present `HomeScreen` (Inbox) as the primary view for authenticated sessions
  - [x] 20/20 automated tests passing with 0 analyzer issues

- [x] **Phase 7 — Anonymous Account Authentication**
  - [x] Connect account registration and login flows with unique `@username` validation
  - [x] Enforce salted password verifiers (never plaintext)
  - [x] Username uniqueness enforcement via local/backend directory
  - [x] Support session switching and re-authentication

- [x] **Phase 8 — Local App Passcode & Device Lock**
  - [x] Local 4-digit numeric passcode setup and confirmation flow (`PasscodeSetupScreen`)
  - [x] Dedicated App Lock view triggered on app launch or background resume (`AppLockScreen`)
  - [x] Hardware-backed secure local storage for device passcode verifier via `flutter_secure_storage` (never sent to server)
  - [x] Biometric unlock integration via `local_auth` (Fingerprint/Face) with graceful passcode fallback
  - [x] Lifecycle auto-lock via `WidgetsBindingObserver` on background pause/hide
  - [x] Profile security controls: Biometric toggle, Change App Passcode, and Lock App Now
  - [x] 29/29 automated tests passing with 0 analyzer issues

- [x] **Phase 9 — Account & Access Security**
  - [x] Remote verification protocols / challenge-response handshake architecture without exposing passwords
  - [x] Rate-limiting and brute-force protection (login exponential backoff + 60s device PIN lockout)
  - [x] Privacy-preserving 12-word recovery key architecture (BIP-39 mnemonic, salted storage, account reset)
  - [x] Local security audit logs with zero-telemetry enforcement in SQLite (Drift Schema v3)
  - [x] 44/44 automated tests passing with 0 analyzer issues

- [ ] **Phase 10 — End-to-End Encryption (E2EE) Architecture**
  - [ ] Cryptographic design (identity keys, prekeys, ratchet session establishment)
  - [ ] Key generation and local secure storage
  - [ ] Encrypt plaintext message payloads before dispatching to relay
  - [ ] Decrypt ciphertext payloads locally on recipient device

- [ ] **Phase 11 — Temporary Firebase Relay**
  - [ ] Ephemeral ciphertext queue (no permanent history on server)
  - [ ] Delivery acknowledgement and purge protocol

- [ ] **Phase 12 — Message Synchronization**
  - [ ] State transitions (`sending` ➔ `sent` ➔ `delivered` ➔ `read` / `failed`)
  - [ ] Offline queue handling and reconciliation

- [ ] **Phase 13 — Real-Time Features**
  - [ ] Real-time typing indicators with debounce
  - [ ] Ephemeral presence (online / last seen)
  - [ ] Real-time read receipts

- [ ] **Phase 14 — Push Notifications**
  - [ ] Privacy-preserving notification payloads (no plaintext leaks)
  - [ ] Background notification routing

- [ ] **Phase 15 — Media Messaging**
  - [ ] Encrypted images, voice notes, and video attachments
  - [ ] Ephemeral transfer and local storage

- [ ] **Phase 16 — Love Connection**
  - [ ] Mutually accepted 1-to-1 couple connection (0 or 1 active connection)
  - [ ] Search username, send request, accept/decline
  - [ ] Hide/show Love Connection on profile

- [ ] **Phase 17 — One-Time Love Code & Conversation Sharing**
  - [ ] Generate 60-second single-use Love Code for explicit sharing authorization
  - [ ] E2EE conversation data transfer to partner device

- [ ] **Phase 18 — Couple-Specific Features**
  - [ ] "Send luv" animated micro-interactions and reactions
  - [ ] Shared memory gallery, relationship timeline, love letters

---

## 3. Codebase Architecture & File Structure

```
e:\ourPlace\
├── .git/                                    # Git repository
├── Private Couple Chat App — Master...md    # Master specification & rules prompt
├── diagram.md                               # Architectural & technical diagrams (Mermaid)
├── docts.md                                 # Master project documentation & task tracker (this file)
├── README.md                                # Root repository readme
└── chatbox/                                 # PRIMARY FLUTTER APPLICATION
    ├── pubspec.yaml                         # Dependencies (drift, crypto, cupertino_icons, local_auth, flutter_secure_storage)
    ├── analysis_options.yaml                # Linter rules configuration
    ├── android/
    │   └── app/src/main/
    │       ├── AndroidManifest.xml          # Declares USE_BIOMETRIC permission
    │       └── kotlin/.../MainActivity.kt   # Extends FlutterFragmentActivity for biometrics
    ├── lib/
    │   ├── main.dart                        # Application entry point with AuthGate
    │   ├── core/
    │   │   ├── constants/app_constants.dart # App constants & username/password rules
    │   │   ├── errors/app_exception.dart    # Centralized exception hierarchy
    │   │   ├── theme/app_theme.dart         # Design tokens & dark theme
    │   │   └── utils/
    │   │       ├── hash_utils.dart          # Cryptographic salt & SHA-256 verifiers
    │   │       └── recovery_key_utils.dart  # BIP-39 mnemonic generation & phrase hashing
    │   ├── database/
    │   │   ├── app_database.dart            # Drift database (Messages, UserAccounts, SecurityLogs - v3)
    │   │   ├── app_database.g.dart          # Drift generated code
    │   │   └── local_database.dart          # Local database singleton & CRUD methods
    │   ├── models/
    │   │   ├── conversation.dart            # Conversation model with Love Connection support
    │   │   ├── message.dart                 # ChatMessage domain model & enums
    │   │   ├── security_log.dart            # Device-local security event audit model
    │   │   ├── user.dart                    # Anonymous User domain model
    │   │   └── user_account.dart            # UserAccount credentials & verification
    │   ├── repositories/
    │   │   ├── auth_repository.dart         # AuthRepository contract & default implementation
    │   │   ├── chat_repository.dart         # ChatRepository contract & LocalChatRepository
    │   │   └── conversation_repository.dart # ConversationRepository & LocalConversationRepository
    │   ├── screens/
    │   │   ├── auth/
    │   │   │   ├── app_lock_screen.dart     # Dedicated device lock with lockout countdown & PIN throttling
    │   │   │   ├── auth_gate.dart           # Session & device lock coordinator (lifecycle auto-lock)
    │   │   │   ├── auth_screen.dart         # Dark-themed login/register with recovery key reset dialog
    │   │   │   └── passcode_setup_screen.dart # Multi-step PIN creation & biometric setup
    │   │   ├── home_screen.dart             # Primary Home screen hosting Inbox & Profile nav
    │   │   ├── inbox/
    │   │   │   └── inbox_screen.dart        # Inbox displaying Love Connection & Conversations
    │   │   ├── profile/
    │   │   │   └── profile_screen.dart      # User Profile, Security/Passcode, Recovery Key & Audit Log
    │   │   └── chat_screen.dart             # Modular ChatScreen widget with active user context
    │   ├── services/
    │   │   ├── access_throttling_service.dart # Exponential backoff & login rate-limiting service
    │   │   ├── app_lock_service.dart        # Device passcode & biometric authentication service
    │   │   ├── auth_security_service.dart   # Zero-knowledge challenge-response protocol engine
    │   │   ├── auth_service.dart            # AuthService contract & LocalAuthService
    │   │   ├── chat_service.dart            # Chat transport service contract
    │   │   ├── encryption_service.dart      # E2EE contract & NoOp implementation
    │   │   ├── notification_service.dart    # Push notifications contract & stub
    │   │   └── secure_storage_service.dart  # Hardware-backed encrypted key-value storage
    │   └── widgets/
    │       ├── chat_header.dart             # Floating pill header with back button, user & partner
    │       ├── chat_input_field.dart        # Message input bar and send button
    │       ├── conversation_tile.dart       # Reusable conversation tile component
    │       ├── date_divider.dart            # Date group divider ("Today", "Yesterday")
    │       ├── message_bubble.dart          # Chat message bubble container
    │       ├── numeric_keypad.dart          # Tactile dark numeric keypad with biometric button
    │       ├── passcode_dots.dart           # Animated passcode dots indicator with shake feedback
    │       └── timestamp_indicator.dart     # Timestamp indicator widget
    └── test/
        └── widget_test.dart                 # Automated test suite (44/44 tests passing)
```

---

## 4. Deep Dive: What Has Been Built So Far

### 4.1. Core Data Models

#### `Conversation` (`chatbox/lib/models/conversation.dart`)
```dart
class Conversation {
  final String id;
  final User partner;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final bool isLoveConnection;
  final DateTime? lastMessageAt;

  bool get hasUnread => unreadCount > 0;
  DateTime get effectiveTimestamp;
  String get formattedTimestamp;
  Conversation copyWith(...);
}
```

#### `ChatMessage` (`chatbox/lib/models/message.dart`)
```dart
enum MessageType { text, image, audio, video, system }
enum MessageStatus { sending, sent, delivered, read, failed }

class ChatMessage {
  final String id;
  final String senderId;
  final String recipientId;
  final String text;
  final DateTime timestamp;
  final MessageType type;
  final MessageStatus status;

  bool get isSent => senderId == 'current_user';
  bool isSentBy(String currentUserId) => senderId == currentUserId || (senderId == 'current_user' && currentUserId.isNotEmpty);
  String getSenderName([String partnerName = '@twilight', String currentUserName = 'You']);
  Map<String, dynamic> toJson();
  factory ChatMessage.fromJson(Map<String, dynamic> json);
  ChatMessage copyWith(...);
  ChatMessage copyWithStatus(MessageStatus newStatus);
}
```

#### `User`, `UserAccount`, and `SecurityLog` (`chatbox/lib/models/`)
- **`User` (`user.dart`):** Public domain representation containing `id`, `username` (`@username`), `displayName`, `createdAt`, `publicIdentityKey`, `loveConnectionId`, `loveConnectionVisibility`, and `isCurrentUser`.
- **`UserAccount` (`user_account.dart`):** Internal account entity storing `accountId`, normalized `username`, `passwordHash`, `salt`, `createdAt`, `publicIdentityKey`, `recoveryKeyHash`, and `recoveryKeySalt`. Exposes `verifyPassword(candidate)` and `verifyRecoveryKey(candidateMnemonic)` to verify credentials against salted SHA-256 verifiers without exposing plaintext.
- **`SecurityLog` (`security_log.dart`):** Domain model for local security audit records (`id`, `eventType`, `severity`, `description`, `timestamp`, `metadata`). Categorizes events via `SecurityEventType` (`loginSuccess`, `loginFailure`, `lockoutTriggered`, `passwordReset`, `pinFailure`, etc.) and `SecuritySeverity` (`low`, `medium`, `high`, `critical`) strictly within the local device sandbox.

### 4.2. UI Design System & Component Library (`chatbox/lib/widgets/`)
All UI components strictly adhere to the minimalist dark aesthetic:
- **`ConversationTile` (`conversation_tile.dart`):**  
  Reusable tile with dark charcoal surface (`#383838`) or romantic tint (`#2E2428`), circular avatar with Love Connection indicator (`❤️`), partner name, last message preview, formatted timestamp, and unread pill badge.
- **`ChatHeader` (`chat_header.dart`):**  
  Floating pill-shaped container anchored inside a `SafeArea`. Displays back button when pushed onto navigation stack, avatar, partner name, active username (`as @alex`), and "Send luv" button.
- **`ChatInputField` (`chat_input_field.dart`):**  
  Custom bottom text field encased in a `0xFF383838` rounded capsule (`borderRadius: BorderRadius.circular(28)`) with white cursor and `#AAAAAA` placeholder, paired with a matching circular send button.
- **`MessageBubble` (`message_bubble.dart`):**  
  Constrained to 75% max viewport width. Sent messages align right; received messages align left. Encased in dark charcoal with `BorderRadius.circular(20)`.
- **`NumericKeypad` (`numeric_keypad.dart`):**  
  Tactile dark keypad with circular buttons (`#282828`), white numerals, haptic feedback on touch, backspace, and biometric icon button.
- **`PasscodeDots` (`passcode_dots.dart`):**  
  4-digit animated circular dots indicator highlighting upon digit entry, featuring horizontal shake animation and red glow on invalid input.

### 4.3. Navigation & Screen Architecture (`chatbox/lib/screens/`)
- **`HomeScreen` (`home_screen.dart`):** Top-level coordinator hosting `InboxScreen` and pushing `ProfileScreen`.
- **`InboxScreen` (`inbox/inbox_screen.dart`):** Main authenticated view with search filtering, `❤️ LOVE CONNECTION` section, `CONVERSATIONS` section, pull-to-refresh, empty state, and new conversation dialog (`+`). Tapping any tile navigates to `ChatScreen`.
- **`ProfileScreen` (`profile/profile_screen.dart`):** User identity card, Security & App Lock settings card (active status, biometrics switch, change passcode, immediate lock), Account Recovery Key card (protected reveal, copy phrase, regenerate), Security Audit Log viewer, Love Connection status with profile visibility toggle, privacy summary, and sign-out action.
- **`ChatScreen` (`chat_screen.dart`):** Conversation thread view with message persistence, auto-scroll, date dividers, and send actions.
- **`AuthScreen` (`auth/auth_screen.dart`):** Dedicated dark-themed login and registration screen with tab switching, unique `@username` validation, salted password entry, rate limiting error banners, and "Forgot Password? Reset with Recovery Key" bottom sheet modal.
- **`AppLockScreen` (`auth/app_lock_screen.dart`):** Dedicated device lock screen protecting local data, accepting passcode entry or biometrics, displaying attempt warnings and live 60-second countdown lockout banner upon 5 consecutive failed attempts.
- **`PasscodeSetupScreen` (`auth/passcode_setup_screen.dart`):** First-time passcode creation and confirmation flow with optional biometric enrollment sheet.
- **`AuthGate` (`auth/auth_gate.dart`):** Coordinates authentication session, device lock state, and lifecycle background pause/hide auto-lock.

### 4.4. Security, Authentication & Access Security Subsystem (`chatbox/lib/services/` & `core/utils/`)
- **`AuthService` (`auth_service.dart`):**  
  Authentication service contract and `LocalAuthService` implementation managing reactive session state, registration with username validation/uniqueness checks, credential verification against salted hashes, recovery key assignment, password reset, login rate-limiting, audit event dispatch, and `currentUserStream`.
- **`AccessThrottlingService` (`access_throttling_service.dart`):**  
  Enforces exponential backoff against remote login brute-force attacks (10s at 3 fails, 30s at 5 fails, 2m at 8 fails, 5m at 10 fails), tracks attempt timestamps per username, computes remaining cooldown durations, and resets on successful authentication.
- **`AuthSecurityService` (`auth_security_service.dart`):**  
  Ephemeral challenge-response zero-knowledge handshake engine. Issues time-bound cryptographic nonces, generates HMAC-SHA256 client proofs over nonces, and validates mutual server identity proofs so passwords or raw hashes never traverse the network.
- **`RecoveryKeyUtils` (`recovery_key_utils.dart`):**  
  BIP-39 standard 2048-word English dictionary mnemonic generator, validator, and normalizer. Hashes phrases with 32-byte salts and SHA-256 for local verification.
- **`SecureStorageService` (`secure_storage_service.dart`):**  
  Hardware-backed key-value storage backed by `flutter_secure_storage` (Android Keystore / iOS Keychain / Windows DPAPI). Features an in-memory adapter (`InMemorySecureStorageService`) for unit tests.
- **`AppLockService` (`app_lock_service.dart`):**  
  Manages device passcode verification, salting (`HashUtils.hashPassword`), attempt tracking, 60-second hardware interface lockout upon 5 failed attempts, `LocalAuthentication` biometric prompts, biometrics toggle, in-memory unlock state (`isAppUnlocked`), and `lockStateChanges` broadcast stream.

### 4.5. Persistence & Database Subsystem (`chatbox/lib/database/`)
- **`LocalDatabase` (`local_database.dart`):**  
  Singleton database manager wrapping Drift/SQLite. Provides reactive queries (`watchMessagesForPartner`), message CRUD, account management (`saveAccount`, `getAccountByUsername`, `verifyAccountCredentials`, `resetPasswordWithRecoveryKey`, `updateRecoveryKey`), and security audit log operations (`logSecurityEvent`, `getSecurityLogs`, `watchSecurityLogs`, `clearOldSecurityLogs`).
- **`Messages` Table (`app_database.dart`):**  
  Local message schema storing `id`, `senderId`, `recipientId`, `partner`, `text`, `type`, `status`, and `timestamp`. Indexed on partner and timestamp.
- **`UserAccounts` Table (`app_database.dart`):**  
  Local account credentials schema (Schema Version 3) storing `accountId`, unique lowercase `username`, salted `passwordHash`, `salt`, `createdAt`, `publicIdentityKey`, `recoveryKeyHash`, and `recoveryKeySalt`.
- **`SecurityLogs` Table (`app_database.dart`):**  
  Device-local audit ledger storing `id` (auto-increment), `eventType`, `severity`, `description`, `timestamp`, and `metadataJson`.

---

## 5. Architectural Decisions Record (ADR)

### ADR 1: Transition from Single-Chat Prototype to Multi-User Inbox Architecture
- **Previous Design:** The app was built as a single 1-on-1 prototype directly launching `ChatScreen` for Alex and Twilight.
- **New Design:** The app is a multi-user messaging system where the primary authenticated screen is the **Inbox** (`HomeScreen`/`InboxScreen`).
- **Reason:** Real-world users communicate with multiple people (friends, family) while maintaining a special Love Connection for their partner.
- **Impact on Future Phases:** Enables multi-user E2EE (Phase 10), search (Phase 7), and selective conversation sharing (Phase 17).

### ADR 2: Three-Tier Credential Separation
- **Previous Design:** Conflated account login with app lock.
- **New Design:** Strictly decoupled:
  1. **Account Password:** Used for account authentication. Salted SHA-256 verifier stored locally. Never used as app passcode.
  2. **Local App Passcode:** Device-only unlock PIN (Phase 8). Never transmitted to servers.
  3. **Love Code:** Ephemeral 60-second single-use authorization for conversation sharing (Phase 17). Never used as an encryption key.
- **Reason:** Prevents remote credential compromise from leaking local access, and prevents local lockouts from requiring cloud account resets.

### ADR 3: Hardware-Backed Local App Passcode & Biometric Security
- **Previous Design:** No physical device-level application lock existed; possession of the unlocked device exposed all local private messages.
- **New Design:** Implemented a dedicated local app lock system with 4-digit passcode setup (`PasscodeSetupScreen`), lock screen (`AppLockScreen`), biometric unlock via `local_auth`, hardware-backed key-value storage (`flutter_secure_storage`), and lifecycle background locking via `WidgetsBindingObserver`.
- **Security Guarantees:**
  - The local passcode is hashed using a random salt with SHA-256 and stored exclusively in hardware keystores (Android Keystore / iOS Keychain / Windows DPAPI).
  - The passcode is **never** transmitted over the network or saved to Firebase.
  - Biometric authentication uses platform OS prompts and never accesses or stores raw biometric data.
  - Device unlock is required upon app launch and after backgrounding without requiring repeated account password entries.

### ADR 4: Self-Sovereign 12-Word Recovery Key & Zero-Telemetry Device Audit Logging
- **Previous Design:** No offline recovery mechanism existed for lost account passwords without introducing email/SMS/cloud central recovery authority.
- **New Design:** Introduced a self-sovereign 12-word BIP-39 recovery mnemonic system generated locally upon account registration. The recovery phrase is verified using a 32-byte salt and SHA-256 hash stored in Drift SQLite (Schema v3). Paired with device-local security audit logging in the `SecurityLogs` table with zero external telemetry.
- **Security Guarantees:**
  - Password recovery is 100% offline and self-sovereign; no customer support, email verification, or phone SMS required.
  - Plaintext mnemonic words are never persisted; only the salted SHA-256 verifier is saved to SQLite.
  - Access throttling defends against brute-force attacks locally and remotely with exponential backoff and 60-second lockouts.
  - All security audit logs are retained strictly in the local SQLite database and are never synced to Firebase or third-party analytics.

---

## 6. Development Rules & Protocol

Every contributor and agent interacting with this codebase **must** adhere to these strict rules:

1. **Rule 1 — Always Track & Report Progress:**  
   Every development turn must start with the status block:
   ```text
   CURRENT PHASE: <Phase Number and Title>
   STATUS: <In Progress | Completed>
   COMPLETED: <List of completed items>
   NEXT TASK: <Immediate next item to build>
   ```
2. **Rule 2 — Never Skip Phases:**  
   Do not introduce Love Connection sharing, E2EE, or relay infrastructure while local inbox, authentication, and security foundations are incomplete.
3. **Rule 3 — Preserve Working Code:**  
   Do not rewrite functional UI or logic without justification. Retain the existing dark charcoal/black design identity.
4. **Rule 4 — Work Incrementally:**  
   Implement one milestone at a time; test and verify before moving forward.
5. **Rule 5 — Architectural Explanations:**  
   Document *why* a design decision was made, not just *how*.
6. **Rule 6 — Test Checklists:**  
   Accompany each completed feature with an explicit automated and manual testing checklist.
7. **Rule 7 — Dependency Restraint:**  
   Add only essential, well-maintained packages.
8. **Rule 8 — Security over Convenience:**  
   Never compromise privacy, authentication, or end-to-end encryption to take shortcuts. Never store plaintext credentials.

---

## 7. Milestone Completion Reports

### 7.1. Phase 6 Completion Report — Inbox & Multi-Conversation UI

- **Current Phase:** Phase 6 — Inbox & Multi-Conversation UI
- **Phase Status:** COMPLETED

#### Completed Work
1. Upgraded application primary navigation from a single 1-on-1 chat prototype to an authenticated multi-user **Inbox**.
2. Created `Conversation` domain model with unread counting, formatted relative timestamps, and Love Connection indicator flags.
3. Created reusable `ConversationTile` component adhering to the dark charcoal `#383838` design token, with circular avatar, Love Connection badge (`❤️`), snippet preview, and unread pill count.
4. Created `ConversationRepository` contract and `LocalConversationRepository` with seed contacts (Love Connection `@twilight`, and users `@sarah`, `@rahim`, `@elena`).
5. Built `InboxScreen` with floating search bar, real-time client-side search filtering, sticky Love Connection section, conversations list, empty search state, and new chat dialog (`+`).
6. Built `HomeScreen` navigation coordinator and `ProfileScreen` with anonymous `@username` identity card, Love Connection status with profile visibility toggle, privacy overview, and sign-out button.
7. Updated `ChatHeader` to display an inline back button (`<`) whenever navigated from Inbox, preserving full backward compatibility with the existing chat thread, local SQLite persistence, and "Send luv" actions.
8. Implemented initial `AuthGate` routing to `HomeScreen` for authenticated sessions.

#### Files Created
- `chatbox/lib/repositories/conversation_repository.dart`: Multi-conversation repository contract and local implementation.
- `chatbox/lib/screens/home_screen.dart`: Primary shell hosting `InboxScreen` and pushing `ProfileScreen`.
- `chatbox/lib/screens/inbox/inbox_screen.dart`: Primary Inbox view with search, Love Connection, and conversations list.
- `chatbox/lib/screens/profile/profile_screen.dart`: Profile identity, Love Connection status, privacy settings, and sign-out.
- `chatbox/lib/widgets/conversation_tile.dart`: Modular conversation list item component.

#### Architecture Changes
- **Single-Chat to Multi-User:** Transformed the top-level UX from a single hard-coded chat to an extensible Inbox architecture backing any number of conversations.
- **Love Connection Isolation:** The Love Connection is highlighted visually as a special relationship category without conferring blanket permissions or automatic access to other user threads.

---

### 7.2. Phase 7 Completion Report — Anonymous Account Authentication

- **Current Phase:** Phase 7 — Anonymous Account Authentication
- **Phase Status:** COMPLETED

#### Completed Work
1. Implemented anonymous account registration and sign-in flows with unique `@username` validation (alphanumeric with underscores, 3–20 characters).
2. Created `HashUtils` utility providing cryptographically secure random salt generation (32 bytes via `Random.secure()`), salted SHA-256 password hashing, and verification against candidate passwords without exposing credentials.
3. Created `UserAccount` domain entity holding account ID, normalized lowercase username, password hash, salt, created timestamp, and public identity key.
4. Added `UserAccounts` table to Drift SQLite database schema (Schema v2) with unique constraint on username.
5. Implemented account CRUD and verification in `LocalDatabase` (`saveAccount`, `getAccountByUsername`, `verifyAccountCredentials`).
6. Built `AuthRepository` and `LocalAuthService` providing session streams (`currentUserStream`), registration, sign in, sign out, and session persistence.
7. Built `AuthScreen` with sleek dark aesthetic (`#000000` / `#383838`), tab switching between "Sign In" and "Create Account", form validation, password visibility toggle, and error banners.
8. Integrated `AuthGate` to reactively route authenticated users to `HomeScreen` and unauthenticated users to `AuthScreen`.

#### Files Created
- `chatbox/lib/core/utils/hash_utils.dart`: Cryptographic salt generation, SHA-256 verifiers, and username validation/normalization.
- `chatbox/lib/models/user_account.dart`: Private account entity with salted verification logic.
- `chatbox/lib/screens/auth/auth_screen.dart`: Anonymous account login and creation screen with dark aesthetic.
- `chatbox/lib/screens/auth/auth_gate.dart`: Session state coordinator directing to `HomeScreen` or `AuthScreen`.

#### Files Modified
- `chatbox/lib/core/constants/app_constants.dart`: Added username and password length constraints.
- `chatbox/lib/database/app_database.dart`: Added `UserAccounts` table with unique username constraint (Schema version 2).
- `chatbox/lib/database/app_database.g.dart`: Generated Drift table code.
- `chatbox/lib/database/local_database.dart`: Added account CRUD methods (`saveAccount`, `getAccountByUsername`, `verifyAccountCredentials`).
- `chatbox/lib/models/user.dart`: Extended with love connection visibility attributes.
- `chatbox/lib/repositories/auth_repository.dart`: Updated to use `LocalAuthService` with salted credential verification.
- `chatbox/lib/services/auth_service.dart`: Enhanced with `currentUserStream` and session management.
- `chatbox/pubspec.yaml` / `chatbox/pubspec.lock`: Added `crypto: ^3.0.6`.

#### Security Guarantees
- **No Plaintext Passwords:** Passwords are never stored in plaintext in SQLite, memory logs, or preferences.
- **Salted SHA-256:** Every account uses a distinct 32-byte cryptographically random salt to defeat rainbow table attacks.
- **Zero PII Required:** Identity consists strictly of an anonymous `@username` and password.

---

### 7.3. Phase 8 Completion Report — Local App Passcode & Device Lock

- **Current Phase:** Phase 8 — Local App Passcode & Device Lock
- **Phase Status:** COMPLETED

#### Completed Work
1. Implemented `SecureStorageService` interface with `DefaultSecureStorageService` (`flutter_secure_storage` hardware-backed keystore/keychain) and `InMemorySecureStorageService` for unit testing.
2. Built `AppLockService` with `DefaultAppLockService` managing salted SHA-256 passcode verifiers (`HashUtils.hashPassword`), `LocalAuthentication` biometric prompts, toggleable biometric unlock, and reactive state broadcast.
3. Created animated `PasscodeDots` indicator with error shake animation and red glow on incorrect entry.
4. Created tactile dark `NumericKeypad` with haptic feedback, 70x70 circular buttons, backspace, and biometric icon button.
5. Built `AppLockScreen` supporting unlock and current-passcode verification modes, auto-biometric prompt, and account re-login fallback.
6. Built `PasscodeSetupScreen` with multi-step creation and confirmation flow, mismatch handling, and optional biometric activation bottom sheet.
7. Enhanced `AuthGate` with `WidgetsBindingObserver` to auto-lock on app background/pause and route cleanly between `AuthScreen`, `PasscodeSetupScreen`, `AppLockScreen`, and `HomeScreen`.
8. Added "Security & App Lock" card to `ProfileScreen` with passcode active status, biometric unlock toggle, change passcode action, and "Lock App Now" button.
9. Added 9 automated tests for App Lock & Biometrics, bringing the automated test suite to 29/29 passing tests (100%).

#### Files Created
- `chatbox/lib/services/secure_storage_service.dart`: Encrypted key-value hardware storage contract and implementations.
- `chatbox/lib/services/app_lock_service.dart`: Device passcode & biometric authentication service.
- `chatbox/lib/widgets/passcode_dots.dart`: Animated 4-digit indicator dots with shake feedback.
- `chatbox/lib/widgets/numeric_keypad.dart`: Charcoal numeric keypad with tactile feedback.
- `chatbox/lib/screens/auth/app_lock_screen.dart`: Dedicated device lock screen.
- `chatbox/lib/screens/auth/passcode_setup_screen.dart`: Passcode creation, confirmation, and biometric setup flow.

#### Files Modified
- `chatbox/pubspec.yaml` / `chatbox/pubspec.lock`: Added `local_auth: ^3.0.2` and `flutter_secure_storage: ^11.1.1`.
- `chatbox/android/app/src/main/kotlin/com/example/chatbox/MainActivity.kt`: Inherits from `FlutterFragmentActivity` for biometrics.
- `chatbox/android/app/src/main/AndroidManifest.xml`: Declared `USE_BIOMETRIC` permission.
- `chatbox/lib/main.dart`: Wired `appLockService` parameter through `MyApp`.
- `chatbox/lib/screens/home_screen.dart`: Passed `appLockService` to `ProfileScreen`.
- `chatbox/lib/screens/auth/auth_gate.dart`: Coordinated session and device lock lifecycle with auto-lock on background.
- `chatbox/lib/screens/profile/profile_screen.dart`: Added "Security & App Lock" settings card.
- `chatbox/test/widget_test.dart`: Added 9 new unit and widget tests (29 tests total).

#### Security Guarantees
- **Strict Credential Separation:** Local 4-digit PIN is stored exclusively in hardware keystores (Keystore/Keychain/DPAPI); never sent to Firebase or remote servers.
- **Biometric Isolation:** Biometric authentication delegates completely to the device OS (`local_auth`); raw biometric data is never accessed or stored by the app.
- **Background Privacy Protection:** On app minimization or pause, the session is immediately locked to prevent unauthorized physical snooping.

---

### 7.4. Phase 9 Completion Report — Account & Access Security

- **Current Phase:** Phase 9 — Account & Access Security
- **Phase Status:** COMPLETED

#### Completed Work
1. **Remote Zero-Knowledge Handshake Protocol:** Implemented `AuthSecurityService` issuing ephemeral server nonces, computing HMAC-SHA256 client proofs over nonces without sending plaintext passwords or raw hashes over the wire, and validating mutual server identity proofs.
2. **Login Brute-Force & Rate-Limiting Protection:** Built `AccessThrottlingService` enforcing exponential backoff (10s at 3 fails, 30s at 5 fails, 2m at 8 fails, 5m at 10 fails), integrated into `AuthService.login(...)` with real-time cooldown calculations.
3. **Local Device Passcode Throttling & 60s Lockout:** Enhanced `AppLockService` with failed attempt tracking. 5 consecutive incorrect passcodes activates a 60-second device lockout. Upgraded `AppLockScreen` with live countdown ticker banner and keypad disablement during lockout.
4. **Privacy-Preserving 12-Word Recovery Key System:** Built `RecoveryKeyUtils` utilizing the standard BIP-39 2048-word English dictionary. Automatically generates 12-word recovery phrases during registration, salted and hashed via SHA-256 into local SQLite.
5. **Drift SQLite Schema v3 Migration:** Upgraded `AppDatabase` to Schema Version 3, adding `recoveryKeyHash` and `recoveryKeySalt` to `UserAccounts` and creating the `SecurityLogs` table with non-destructive migration preserving existing accounts and chat history.
6. **Account Password Reset Flow:** Added "Forgot Password? Reset with Recovery Key" sheet to `AuthScreen`, enabling users to securely reset their password on-device with their 12-word phrase without central authority or PII.
7. **Profile Security Controls:** Extended `ProfileScreen` with "Account Recovery Key" viewer/backup (gated by passcode confirmation, with copy-to-clipboard and regenerate actions) and "Security Audit Log" viewer displaying local chronological security events with zero-telemetry guarantee.
8. **Automated Test Suite Expansion:** Added 15 new automated tests across cryptographic utilities, throttling, challenge-response handshake, SQLite Schema v3, and UI widget flows, bringing the test suite to **44/44 passing tests (100%)** with **0 analyzer issues**.

#### Files Created
- `chatbox/lib/core/utils/recovery_key_utils.dart`: BIP-39 12-word generator, validator, normalizer, and salted verifier.
- `chatbox/lib/models/security_log.dart`: Domain model for device-local security audit events.
- `chatbox/lib/services/access_throttling_service.dart`: Exponential backoff rate limiter for logins.
- `chatbox/lib/services/auth_security_service.dart`: Zero-knowledge challenge-response handshake engine.

#### Files Modified
- `chatbox/lib/database/app_database.dart`: Added recovery columns to `UserAccounts`, added `SecurityLogs` table, bumped to Schema v3.
- `chatbox/lib/database/app_database.g.dart`: Generated Drift schema v3 code via build_runner.
- `chatbox/lib/database/local_database.dart`: Added recovery key methods, password reset, and SecurityLogs CRUD.
- `chatbox/lib/models/user_account.dart`: Added recoveryKeyHash/recoveryKeySalt and verifyRecoveryKey.
- `chatbox/lib/services/app_lock_service.dart`: Added PIN throttling and 60-second lockout timer.
- `chatbox/lib/services/auth_service.dart`: Integrated throttling, recovery key generation, reset, and audit logging.
- `chatbox/lib/repositories/auth_repository.dart`: Exposed recovery key and rate limit query methods.
- `chatbox/lib/screens/auth/app_lock_screen.dart`: Added live lockout countdown banner and attempt warnings.
- `chatbox/lib/screens/auth/auth_screen.dart`: Added password reset bottom sheet using 12-word recovery phrase.
- `chatbox/lib/screens/profile/profile_screen.dart`: Added Account Recovery Key and Security Audit Log viewers.
- `chatbox/test/widget_test.dart`: Added 15 new unit and widget tests (44 tests total).

#### Security Guarantees
- **Zero Plaintext Password Exposure:** Passwords and recovery keys are strictly stored and verified as salted SHA-256 hashes.
- **Anti-Brute-Force Lockouts:** 5 failed device PIN attempts locks the physical interface for 60 seconds; login attempts trigger exponential backoff.
- **Offline Self-Sovereign Recovery:** Account recovery does not require cloud support, emails, phone numbers, or central servers.
- **Zero Cloud Telemetry:** Security audit logs reside strictly on the local device SQLite database.

---

## 8. Verification & Testing Matrix

### Current Automated Test Suite Status
- **Test Command:** `flutter test`
- **Results:** `44 / 44 tests passing` (100% pass rate)
- **Analyzer Check:** `flutter analyze` ➔ `No issues found! (ran in 17.8s)`

### Comprehensive Test Coverage Breakdown

| Suite | Tests | Scope & Verification Highlights |
| :--- | :---: | :--- |
| **Cryptographic Utils** | 5 | Random salt generation (32 bytes), SHA-256 consistency, username normalization, input validation, salted password verification |
| **Local SQLite Database** | 4 | In-memory Drift tests verifying account creation, duplicate username rejection, credential matching, and message CRUD |
| **Conversation Repository** | 3 | Seed loading, Love Connection retrieval, starting/finding conversations, unread count tracking |
| **Authentication Service** | 1 | Complete registration flow, duplicate username rejection, sign-in validation, session persistence, sign-out |
| **Chat Repository** | 1 | Local chat repository message delegation, status update transitions, and conversation retrieval |
| **Inbox & Chat UI Widgets** | 6 | `ConversationTile` Love badge rendering, `InboxScreen` search filtering, push navigation & back button, `AuthScreen` tabs, `AuthGate` session routing, `ChatScreen` messaging & "Send luv" |
| **App Lock & Secure Storage** | 3 | Passcode salting and hashing without plaintext storage, passcode verification and app unlock, biometric toggle & clear passcode lifecycle |
| **App Lock UI Widgets** | 6 | `PasscodeDots` fill/shake feedback, `NumericKeypad` tactile buttons/biometrics, `PasscodeSetupScreen` create/confirm/mismatch, `AppLockScreen` incorrect error/unlock, `AuthGate` setup routing/auto-lock, `ProfileScreen` security card & immediate lock |
| **Recovery Key Utilities** | 3 | BIP-39 mnemonic generation, 12-word dictionary validation, normalization, salted hashing & verification |
| **Access Throttling & Rate Limiting** | 2 | Exponential backoff cooldown escalation (10s, 30s, 2m, 5m), lockout enforcement, reset on success |
| **Challenge-Response Handshake** | 3 | Ephemeral challenge nonces, HMAC-SHA256 client proof generation & verification, mutual server proof |
| **Database Schema v3 & Security Logs** | 3 | Recovery key persistence, password reset with recovery phrase verification, security log insertion/retrieval/cleanup |
| **App Lock PIN Throttling** | 1 | 5 failed attempts triggering 60s lockout, rejection during lockout, unlock reset |
| **Phase 9 UI Widgets** | 3 | `AppLockScreen` lockout banner, `AuthScreen` reset with recovery key, `ProfileScreen` recovery key card and audit log viewer |
| **Total Test Suite** | **44** | **100% Passing — Zero Analyzer Issues** |

---

## 9. Immediate Action Items & Next Milestone

### Next Phase: Phase 10 — End-to-End Encryption (E2EE) Layer

Phase 10 designs and implements the core cryptographic protocol guaranteeing that only the sender and recipient can read conversation contents.

#### Key Objectives for Phase 10:
1. **Cryptographic Identity & Ratchet Session Keys:**
   - Generate identity key pairs (Ed25519 / X25519) and signed prekeys per user.
   - Store private identity keys securely in hardware keystores (`flutter_secure_storage`).
2. **Payload Encryption & Decryption:**
   - Double Ratchet or Signal Protocol-inspired session management.
   - Symmetric AES-256-GCM / ChaCha20-Poly1305 payload encryption.
   - Compute and verify HMAC integrity tags.
3. **Local Cryptographic Engine:**
   - Decouple encryption engine from UI and local storage.
   - Implement `EncryptionService` encrypting outgoing plaintext messages before network staging, and decrypting incoming payloads before SQLite insertion.


