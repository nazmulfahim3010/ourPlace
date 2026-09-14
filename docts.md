# ourPlace — Master Project Documentation & Task Tracking Context
> **Document Version:** 3.0.0  
> **Last Updated:** 2026-09-14  
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
| **Current Phase** | **Phase 8 — Local App Passcode & Device Lock** |
| **Current Status** | **COMPLETED** (Ready for Phase 9: Account & Access Security) |
| **Completed Phases** | **Phase 1** (UI Prototypes), **Phase 2** (Message Architecture), **Phase 3** (Functional Local Chat), **Phase 4** (Local Database), **Phase 5** (Application Architecture), **Phase 6** (Inbox & Multi-Conversation UI), **Phase 7** (Anonymous Account Authentication), **Phase 8** (Local App Passcode & Device Lock) |
| **Next Phase** | **Phase 9 — Account & Access Security** |

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
       (COMPLETED)                     (COMPLETED)                       (NEXT)
                                                                          │
                                                                          ▼
[Phase 12: Message Sync] ◄──  [Phase 11: Temp Relay]    ◄──  [Phase 10: E2EE Layer]
       (PLANNED)                       (PLANNED)                     (PLANNED)
          │
          ▼
[Phase 13: Real-Time]    ──►  [Phase 14: Push Notifs]   ──►  [Phase 15: Media]
       (PLANNED)                       (PLANNED)                     (PLANNED)
                                                                          │
                                                                          ▼
[Phase 18: Couple Feat.] ◄──  [Phase 17: Love Code/Share]◄── [Phase 16: Love Connection]
       (PLANNED)                       (PLANNED)                     (PLANNED)
```

#### Detailed Phase Progress Breakdown               (PLANNED)                     (PLANNED)
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

- [ ] **Phase 9 — Account & Access Security**
  - [ ] Remote verification protocols without exposing passwords
  - [ ] Rate-limiting and brute-force protection
  - [ ] Privacy-preserving recovery key architecture

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
    │   │   ├── conversation.dart            # Conversation model with Love Connection support
    │   │   ├── message.dart                 # ChatMessage domain model & enums
    │   │   ├── user.dart                    # Anonymous User domain model
    │   │   └── user_account.dart            # UserAccount credentials & verification
    │   ├── repositories/
    │   │   ├── auth_repository.dart         # AuthRepository contract & default implementation
    │   │   ├── chat_repository.dart         # ChatRepository contract & LocalChatRepository
    │   │   └── conversation_repository.dart # ConversationRepository & LocalConversationRepository
    │   ├── screens/
    │   │   ├── auth/
    │   │   │   ├── auth_gate.dart           # Reactive session gate routing to HomeScreen/AuthScreen
    │   │   │   └── auth_screen.dart         # Dark-themed login & registration UI
    │   │   ├── home_screen.dart             # Primary Home screen hosting Inbox & Profile nav
    │   │   ├── inbox/
    │   │   │   └── inbox_screen.dart        # Inbox displaying Love Connection & Conversations
    │   │   ├── profile/
    │   │   │   └── profile_screen.dart      # User Profile, Love Connection status, & privacy
    │   │   └── chat_screen.dart             # Modular ChatScreen widget with active user context
    │   ├── services/
    │   │   ├── auth_service.dart            # AuthService contract & LocalAuthService
    │   │   ├── chat_service.dart            # Chat transport service contract
    │   │   ├── encryption_service.dart      # E2EE contract & NoOp implementation
    │   │   └── notification_service.dart    # Push notifications contract & stub
    │   └── widgets/
    │       ├── chat_header.dart             # Floating pill header with back button, user & partner
    │       ├── chat_input_field.dart        # Message input bar and send button
    │       ├── conversation_tile.dart       # Reusable conversation tile component
    │       ├── date_divider.dart            # Date group divider ("Today", "Yesterday")
    │       ├── message_bubble.dart          # Chat message bubble container
    │       └── timestamp_indicator.dart     # Timestamp indicator widget
    └── test/
        └── widget_test.dart                 # Automated test suite (20/20 tests passing)
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

#### `User` & `UserAccount` (`chatbox/lib/models/`)
- **`User` (`user.dart`):** Public domain representation containing `id`, `username` (`@username`), `displayName`, `createdAt`, `publicIdentityKey`, `loveConnectionId`, `loveConnectionVisibility`, and `isCurrentUser`.
- **`UserAccount` (`user_account.dart`):** Internal entity storing `accountId`, normalized `username`, `passwordHash`, `salt`, `createdAt`, and `publicIdentityKey`. Exposes `verifyPassword(candidate)` to match against salted hashes without exposing credentials.

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

### 4.3. Navigation & Screen Architecture (`chatbox/lib/screens/`)
- **`HomeScreen` (`home_screen.dart`):** Top-level coordinator hosting `InboxScreen` and pushing `ProfileScreen`.
- **`InboxScreen` (`inbox/inbox_screen.dart`):** Main authenticated view with search filtering, `❤️ LOVE CONNECTION` section, `CONVERSATIONS` section, pull-to-refresh, empty state, and new conversation dialog (`+`). Tapping any tile navigates to `ChatScreen`.
- **`ProfileScreen` (`profile/profile_screen.dart`):** User identity card, Love Connection status with profile visibility toggle, privacy summary, and sign-out action.
- **`ChatScreen` (`chat_screen.dart`):** Conversation thread view with message persistence, auto-scroll, date dividers, and send actions.

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

## 7. Phase 6 Completion & Milestone Report

- **Current Phase:** Phase 6 — Inbox & Multi-Conversation UI
- **Phase Status:** COMPLETED

### Completed Work
1. Upgraded application primary navigation from a single 1-on-1 chat prototype to an authenticated multi-user **Inbox**.
2. Created `Conversation` domain model with unread counting, formatted relative timestamps, and Love Connection indicator flags.
3. Created reusable `ConversationTile` component adhering to the dark charcoal `#383838` design token, with circular avatar, Love Connection badge (`❤️`), snippet preview, and unread pill count.
4. Created `ConversationRepository` contract and `LocalConversationRepository` with seed contacts (Love Connection `@twilight`, and users `@sarah`, `@rahim`, `@elena`).
5. Built `InboxScreen` with floating search bar, real-time client-side search filtering, sticky Love Connection section, conversations list, empty search state, and new chat dialog (`+`).
6. Built `HomeScreen` navigation coordinator and `ProfileScreen` with anonymous `@username` identity card, Love Connection status with profile visibility toggle, privacy overview, and sign-out button.
7. Updated `ChatHeader` to display an inline back button (`<`) whenever navigated from Inbox, preserving full backward compatibility with the existing chat thread, local SQLite persistence, and "Send luv" actions.
8. Implemented `AuthGate` routing to `HomeScreen` for authenticated sessions and `AuthScreen` when logged out.
9. Implemented foundational `UserAccount` and `HashUtils` (salted SHA-256 verifiers) ready for Phase 7 authentication.

