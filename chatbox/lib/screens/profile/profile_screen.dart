import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chatbox/core/theme/app_theme.dart';
import 'package:chatbox/core/utils/recovery_key_utils.dart';
import 'package:chatbox/database/local_database.dart';
import 'package:chatbox/models/love_connection.dart';
import 'package:chatbox/models/security_log.dart';
import 'package:chatbox/models/user.dart';
import 'package:chatbox/repositories/auth_repository.dart';
import 'package:chatbox/services/app_lock_service.dart';
import 'package:chatbox/services/conversation_sharing_service.dart';
import 'package:chatbox/services/love_connection_service.dart';
import 'package:chatbox/widgets/claim_love_code_dialog.dart';
import 'package:chatbox/services/notification_service.dart';
import 'package:chatbox/services/realtime_service.dart';
import 'package:chatbox/screens/auth/app_lock_screen.dart';
import 'package:chatbox/screens/auth/passcode_setup_screen.dart';
import 'package:chatbox/screens/couple/couple_milestones_screen.dart';
import 'package:chatbox/repositories/chat_repository.dart';

/// Profile screen displaying anonymous account identity, Love Connection status, and privacy settings
class ProfileScreen extends StatefulWidget {
  final User? currentUser;
  final AuthRepository? authRepository;
  final AppLockService? appLockService;
  final RealtimeService? realtimeService;
  final NotificationService? notificationService;
  final LoveConnectionService? loveConnectionService;
  final ConversationSharingService? conversationSharingService;
  final ChatRepository? chatRepository;

