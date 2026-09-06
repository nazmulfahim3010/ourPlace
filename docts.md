# ourPlace — Master Project Documentation & Task Tracking Context
> **Document Version:** 1.0.0  
> **Last Updated:** 2026-09-06  
> **Target Application:** Private Couple Chat Application (`ourPlace`)  
> **Lead Framework:** Flutter (Dart 3.11+)

---

## 1. Executive Summary & Vision

**`ourPlace`** is an ultra-private, modern mobile messaging application designed exclusively for two authorized people (a couple).

### Core Philosophy
> *"Firebase helps the two phones communicate. The phones own the conversation."*

Unlike conventional messaging platforms that persist conversation history indefinitely on remote cloud servers, `ourPlace` enforces a **local-first, privacy-centric architecture**:
- **Permanent Chat History:** Resides exclusively in the local database (SQLite/Drift) on the two users' physical devices.
- **Remote Infrastructure (Firebase):** Functions strictly as an identity provider (Authentication) and an ephemeral transport relay.
- **End-to-End Encryption (E2EE):** Plaintext never leaves the device unencrypted; Firebase and network intermediaries only see encrypted ciphertexts. Ephemeral relay messages are destroyed upon successful delivery receipt.
- **Aesthetic:** Minimalist, sleek, high-contrast dark theme (pure black `#000000` with dark charcoal `#383838` containers and white typography).

---

## 2. Project Development Status & Roadmap Tracker

In accordance with the **Master Development Rules**, progress is tracked strictly against the 14 defined phases. Phases must be completed sequentially without skipping ahead.

### Current Status Dashboard

| Metric | Status |
| :--- | :--- |
| **Current Phase** | **Phase 5 — Application Architecture & Repositories** |
| **Current Status** | Clean architecture refactoring & repository abstraction |
| **Completed Phases** | **Phase 1** (UI Prototypes), **Phase 2** (Message Architecture), **Phase 3** (Functional Local Chat), **Phase 4** (Local Database with Drift / SQLite) |
| **Next Phase** | **Phase 6 — Firebase Authentication** |

---

### Phase-by-Phase Roadmap Matrix

