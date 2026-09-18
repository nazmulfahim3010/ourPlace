# ourPlace — Architectural & Technical Diagrams Specification
> **Document Version:** 1.3.0  
> **Last Updated:** 2026-09-18  
> **Target Application:** Privacy-First Anonymous Multi-User Messaging Application with Couple Subsystem (`ourPlace`)  
> **Companion Document:** [`docts.md`](file:///e:/ourPlace/docts.md)

---

## Table of Contents
1. [High-Level System Topology & Privacy Boundary](#1-high-level-system-topology--privacy-boundary)
2. [Three-Tier Credential Separation Model](#2-three-tier-credential-separation-model)
3. [App Launch & Authentication Gate State Machine](#3-app-launch--authentication-gate-state-machine)
4. [App Lifecycle & Background Auto-Lock Flow](#4-app-lifecycle--background-auto-lock-flow)
5. [Clean Architecture Layer Dependencies](#5-clean-architecture-layer-dependencies)
6. [End-to-End Encryption & Ephemeral Relay Protocol](#6-end-to-end-encryption--ephemeral-relay-protocol)
7. [Multi-User Navigation & Screen Hierarchy](#7-multi-user-navigation--screen-hierarchy)
8. [Love Connection & One-Time Love Code Sharing Flow](#8-love-connection--one-time-love-code-sharing-flow)
9. [Local Database Schema & Entity Relationships](#9-local-database-schema--entity-relationships)
10. [Security Enclave & Cryptographic Trust Boundaries](#10-security-enclave--cryptographic-trust-boundaries)
11. [Message State Lifecycle & Synchronization Flow](#11-message-state-lifecycle--synchronization-flow)

---

## 1. High-Level System Topology & Privacy Boundary

The core philosophy of `ourPlace` is:
> *"The phones own the conversation. The server only helps the phones communicate."*

```mermaid
flowchart TB
    subgraph DeviceA["User Device A (Local Sandbox)"]
        UI_A["Flutter UI (Inbox & Chat)"]
        Auth_A["Auth & AppLock Service"]
        DB_A[("Local SQLite Database (Permanent Messages)")]
        KeyStore_A[("Hardware Keystore / Keychain (Local PIN Verifier)")]
        E2EE_A["E2EE Cryptographic Engine (Signal Protocol / Ratchet)"]
    end

    subgraph FirebaseCloud["Untrusted Ephemeral Cloud (Firebase)"]
        AuthRelay["Identity & Signaling Routing"]
        CiphertextRelay["Ephemeral Ciphertext Queue (Purged immediately upon delivery)"]
        FCM["Push Notifications (No message content)"]
    end

    subgraph DeviceB["User Device B (Local Sandbox)"]
        UI_B["Flutter UI (Inbox & Chat)"]
        Auth_B["Auth & AppLock Service"]
        DB_B[("Local SQLite Database (Permanent Messages)")]
        KeyStore_B[("Hardware Keystore / Keychain (Local PIN Verifier)")]
        E2EE_B["E2EE Cryptographic Engine (Signal Protocol / Ratchet)"]
    end

    UI_A <--> Auth_A
    Auth_A <--> KeyStore_A
    UI_A <--> DB_A
    UI_A <--> E2EE_A

    UI_B <--> Auth_B
    Auth_B <--> KeyStore_B
    UI_B <--> DB_B
    UI_B <--> E2EE_B

    E2EE_A -- "1. Dispatch Encrypted Ciphertext" --> CiphertextRelay
    Auth_A -- "Signaling & User Directory" --> AuthRelay
    AuthRelay -- "Signaling & User Directory" --> Auth_B
    CiphertextRelay -- "Silent Wakeup Signal" --> FCM
    FCM -- "FCM Ping" --> DeviceB
    CiphertextRelay -- "2. Pull Ciphertext & Ack Delivery" --> E2EE_B
    E2EE_B -- "3. Purge Request" --> CiphertextRelay
```

---

## 2. Three-Tier Credential Separation Model

`ourPlace` enforces strict isolation between account authentication, local device security, and ephemeral love sharing:

```mermaid
classDiagram
    class AccountPassword {
        +String candidatePassword
        +String randomSalt (32 bytes)
        +String saltedSha256Hash
        +verifyPassword(candidate)
        -- Scope --
        Remote Account Verification
        Never plaintext
        Never used for device lock
    }

    class LocalAppPasscode {
        +String numericPin (4 digits)
        +String hardwareSalt (32 bytes)
        +String secureKeystoreHash
        +bool biometricsEnabled
        +verifyPasscode(candidate)
        -- Scope --
        Device-Local Unlock Only
        Stored in Android Keystore / iOS Keychain
        Never sent to Firebase or server
    }

    class OneTimeLoveCode {
        +String ephemeralCode (6 digits)
        +DateTime createdAt
        +Duration validDuration (60 seconds)
        +bool isUsed
        +validateCode(candidate)
        -- Scope --
        Phase 17 Love Sharing Authorization
        Single-use, expires in 60s
        Never used as encryption key
    }

    class EmergencyRecoveryKey {
        +List~String~ mnemonicWords (12 words)
        +String randomSalt (32 bytes)
        +String saltedSha256Hash
        +verifyRecoveryKey(candidateMnemonic)
        -- Scope --
        Phase 9 Offline Account Password Reset
        Self-sovereign BIP-39 mnemonic
        Never transmitted across network
    }

    AccountPassword <.. LocalAppPasscode : "Strict Isolation (Separate Verifiers)"
    LocalAppPasscode <.. OneTimeLoveCode : "Strict Isolation (Ephemeral Authorization)"
    AccountPassword <.. EmergencyRecoveryKey : "Self-Sovereign Recovery (Zero Cloud PII)"
```

---

## 3. App Launch & Authentication Gate State Machine

Upon launch, [`AuthGate`](file:///e:/ourPlace/chatbox/lib/screens/auth/auth_gate.dart) evaluates account session and local device security state:

```mermaid
stateDiagram-v2
    [*] --> AppLaunch: Application Cold Start

    state AppLaunch {
        CheckSession: Check Active Account Session
    }

    CheckSession --> Unauthenticated: No User Logged In
    CheckSession --> Authenticated: Valid Session Found

    state Unauthenticated {
        AuthScreen: AuthScreen (Sign In / Register)
        AccountCreation: Validate @username & Hash Password
        AuthScreen --> AccountCreation: Submit Form
        AccountCreation --> Authenticated: Account Created / Signed In
    }

    state Authenticated {
        CheckPasscode: Check isPasscodeConfigured()
    }

    CheckPasscode --> PasscodeSetup: Passcode Not Configured
    CheckPasscode --> CheckLockState: Passcode Configured

    state PasscodeSetup {
        EnterPin: Enter 4-Digit Passcode
        ConfirmPin: Confirm 4-Digit Passcode
        EnrollBiometrics: Optional Biometric Prompt
        EnterPin --> ConfirmPin: 4 Digits
        ConfirmPin --> EnterPin: Mismatch (Shake & Reset)
        ConfirmPin --> EnrollBiometrics: Match
        EnrollBiometrics --> Unlocked: Passcode Saved to Keystore
    }

    state CheckLockState {
        EvaluateUnlock: isAppUnlocked == true?
    }

    EvaluateUnlock --> AppLockScreen: Locked (false)
    EvaluateUnlock --> Unlocked: Unlocked (true)

    state AppLockScreen {
        PromptBiometric: Auto-Prompt Biometrics (if enabled)
        NumericKeypad: Charcoal Keypad PIN Entry
        FallbackLogin: Log in with Account Password
        PromptBiometric --> Unlocked: Biometric Success
        NumericKeypad --> Unlocked: PIN Matches Keystore Hash
        NumericKeypad --> AppLockScreen: PIN Mismatch (Shake Dots)
        FallbackLogin --> Unauthenticated: Session Cleared
    }

    state Unlocked {
        HomeScreen: HomeScreen (Inbox & Profile)
    }
```

---

## 4. App Lifecycle & Background Auto-Lock Flow

When the user leaves or backgrounds `ourPlace`, [`AuthGate`](file:///e:/ourPlace/chatbox/lib/screens/auth/auth_gate.dart) automatically locks the app to protect conversations from physical access:

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant OS as Mobile OS (Android / iOS)
    participant AuthGate as AuthGate (WidgetsBindingObserver)
    participant AppLockService as AppLockService
    participant Keystore as SecureStorageService
    participant UI as Screen Presentation

    Note over User,UI: App is currently active in Foreground (HomeScreen)
    User->>OS: Press Home / Switch Apps / Lock Screen
    OS->>AuthGate: didChangeAppLifecycleState(AppLifecycleState.paused / hidden)
    AuthGate->>AppLockService: lockApp()
    AppLockService->>AppLockService: _isAppUnlocked = false
    AppLockService-->>AuthGate: lockStateChanges.add(false)
    AuthGate->>UI: Trigger Rebuild (Swap HomeScreen with AppLockScreen)

    Note over User,UI: Device is later reopened
    User->>OS: Tap ourPlace App Icon
    OS->>AuthGate: didChangeAppLifecycleState(AppLifecycleState.resumed)
    UI->>User: Render AppLockScreen (Conversations Hidden)
    
    alt Biometrics Enabled
        AppLockService->>OS: LocalAuthentication.authenticate()
        OS-->>User: Display Fingerprint / Face Prompt
        User->>OS: Provide Valid Biometric
        OS-->>AppLockService: Authentication Result: Success
        AppLockService->>AppLockService: _isAppUnlocked = true
        AppLockService-->>AuthGate: lockStateChanges.add(true)
        AuthGate->>UI: Swap to HomeScreen (Inbox)
    else Numeric PIN Entry
        User->>UI: Enter 4-digit PIN on NumericKeypad
        UI->>AppLockService: verifyPasscode(candidatePin)
        AppLockService->>Keystore: Read stored hash & salt
        AppLockService->>AppLockService: Hash candidate with salt & compare
        alt Correct PIN
            AppLockService->>AppLockService: _isAppUnlocked = true
            AppLockService-->>AuthGate: lockStateChanges.add(true)
            AuthGate->>UI: Swap to HomeScreen (Inbox)
        else Incorrect PIN
            AppLockService-->>UI: Return false
            UI->>UI: Shake PasscodeDots & Flash Red
        end
    end
```

---

## 5. Clean Architecture Layer Dependencies

The codebase follows Clean Architecture with unidirectional dependencies:

```mermaid
flowchart TD
    subgraph PresentationLayer["Presentation Layer (Flutter Widgets & Screens)"]
        Screens["Screens\n- HomeScreen\n- InboxScreen\n- ChatScreen\n- ProfileScreen (Recovery Key & Audit Log)\n- AuthScreen (Recovery Key Reset)\n- AppLockScreen (Lockout Countdown)\n- PasscodeSetupScreen"]
        Widgets["Reusable Widgets\n- ConversationTile\n- ChatHeader\n- MessageBubble\n- ChatInputField\n- NumericKeypad\n- PasscodeDots\n- DateDivider"]
    end

    subgraph ServiceRepositoryLayer["Service & Repository Layer (Business Orchestration)"]
        AuthRepo["AuthRepository / AuthService\n- User Registration\n- Salted SHA-256 Auth\n- E2EE Key Initialization\n- Session Stream & Recovery Resets"]
        ChatRepo["ChatRepository / LocalChatRepository\n- Message Delegation & Transport Encryption\n- Ephemeral Relay Sync & Delivery ACK Purge\n- Cleartext Local SQLite Invariant"]
        ConvRepo["ConversationRepository\n- Love Connection Seed\n- Inbox Unread Tracking"]
        AppLockServ["AppLockService\n- Passcode Keystore Verification\n- PIN Throttling & 60s Lockout\n- Local Biometrics & Auto-Lock"]
        SecurityServ["AuthSecurityService & AccessThrottling\n- Challenge-Response Handshake\n- Exponential Backoff (10s..5m)"]
        EncryptionServ["EncryptionService / StandardE2EEEncryptionService\n- X25519 ECDH Shared Secret\n- HKDF-SHA256 Key Derivation\n- AES-256-GCM AEAD Authenticated Encryption\n- Hardware Private Key Keystore Isolation"]
        RelayServ["RelayService / InMemoryFirebaseRelayService\n- Ephemeral Ciphertext Queue\n- Delivery ACK & Immediate Purge\n- 48h Ephemeral TTL Garbage Collection"]
    end

    subgraph DomainLayer["Domain & Core Layer (Pure Dart Business Rules)"]
        Models["Domain Models\n- User & UserAccount\n- Conversation & ChatMessage\n- EncryptedPayload (E2EE Envelope)\n- EphemeralRelayEnvelope (Relay Wire Envelope)\n- SecurityLog (Audit Events)"]
        CryptoCore["Cryptographic & Core Utils\n- CryptoKeyUtils (X25519, HKDF, AES-GCM)\n- RecoveryKeyUtils (BIP-39 Mnemonic)\n- HashUtils (Salt + SHA-256)\n- AppTheme (Pure Black & Charcoal)\n- AppConstants & Exceptions (SecurityException)"]
    end

    subgraph DataStorageLayer["Data & Hardware Layer (Infrastructure)"]
        DriftDB["Drift SQLite Database (v3)\n- Messages Table\n- UserAccounts Table (Recovery Key & Public Identity Key)\n- SecurityLogs Table (Audit Ledger)"]
        SecStore["flutter_secure_storage\n- Android Keystore / iOS Keychain / Windows DPAPI\n- Passcode Verifier & E2EE Private Keys"]
        LocalAuth["local_auth\n- Platform OS Biometrics"]
    end

    Screens --> Widgets
    Screens --> AuthRepo
    Screens --> ChatRepo
    Screens --> ConvRepo
    Screens --> AppLockServ

    AuthRepo --> SecurityServ
    AuthRepo --> EncryptionServ
    AuthRepo --> Models
    ChatRepo --> EncryptionServ
    ChatRepo --> RelayServ
    ChatRepo --> Models
    ConvRepo --> Models
    AppLockServ --> CryptoCore
    SecurityServ --> CryptoCore
    EncryptionServ --> CryptoCore
    EncryptionServ --> SecStore

    AuthRepo --> DriftDB
    ChatRepo --> DriftDB
    AppLockServ --> SecStore
    AppLockServ --> LocalAuth
    DriftDB --> Models
```

---

## 6. End-to-End Encryption & Ephemeral Relay Protocol

Implemented in **Phase 10** (X25519 ECDH + HKDF-SHA256 + AES-256-GCM authenticated payload encryption & tamper detection) and **Phase 11** (Temporary Firebase Relay with Delivery ACK Purge), this protocol guarantees zero-knowledge message delivery with no permanent server footprint:


```mermaid
sequenceDiagram
    autonumber
    actor Alice as Sender (Alice)
    participant AliceE2EE as Alice Device Engine
    participant Relay as Firebase Ephemeral Relay
    participant FCM as Push Notification Service
    participant BobE2EE as Bob Device Engine
    actor Bob as Recipient (Bob)

    Note over Alice,Bob: Active E2EE Session established via Ratchet Keys
    Alice->>AliceE2EE: Write message: "Hey, are you free tonight?"
    AliceE2EE->>AliceE2EE: Generate message key via Double Ratchet
    AliceE2EE->>AliceE2EE: Encrypt plaintext payload with AES-GCM
    AliceE2EE->>Relay: POST /relay/messages { recipient: "@bob", ciphertext: "0x8f3a..." }
    Relay->>Relay: Enqueue ephemeral payload in volatile queue

    Relay->>FCM: Trigger silent background wakeup ping to Bob
    FCM->>BobE2EE: Silent Push (No message payload)

    BobE2EE->>Relay: GET /relay/messages/pending?recipient="@bob"
    Relay-->>BobE2EE: Return ciphertext payload: "0x8f3a..."
    
    BobE2EE->>BobE2EE: Decrypt payload using Bob Private Ratchet Key
    BobE2EE->>BobE2EE: Verify HMAC & integrity
    BobE2EE->>BobE2EE: Save decrypted message into Local SQLite DB
    
    BobE2EE->>Relay: DELETE /relay/messages/0x8f3a (Delivery ACK)
    Relay->>Relay: Permanently purge ciphertext from Cloud Relay
    
    BobE2EE->>Bob: Display message in UI & show notification
```

---

## 7. Multi-User Navigation & Screen Hierarchy

The application navigation routes between multiple conversation partners while elevating the Love Connection:

```mermaid
graph TD
    AuthGate["AuthGate\n(Lifecycle Auto-Lock Coordinator)"]

    AuthGate -->|Not Logged In| AuthScreen["AuthScreen\n(Sign In / Register)"]
    AuthGate -->|Passcode Not Set| PasscodeSetupScreen["PasscodeSetupScreen\n(4-Digit PIN Creation & Biometrics)"]
    AuthGate -->|Session Locked| AppLockScreen["AppLockScreen\n(Tactile Keypad / Biometrics Prompt)"]
    AuthGate -->|Session Active & Unlocked| HomeScreen["HomeScreen\n(Main Scaffold)"]

    HomeScreen --> InboxScreen["InboxScreen\n(Primary View)"]
    HomeScreen --> ProfileScreen["ProfileScreen\n(Identity & Settings)"]

    subgraph InboxLayout["Inbox Components"]
        SearchBar["Instant Search Filter"]
        LoveSection["❤️ LOVE CONNECTION (0 or 1 Partner)\n- Special Romantic Tint (#2E2428)\n- Heart Badge\n- Pinned Top Position"]
        ConvList["CONVERSATIONS (Multi-User)\n- User A, User B, User C\n- Unread Badge Counter\n- Relative Timestamps"]
    end

    InboxScreen --> SearchBar
    InboxScreen --> LoveSection
    InboxScreen --> ConvList

    LoveSection -->|Tap Partner| ChatScreenLove["ChatScreen (@twilight)\n- Floating Header with 'Send luv'\n- SQLite History\n- Back Button to Inbox"]
    ConvList -->|Tap User| ChatScreenRegular["ChatScreen (@sarah / @rahim)\n- Standard Header\n- SQLite History\n- Back Button to Inbox"]

    subgraph ProfileLayout["Profile Components"]
        UserId["Anonymous Identity Card (@alex)"]
        SecurityCard["Security & App Lock\n- Passcode Active Status\n- Biometrics Switch\n- Change Passcode\n- 'Lock App Now' Button"]
        LoveToggle["Love Connection Visibility Toggle"]
        SignOut["Sign Out Button"]
    end

    ProfileScreen --> UserId
    ProfileScreen --> SecurityCard
    ProfileScreen --> LoveToggle
    ProfileScreen --> SignOut
```

---

## 8. Love Connection & One-Time Love Code Sharing Flow

In **Phase 17**, users can selectively grant their partner access to view a specific conversation thread using an ephemeral 60-second authorization code:

```mermaid
sequenceDiagram
    autonumber
    actor Alex as User (Alex)
    actor Twilight as Love Partner (Twilight)
    participant AlexDevice as Alex's Device
    participant CloudRelay as Temporary Relay
    participant TwilightDevice as Twilight's Device

    Twilight->>Alex: Requests to view conversation with @sarah
    Alex->>AlexDevice: Tap "Share Conversation" -> Select @sarah
    AlexDevice->>AlexDevice: Generate 6-digit random code (e.g. "849201")
    AlexDevice->>AlexDevice: Set 60-second expiration timer
    AlexDevice->>Alex: Display One-Time Love Code on screen

    Alex-->>Twilight: Tells code "849201" (In person / out of band)
    Twilight->>TwilightDevice: Enter Code "849201" on Love Connection screen
    TwilightDevice->>CloudRelay: POST /love-share/claim { code: "849201", partner: "@twilight" }
    
    CloudRelay->>AlexDevice: Relay claim request
    AlexDevice->>AlexDevice: Verify code == "849201" AND now < expiresAt AND !isUsed
    
    alt Code Valid
        AlexDevice->>AlexDevice: Mark code as USED
        AlexDevice->>AlexDevice: Package & encrypt @sarah's messages with Twilight's key
        AlexDevice->>CloudRelay: Push encrypted conversation bundle
        CloudRelay->>TwilightDevice: Transmit encrypted bundle
        CloudRelay->>CloudRelay: Purge bundle immediately
        TwilightDevice->>TwilightDevice: Decrypt and render temporary view
        TwilightDevice->>Twilight: Display conversation preview
    else Code Expired or Incorrect
        AlexDevice-->>CloudRelay: Reject authorization
        CloudRelay-->>TwilightDevice: Return "Invalid or Expired Code"
        TwilightDevice->>Twilight: Show error: "Code expired or invalid"
    end
```

---

## 9. Local Database Schema & Entity Relationships

The local Drift SQLite database (Schema Version 3) enforces local persistence for accounts, chat messages, and device security logs:

```mermaid
erDiagram
    USER_ACCOUNTS {
        TEXT account_id PK "UUID"
        TEXT username UK "Unique normalized lowercase username"
        TEXT password_hash "Salted SHA-256 verifier"
        TEXT salt "32-byte cryptographically random salt"
        DATETIME created_at "Account creation timestamp"
        TEXT public_identity_key "Nullable E2EE identity key"
        TEXT recovery_key_hash "Salted SHA-256 recovery mnemonic verifier (nullable)"
        TEXT recovery_key_salt "32-byte recovery salt (nullable)"
    }

    MESSAGES {
        TEXT id PK "Unique message UUID"
        TEXT sender_id "Sender identifier (@user or 'current_user')"
        TEXT recipient_id "Recipient identifier"
        TEXT partner "Partner username indexing conversation"
        TEXT text "Message text content"
        INTEGER type "MessageType enum (0:text, 1:image, 2:audio, 3:video, 4:system)"
        INTEGER status "MessageStatus enum (0:sending, 1:sent, 2:delivered, 3:read, 4:failed)"
        DATETIME timestamp "UTC timestamp"
    }

    SECURITY_LOGS {
        INTEGER id PK "Auto-increment audit ID"
        TEXT event_type "SecurityEventType (login, passwordReset, pinFailure, etc.)"
        TEXT severity "SecuritySeverity (low, medium, high, critical)"
        TEXT description "Human-readable event audit description"
        DATETIME timestamp "UTC event timestamp"
        TEXT metadata_json "Nullable JSON serialized audit details"
    }

    CONVERSATION_DOMAIN {
        TEXT id PK
        TEXT partner_username
        TEXT last_message_id FK
        INTEGER unread_count
        BOOLEAN is_love_connection
        DATETIME last_message_at
    }

    USER_DOMAIN {
        TEXT id PK
        TEXT username
        TEXT display_name
        DATETIME created_at
        TEXT love_connection_id
        BOOLEAN love_connection_visibility
    }

    USER_ACCOUNTS ||--o{ USER_DOMAIN : "Hydrates"
    USER_ACCOUNTS ||--o{ SECURITY_LOGS : "Logs device security events for"
    MESSAGES }o--|| CONVERSATION_DOMAIN : "Aggregated into"
    USER_DOMAIN ||--o{ CONVERSATION_DOMAIN : "Partner of"
```

---

## 10. Security Enclave & Cryptographic Trust Boundaries

Physical and network security boundaries ensure zero data leakage and zero cloud telemetry:

```mermaid
flowchart LR
    subgraph NetworkSpace["Untrusted Network Space"]
        PublicInternet["Public Internet"]
        FirebaseServers["Firebase Ephemeral Relay\n- No permanent message storage\n- No plaintext passwords\n- Zero telemetry"]
    end

    subgraph AppSandbox["Device Application Sandbox (Flutter App)"]
        RAM["Application Volatile Memory\n- Ephemeral state\n- Access Throttling & PIN Lockout Ticker\n- Plaintext only during active viewing\n- Wiped upon app lock"]
        LocalSQLite["SQLite Database File (Schema v3)\n- Drift Encrypted/Protected Local Store\n- Permanent conversation history\n- Local Security Audit Logs (Zero Telemetry)"]
    end

    subgraph HardwareEnclave["Hardware Security Enclave (OS Protected)"]
        Keystore["Android Keystore / iOS Keychain\n- 4-digit Passcode SHA-256 Hash + Salt\n- E2EE Identity Private Keys\n- Hardware-backed protection"]
        BiometricSensor["Platform Biometric Sensor\n- Fingerprint / Face ID\n- Auth handled strictly by OS\n- App receives only boolean result"]
    end

    PublicInternet <-->|TLS 1.3 + E2EE Ciphertext Only| FirebaseServers
    FirebaseServers <-->|Ephemeral E2EE Ciphertext| RAM
    RAM <-->|CRUD Operations| LocalSQLite
    RAM <-->|Protected Key-Value Operations| Keystore
    RAM <-->|LocalAuthentication Prompt| BiometricSensor
```

---

## 11. Message State Lifecycle & Synchronization Flow

### 11.1. Monotonic Unidirectional State Machine
Messages follow a strictly monotonic forward lifecycle. No regression is permitted, and `read` status is terminal.

```mermaid
stateDiagram-v2
    [*] --> sending: User taps send (saved locally)
    sending --> sent: Dispatched to Ephemeral Relay
    sending --> failed: Network offline / error
    failed --> sending: Retry message (manual or sync)
    failed --> sent: Reconnection queue flush
    sent --> delivered: Ephemeral Delivery Receipt received
    delivered --> read: Ephemeral Read Receipt received
    sent --> read: Read Receipt (batched / fast open)
    read --> [*]: Terminal state (immutable)
```

### 11.2. Offline Queueing and Reconnection Sequence
When offline, outbound messages are persisted in local SQLite with `failed` status. When network connectivity resumes, `flushOutboundQueue` drains all unsent messages to the relay.

```mermaid
sequenceDiagram
    autonumber
    actor Alice as Alice Device (Offline)
    participant LocalDB as Alice Local SQLite
    participant Sync as Alice SyncService
    participant Relay as Firebase Ephemeral Relay
    actor Bob as Bob Device

    Alice->>LocalDB: 1. Save cleartext message (status: sending)
    Alice->>Sync: 2. Attempt dispatch
    Note over Sync: Network offline detected
    Sync->>LocalDB: 3. Update status: failed (queued)
    Note over Alice: User sees red error tick & offline indicator

    Note over Alice, Relay: Connectivity restored (online: true)
    Alice->>Sync: 4. Trigger reconcile() / flushOutboundQueue()
    Sync->>LocalDB: 5. Query getUnsentMessages()
    LocalDB-->>Sync: Return [offline_msg_01]
    Sync->>Relay: 6. Dispatch E2EE ciphertext envelope
    Relay-->>Sync: Relay HTTP 200 / ACK
    Sync->>LocalDB: 7. updateMessageStatusIfProgressing(sent)
    Note over Alice: Single check tick (sent) renders in UI

    Bob->>Relay: 8. fetchPendingRelayEnvelopes()
    Relay-->>Bob: Deliver ciphertext
    Bob->>Relay: 9. acknowledgeAndPurge() (atomic wipe)
```

### 11.3. End-to-End Delivery & Read Receipt Flow
Receipts are transmitted as ephemeral wire envelopes through the relay and purged immediately upon receipt.

```mermaid
sequenceDiagram
    autonumber
    actor Alice as Alice Device
    participant AliceDB as Alice Local SQLite
    participant Relay as Firebase Ephemeral Relay
    participant BobDB as Bob Local SQLite
    actor Bob as Bob Device

    Alice->>AliceDB: Save cleartext (status: sending)
    Alice->>Relay: Dispatch E2EE ciphertext envelope
    Alice->>AliceDB: updateMessageStatusIfProgressing(sent)

    Note over Bob: Bob comes online / connects
    Bob->>Relay: fetchPendingRelayEnvelopes("@bob")
    Relay-->>Bob: Return ciphertext envelope
    Bob->>Bob: Decrypt payload using Alice's public key
    Bob->>BobDB: Save cleartext (status: delivered)
    Bob->>Relay: acknowledgeAndPurge(messageId) (erases ciphertext from cloud)
    Bob->>Relay: sendDeliveryReceipt(targetMessageId, recipient: "@alice")

    Note over Alice: Alice syncs / listens
    Alice->>Relay: fetchPendingRelayEnvelopes("@alice")
    Relay-->>Alice: Return Delivery Receipt envelope
    Alice->>AliceDB: updateMessageStatusIfProgressing(delivered)
    Alice->>Relay: acknowledgeAndPurge(receiptEnvelopeId)
    Note over Alice: Double gray check ticks render in UI

    Note over Bob: Bob opens conversation screen
    Bob->>BobDB: markConversationAsRead("@alice") (status: read)
    Bob->>Relay: sendReadReceipt(targetMessageId, recipient: "@alice")

    Alice->>Relay: fetchPendingRelayEnvelopes("@alice")
    Relay-->>Alice: Return Read Receipt envelope
    Alice->>AliceDB: updateMessageStatusIfProgressing(read)
    Alice->>Relay: acknowledgeAndPurge(receiptEnvelopeId)
    Note over Alice: Double blue check ticks render in UI
```