  const ProfileScreen({
    super.key,
    this.currentUser,
    this.authRepository,
    this.appLockService,
    this.realtimeService,
    this.notificationService,
    this.loveConnectionService,
    this.conversationSharingService,
    this.chatRepository,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final LoveConnectionService _loveConnectionService;
  late final ConversationSharingService _conversationSharingService;
  bool _hideLoveConnection = false;
  bool _biometricsEnabled = false;
  bool _biometricsAvailable = false;
  late final RealtimeService _realtimeService;
  late final NotificationService _notificationService;
  bool _presenceSharingEnabled = true;
  bool _typingSharingEnabled = true;
  bool _notificationsEnabled = true;
  bool _discreetModeEnabled = true;
  bool _soundEnabled = true;

  @override
  void initState() {
    super.initState();
    _loveConnectionService = widget.loveConnectionService ??
        InMemoryLoveConnectionService();
    _conversationSharingService = widget.conversationSharingService ??
        InMemoryConversationSharingService();
    _realtimeService = widget.realtimeService ?? DefaultRealtimeService();
    _notificationService =
        widget.notificationService ?? DefaultNotificationService();
    _notificationsEnabled = _notificationService.settings.enabled;
    _discreetModeEnabled =
        _notificationService.settings.hidePreviewOnLockScreen;
    _soundEnabled = _notificationService.settings.soundEnabled;
    _loadSecuritySettings();
  }

  Future<void> _updateNotificationSettings() async {
    final updated = _notificationService.settings.copyWith(
      enabled: _notificationsEnabled,
      hidePreviewOnLockScreen: _discreetModeEnabled,
      soundEnabled: _soundEnabled,
    );
    await _notificationService.updateSettings(updated);
  }

  void _handleTestNotification() {
    _notificationService.showLocalAlert(
      title: widget.currentUser?.displayName ?? 'Nest Partner',
      body: '❤️ This is a private test message.',
      conversationId: widget.currentUser?.id ?? '@partner',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _discreetModeEnabled
              ? 'Discreet alert triggered: "Nest • New private message received"'
              : 'Alert triggered with cleartext preview.',
          style: const TextStyle(
            color: AppTheme.notificationTextPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.notificationSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: _discreetModeEnabled
                ? AppTheme.notificationDiscreetGold
                : AppTheme.notificationBorder,
            width: 1.2,
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _loadSecuritySettings() async {
    if (widget.appLockService != null) {
      final avail = await widget.appLockService!.isBiometricsAvailable();
      final enabled = await widget.appLockService!.isBiometricsEnabled();
      if (mounted) {
        setState(() {
          _biometricsAvailable = avail;
          _biometricsEnabled = enabled;
        });
      }
    }
    final pSharing = await _realtimeService.isPresenceSharingEnabled();
    final tSharing = await _realtimeService.isTypingSharingEnabled();
    if (mounted) {
      setState(() {
        _presenceSharingEnabled = pSharing;
        _typingSharingEnabled = tSharing;
      });
    }
  }

  void _handleChangePasscode() {
    if (widget.appLockService == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AppLockScreen(
          appLockService: widget.appLockService!,
          mode: AppLockMode.verifyCurrent,
          autoPromptBiometrics: false,
          onVerified: (verified) {
            if (verified) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => PasscodeSetupScreen(
                    appLockService: widget.appLockService!,
                    isChangingPasscode: true,
                    onSetupComplete: () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('App passcode updated successfully'),
                          backgroundColor: Color(0xFF2E2E2E),
                        ),
                      );
                    },
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  void _handleLockNow() {
    widget.appLockService?.lockApp();
    Navigator.of(context).pop();
  }

  void _handleViewRecoveryKey() {
    if (widget.appLockService != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AppLockScreen(
            appLockService: widget.appLockService!,
            mode: AppLockMode.verifyCurrent,
            autoPromptBiometrics: true,
            onVerified: (verified) {
              if (verified) {
                Navigator.of(context).pop();
                _showRecoveryKeyBottomSheet();
              }
            },
          ),
        ),
      );
    } else {
      _showRecoveryKeyBottomSheet();
    }
  }

  void _showRecoveryKeyBottomSheet() {
    String currentKey = widget.authRepository?.lastRegisteredRecoveryKey ??
        RecoveryKeyUtils.generateMnemonic();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final words = currentKey.split(' ');
            return Padding(
              padding: EdgeInsets.only(
                left: 20.0,
                right: 20.0,
                top: 20.0,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.key, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              '12-Word Recovery Key',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Store these 12 words offline in a private place. This phrase is required to restore account access if you forget your password.',
                      style: TextStyle(color: Colors.white54, fontSize: 12.5),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF282828),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF383838)),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(words.length, (index) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF383838),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${index + 1}. ${words[index]}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final newKey = RecoveryKeyUtils.generateMnemonic();
                              final username = widget.currentUser?.username ?? '@alex';
                              if (widget.authRepository != null) {
                                await widget.authRepository!.setRecoveryKey(
                                  username: username,
                                  recoveryPhrase: newKey,
                                );
                              }
                              setModalState(() {
                                currentKey = newKey;
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Generated and saved new recovery key'),
                                    backgroundColor: Color(0xFF2E2E2E),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.refresh, color: Colors.white70, size: 16),
                            label: const Text(
                              'Regenerate',
                              style: TextStyle(color: Colors.white, fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF444444)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: currentKey));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Recovery phrase copied to clipboard'),
                                  backgroundColor: Color(0xFF2E2E2E),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy, color: Colors.black, size: 16),
                            label: const Text(
                              'Copy Phrase',
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _handleViewAuditLog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.shield, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Security Audit Log',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Zero Cloud Telemetry Guarantee • Stored strictly on device',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: FutureBuilder<List<SecurityLog>>(
                        future: LocalDatabase().getSecurityLogs(limit: 50),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            );
                          }
                          final logs = snapshot.data!;
                          if (logs.isEmpty) {
                            return const Center(
                              child: Text(
                                'No security events recorded yet.',
                                style: TextStyle(color: Colors.white38, fontSize: 13),
                              ),
                            );
                          }

                          return ListView.separated(
                            itemCount: logs.length,
                            separatorBuilder: (context, index) => const Divider(color: Color(0xFF2E2E2E), height: 1),

                            itemBuilder: (context, index) {
                              final log = logs[index];
                              final isWarning = log.severity == 'warning';
                              final isCritical = log.severity == 'critical';
                              final badgeColor = isCritical
                                  ? Colors.redAccent
                                  : isWarning
                                      ? Colors.orangeAccent
                                      : const Color(0xFF4CAF50);

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: badgeColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                                      ),
                                      child: Text(
                                        log.eventType.replaceAll('_', ' ').toUpperCase(),
                                        style: TextStyle(
                                          color: badgeColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            log.details,
                                            style: const TextStyle(color: Colors.white, fontSize: 13),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            log.formattedTime,
                                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 42,
                      child: OutlinedButton(
                        onPressed: () async {
                          await LocalDatabase().clearSecurityLogs();
                          setModalState(() {});
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF444444)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text(
                          'Clear Audit Log',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.currentUser?.username ?? '@alex';
    final initial = username.length > 1 ? username[1].toUpperCase() : 'A';


    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              /// Header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Profile & Privacy',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              /// User Identity Card
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF383838),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Public Identity • Anonymous',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),



              /// Security & App Lock Card (Phase 8)
              if (widget.appLockService != null) ...[
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF242424),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF333333)),
                  ),
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lock_outline_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Security & App Lock',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Passcode Status',
                                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Active • Protected locally',
                                style: TextStyle(color: Color(0xFF4CAF50), fontSize: 12.5),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: _handleChangePasscode,
                            child: const Text(
                              'Change',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Color(0xFF333333), height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Biometric Unlock',
                                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _biometricsAvailable
                                    ? (_biometricsEnabled ? 'Enabled (Fingerprint / Face)' : 'Disabled')
                                    : 'Not available on this device',
                                style: TextStyle(
                                  color: _biometricsAvailable ? AppTheme.textSecondary : Colors.white38,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _biometricsEnabled,
                            activeThumbColor: Colors.white,
                            activeTrackColor: const Color(0xFF555555),
                            onChanged: _biometricsAvailable
                                ? (val) async {
                                    setState(() => _biometricsEnabled = val);
                                    await widget.appLockService!.setBiometricsEnabled(val);
                                  }
                                : null,
                          ),
                        ],
                      ),
                      const Divider(color: Color(0xFF333333), height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Account Recovery Key',
                                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '12-word offline backup',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: _handleViewRecoveryKey,
                            child: const Text(
                              'View / Backup',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Color(0xFF333333), height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Security Audit Log',
                                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Device-local event logs',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: _handleViewAuditLog,
                            child: const Text(
                              'View Log',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Color(0xFF333333), height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: OutlinedButton.icon(
                          onPressed: _handleLockNow,
                          icon: const Icon(Icons.lock, color: Colors.white70, size: 16),
                          label: const Text(
                            'Lock App Now',
                            style: TextStyle(color: Colors.white, fontSize: 13.5),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF444444)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

              ],

              /// Love Connection Card (Phase 16)
              _buildLoveConnectionCard(),
              const SizedBox(height: 20),

              /// Privacy & Real-Time Presence Card (Phase 13)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF242424),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.visibility, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Privacy & Presence (Phase 13)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Zero Telemetry • You control what your partner sees',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Share Online Status & Last Seen',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      subtitle: const Text(
                        'When disabled, you appear permanently offline to your partner.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      value: _presenceSharingEnabled,
                      activeThumbColor: const Color(0xFF00E676),
                      onChanged: (val) async {
                        setState(() {
                          _presenceSharingEnabled = val;
                        });
                        await _realtimeService.setPresenceSharingEnabled(val);
                      },
                    ),
                    const Divider(color: Color(0xFF333333), height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Share Typing Indicator',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      subtitle: const Text(
                        'When disabled, partner will not see "typing..." when you write.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      value: _typingSharingEnabled,
                      activeThumbColor: const Color(0xFFFF80AB),
                      onChanged: (val) async {
                        setState(() {
                          _typingSharingEnabled = val;
                        });
                        await _realtimeService.setTypingSharingEnabled(val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              /// Notifications & Privacy Card (Phase 14)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF242424),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.notifications_active_outlined, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Notifications & Privacy (Phase 14)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Zero Plaintext • Silent wake-up pings & lock screen privacy',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Push Notifications',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      subtitle: const Text(
                        'Allow silent wake-up signals when the app is in background.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      value: _notificationsEnabled,
                      activeThumbColor: const Color(0xFF00E676),
                      onChanged: (val) async {
                        setState(() {
                          _notificationsEnabled = val;
                        });
                        await _updateNotificationSettings();
                      },
                    ),
                    const Divider(color: Color(0xFF333333), height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Discreet Mode',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      subtitle: const Text(
                        'Hide sender & message preview on lock screen. Displays "New private message".',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      value: _discreetModeEnabled,
                      activeThumbColor: const Color(0xFFFFB300),
                      onChanged: (val) async {
                        setState(() {
                          _discreetModeEnabled = val;
                        });
                        await _updateNotificationSettings();
                      },
                    ),
                    const Divider(color: Color(0xFF333333), height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Sound & Haptics',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      subtitle: const Text(
                        'Play discrete alert sound and subtle vibration on new messages.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      value: _soundEnabled,
                      activeThumbColor: Colors.white70,
                      onChanged: (val) async {
                        setState(() {
                          _soundEnabled = val;
                        });
                        await _updateNotificationSettings();
                      },
                    ),
                    const Divider(color: Color(0xFF333333), height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: OutlinedButton.icon(
                        onPressed: _handleTestNotification,
                        icon: const Icon(Icons.notifications_none_rounded, color: Colors.white70, size: 16),
                        label: const Text(
                          'Test Private Notification',
                          style: TextStyle(color: Colors.white, fontSize: 13.5),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF444444)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              /// Love Connection Card
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2E2428),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFFF6B81).withValues(alpha: 0.35),
                  ),
                ),
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.favorite, color: Color(0xFFFF6B81), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Love Connection',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Connected with @twilight',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '0 or 1 active couple connection. Does not automatically grant access to other chats.',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Hide from visible profile',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        Switch(
                          value: _hideLoveConnection,
                          activeThumbColor: const Color(0xFFFF6B81),
                          onChanged: (val) {
                            setState(() {
                              _hideLoveConnection = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              /// Privacy Architecture Info Card
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF242424),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                padding: const EdgeInsets.all(16.0),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield_outlined, color: Colors.white70, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Privacy Guarantee',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• No Gmail or personal email required\n'
                      '• No phone number or contacts collected\n'
                      '• Chat history is stored locally on device\n'
                      '• Local App Passcode & Biometric Security Active\n'
                      '• Three-tier credential separation enforced',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              /// Sign Out Button
              if (widget.authRepository != null)
                SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      widget.appLockService?.lockApp();
                      await widget.authRepository!.signOut();
                    },
                    icon: const Icon(Icons.logout, color: Colors.white70, size: 18),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF444444)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Love Connection Card Component (Phase 16)
  Widget _buildLoveConnectionCard() {
    final currentUserId = widget.currentUser?.id ?? 'current_user';
    final currentUsername = widget.currentUser?.username ?? '@alex';

    return StreamBuilder<LoveConnection?>(
      stream: _loveConnectionService.watchLoveConnection(currentUserId: currentUserId),
      builder: (context, snapshot) {
        final conn = snapshot.data;
        final isConnected = conn != null && conn.isConnected;
        final isPendingSent = conn != null && conn.isPendingSent;
        final isPendingReceived = conn != null && conn.isPendingReceived;

        return Container(
          decoration: BoxDecoration(
            color: isConnected
                ? const Color(0xFF2E2428)
                : const Color(0xFF242424),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isConnected
                  ? const Color(0xFFFF6B81).withValues(alpha: 0.5)
                  : const Color(0xFF333333),
              width: isConnected ? 1.5 : 1.0,
            ),
          ),
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(isConnected ? '❤️' : '🤍', style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      const Text(
                        'Love Connection',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isConnected
                          ? Colors.pinkAccent.withValues(alpha: 0.2)
                          : isPendingSent || isPendingReceived
                              ? Colors.amberAccent.withValues(alpha: 0.15)
                              : Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isConnected
                          ? 'CONNECTED'
                          : isPendingSent
                              ? 'INVITATION SENT'
                              : isPendingReceived
                                  ? 'REQUEST RECEIVED'
                                  : '0 OF 1 ACTIVE',
                      style: TextStyle(
                        color: isConnected
                            ? const Color(0xFFFF6B81)
                            : isPendingSent || isPendingReceived
                                ? Colors.amberAccent
                                : Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (isConnected) ...[
                // Connected Partner Details
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFFF6B81).withValues(alpha: 0.2),
                      child: const Text('💕', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            conn.partnerUsername,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            conn.connectedAt != null
                                ? 'Connected since ${conn.connectedAt!.month}/${conn.connectedAt!.day}/${conn.connectedAt!.year}'
                                : 'Active Love Connection',
                            style: const TextStyle(
                              color: Color(0xFFAAAAAA),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF383838), height: 24),
                // Privacy Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Show in Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Display couple badge on identity',
                          style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
                        ),
                      ],
                    ),
                    Switch(
                      value: conn.isVisibleOnProfile,
                      activeThumbColor: Colors.pinkAccent,
                      activeTrackColor: Colors.pinkAccent.withValues(alpha: 0.4),
                      onChanged: (val) async {
                        await _loveConnectionService.setVisibilityOnProfile(
                          val,
                          currentUserId: currentUserId,
                        );
                      },
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF383838), height: 24),

                // Phase 18: Couple Space & Milestones action
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.favorite_rounded, color: Colors.white, size: 16),
                    label: const Text(
                      'Open Couple Space ❤️',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4081),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CoupleMilestonesScreen(
                            loveConnection: conn,
                            chatRepository: widget.chatRepository ?? LocalChatRepository(),
                            currentUsername: currentUsername,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // Phase 17: Redeem Partner's Love Code action
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.download_rounded, color: Colors.black, size: 16),
                    label: const Text(
                      'Redeem Partner\'s Love Code',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      ClaimLoveCodeDialog.show(
                        context,
                        currentUserId: currentUserId,
                        currentUsername: currentUsername,
                        lovePartnerUsername: conn.partnerUsername,
                        sharingService: _conversationSharingService,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // Disconnect action
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.link_off_rounded, color: Colors.white70, size: 16),
                    label: const Text(
                      'Disconnect Love Partner',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF555555)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => _confirmUnlinkLoveConnection(currentUserId, currentUsername),
                  ),
                ),
              ] else if (isPendingSent) ...[
                // Request Sent pending
                Text(
                  'Waiting for ${conn.partnerUsername} to accept your invitation...',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: OutlinedButton(
                    onPressed: () async {
                      await _loveConnectionService.cancelConnectionRequest(
                        currentUserId: currentUserId,
                        currentUsername: currentUsername,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF555555)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Cancel Request', style: TextStyle(color: Colors.white70)),
                  ),
                ),
              ] else if (isPendingReceived) ...[
                // Request Received
                Text(
                  '${conn.partnerUsername} wants to establish a Love Connection with you! ❤️',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pinkAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () async {
                          await _loveConnectionService.acceptConnectionRequest(
                            partnerUsername: conn.partnerUsername,
                            currentUserId: currentUserId,
                            currentUsername: currentUsername,
                          );
                        },
                        child: const Text('Accept ❤️', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () async {
                        await _loveConnectionService.declineConnectionRequest(
                          partnerUsername: conn.partnerUsername,
                          currentUserId: currentUserId,
                          currentUsername: currentUsername,
                        );
                      },
                      child: const Text('Decline', style: TextStyle(color: Colors.white60)),
                    ),
                  ],
                ),
              ] else ...[
                // None
                const Text(
                  'Nest is strictly 1-to-1 for couples. Connect with your partner using their anonymous @username to activate couple features.',
                  style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 13),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    icon: const Text('❤️', style: TextStyle(fontSize: 16)),
                    label: const Text(
                      'Connect with Partner',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () => _showConnectPartnerDialog(currentUserId, currentUsername),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showConnectPartnerDialog(String currentUserId, String currentUsername) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF242424),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Connect with Partner', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your partner\'s anonymous @username to send a Love Connection request:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF383838),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  prefixText: '@',
                  prefixStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  hintText: 'partner_username',
                  hintStyle: TextStyle(color: Colors.white38),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pinkAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.of(ctx).pop();
              try {
                await _loveConnectionService.sendConnectionRequest(
                  partnerUsername: text,
                  currentUserId: currentUserId,
                  currentUsername: currentUsername,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Love Connection request sent to @$text! ❤️'),
                      backgroundColor: const Color(0xFF2E2428),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }

  void _confirmUnlinkLoveConnection(String currentUserId, String currentUsername) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF242424),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Disconnect Partner?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to disconnect? Your device\'s local chat history will remain completely safe on your phone, but couple features will be paused.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep Connected', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _loveConnectionService.unlinkLoveConnection(
                currentUserId: currentUserId,
                currentUsername: currentUsername,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Love Connection unlinked.'), backgroundColor: Color(0xFF383838)),
                );
              }
            },
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }
}
