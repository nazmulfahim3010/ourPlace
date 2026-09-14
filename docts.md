# ourPlace — Master Project Documentation & Task Tracking Context
> **Document Version:** 2.0.0  
> **Last Updated:** 2026-09-14  
> **Target Application:** Privacy-First Anonymous Messaging Application (`ourPlace`)  
> **Lead Framework:** Flutter (Dart 3.11+)

---

## 1. Executive Summary & Vision

**`ourPlace`** is a privacy-first messaging application designed around anonymous identities, local-first storage, end-to-end encryption (E2EE), and user-controlled sharing.

### Core Philosophy
> *"The phones own the conversation. The server only helps the phones communicate."*

Unlike conventional messaging platforms that harvest user metadata and persist conversations on remote cloud servers, `ourPlace` enforces an **uncompromising privacy architecture**:

- **Zero Personally Identifiable Information (PII):** Users never provide Gmail/email, phone numbers, real names, contact lists, or location data.
- **Three-Pillar Identity System:**
  1. **Unique Username (`@username`):** The user's public identity for discovery and chat routing.
  2. **Account Password:** Salted cryptographic verifier for account authentication. Passwords are never stored in plaintext and never logged.
  3. **Local App Passcode:** Protects access to the application on the local physical device. (Strictly decoupled from account password; never sent to servers).
- **Multi-User Foundation with Couple Focus:** Supports multiple one-to-one conversations with a specialized **Love Connection** subsystem (0 or 1 active couple connection) featuring explicit, temporary 60-second One-Time Love Code sharing.
- **Permanent Chat History:** Resides exclusively in the local database (SQLite/Drift) on physical user devices.
- **Remote Infrastructure (Firebase):** Restricted to identity routing, signaling, push notifications, and ephemeral ciphertext relays (purged immediately upon delivery).
- **Aesthetic:** Minimalist, sleek, high-contrast dark theme (pure black `#000000` with dark charcoal `#383838` containers and white typography).

---

## 2. Project Development Status & Roadmap Tracker

In accordance with the **Master Development Rules**, progress is tracked strictly against the 17 defined phases. Phases must be completed sequentially without skipping ahead.

### Current Status Dashboard

| Metric | Status |
| :--- | :--- |
| **Current Phase** | **Phase 6 — Anonymous Identity System** |
| **Current Status** | **COMPLETED** (Ready for Phase 7: Local App Passcode & Device Security) |
| **Completed Phases** | **Phase 1** (UI Prototypes), **Phase 2** (Message Architecture), **Phase 3** (Functional Local Chat), **Phase 4** (Local Database), **Phase 5** (Application Architecture), **Phase 6** (Anonymous Identity System) |
| **Next Phase** | **Phase 7 — Local App Passcode & Device Security** |

---

### Phase-by-Phase Roadmap Matrix (17 Phases)

