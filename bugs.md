# Nest (chatbox) — Bug & Problem Report

Review date: 2026-11-01
Scope: `chatbox/lib/**`, Firebase rules documented in `SERVER_AND_NETWORKING.md`, CI workflow, repo hygiene.
Reviewed against the working tree, including uncommitted changes. `flutter analyze` reports only 2 warnings (unused import, unused method). The code compiles, so everything below is a **logic, security or design bug** that static analysis can't catch.

Severity legend: 🔴 Critical (security/data loss) · 🟠 High (feature broken / visible to users) · 🟡 Medium · 🟢 Low

---

## Summary

| # | Severity | Area | Title |
|---|----------|------|-------|
| 1 | 🔴 | Firebase | Relay and directory are world-readable/writable; REST client sends no auth |
| 2 | 🔴 | Identity | Anyone can claim any username and overwrite its public key (account takeover / MITM) |
| 3 | 🔴 | Crypto | Sign-out deletes the E2EE private key, so earlier messages can't be decrypted after login |
| 4 | 🔴 | Crypto | Outbound queue sends **plaintext** when recipient key isn't found |
| 5 | 🔴 | Crypto | Media is uploaded to Firebase Storage **unencrypted** |
| 6 | 🔴 | Crypto | Love notes are sent in plaintext |
| 7 | 🔴 | Crypto | Shared conversation bundle (full chat history) is sent in plaintext |
| 8 | 🔴 | Crypto | Sender authentication: trusts the public key inside the ciphertext envelope |
| 9 | 🟠 | Sync | ✅ ~~Love requests, reactions, love notes, luv bursts and share bundles are silently dropped in production~~ |
| 10 | 🟠 | Sync | ✅ ~~Typing/presence signals are saved as chat messages and trigger notifications~~ |
| 11 | 🟠 | Sync | ✅ ~~`processInboundEnvelopes` runs concurrently, causing duplicate notifications/receipts and status regressions~~ |
| 12 | 🟠 | Sync | ✅ ~~A single bad envelope stops the inbound queue (poison message)~~ |
| 13 | 🟠 | Sync | Decryption failure stores the raw ciphertext as message text |
| 14 | 🟠 | Realtime | `watchTyping` / `watchPresence` leak Firebase listeners every time a chat opens |
| 15 | 🟠 | Chat | Messages that arrive while the chat is open are never marked read |
| 16 | 🟡 | DB | Re-saving an inbound message overwrites status, reactions and local media path |
| 17 | 🟡 | DB | `getSharedMediaMessages` returns media from **all** conversations |
| 18 | 🟡 | DB | Inconsistent username normalization across queries |
| 19 | 🟡 | Chat | Message IDs based only on milliseconds can collide |
| 20 | 🟡 | Relay | `purgeExpiredMessages` reads the whole `/relays` tree (rules deny it, and it would leak privacy if allowed) |
| 21 | 🟡 | Relay | Every write/delete is done twice (REST + SDK) |
| 22 | 🟡 | Auth | Fast unsalted-iteration SHA-256 for passwords/passcodes; lockouts reset on restart |
| 23 | 🟡 | Auth | Sign-out from chat/profile screens doesn't stop the relay listener |
| 24 | 🟡 | Love | `acceptConnectionRequest` accepts with no pending request and overwrites an existing one |
| 25 | 🟡 | Model | Missing/invalid `expires_at` makes envelope expire immediately |
| 26 | 🟡 | Arch | Multiple `LocalChatRepository` instances, each with its own pollers |
| 27 | 🟢 | CI | GitHub workflow can never pass (wrong directory, `dart` instead of `flutter`) |
| 28 | 🟢 | Repo | Release binaries (≈117 MB) and build outputs committed; new required file untracked |
| 29 | 🟢 | Code | Lint warnings / dead code |

---

## 🔴 Critical

### 1. Firebase relay & directory are world-readable/writable; REST client sends no auth
**Where:** `SERVER_AND_NETWORKING.md:204-222` (documented rules), `chatbox/lib/services/firebase_rest_client.dart:21-24`

