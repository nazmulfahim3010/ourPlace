# ourPlace — Privacy-First Messaging Application

> **Tagline:** *"The phones own the conversation. The server only helps the phones communicate."*  
> **Target Framework:** Flutter (Dart 3.11+)  
> **Design Aesthetic:** Minimalist High-Contrast Dark Mode (`#000000` pure black & `#383838` dark charcoal)  
> **Current Progress:** **Phase 9 Completed** (44/44 automated tests passing, 0 analyzer issues)

---

## 📚 Master Documentation & Diagrams

Quick access to master project specifications, task tracking, and architectural diagrams:

| Document | Description | Direct Link |
| :--- | :--- | :--- |
| **Project Tracker & Docs** | Single source of truth: 18-phase roadmap, milestones, ADRs, test matrix | [`docts.md`](file:///e:/ourPlace/docts.md) |
| **Architectural Diagrams** | 10 Mermaid diagrams covering topology, state machines, E2EE, and auto-lock flows | [`diagram.md`](file:///e:/ourPlace/diagram.md) |
| **Master Development Prompt** | Core vision, development rules, privacy principles, and constraints | [`Private Couple Chat App — Master Development Prompt.md`](file:///e:/ourPlace/Private%20Couple%20Chat%20App%20%E2%80%94%20Master%20Development%20Prompt.md) |

---

## 🗺️ Visual Architecture & Diagram Quick Links

Jump directly to specific architectural diagrams inside [`diagram.md`](file:///e:/ourPlace/diagram.md):

- [1. High-Level System Topology & Privacy Boundary](file:///e:/ourPlace/diagram.md#1-high-level-system-topology--privacy-boundary)
- [2. Three-Tier Credential Separation Model](file:///e:/ourPlace/diagram.md#2-three-tier-credential-separation-model)
- [3. App Launch & Authentication Gate State Machine](file:///e:/ourPlace/diagram.md#3-app-launch--authentication-gate-state-machine)
- [4. App Lifecycle & Background Auto-Lock Flow](file:///e:/ourPlace/diagram.md#4-app-lifecycle--background-auto-lock-flow)
- [5. Clean Architecture Layer Dependencies](file:///e:/ourPlace/diagram.md#5-clean-architecture-layer-dependencies)
- [6. End-to-End Encryption & Ephemeral Relay Protocol](file:///e:/ourPlace/diagram.md#6-end-to-end-encryption--ephemeral-relay-protocol)
- [7. Multi-User Navigation & Screen Hierarchy](file:///e:/ourPlace/diagram.md#7-multi-user-navigation--screen-hierarchy)
- [8. Love Connection & One-Time Love Code Sharing Flow](file:///e:/ourPlace/diagram.md#8-love-connection--one-time-love-code-sharing-flow)
- [9. Local Database Schema & Entity Relationships](file:///e:/ourPlace/diagram.md#9-local-database-schema--entity-relationships)
- [10. Security Enclave & Cryptographic Trust Boundaries](file:///e:/ourPlace/diagram.md#10-security-enclave--cryptographic-trust-boundaries)

---

## 📂 Source Code Quick Links

### 🚪 App Entry & Navigation Flow
- [`main.dart`](file:///e:/ourPlace/chatbox/lib/main.dart) — Application entrypoint with dark theme and dependency wiring
- [`auth_gate.dart`](file:///e:/ourPlace/chatbox/lib/screens/auth/auth_gate.dart) — Session & device lock coordinator with background auto-lock

### 📱 Screens (`lib/screens/`)
- [`home_screen.dart`](file:///e:/ourPlace/chatbox/lib/screens/home_screen.dart) — Main authenticated shell hosting Inbox and Profile
- [`inbox_screen.dart`](file:///e:/ourPlace/chatbox/lib/screens/inbox/inbox_screen.dart) — Inbox with real-time search, Love Connection section, and conversations list
- [`chat_screen.dart`](file:///e:/ourPlace/chatbox/lib/screens/chat_screen.dart) — Conversation view with SQLite persistence, auto-scroll, and "Send luv" action
- [`profile_screen.dart`](file:///e:/ourPlace/chatbox/lib/screens/profile/profile_screen.dart) — User profile card, Security & Passcode, Recovery Key backup & Security Audit Log
- [`auth_screen.dart`](file:///e:/ourPlace/chatbox/lib/screens/auth/auth_screen.dart) — Anonymous registration, login, rate limiting, and 12-word recovery reset
- [`app_lock_screen.dart`](file:///e:/ourPlace/chatbox/lib/screens/auth/app_lock_screen.dart) — Device lock with tactile keypad, biometrics, attempt warnings, and 60s lockout countdown
- [`passcode_setup_screen.dart`](file:///e:/ourPlace/chatbox/lib/screens/auth/passcode_setup_screen.dart) — Multi-step 4-digit PIN creation and biometric enrollment

### 🧩 UI Design System & Reusable Widgets (`lib/widgets/`)
- [`conversation_tile.dart`](file:///e:/ourPlace/chatbox/lib/widgets/conversation_tile.dart) — Conversation tile with Love Connection badge (`❤️`) and unread counters
- [`numeric_keypad.dart`](file:///e:/ourPlace/chatbox/lib/widgets/numeric_keypad.dart) — Charcoal tactile 70x70 numeric keypad with haptics & biometric button
- [`passcode_dots.dart`](file:///e:/ourPlace/chatbox/lib/widgets/passcode_dots.dart) — 4-digit animated indicator dots with shake feedback on error
- [`chat_header.dart`](file:///e:/ourPlace/chatbox/lib/widgets/chat_header.dart) — Floating pill-shaped header with partner info, active identity, and back navigation
- [`chat_input_field.dart`](file:///e:/ourPlace/chatbox/lib/widgets/chat_input_field.dart) — Capsule text input bar with circular send button
- [`message_bubble.dart`](file:///e:/ourPlace/chatbox/lib/widgets/message_bubble.dart) — 75% max-width message bubble with sent/received alignment
- [`date_divider.dart`](file:///e:/ourPlace/chatbox/lib/widgets/date_divider.dart) — Sticky date divider ("Today", "Yesterday", or formatted date)
- [`timestamp_indicator.dart`](file:///e:/ourPlace/chatbox/lib/widgets/timestamp_indicator.dart) — Subdued timestamp indicator

### 🔒 Security, Authentication & Services (`lib/services/`)
- [`access_throttling_service.dart`](file:///e:/ourPlace/chatbox/lib/services/access_throttling_service.dart) — Exponential backoff & login rate-limiting service (10s, 30s, 2m, 5m)
- [`auth_security_service.dart`](file:///e:/ourPlace/chatbox/lib/services/auth_security_service.dart) — Zero-knowledge challenge-response protocol engine (HMAC-SHA256 proofs)
- [`app_lock_service.dart`](file:///e:/ourPlace/chatbox/lib/services/app_lock_service.dart) — Local app lock manager (PIN throttling, 60s lockout, biometrics, state broadcast)
- [`secure_storage_service.dart`](file:///e:/ourPlace/chatbox/lib/services/secure_storage_service.dart) — Hardware Keystore abstraction (`flutter_secure_storage`)
- [`auth_service.dart`](file:///e:/ourPlace/chatbox/lib/services/auth_service.dart) — Session service with reactive `currentUserStream`, recovery resets & audit logs
- [`chat_service.dart`](file:///e:/ourPlace/chatbox/lib/services/chat_service.dart) — Transport service interface
- [`encryption_service.dart`](file:///e:/ourPlace/chatbox/lib/services/encryption_service.dart) — E2EE interface
- [`notification_service.dart`](file:///e:/ourPlace/chatbox/lib/services/notification_service.dart) — Push notification interface

### 🗄️ Repositories (`lib/repositories/`)
- [`auth_repository.dart`](file:///e:/ourPlace/chatbox/lib/repositories/auth_repository.dart) — Authentication repository contract, recovery key & throttling methods
- [`conversation_repository.dart`](file:///e:/ourPlace/chatbox/lib/repositories/conversation_repository.dart) — Multi-user conversations and Love Connection seed data
- [`chat_repository.dart`](file:///e:/ourPlace/chatbox/lib/repositories/chat_repository.dart) — Message sending, retrieval, and status management

### 💾 Local Database & Persistence (`lib/database/`)
- [`local_database.dart`](file:///e:/ourPlace/chatbox/lib/database/local_database.dart) — Singleton database manager with reactive queries, recovery keys, and SecurityLogs CRUD
- [`app_database.dart`](file:///e:/ourPlace/chatbox/lib/database/app_database.dart) — Drift SQLite schema v3 (`Messages`, `UserAccounts`, and `SecurityLogs` tables)
- [`app_database.g.dart`](file:///e:/ourPlace/chatbox/lib/database/app_database.g.dart) — Generated Drift database code

### 📦 Domain Models (`lib/models/`)
- [`user.dart`](file:///e:/ourPlace/chatbox/lib/models/user.dart) — Public anonymous User model
- [`user_account.dart`](file:///e:/ourPlace/chatbox/lib/models/user_account.dart) — Private account entity with salted verification & recovery key verification logic
- [`security_log.dart`](file:///e:/ourPlace/chatbox/lib/models/security_log.dart) — Device-local security event audit model
- [`conversation.dart`](file:///e:/ourPlace/chatbox/lib/models/conversation.dart) — Conversation domain model with Love Connection support
- [`message.dart`](file:///e:/ourPlace/chatbox/lib/models/message.dart) — `ChatMessage` model, `MessageType`, and `MessageStatus` enums

### 🛠️ Core Infrastructure & Tokens (`lib/core/`)
- [`recovery_key_utils.dart`](file:///e:/ourPlace/chatbox/lib/core/utils/recovery_key_utils.dart) — BIP-39 12-word recovery mnemonic generator, validator, normalizer, and verifier
- [`hash_utils.dart`](file:///e:/ourPlace/chatbox/lib/core/utils/hash_utils.dart) — Cryptographic salt generation (32 bytes), SHA-256 verifiers, username validation
- [`app_theme.dart`](file:///e:/ourPlace/chatbox/lib/core/theme/app_theme.dart) — Centralized dark theme tokens (`#000000` / `#383838`)
- [`app_constants.dart`](file:///e:/ourPlace/chatbox/lib/core/constants/app_constants.dart) — Credential constraints & app constants
- [`app_exception.dart`](file:///e:/ourPlace/chatbox/lib/core/errors/app_exception.dart) — Centralized exception hierarchy

### 🧪 Automated Tests (`test/`)
- [`widget_test.dart`](file:///e:/ourPlace/chatbox/test/widget_test.dart) — Automated test suite with 44 passing unit, repository, security, and widget tests (100% pass rate)

---

## ⚡ Quick Start & Development Commands

All commands should be executed from the `chatbox/` directory:

```bash
cd chatbox

# Check code health & analyze linting
flutter analyze

# Run the complete automated test suite (44 tests)
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

3. **Brute-Force & Rate-Limiting Protection:**
   - Account logins enforce exponential backoff (10s, 30s, 2m, 5m).
   - 5 incorrect device PIN attempts triggers a 60-second hardware interface lockout with real-time countdown timer.

4. **Zero-Knowledge Remote Verification Preparation:**
   - Challenge-response handshake protocol computes ephemeral HMAC-SHA256 client proofs over nonces so credentials are never sent across the wire.

5. **Device-Local Security Audit Logging:**
   - Complete security events log stored in Drift SQLite on device (`SecurityLogs` table) with zero cloud telemetry.

6. **Background Privacy Protection:**
   - App automatically locks on minimization, app-switching, or screen lock via `WidgetsBindingObserver`.
   - Conversations and messages are never left exposed in task switchers.