```
[Phase 1: UI Prototype]  ──►  [Phase 2: Message Model]  ──►  [Phase 3: Local Chat]
       (COMPLETED)                     (COMPLETED)                     (COMPLETED)
                                                                          │
                                                                          ▼
[Phase 6: Anon Identity] ◄──  [Phase 5: Clean Arch]     ◄──  [Phase 4: Local DB]
       (COMPLETED)                     (COMPLETED)                     (COMPLETED)
          │
          ▼
[Phase 7: App Passcode]  ──►  [Phase 8: Access Security]──►  [Phase 9: E2EE Layer]
        (NEXT)                         (PLANNED)                     (PLANNED)
                                                                          │
                                                                          ▼
[Phase 12: Real-Time]    ◄──  [Phase 11: Message Sync]  ◄──  [Phase 10: Temp Relay]
       (PLANNED)                       (PLANNED)                     (PLANNED)
          │
          ▼
[Phase 13: Push Notifs]  ──►  [Phase 14: Media]         ──►  [Phase 15: Love Connection]
       (PLANNED)                       (PLANNED)                     (PLANNED)
                                                                          │
                                                                          ▼
[Phase 17: Couple Feat.] ◄──  [Phase 16: Love Code / Share]
       (PLANNED)                       (PLANNED)
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

- [x] **Phase 6 — Anonymous Identity System**
  - [x] Purged legacy Firebase email/password whitelist assumptions
  - [x] Implemented `HashUtils` with cryptographic SHA-256 salted password hashing and secure random salts
  - [x] Created `UserAccount` entity encapsulating account credentials and salted verification
  - [x] Upgraded `User` domain model with `@username`, `createdAt`, `publicIdentityKey`, and privacy attributes
  - [x] Added `UserAccounts` table to Drift SQLite database (`schemaVersion: 2`) with unique username constraints
  - [x] Implemented `AuthService` and `LocalAuthService` managing registration, password verification, and auth state
  - [x] Implemented `AuthRepository` and `DefaultAuthRepository` delegating to identity service
  - [x] Built minimalist dark-themed `AuthScreen` with "Sign In" and "Create Account" tabs, validation, and error banners
  - [x] Created reactive `AuthGate` dynamically routing between `AuthScreen` and `ChatScreen`
  - [x] Integrated sign out and current user `@username` indicator into `ChatHeader`
  - [x] Comprehensive automated test suite passing with 14/14 tests and 0 analyzer issues

- [ ] **Phase 7 — Local App Passcode & Device Security**
  - [ ] Local 4- or 6-digit app passcode setup and verification (completely separate from account password)
  - [ ] App Lock view triggered on app launch or background resume
  - [ ] Secure local storage for device passcode verifier (never sent to server)
  - [ ] Rate-limiting and retry backoff on failed passcode attempts

- [ ] **Phase 8 — Account & Access Security**
  - [ ] Remote verification protocols without exposing passwords
  - [ ] Rate-limiting and brute-force protection
  - [ ] Privacy-preserving recovery key architecture

- [ ] **Phase 9 — End-to-End Encryption (E2EE) Architecture**
  - [ ] Cryptographic design (identity keys, prekeys, ratchet session establishment)
  - [ ] Key generation and local secure storage
  - [ ] Encrypt plaintext message payloads before dispatching to relay
  - [ ] Decrypt ciphertext payloads locally on recipient device

- [ ] **Phase 10 — Temporary Firebase Relay**
  - [ ] Ephemeral ciphertext queue (no permanent history on server)
  - [ ] Delivery acknowledgement and purge protocol

- [ ] **Phase 11 — Message Synchronization**
  - [ ] State transitions (`sending` ➔ `sent` ➔ `delivered` ➔ `read` / `failed`)
  - [ ] Offline queue handling and reconciliation

- [ ] **Phase 12 — Real-Time Features**
  - [ ] Real-time typing indicators with debounce
  - [ ] Ephemeral presence (online / last seen)
  - [ ] Real-time read receipts

- [ ] **Phase 13 — Push Notifications**
  - [ ] Privacy-preserving notification payloads (no plaintext leaks)
  - [ ] Background notification routing

- [ ] **Phase 14 — Media Messaging**
  - [ ] Encrypted images, voice notes, and video attachments
  - [ ] Ephemeral transfer and local storage

- [ ] **Phase 15 — Love Connection**
  - [ ] Mutually accepted 1-to-1 couple connection (0 or 1 active connection)
  - [ ] Search username, send request, accept/decline
  - [ ] Hide/show Love Connection on profile

- [ ] **Phase 16 — One-Time Love Code & Conversation Sharing**
  - [ ] Generate 60-second single-use Love Code for explicit sharing authorization
  - [ ] E2EE conversation data transfer to partner device

- [ ] **Phase 17 — Couple-Specific Features**
  - [ ] "Send luv" animated micro-interactions and reactions
  - [ ] Shared memory gallery, relationship timeline, love letters

---

## 3. Codebase Architecture & File Structure

The workspace contains the primary Flutter application under the `chatbox/` directory:

```
e:\ourPlace\
├── .git/                                    # Git repository
├── Private Couple Chat App — Master...md    # Master specification & rules prompt
├── docts.md                                 # Master project documentation & task tracker (this file)
├── README.md                                # Root repository readme
└── chatbox/                                 # PRIMARY FLUTTER APPLICATION
    ├── pubspec.yaml                         # Dependencies (drift, crypto, cupertino_icons)
    ├── analysis_options.yaml                # Linter rules configuration
    ├── lib/
    │   ├── main.dart                        # Application entry point with AuthGate
    │   ├── core/
    │   │   ├── constants/app_constants.dart # App constants & username/password rules
    │   │   ├── errors/app_exception.dart    # Centralized exception hierarchy
    │   │   ├── theme/app_theme.dart         # Design tokens & dark theme
    │   │   └── utils/hash_utils.dart        # Cryptographic salt & SHA-256 verifiers
    │   ├── database/
    │   │   ├── app_database.dart            # Drift database (Messages & UserAccounts tables)
    │   │   ├── app_database.g.dart          # Drift generated code
    │   │   └── local_database.dart          # Local database singleton & CRUD methods
    │   ├── models/
    │   │   ├── conversation.dart            # Conversation model
    │   │   ├── message.dart                 # ChatMessage domain model & enums
    │   │   ├── user.dart                    # Anonymous User domain model
    │   │   └── user_account.dart            # UserAccount credentials & verification
    │   ├── repositories/
    │   │   ├── auth_repository.dart         # AuthRepository contract & default implementation
    │   │   └── chat_repository.dart         # ChatRepository contract & LocalChatRepository
    │   ├── screens/
    │   │   ├── auth/
    │   │   │   ├── auth_gate.dart           # Reactive session gate
    │   │   │   └── auth_screen.dart         # Dark-themed login & registration UI
    │   │   └── chat_screen.dart             # Modular ChatScreen widget with active user context
    │   ├── services/
    │   │   ├── auth_service.dart            # AuthService contract & LocalAuthService
    │   │   ├── chat_service.dart            # Chat transport service contract
    │   │   ├── encryption_service.dart      # E2EE contract & NoOp implementation
    │   │   └── notification_service.dart    # Push notifications contract & stub
    │   └── widgets/
    │       ├── chat_header.dart             # Floating pill header with @username & sign-out
    │       ├── chat_input_field.dart        # Message input bar and send button
    │       ├── date_divider.dart            # Date group divider ("Today", "Yesterday")
    │       ├── message_bubble.dart          # Chat message bubble container
    │       └── timestamp_indicator.dart     # Timestamp indicator widget
    └── test/
        └── widget_test.dart                 # Automated test suite (14/14 tests passing)