```
[Phase 1: UI Prototype]  ──►  [Phase 2: Message Model]  ──►  [Phase 3: Local Chat]
       (COMPLETED)                     (COMPLETED)                     (COMPLETED)
                                                                          │
                                                                          ▼
[Phase 6: Firebase Auth] ◄──  [Phase 5: Clean Arch]     ◄──  [Phase 4: Local DB]
       (PLANNED)                       (CURRENT)                       (COMPLETED)
          │
          ▼
[Phase 7: Security Rules]──►  [Phase 8: E2EE Layer]     ──►  [Phase 9: Temp Relay]
       (PLANNED)                       (PLANNED)                     (PLANNED)
                                                                          │
                                                                          ▼
[Phase 12: Push Notifs]  ◄──  [Phase 11: Real-Time]     ◄──  [Phase 10: Message Sync]
       (PLANNED)                       (PLANNED)                     (PLANNED)
          │
          ▼
[Phase 13: Media Messages]──► [Phase 14: Couple Features]
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
  - [x] Model utilities (`copyWith`, `copyWithStatus`, `isSent`, UI compatibility getters)
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

- [ ] **Phase 5 — Application Architecture Refactoring**
  - [x] Separate `models/`, `widgets/`, `screens/`, `services/`, `database/`
  - [ ] Establish `core/` (constants, theme, error handling, utils)
  - [ ] Establish `repositories/` (`ChatRepository`, `AuthRepository`)
  - [ ] Integrate formal state management (e.g., Riverpod or Bloc)
  - [ ] Decouple UI directly from services/database

- [ ] **Phase 6 — Firebase Authentication**
  - [ ] Configure Firebase CLI & `firebase_core` for Flutter
  - [ ] Setup Firebase Auth for exactly two whitelisted user accounts
  - [ ] Build login / splash view
  - [ ] Persist auth tokens securely with auto-login and session validation
  - [ ] Restrict access: strictly two authorized UIDs

- [ ] **Phase 7 — Security Model**
  - [ ] Firestore / Realtime Database security rules strictly locking down read/write to the two authorized UIDs
  - [ ] Client verification preventing unauthorized user spoofing
  - [ ] Secure storage (`flutter_secure_storage`) for sensitive tokens and device keys
  - [ ] Zero sensitive credentials hardcoded in the codebase

- [ ] **Phase 8 — End-to-End Encryption (E2EE)**
  - [ ] Cryptographic design document (Signal protocol or X25519 + AES-GCM / ChaCha20-Poly1305)
  - [ ] Key generation, storage in hardware Keystore/Keychain, and public key exchange
  - [ ] Encrypt plaintext message payloads before dispatching to relay
  - [ ] Decrypt ciphertext payloads locally on the recipient device

- [ ] **Phase 9 — Firebase Ephemeral Relay**
  - [ ] Outgoing messages published as ciphertext to temporary relay queue
  - [ ] Recipient listener ingests incoming ciphertext and acknowledges delivery
  - [ ] Sender/server purges temporary relay records upon confirmed delivery
  - [ ] Offline queue handling (messages wait on relay only until recipient comes online)

- [ ] **Phase 10 — Message Synchronization & Status Lifecycle**
  - [ ] State transitions: `sending` ➔ `sent` ➔ `delivered` ➔ `read` (or `failed`)
  - [ ] Message retry queue for network drops / offline reconnects
  - [ ] Duplicate message deduplication via unique UUIDs
  - [ ] Bi-directional sync between local SQLite and remote acknowledgements

- [ ] **Phase 11 — Real-Time Features**
  - [ ] Real-time typing indicators with debounce
  - [ ] Ephemeral presence (online / offline / last active timestamp)
  - [ ] Real-time read receipt updates
  - [ ] Battery- and quota-efficient socket / stream listeners

- [ ] **Phase 12 — Push Notifications**
  - [ ] Firebase Cloud Messaging (FCM) integration
  - [ ] Background message handlers
  - [ ] Privacy-preserving notification payloads (no plaintext leaks in OS banners)
  - [ ] Tap notification deep-linking directly into chat

- [ ] **Phase 13 — Media Messaging**
  - [ ] Image, voice note, and video attachment capture/picker
  - [ ] Client-side encryption of media files prior to upload
  - [ ] Temporary signed cloud storage upload/download
  - [ ] Local caching and decryption of media assets
  - [ ] Automatic remote media purge after retrieval

- [ ] **Phase 14 — Couple-Specific Features**
  - [ ] Interactive "Send luv" animated micro-interaction & haptics
  - [ ] Floating heart animations & reactions
  - [ ] "Open When..." time-locked or location-locked notes
  - [ ] Relationship timeline & anniversary countdown
  - [ ] Shared photo memory gallery

---

## 3. Codebase Architecture & File Structure

The workspace contains the primary Flutter application under the `chatbox/` directory:

```
e:\ourPlace\
├── .git/                                    # Git repository
├── Private Couple Chat App — Master...md    # Master specification & rules prompt
├── docts.md                                 # Full project documentation & task tracker (this file)
├── README.md                                # Root repository readme
├── demoproject/                             # Standalone scaffold (experimental / scratch)
└── chatbox/                                 # PRIMARY FLUTTER APPLICATION
    ├── pubspec.yaml                         # Dependencies and assets configuration
    ├── analysis_options.yaml                # Linter rules configuration
    ├── lib/
    │   ├── main.dart                        # Application entry point
    │   ├── chat_screen.dart                 # [LEGACY] Original monolithic UI (Phase 1)
    │   ├── database/
    │   │   └── local_database.dart          # Database service interface stub
    │   ├── models/
    │   │   └── message.dart                 # ChatMessage model & enums (Phase 2)
    │   ├── screens/
    │   │   └── chat_screen.dart             # Modularized ChatScreen widget (Phases 2-3)
    │   ├── services/
    │   │   └── chat_service.dart            # Chat business logic service stub
    │   └── widgets/
    │       ├── chat_header.dart             # Floating pill header with partner info
    │       ├── chat_input_field.dart        # Message input bar and send button
    │       ├── message_bubble.dart          # Chat message bubble container
    │       └── timestamp_indicator.dart     # Timestamp indicator widget
    └── test/
        └── widget_test.dart                 # Flutter widget test suite