### Files Created
- `chatbox/lib/core/utils/hash_utils.dart`: Cryptographic salt generation, SHA-256 verifiers, and username validation/normalization.
- `chatbox/lib/models/user_account.dart`: Private account entity with salted verification logic.
- `chatbox/lib/repositories/conversation_repository.dart`: Multi-conversation repository contract and local implementation.
- `chatbox/lib/screens/auth/auth_gate.dart`: Session state coordinator directing to `HomeScreen` or `AuthScreen`.
- `chatbox/lib/screens/auth/auth_screen.dart`: Anonymous account login and creation screen with dark aesthetic.
- `chatbox/lib/screens/home_screen.dart`: Primary shell hosting `InboxScreen` and pushing `ProfileScreen`.
- `chatbox/lib/screens/inbox/inbox_screen.dart`: Primary Inbox view with search, Love Connection, and conversations list.
- `chatbox/lib/screens/profile/profile_screen.dart`: Profile identity, Love Connection status, privacy settings, and sign-out.
- `chatbox/lib/widgets/conversation_tile.dart`: Modular conversation list item component.

### Files Modified
- `chatbox/lib/core/constants/app_constants.dart`: Added username and password length constraints.
- `chatbox/lib/database/app_database.dart`: Added `UserAccounts` table with unique username constraint (Schema version 2).
- `chatbox/lib/database/app_database.g.dart`: Generated Drift table code.
- `chatbox/lib/database/local_database.dart`: Added account CRUD methods (`saveAccount`, `getAccountByUsername`, `verifyAccountCredentials`).
- `chatbox/lib/main.dart`: Wired app entrypoint to `AuthGate` with `AppTheme.darkTheme`.
- `chatbox/lib/models/conversation.dart`: Added `isLoveConnection`, `unreadCount`, `lastMessageAt`, and `formattedTimestamp`.
- `chatbox/lib/models/message.dart`: Added `recipientId` support and multi-user compatibility.
- `chatbox/lib/models/user.dart`: Extended with love connection visibility attributes.
- `chatbox/lib/repositories/auth_repository.dart`: Updated to use `LocalAuthService` with salted credential verification.
- `chatbox/lib/screens/chat_screen.dart`: Integrated active user and partner metadata from conversation.
- `chatbox/lib/services/auth_service.dart`: Enhanced with `currentUserStream` and session management.
- `chatbox/lib/widgets/chat_header.dart`: Added back navigation button and dynamic partner title.
- `chatbox/lib/widgets/message_bubble.dart`: Updated to evaluate dynamic current user sender IDs.
- `chatbox/pubspec.yaml` / `chatbox/pubspec.lock`: Added `crypto: ^3.0.6`.
- `chatbox/test/widget_test.dart`: Added 20 automated tests covering crypto, database, models, auth, and UI.
- `docts.md`: Synchronized documentation, roadmap matrix, and ADRs.