```

---

## 4. Deep Dive: What Has Been Built So Far

### 4.1. Core Data Models

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

#### `User` & `UserAccount` (`chatbox/lib/models/`)
- **`User` (`user.dart`):** Public domain representation containing `id`, `username` (`@username`), `displayName`, `createdAt`, `publicIdentityKey`, `loveConnectionId`, `loveConnectionVisibility`, and `isCurrentUser`.
- **`UserAccount` (`user_account.dart`):** Internal entity storing `accountId`, normalized `username`, `passwordHash`, `salt`, `createdAt`, and `publicIdentityKey`. Exposes `verifyPassword(candidate)` to match against salted hashes without exposing credentials.

### 4.2. Cryptographic Security (`chatbox/lib/core/utils/hash_utils.dart`)
- **`generateSalt([int length = 16])`:** Uses `Random.secure()` to create unique per-account hexadecimal salts.
- **`hashPassword(password, salt)`:** Performs salted SHA-256 hashing (`sha256.convert(utf8.encode('$salt:$password'))`).
- **`normalizeUsername(input)`:** Lowercases, trims, and formats handles with a leading `@` (`@alex`).
- **Validation:** Enforces 3–20 character limits, regex `^[a-zA-Z0-9_]+$`, and minimum 6-character passwords.

### 4.3. Local Database & Persistence (`chatbox/lib/database/`)
- Drift SQLite database (`app_database.dart`) with `schemaVersion: 2`.
- **`Messages` Table:** Stores message ID, sender ID, recipient ID, text payload, timestamp, type, and status.
- **`UserAccounts` Table:** Stores account ID (PK), unique `username`, `passwordHash`, `salt`, `createdAt`, and `publicIdentityKey`.
- **`LocalDatabase` Singleton:** Exposes complete CRUD operations for messages and anonymous accounts.

### 4.4. Authentication Flow & UI (`chatbox/lib/screens/auth/`)
- **`AuthGate` (`auth_gate.dart`):** StreamBuilder listening to `authRepository.authStateChanges`. Dynamically renders `ChatScreen` if authenticated, or `AuthScreen` if unauthenticated.
- **`AuthScreen` (`auth_screen.dart`):** High-contrast dark theme screen (`#000000`/`#383838`) with tabs for **Sign In** and **Create Account**, inline validation, password visibility toggles, loading spinners, and error banners.
- **`ChatHeader` Integration:** Displays the logged-in user handle (`as @username`) alongside the partner name, and includes a quick sign-out action to revoke session state.