```

---

## 4. Deep Dive: What Has Been Built So Far

### 4.1. Core Data Model (`chatbox/lib/models/message.dart`)
The core domain model encapsulates complete metadata for chat messages:

```dart
enum MessageType { text, image, audio, video, system }
enum MessageStatus { sending, sent, delivered, read, failed }

class ChatMessage {
  final String id;              // Unique identifier (UUID or timestamp-based)
  final String senderId;        // Sender user ID ('current_user' or partnerId)
  final String recipientId;     // Target recipient user ID
  final String text;            // Message text payload
  final DateTime timestamp;     // UTC creation timestamp
  final MessageType type;       // Payload type enum
  final MessageStatus status;   // Delivery status lifecycle enum

  bool get isSent => senderId == 'current_user';
  Map<String, dynamic> toJson();
  factory ChatMessage.fromJson(Map<String, dynamic> json);
  ChatMessage copyWith(...);
  ChatMessage copyWithStatus(MessageStatus newStatus);
}
```

### 4.2. UI Design System & Component Library (`chatbox/lib/widgets/`)
All UI components strictly adhere to the minimalist dark aesthetic:
- **`ChatHeader` (`chat_header.dart`):**  
  A floating pill-shaped container (`BoxDecoration(color: Color(0xFF383838), borderRadius: BorderRadius.circular(24))`) anchored inside a `SafeArea`. Displays partner's avatar, partner name, and a "💕 Send luv" button.
- **`ChatInputField` (`chat_input_field.dart`):**  
  Custom bottom text field encased in a `0xFF383838` rounded capsule (`borderRadius: BorderRadius.circular(28)`) with white cursor and `#AAAAAA` placeholder, paired with a matching circular send button.
- **`MessageBubble` (`message_bubble.dart`):**  
  Constrained to 75% max viewport width. Sent messages align right; received messages align left. Encased in dark charcoal with `BorderRadius.circular(20)`.
- **`TimestampIndicator` (`timestamp_indicator.dart`):**  
  Renders formatted time strings (`HH:mm`) in `Colors.white54` above each message bubble, aligned to match the sender orientation.

### 4.3. Main Screen & Interaction Flow (`chatbox/lib/screens/chat_screen.dart`)
- Hosts the message state `List<ChatMessage> _messages`.
- Pre-populated with structured mock messages demonstrating both received and sent messages across different statuses (`read`, `delivered`).
- Implements `_sendMessage()`: validates input, creates a new `ChatMessage` with `MessageStatus.sending`, prepends it to the reversed `ListView`, and clears the text controller.
- Displays feedback on "Send luv" taps using `ScaffoldMessenger` snackbars.

### 4.4. Service & Persistence Skeletons
- **`ChatService` (`chatbox/lib/services/chat_service.dart`):**  
  Singleton pattern stubbed out with asynchronous methods (`sendMessage`, `fetchMessages`, `sendLuv`, `markMessagesAsRead`, `deleteMessage`, `editMessage`).
- **`LocalDatabase` (`chatbox/lib/database/local_database.dart`):**  
  Singleton service stub with contracts for database initialization, saving, paginated queries, searching, updates, deletions, and connection lifecycle.

---

## 5. Target Architecture & End-to-End Flow