**Problem:**
- Rules are `".read": true` on `/relays/$recipientId` and `/directory`, and `".write": true` on every message and every directory entry. The doc claims "read access is scoped per recipient ID", but it isn't: anyone with the (public) DB URL can read every user's queue, see who talks to whom and when, delete other users' messages before delivery, and inject envelopes as anyone.
- `.validate` doesn't run on deletes, so the "validation" doesn't stop deletion.
- `FirebaseRestDatabaseClient._buildUri` never appends `?auth=<idToken>`. Even though `main.dart:29` signs in anonymously, REST calls go out unauthenticated. So the rules *must* stay public for the app to work.

**Solution:**
1. Attach the Firebase ID token to REST calls: `Uri.parse('$_baseUrl/$cleanPath.json?auth=${await FirebaseAuth.instance.currentUser?.getIdToken()}')`. Or drop the REST path and use the SDK only (see #21).
2. Bind each username to a Firebase `uid` on registration (`/usernames/$name: uid`) and lock the rules down:
```json
"relays": {
  "$recipient": {
    ".read":  "root.child('usernames').child($recipient).val() === auth.uid",
    "$msg": {
      ".write": "auth != null && (!data.exists() && newData.child('sender_id').val() === root.child('uids').child(auth.uid).val()) || (root.child('usernames').child($recipient).val() === auth.uid && !newData.exists())",
      ".validate": "newData.hasChildren(['id','sender_id','recipient_id','ciphertext','timestamp','expires_at'])"
    }
  }
},
"directory": {
  ".read": "auth != null",
  "$username": { ".write": "root.child('usernames').child($username).val() === auth.uid" }
}
```
(Only the recipient reads/deletes; senders can only create, and only as themselves.)

---

### 2. Anyone can register an existing username and overwrite its public key
**Where:** `chatbox/lib/services/auth_service.dart:171` (uniqueness check), `:213` and `:112` (publish), `chatbox/lib/services/user_directory_service.dart:153-166`

**Problem:** `isUsernameTaken` only checks the **local SQLite DB**. On a second device, `@alice` is "available". Registering it calls `publishProfile`, which does an unconditional `PUT directory/@alice`. That replaces Alice's `publicIdentityKey` with the attacker's. Senders then resolve the attacker's key from the directory (`chat_repository.dart:224-232`, `sync_service.dart:180-186`), so new messages to "Alice" are encrypted for the attacker. Combined with #1, the attacker can also read Alice's relay queue. This is a full impersonation/MITM.

**Solution:**
- Check the remote directory (or a `/usernames` claim node written in a transaction) before registering, and fail if the name is taken.
- Enforce ownership server-side (rules in #1) so only the original `uid` can update `directory/$username`.
- Clients should pin the partner's key on first contact (TOFU). The Love Connection already stores `partnerPublicKey`. Warn the user if the directory key ever changes, instead of silently switching to it.

---

### 3. Sign-out deletes the E2EE private key
**Where:** `chatbox/lib/services/auth_service.dart:385`, `chatbox/lib/services/encryption_service.dart:227-236`

**Problem:** `signOut()` calls `_encryptionService.clearKeys()`, which deletes `e2ee_priv_key_<accountId>` from secure storage. On the next `login()`, `initializeUserKeys` finds no key and **generates a new keypair**. Then:
- All envelopes already queued for this user, encrypted to the old key, fail to decrypt (and hit #13).
- Partners keep the old key cached (local account / Love Connection `partnerPublicKey`), so messages they send keep failing until something refreshes it.
- Shared bundles / restores encrypted to the old key are lost.

**Solution:** On sign-out, clear only the **in-memory** cache (`_cachedKeyPair`, `_cachedPublicKeyBase64`, `_activeUserId`). Delete the stored keys only on an explicit "Delete account / wipe device" action. If the keys must be removed for security, wrap the private key with a key derived from the password (e.g. Argon2id(password, salt)) and keep it at rest. Don't throw it away.

```dart
// EncryptionService
Future<void> lockSession() async { _cachedKeyPair = null; _cachedPublicKeyBase64 = null; _activeUserId = null; }
// AuthService.signOut()
await _encryptionService.lockSession();   // instead of clearKeys()
```

---

### 4. Offline/retry queue sends plaintext if the recipient key isn't found
**Where:** `chatbox/lib/services/sync_service.dart:216-249` (`_dispatchOutboundMessage`)

**Problem:**
```dart
final recipientKey = await _resolveRecipientPublicKey(message.recipientId);
if (recipientKey != null && recipientKey.isNotEmpty) { ...encrypt... }
await _chatService.sendMessage(outbound);   // outbound == plaintext if no key
```
`LocalChatRepository.sendMessage` correctly refuses to send without a key (`chat_repository.dart:273-278`). But it marks the message `failed`, and `flushOutboundQueue` / `retryMessage` then pick it up and send the **cleartext** to Firebase when the directory lookup fails (offline, directory unavailable, or rules issue).

**Solution:** Treat a missing key as a hard failure in the sync path too:
```dart
if (recipientKey == null || recipientKey.isEmpty) {
  await _database.updateMessageStatus(message.id, MessageStatus.failed);
  return false;
}
```
Better still, move encryption into one shared helper used by both `ChatRepository.sendMessage` and `SyncService`, so the two paths can't drift apart.

---

### 5. Media blobs are uploaded unencrypted
**Where:** `chatbox/lib/repositories/chat_repository.dart:315-345` (`sendMediaMessage`), `chatbox/lib/services/firebase_media_relay_service.dart:33-59`

**Problem:** `uploadEncryptedBlob(blobId, mediaBytes)` is passed the **raw plaintext bytes**. `MediaEncryptionService.encryptMedia` exists (`media_encryption_service.dart:25`) but is never called anywhere. Photos, videos and voice notes sit in Firebase Storage in clear form behind a bearer `getDownloadURL()` link for 24 h. If the recipient never comes online, they stay there indefinitely (nothing enforces the `expiresAt` metadata).

**Solution:**
1. `final pkg = await _mediaEncryptionService.encryptMedia(bytes: mediaBytes, ...)` → upload `pkg.ciphertext`.
2. Put the per-file key + nonce inside the E2EE-encrypted `mediaAttachment` JSON (already sent in the encrypted message payload).
3. On receive (`sync_service.dart:349-365`), download, decrypt with the key from the attachment, then save to the sandbox.
4. Add a Storage lifecycle rule / Cloud Function to delete objects older than the TTL.

---

### 6. Love notes are sent in plaintext
**Where:** `chatbox/lib/services/couple_features_service.dart:352-370`, receiver `chatbox/lib/services/sync_service.dart:291-299`

**Problem:** `jsonEncode(note.toJson())` (title, body, tag, openAt) is put straight into the `encryptedPayload` field, even though the parameter name says "encrypted". The receiver does `LoveNote.fromJson(jsonDecode(envelope.ciphertextPayload))`, which confirms it's plaintext end to end. The service even receives an `encryptionService` in its constructor (`chat_repository.dart:153`) and doesn't use it. Reactions (`message_reaction`) are also plaintext, which leaks message IDs and emoji.

**Solution:** Encrypt `noteJson` with `encryptPayload(noteJson, partnerKey)` before enqueueing, and `decryptPayload` in `handleInboundLoveNote`. Do the same for reactions.

---

### 7. Shared conversation bundle is sent in plaintext
**Where:** `chatbox/lib/services/conversation_sharing_service.dart:337-347`

**Problem:**
```dart
final recipientAccount = await _localDatabase.getAccountByUsername(requesterUsername);
final pubKey = recipientAccount?.publicIdentityKey;
if (pubKey != null && pubKey.isNotEmpty) { payload = await enc.encryptPayload(...); }
```
Accounts exist only on the device where they were registered, so the partner's account is **never** in the local DB in real two-device use. The whole conversation history (`bundle.toJsonString()`) is therefore pushed to Firebase in cleartext.

**Solution:** Resolve the key the same way as messages (Love Connection `partnerPublicKey` → directory). If no key is found, **abort** the share and don't send anything. The receiver should also refuse unencrypted bundles.

---

### 8. Sender authentication trusts the key inside the envelope
**Where:** `chatbox/lib/services/sync_service.dart:327-341`, `chatbox/lib/repositories/chat_repository.dart:362-368`, `chatbox/lib/services/encryption_service.dart:181-183`

**Problem:** If the sender's key can't be resolved locally, the code falls back to `EncryptedPayload.senderPublicKey`, which the sender chose. With public write rules (#1), anyone can write an envelope with `sender_id: "@partner"`, encrypt with their **own** key, and embed their own public key. Decryption succeeds, and the app shows a forged message "from your partner". Receipts (`isDeliveryReceipt`/`isReadReceipt`, `sync_service.dart:300-313`) and love/luv signals aren't authenticated at all. Anyone can mark your messages as "read" or unlink your Love Connection.

**Solution:**
- Never use the envelope-supplied key for authentication. Use only a pinned/known key for `senderId`. If none is available, show the message as "unverified" or reject it.
- Bind metadata into the AEAD: pass `senderId|recipientId|messageId` as AAD to AES-GCM, so a ciphertext can't be replayed under another identity.
- Encrypt and authenticate control signals (receipts, love_*), or at least check `envelope.senderId == message.recipientId` before applying a receipt.

---

## 🟠 High

### 9. Love/share/couple signals are silently dropped in production — ✅ FIXED
**Where:** `chatbox/lib/repositories/chat_repository.dart:132-144`, `chatbox/lib/main.dart:39-42`, `chatbox/lib/services/sync_service.dart:259-299`

**Problem:** The constructor builds `DefaultSyncService(... loveConnectionService: loveConnectionService, conversationSharingService: conversationSharingService, coupleFeaturesService: coupleFeaturesService)` using the **raw nullable constructor parameters**, not the `_loveConnectionService` etc. fields it just created. `main.dart` doesn't pass them, so in production all three are `null` inside the sync service. `processInboundEnvelopes` then does:
```dart
if (_loveConnectionService != null) { ... }   // skipped
await _chatService.acknowledgeAndPurge(...);   // still deletes it!
```
Incoming Love Connection requests/accepts/unlinks, love-code claims/bundles, love notes, reactions and luv bursts are all **acked and deleted without being handled**. Also, `DefaultSyncService` is the only consumer of these envelopes (no other code calls `processInboundLoveEnvelope` / `handleInboundEnvelope` / `handleInboundReaction` / `handleInboundLoveNote`).

There's a second problem in the same constructor: it creates **separate** `DefaultLoveConnectionService` instances for the repository and for the sharing service, so their caches and streams don't agree.

**Solution:** Build the dependencies once in locals, then share them:
```dart
factory LocalChatRepository({...}) {
  final db = database ?? LocalDatabase();
  final chat = chatService ?? ChatService.instance;
  final enc = encryptionService ?? StandardE2EEEncryptionService.instance;
  final love = loveConnectionService ?? DefaultLoveConnectionService(database: db, relayService: chat.relayService, ...);
  final share = conversationSharingService ?? DefaultConversationSharingService(..., loveConnectionService: love);
  final couple = coupleFeaturesService ?? DefaultCoupleFeaturesService(...);
  final sync = syncService ?? DefaultSyncService(..., loveConnectionService: love, conversationSharingService: share, coupleFeaturesService: couple);
  return LocalChatRepository._(db, chat, enc, sync, love, share, couple, ...);
}
```
Also: don't ack an envelope that wasn't handled.

---

### 10. Typing/presence signals are processed as chat messages — ✅ FIXED
**Where:** `chatbox/lib/services/sync_service.dart:259-314`, `chatbox/lib/services/realtime_service.dart:125-137, 206-233`

**Problem:** Typing (`type: typing`) and presence (`type: presence`) envelopes go into the same `/relays/<user>` queue as messages. `processInboundEnvelopes` has no branch for `isTypingSignal` / `isPresenceSignal`, so they fall into the final `else` ("Standard incoming message"). There, they are:
- saved to SQLite as a chat message with text `"true"`, `"false"` or `{"isOnline":true,...}`,
- shown as a local notification,
- answered with a **delivery receipt** (which creates more relay traffic).

Presence heartbeats go out every 20 s (`realtime_service.dart:268`) and the sync poller runs every 3 s, so this is a race the sync service often wins. Users see junk messages appear in the chat.

**Solution:** In `processInboundEnvelopes`, skip (or handle and purge) these types before the message branch:
```dart
} else if (envelope.isTypingSignal || envelope.isPresenceSignal) {
  continue; // owned by RealtimeService
}
```
Better: put ephemeral signals under a separate path (`/signals/<user>`), or use a non-persisted channel (`onDisconnect`-backed presence node) so they never share the message queue.

---

### 11. Concurrent inbound processing — ✅ FIXED
**Where:** `chatbox/lib/services/sync_service.dart:117-149, 252-420`; callers in `chat_screen.dart:85-86, 179-180`, `inbox_screen.dart:59-60`

**Problem:** `processInboundEnvelopes` is triggered at the same time by:
- the Firebase `onValue` stream (fires on every change, including the purges this function performs),
- a 3-second `Timer.periodic` that doesn't wait for the previous run to finish,
- the initial call, plus `reconcile()` from every screen's `initState` and resume.

With no re-entrancy guard, the same envelope is fetched by 2–3 runs before the first one acks it. That causes duplicate notifications, duplicate delivery receipts, and duplicate `saveMessage` calls. With #16, this can also move a message's status **backwards** (e.g. `read` → `delivered`).

**Solution:**
```dart
Future<List<ChatMessage>>? _inFlight;
bool _rerunRequested = false;

Future<List<ChatMessage>> processInboundEnvelopes({required String currentUserId}) {
  if (_inFlight != null) { _rerunRequested = true; return _inFlight!; }
  return _inFlight = _drain(currentUserId).whenComplete(() {
    _inFlight = null;
    if (_rerunRequested) { _rerunRequested = false; processInboundEnvelopes(currentUserId: currentUserId); }
  });
}
```
Also keep a short-lived `Set<String>` of already-processed envelope IDs, and use the stream **or** polling (polling only as a fallback when the socket is down), not both.

---

### 12. A single bad envelope blocks the queue — ✅ FIXED
**Where:** `chatbox/lib/services/sync_service.dart:258-410`

**Problem:** The `for` loop has no per-envelope `try/catch`. Any throw (a handler throws, `sendDeliveryReceipt` fails because of the network, a DB error) aborts the rest of the batch. The failing envelope was never acked, so it's retried first on every 3-second tick and fails the same way every time. Messages behind it never get delivered. Also, the 3 s poller does `catch (_) {}`, so this happens silently.

**Solution:** Wrap each envelope's handling in `try/catch`. Log the error, count failed attempts per ID, and after N attempts move it to a local "undecryptable / failed" state and ack it. Send receipts fire-and-forget (`unawaited(...)` with its own catch), so a receipt failure can't block ingestion.

---

### 13. Decryption failure stores ciphertext as the message text
**Where:** `chatbox/lib/services/sync_service.dart:378-384`, `chatbox/lib/repositories/chat_repository.dart:391-396`

**Problem:** On any decryption error, the code falls through to `saveMessage(raw)`. Then the raw `EncryptedPayload` JSON (`{"version":1,"senderPublicKey":...}`) is saved as the message text and shown in the bubble and in the notification. The envelope is also acked, so the message is permanently lost. This happens in practice after #3 (key rotation on sign-out).

**Solution:** On failure, save a placeholder message (`type: undecryptable`, text "🔒 Message couldn't be decrypted") and don't show the ciphertext. Optionally leave the envelope in the relay for a later retry (for example, after a key refresh) instead of acking it right away.

---

### 14. Realtime listeners leak on every chat open
**Where:** `chatbox/lib/services/realtime_service.dart:125, 206`

**Problem:** `watchTyping` and `watchPresence` each call `_chatService.watchPendingRelayEnvelopes(currentUserId).listen(...)` and **throw away the `StreamSubscription`**. `ChatScreen.dispose()` cancels the controller subscription, but not these Firebase `onValue` listeners. Each time you open a chat, two more permanent listeners are added. Each one re-downloads the entire queue on every change and calls `acknowledgeAndPurge` again. Memory, bandwidth and duplicate deletes grow without limit.

**Solution:** Store the subscriptions in a map keyed by `currentUserId:partnerId`. Create them once in `putIfAbsent`, and cancel them in `dispose()` / when the last listener on the broadcast controller goes away (`StreamController.broadcast(onCancel: ...)`).

---

### 15. Messages received while the chat is open stay unread
**Where:** `chatbox/lib/screens/chat_screen.dart:220` (only call site), `chatbox/lib/screens/chat_screen.dart:90-99`

**Problem:** `markConversationAsRead` runs once in `_loadMessagesFromRepository()`. Messages that arrive later through `watchMessages` are shown but never marked read. The sender never gets a read receipt, and the inbox badge (`getUnreadCountForPartner`) still counts them when the user goes back.

**Solution:** In the `watchMessages` listener, if any incoming message (`senderId == partnerId`) has status `!= read` and the app is in the foreground, call `markConversationAsRead` (debounced ~500 ms).

---

## 🟡 Medium

### 16. `saveMessage` (insert-or-update) overwrites local state
**Where:** `chatbox/lib/database/local_database.dart:102-106, 123-132`

**Problem:** `insertOnConflictUpdate` replaces **every** column. When an inbound envelope is reprocessed (#11), or a shared bundle is imported (`conversation_sharing_service.dart:427`), the existing row's `status` (e.g. `read`), `reactions` (reset to `null`) and `mediaData.localPath` are overwritten with the incoming values.

**Solution:** Use `insert(..., mode: InsertMode.insertOrIgnore)` for inbound messages. For imports, use an upsert that only updates selected columns: `onConflict: DoUpdate((old) => MessagesCompanion(messageText: ...), target: [messages.id])`. Keep the higher status and merge reactions.

### 17. `getSharedMediaMessages` returns media from every conversation
**Where:** `chatbox/lib/database/local_database.dart:725-744`

**Problem:** The filter is `(sender==partner | recipient==partner | sender=='current_user' | recipient=='current_user') & mediaData != null`. These are ORs, not a pair. Any media you sent to *anyone* shows up in this partner's "Shared Memories", and so does any media the partner exchanged with others on a shared device.

**Solution:** Reuse `_partnerFilter(tbl, partnerUsername, currentUserId)` and `& tbl.mediaData.isNotNull()`, and add a `currentUserId` parameter.

### 18. Inconsistent username normalization
**Where:** `chatbox/lib/database/local_database.dart:274-290, 359-371, 374-385, 388-402, 337-356` vs. `_partnerFilter` at `:135-158`; `chatbox/lib/services/couple_features_service.dart:355-361`; `realtime_service.dart:126, 207`

**Problem:** Some queries normalize IDs (`@bob` == `bob`, lowercase), but `searchMessages`, `markConversationAsRead`, `clearMessagesForPartner`, `getMessageCountForPartner` and `getUnsentMessages` use exact `equals`. Meanwhile, love notes are sent with IDs **without** `@` (`couple_features_service.dart:355-361`), and realtime matching uses `env.senderId == partnerId`. Any ID that arrives in the "other" form won't be marked read, can't be cleared, isn't counted, and isn't matched. Search also uses `contains`, which is a case-sensitive `LIKE` with no escaping of `%` and `_`.

**Solution:** Normalize once at the edges, always storing `HashUtils.normalizeUsername(x)`, and route every query through a single helper (`_partnerFilter`). Run a one-time migration that rewrites the existing `senderId` / `recipientId` values to the normalized form.

### 19. Message IDs can collide
**Where:** `chatbox/lib/screens/chat_screen.dart:246, 444`

**Problem:** `'msg_${DateTime.now().millisecondsSinceEpoch}'`. Two partners sending in the same millisecond, or a double tap, produce the same primary key. `insertOnConflictUpdate` then silently replaces one message with the other.

**Solution:** Use a UUID v4 (`package:uuid`) or `'${senderId}_${millis}_${Random.secure().nextInt(1<<32)}'`.

### 20. `purgeExpiredMessages` reads the whole `/relays` tree
**Where:** `chatbox/lib/services/firebase_relay_service.dart:198-230`

**Problem:** It does `ref('relays').get()` at the root. With the documented rules there's no `.read` at `/relays`, so this always fails, and the error is swallowed. Expired envelopes for offline users are never cleaned up. If it were allowed, every client would download every user's queue (a privacy leak and O(all users) bandwidth).

**Solution:** Do TTL cleanup on the server (a scheduled Cloud Function querying `orderByChild('expires_at').endAt(now)`). On the client, purge only your own queue (already done in `fetchPendingMessages`). Add `".indexOn": ["expires_at"]`.

### 21. Every relay/directory write and delete is done twice (REST + SDK)
**Where:** `chatbox/lib/services/firebase_relay_service.dart:54-73, 159-177`, `chatbox/lib/services/user_directory_service.dart:153-166, 196-221`

**Problem:** `enqueueMessage` PUTs over REST **and** `.set()`s through the SDK. `acknowledgeAndPurge` deletes twice. Writes cost double, `onValue` fires twice, and the two writes can arrive in either order. `acknowledgeAndPurge` returns only the REST result, so on platforms where REST is blocked it reports failure even though the SDK delete succeeded.

**Solution:** Choose a transport per platform at startup: SDK on Android/iOS/web/macOS, REST (with auth, see #1) on Windows/Linux. Fall back to the other only on error.

### 22. Weak password/passcode hashing; lockouts reset on restart
**Where:** `chatbox/lib/core/utils/hash_utils.dart:16-20`, `chatbox/lib/services/app_lock_service.dart:59-60, 145-168`, `chatbox/lib/services/access_throttling_service.dart`

**Problem:** Passwords, the app passcode and recovery verifiers use one round of `sha256(salt:password)`. A 4–6 digit passcode verifier pulled from storage can be brute-forced in microseconds. The failed-attempt counter and `_lockoutUntil` (passcode) and the login throttle live in memory only, so killing the app resets them. Comparisons use `==` (not constant-time).

**Solution:** Use a slow KDF: Argon2id (`package:cryptography` has `Argon2id`), or PBKDF2-HMAC-SHA256 with ≥ 210k iterations. Persist the failed-attempt count and lockout timestamp in secure storage. Compare digests in constant time.

### 23. Sign-out from chat/profile doesn't stop the relay listener
**Where:** `chatbox/lib/screens/chat_screen.dart:622`, `chatbox/lib/screens/profile/profile_screen.dart:1082` (vs. `auth_gate.dart:131`, which does stop it)

**Problem:** Only the lock-screen sign-out calls `stopRelayListener()`. After signing out elsewhere, the 3 s poller and the Firebase listener keep running for the old user. They keep pulling, decrypting (with keys that were just deleted, see #3), storing messages, and showing notifications while no one is logged in. Realtime presence heartbeats also keep running.

**Solution:** Move the teardown into one place. `AuthService.signOut()` (or an auth-state listener in `AuthGate`) should call `chatRepository.stopRelayListener()` and `realtimeService.dispose()`.

### 24. `acceptConnectionRequest` doesn't verify a pending request
**Where:** `chatbox/lib/services/love_connection_service.dart:236-246`

**Problem:** It takes `current ?? new` and forces `status: connected, partnerUsername: <given>`. If `current` is a `requestSent` to `@carol`, accepting `@bob` silently turns it into a connection with Bob. If no request exists, it still "accepts" and notifies the target.

**Solution:** Require `current != null && current.status == requestReceived && current.partnerUsername == normalizedPartner`. Otherwise throw a `LoveConnectionException`.

### 25. Missing/invalid `expires_at` → envelope immediately purged
**Where:** `chatbox/lib/models/ephemeral_relay_envelope.dart:494-511` (`parseDateTime` fallback at `:499`)

**Problem:** A missing or unparseable timestamp falls back to `DateTime.now()`. A moment later `isExpired()` returns true, and the envelope is deleted unread. Also, SDK values may come back as `double`/`num`, which isn't handled.

**Solution:** For `expires_at`, fall back to `timestamp + 48h` (or treat the envelope as invalid and log it). Handle `num` with `DateTime.fromMillisecondsSinceEpoch(val.toInt(), isUtc: true)`.

### 26. Multiple `LocalChatRepository` instances, each with its own pollers
**Where:** `chatbox/lib/screens/chat_screen.dart:79`, `chatbox/lib/screens/profile/profile_screen.dart:1284`, `chatbox/lib/screens/auth/auth_gate.dart:44`

**Problem:** Fallbacks like `widget.repository ?? LocalChatRepository()` create a new repository, which means a new `DefaultSyncService` with its own timers, a new `DefaultRealtimeService`, and so on. Each one calling `startRelayListener` adds another 3 s poller, which makes #11 worse.

**Solution:** Create the repository once in `main.dart` and provide it through `Provider` / `InheritedWidget`. Make the fallbacks assert in debug mode instead of building new instances.

---

## 🟢 Low

### 27. GitHub Actions workflow can never pass
**Where:** `.github/workflows/dart.yml`

**Problem:** It runs `dart pub get`, `dart analyze` and `dart test` at the repo root. There's no `pubspec.yaml` there (the app is in `chatbox/`), and it's a Flutter project (it needs `flutter`, and tests use `flutter_test`).

**Solution:**
```yaml
defaults: { run: { working-directory: chatbox } }
steps:
  - uses: actions/checkout@v4
  - uses: subosito/flutter-action@v2
    with: { channel: stable, cache: true }
  - run: flutter pub get
  - run: flutter analyze
  - run: flutter test
```

### 28. Repo hygiene
**Where:** repo root, `chatbox/android/build/…`, `git status`

**Problem:**
- `Nest-release.apk` (64 MB) and `Nest-release.aab` (53 MB) are committed. That bloats every clone, and binaries don't belong in git (use GitHub Releases).
- Files under `*/android/build/` are tracked (they show up in `git diff` CRLF warnings).
- `chatbox/lib/services/firebase_rest_client.dart` is **untracked** (`??`), but the modified relay and directory services import it. Committing the other changes without it breaks the build for everyone else.
- The Firebase API key is hard-coded in `main.dart:21`. That's normal for Firebase client keys, but since the rules are open (#1), anyone can use it. Restrict the key in the GCP console (Android package + SHA-1).

**Solution:** `git rm --cached Nest-release.* -r chatbox/android/build`, add `*.apk`, `*.aab` and `**/build/` to `.gitignore`, and `git add chatbox/lib/services/firebase_rest_client.dart` with the related changes. Consider `git filter-repo` to remove the binaries from history.

### 29. Lint warnings / dead code
**Where:** `chatbox/lib/repositories/conversation_repository.dart:5` (unused import), `chatbox/lib/screens/chat_screen.dart:235` (`_generateInitialSeedMessages` unused). `chatbox/lib/chat_screen.dart` duplicates `lib/screens/chat_screen.dart`. `ChatService.fetchMessages/sendLuv/markMessagesAsRead/deleteMessage/editMessage` (`chat_service.dart:72-104`) are stubs with fake delays that return success while doing nothing (e.g. `deleteMessage` returns `true`).

**Solution:** Remove the dead code and the duplicate file. Either implement the stubs or delete them so callers can't depend on fake success.

---

## Fix log
- **2026-11-01 — #9–#12 fixed** (`chatbox/lib/repositories/chat_repository.dart`, `chatbox/lib/services/sync_service.dart`):
  - #9: `LocalChatRepository` is now a factory that builds each dependency once and passes the same love/sharing/couple instances to `DefaultSyncService`.
  - #10: `processInboundEnvelopes` skips typing/presence envelopes and leaves them for `RealtimeService`.
  - #11: concurrent calls share one in-flight drain (with a re-run flag if more envelopes arrive), plus a bounded set of recently handled IDs.
  - #12: each envelope is handled in its own try/catch; after 5 failed attempts it is dropped and purged. Notifications and delivery receipts can no longer fail an envelope that is already saved.
  - Tests: `chatbox/test/sync/inbound_processing_test.dart` (5 tests). The 9 failures in `test/widget_test.dart` were already failing before this change (fail-closed recipient key, DB/inbox expectations).

## Suggested fix order
1. **#9, #10, #11, #12** – a few lines each; they fix the most visible breakage (lost love requests, junk messages, duplicate notifications).
2. **#3, #4, #5, #6, #7** – stop the plaintext leaks and the key loss.
3. **#1, #2, #8** – server rules + username ownership + key pinning (these need a Firebase Auth ↔ username binding, so plan them together).
4. Everything else.