---

## 5. Target Architecture & End-to-End Flow

```
                 ourPlace
                    │
        ┌───────────┴───────────┐
        │                       │
     Username                Password (Salted Verifier)
  (@public_id)                  │
        │                       │
        └───────────┬───────────┘
                    │
               Account ID
                    │
          ┌─────────┴─────────┐
          │                   │
     Multiple Chats      Love Connection (Phase 15)
          │                   │
          │             0 or 1 Active
     Local Database           │
  (Drift / SQLite)       60s One-Time Love Code (Phase 16)
          │                   │
          └─────────┬─────────┘
                    │
              E2EE Layer (Phase 9)
                    │
         Temporary Firebase Relay (Phase 10)
         (Ephemeral Ciphertext Only)
                    │
                 Internet
```

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
   Do not introduce Love Connection, E2EE, or relay infrastructure while identity, local security, and database foundations are incomplete.
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

## 7. Immediate Action Items & Next Milestone

### Immediate Next Steps (Starting Phase 7)

#### Task 7.1: Local App Passcode Architecture (Phase 7)
- [ ] Define local passcode domain model and cryptographic storage mechanism (using local salted hash, never sent to remote servers).
- [ ] Implement `PasscodeService` with setup, verification, change, and attempt rate-limiting.
- [ ] Build `AppLockScreen` matching `#000000`/`#383838` dark design with 4/6-digit numeric keypad and animated pin dots.
- [ ] Connect App Lifecycle Observer to lock app on background resume/timeout.
- [ ] Unit & widget tests verifying passcode verification, incorrect attempt lockouts, and app lock transitions.

---

## 8. Verification & Testing Matrix

### Current Automated Test Suite Status
- **Test Command:** `flutter test`
- **Results:** `14 / 14 tests passing` (100% pass rate)
- **Analyzer Check:** `flutter analyze` ➔ `No issues found! (ran in 4.1s)`

### Test Coverage Highlights
1. **Cryptographic Tests:** Random salt generation, SHA-256 consistency, username normalization, and input validation.
2. **Database Tests:** In-memory SQLite tests verifying account insertion, unique username enforcement, retrieval, and message CRUD.
3. **Authentication Tests:** Registration, duplicate username rejection, sign out, invalid password rejection, and correct credential login.
4. **UI Widget Tests:** `AuthScreen` tab switching, `AuthGate` session transitions, `ChatScreen` smoke test, message sending, and "Send luv" interaction.