```
+-------------------------------------------------------------------------+
|                              USER 1 DEVICE                              |
|                                                                         |
|  +--------------------+       +--------------------------------------+  |
|  |    Flutter UI      | <---> |   Local Database (Drift / SQLite)    |  |
|  +--------------------+       +--------------------------------------+  |
|            |                                     |                      |
|            v                                     v                      |
|  +--------------------+       +--------------------------------------+  |
|  | State / Repository | ----> | E2EE Encryption Engine (AES / Curve) |  |
|  +--------------------+       +--------------------------------------+  |
+--------------------------------------------------|----------------------+
                                                   | Encrypted Payload
                                                   v
                     +-------------------------------------------+
                     |         FIREBASE TEMPORARY RELAY          |
                     |  - Cloud Firestore / Realtime DB Queue    |
                     |  - Holds ephemeral ciphertext ONLY        |
                     |  - Purged immediately upon receipt ack    |
                     +-------------------------------------------+
                                                   |
                                                   | Encrypted Payload
                                                   v
+--------------------------------------------------|----------------------+
|                              USER 2 DEVICE                              |
|                                                                         |
|  +--------------------+       +--------------------------------------+  |
|  |    Flutter UI      | <---> |   Local Database (Drift / SQLite)    |  |
|  +--------------------+       +--------------------------------------+  |
|            ^                                     ^                      |
|            |                                     |                      |
|  +--------------------+       +--------------------------------------+  |
|  | State / Repository | <---- | E2EE Decryption Engine (AES / Curve) |  |
|  +--------------------+       +--------------------------------------+  |
+-------------------------------------------------------------------------+
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
   Do not introduce Firebase, E2EE, or Push Notifications while local chat and persistence are incomplete. Complete Phase 3 and Phase 4 first.
3. **Rule 3 — Preserve Working Code:**  
   Do not rewrite functional UI or logic without justification. Retain the existing dark charcoal/black design identity.
4. **Rule 4 — Work Incrementally:**  
   Implement one milestone at a time; test and verify before moving forward.
5. **Rule 5 — Architectural Explanations:**  
   Document *why* a design decision was made, not just *how*.
6. **Rule 6 — Test Checklists:**  
   Accompany each completed feature with an explicit manual/automated testing checklist.
7. **Rule 7 — Dependency Restraint:**  
   Add only essential, well-maintained packages.
8. **Rule 8 — Security over Convenience:**  
   Never compromise end-to-end encryption or backend authentication to take shortcuts.

---

## 7. Immediate Action Items & Future Task Backlog

### Immediate Next Steps (Finishing Phase 3 ➔ Starting Phase 4)

#### Task 3.1: Complete Functional Local Chat (Phase 3)
- [x] Add date dividers between message groups (e.g., "Today", "Yesterday").
- [x] Implement auto-scroll to latest message when sending.
- [x] Connect `ChatInputField` submit action (Enter key / keyboard done action).
- [x] Handle keyboard focus dismiss when tapping outside input.

#### Task 3.2: Technical Debt Cleanup
- [x] Modernize constructor parameters across widgets to use super parameters (`super.key`) to clear the 12 `use_super_parameters` analyzer lints.
- [x] Forward legacy `chatbox/lib/chat_screen.dart` to `chatbox/lib/screens/chat_screen.dart` to remove duplication.
- [x] Update `chatbox/test/widget_test.dart` to smoke test `ChatScreen` instead of the non-existent counter app (100% tests passing).
- [ ] Clarify / clean up `demoproject/` workspace folder.

#### Task 4.1: SQLite / Drift Integration (Phase 4)
- [x] Add `drift`, `drift_flutter`, `drift_dev`, and `build_runner` to `chatbox/pubspec.yaml`.
- [x] Implement `Messages` table schema matching `ChatMessage` domain model.
- [x] Generate `app_database.g.dart` using `build_runner`.
- [x] Connect `LocalDatabase` singleton implementation to Drift `AppDatabase`.
- [x] Wire message sending to save to SQLite, query on startup, and update UI reactively.
- [x] Comprehensive in-memory SQLite unit and widget tests passing (4/4 tests).

---

## 8. Verification & Testing Matrix

### Manual Verification Flow for Current State
1. **Launch App:** Run `flutter run` inside `chatbox/`.
2. **UI Inspection:**
   - Confirm pure black background `#000000`.
   - Confirm floating pill header showing "Alex" avatar and "Send luv" button.
   - Confirm mock messages load with proper right-align (You) and left-align (Alex).
3. **Send Message:**
   - Type `"Hello sweetheart"` into bottom input field.
   - Tap send icon.
   - Verify input field clears immediately.
   - Verify `"Hello sweetheart"` appears at the bottom of the chat list with timestamp and right alignment.
4. **Send Luv:**
   - Tap "💕 Send luv" in header.
   - Verify dark charcoal SnackBar appears stating `"💕 Love sent!"`.