### Architecture Changes
- **Single-Chat to Multi-User:** Transformed the top-level UX from a single hard-coded chat to an extensible Inbox architecture backing any number of conversations.
- **Love Connection Isolation:** The Love Connection is highlighted visually as a special relationship category without conferring blanket permissions or automatic access to other user threads.
- **Strict Credential Separation:** Laid architectural boundaries separating Account Passwords (remote auth via salted hashes), Local App Passcodes (device lock PINs in Phase 8), and Love Codes (ephemeral 60s sharing authorizations in Phase 17).

### UI Changes
- Replaced direct opening of `ChatScreen` with `InboxScreen`.
- Designed `ConversationTile` matching `#000000` / `#383838` dark palette with heart badge (`❤️`) for Love Connection.
- Real-time instant search bar with empty state handling.
- Back button navigation in `ChatHeader` enabling seamless round-trip between Inbox and individual chats.
- `ProfileScreen` with privacy stats, identity details, and toggleable Love Connection visibility.

### Tests Performed
- Ran full test suite via `flutter test` across:
  - Cryptographic salt generation, hashing consistency, username normalization, and password verification (5 tests).
  - SQLite local database storage for accounts and messages (4 tests).
  - Conversation repository seed retrieval, unread counts, and new chat creation (3 tests).
  - Authentication service registration, duplicate username rejection, sign in, and sign out (1 test).
  - Chat repository message delegation (1 test).
  - Widget UI tests for `ConversationTile`, `InboxScreen`, navigation, `AuthScreen`, `AuthGate`, and `ChatScreen` (6 tests).
- Ran code analysis via `flutter analyze`.

### Test Results
- **`flutter test`:** 20 / 20 tests passed (100%).
- **`flutter analyze`:** No issues found (0 warnings, 0 errors).

### Known Limitations
- Network relay and cloud directory sync are not yet implemented (by design, planned for Phases 10–12).
- Love Code single-use sharing protocol belongs to Phase 17.

---

## 8. Phase 8 Completion & Milestone Report

- **Current Phase:** Phase 8 — Local App Passcode & Device Lock
- **Phase Status:** COMPLETED

### Completed Work
1. Implemented `SecureStorageService` interface with `DefaultSecureStorageService` (`flutter_secure_storage` hardware-backed keystore/keychain) and `InMemorySecureStorageService` for unit testing.
2. Built `AppLockService` with `DefaultAppLockService` managing salted SHA-256 passcode verifiers (`HashUtils.hashPassword`), `LocalAuthentication` biometric prompts, toggleable biometric unlock, and reactive state broadcast.
3. Created animated `PasscodeDots` indicator with error shake animation and red glow on incorrect entry.
4. Created tactile dark `NumericKeypad` with haptic feedback, 70x70 keys, backspace, and biometric icon button.
5. Built `AppLockScreen` supporting unlock and current-passcode verification modes, auto-biometric prompt, and account re-login fallback.
6. Built `PasscodeSetupScreen` with multi-step creation and confirmation flow, mismatch handling, and optional biometric activation bottom sheet.
7. Enhanced `AuthGate` with `WidgetsBindingObserver` to auto-lock on app background/pause and route cleanly between `AuthScreen`, `PasscodeSetupScreen`, `AppLockScreen`, and `HomeScreen`.
8. Added "Security & App Lock" card to `ProfileScreen` with passcode active status, biometric unlock toggle, change passcode action, and "Lock App Now" button.
9. Added 9 automated tests for App Lock & Biometrics, bringing the automated test suite to 29/29 passing tests (100%).

### Files Created
- `chatbox/lib/services/secure_storage_service.dart`: Encrypted key-value hardware storage contract and implementations.
- `chatbox/lib/services/app_lock_service.dart`: Device passcode & biometric authentication service.
- `chatbox/lib/widgets/passcode_dots.dart`: Animated 4-digit indicator dots with shake feedback.
- `chatbox/lib/widgets/numeric_keypad.dart`: Charcoal numeric keypad with tactile feedback.
- `chatbox/lib/screens/auth/app_lock_screen.dart`: Dedicated device lock screen.
- `chatbox/lib/screens/auth/passcode_setup_screen.dart`: Passcode creation, confirmation, and biometric setup flow.

### Files Modified
- `chatbox/pubspec.yaml` / `chatbox/pubspec.lock`: Added `local_auth: ^3.0.2` and `flutter_secure_storage: ^11.1.1`.
- `chatbox/android/app/src/main/kotlin/com/example/chatbox/MainActivity.kt`: Inherits from `FlutterFragmentActivity`.
- `chatbox/android/app/src/main/AndroidManifest.xml`: Declared `USE_BIOMETRIC` permission.
- `chatbox/lib/main.dart`: Wired `appLockService` parameter through `MyApp`.
- `chatbox/lib/screens/home_screen.dart`: Passed `appLockService` to `ProfileScreen`.
- `chatbox/lib/screens/auth/auth_gate.dart`: Coordinated session and device lock lifecycle.
- `chatbox/lib/screens/profile/profile_screen.dart`: Added "Security & App Lock" settings card.
- `chatbox/test/widget_test.dart`: Added 9 new unit and widget tests (29 tests total).
- `docts.md`: Synchronized documentation, ADR 3, and status matrix.

### Next Phase
- **Phase 9 — Account & Access Security:** Remote verification protocols, rate-limiting, brute-force protection, and recovery key architecture.

---

## 9. Verification & Testing Matrix

### Current Automated Test Suite Status
- **Test Command:** `flutter test`
- **Results:** `29 / 29 tests passing` (100% pass rate)
- **Analyzer Check:** `flutter analyze` ➔ `No issues found! (ran in 5.6s)`

### Test Coverage Highlights
1. **Cryptographic Tests (5 tests):** Random salt generation, SHA-256 consistency, username normalization, input validation, and salted password verification.
2. **Database Tests (4 tests):** In-memory SQLite tests verifying account insertion, unique username enforcement, retrieval, and message CRUD.
3. **Conversation Tests (3 tests):** Seed loading, Love Connection retrieval, starting/finding conversations, and marking as read.
4. **Authentication Tests (1 test):** Registration, duplicate username rejection, sign out, invalid password rejection, and correct credential login.
5. **Chat Repository Tests (1 test):** Message delegation, status updates, and message retrieval.
6. **UI Widget Tests (6 tests):**
   - `ConversationTile`: Love Connection styling, badge rendering, and tap callbacks.
   - `InboxScreen`: Header, search bar filtering, Love Connection section, conversations section.
   - Navigation: Tapping conversation opens `ChatScreen`, and back button returns to `InboxScreen`.
   - `AuthScreen`: Tab switching between Sign In and Create Account.
   - `AuthGate`: Presenting `HomeScreen` on active session and `AuthScreen` on logout.
   - `ChatScreen`: Smoke test, sending message, and "Send luv" interaction.
7. **App Lock & Secure Storage Tests (3 tests):**
   - Passcode salting and hashing without plaintext storage.
   - Passcode verification and app unlock.
   - Biometric toggle and clear passcode lifecycle.
8. **App Lock UI Widget Tests (6 tests):**
   - `PasscodeDots`: Filled/unfilled rendering and error state.
   - `NumericKeypad`: Digit, backspace, and biometric callback handling.
   - `PasscodeSetupScreen`: Create, confirm, mismatch error reset, and complete.
   - `AppLockScreen`: Incorrect passcode error and correct passcode unlock.
   - `AuthGate`: First-time setup routing and lock-state coordination.
   - `ProfileScreen`: Security card display, active passcode badge, and "Lock App Now" action.

