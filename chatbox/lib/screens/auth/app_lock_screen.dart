import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chatbox/core/theme/app_theme.dart';
import 'package:chatbox/services/app_lock_service.dart';
import 'package:chatbox/widgets/numeric_keypad.dart';
import 'package:chatbox/widgets/passcode_dots.dart';

enum AppLockMode {
  unlock,
  verifyCurrent,
}

/// Dedicated device lock screen protecting local data and conversations
class AppLockScreen extends StatefulWidget {
  final AppLockService appLockService;
  final VoidCallback? onUnlocked;
  final ValueChanged<bool>? onVerified;
  final VoidCallback? onSignOutRequested;
  final AppLockMode mode;
  final bool autoPromptBiometrics;

  const AppLockScreen({
    super.key,
    required this.appLockService,
    this.onUnlocked,
    this.onVerified,
    this.onSignOutRequested,
    this.mode = AppLockMode.unlock,
    this.autoPromptBiometrics = true,
  });

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  String _enteredCode = '';
  bool _hasError = false;
  String? _errorMessage;
  bool _showBiometricButton = false;
  bool _isChecking = false;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
    if (widget.appLockService.isLockedOut()) {
      _startLockoutCountdown();
    }
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  void _startLockoutCountdown() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!widget.appLockService.isLockedOut()) {
        timer.cancel();
        setState(() {
          _hasError = false;
          _errorMessage = null;
        });
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _checkBiometrics() async {
    final available = await widget.appLockService.isBiometricsAvailable();
    final enabled = await widget.appLockService.isBiometricsEnabled();

    if (mounted) {
      setState(() {
        _showBiometricButton = available && enabled && widget.mode == AppLockMode.unlock;
      });

      if (_showBiometricButton && widget.autoPromptBiometrics && !widget.appLockService.isLockedOut()) {
        // Small delay to ensure frame is rendered
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _authenticateBiometrics();
        });
      }
    }
  }

  Future<void> _authenticateBiometrics() async {
    if (_isChecking || widget.appLockService.isLockedOut()) return;
    setState(() => _isChecking = true);

    final success = await widget.appLockService.authenticateWithBiometrics(
      reason: 'Unlock Nest to access private messages',
    );

    if (!mounted) return;

    setState(() => _isChecking = false);

    if (success) {
      widget.onUnlocked?.call();
      widget.onVerified?.call(true);
    }
  }

  void _onDigit(int digit) {
    if (widget.appLockService.isLockedOut() || _enteredCode.length >= 4 || _isChecking) return;

    setState(() {
      _hasError = false;
      _errorMessage = null;
      _enteredCode += digit.toString();
    });

    if (_enteredCode.length == 4) {
      _verifyPasscode(_enteredCode);
    }
  }

  void _onBackspace() {
    if (_enteredCode.isNotEmpty && !_isChecking && !widget.appLockService.isLockedOut()) {
      setState(() {
        _hasError = false;
        _errorMessage = null;
        _enteredCode = _enteredCode.substring(0, _enteredCode.length - 1);
      });
    }
  }

  Future<void> _verifyPasscode(String candidate) async {
    if (widget.appLockService.isLockedOut()) {
      _startLockoutCountdown();
      return;
    }

    setState(() => _isChecking = true);

    final isValid = await widget.appLockService.verifyPasscode(candidate);

    if (!mounted) return;

    if (isValid) {
      _lockoutTimer?.cancel();
      setState(() {
        _isChecking = false;
        _enteredCode = '';
      });

      if (widget.mode == AppLockMode.unlock) {
        widget.onUnlocked?.call();
      } else {
        widget.onVerified?.call(true);
      }
    } else {
      final isNowLockedOut = widget.appLockService.isLockedOut();
      if (isNowLockedOut) {
        _startLockoutCountdown();
      }

      final remaining = 5 - widget.appLockService.failedAttempts;
      final errorMsg = isNowLockedOut
          ? 'Device temporarily locked for 60s'
          : (remaining <= 2 && remaining > 0)
              ? 'Incorrect passcode ($remaining attempts left)'
              : 'Incorrect passcode';

      setState(() {
        _isChecking = false;
        _hasError = true;
        _errorMessage = errorMsg;
        _enteredCode = '';
      });

      if (widget.mode == AppLockMode.verifyCurrent) {
        widget.onVerified?.call(false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final isVerifyOnly = widget.mode == AppLockMode.verifyCurrent;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      /// Header / Back button (if verify mode)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          children: [
                            if (isVerifyOnly)
                              IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: () => Navigator.of(context).pop(),
                              )
                            else
                              const SizedBox(height: 36),
                          ],
                        ),
                      ),

                      const Spacer(),

                      /// Lock Icon / Shield
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isVerifyOnly ? const Color(0xFF282828) : Colors.white,
                          boxShadow: isVerifyOnly
                              ? null
                              : [
                                  BoxShadow(
                                    color: const Color(0xFF1D525D).withValues(alpha: 0.35),
                                    blurRadius: 18,
                                    spreadRadius: 1,
                                  ),
                                ],
                        ),
                        padding: isVerifyOnly ? EdgeInsets.zero : const EdgeInsets.all(9),
                        child: isVerifyOnly
                            ? const Icon(
                                Icons.lock_outline_rounded,
                                color: Colors.white,
                                size: 28,
                              )
                            : Image.asset(
                                'assets/images/logo_icon.png',
                                fit: BoxFit.contain,
                              ),
                      ),
                      const SizedBox(height: 16),

                      /// Title
                      Text(
                        isVerifyOnly ? 'Confirm Passcode' : 'Nest',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),

                      /// Subtitle
                      Text(
                        isVerifyOnly
                            ? 'Enter current passcode to continue'
                            : 'Enter your 4-digit passcode to unlock',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 20),

                      /// Dots indicator
                      PasscodeDots(
                        length: 4,
                        filledCount: _enteredCode.length,
                        hasError: _hasError,
                        onAnimationComplete: () {
                          if (mounted) setState(() => _hasError = false);
                        },
                      ),
                      const SizedBox(height: 12),

                      /// Lockout alert banner
                      if (widget.appLockService.isLockedOut())
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A1517),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.timer_outlined, color: Color(0xFFFF5252), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Lockout Active: ${widget.appLockService.remainingLockoutSeconds()}s remaining',
                                style: const TextStyle(
                                  color: Color(0xFFFF5252),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                      /// Error message display
                      SizedBox(
                        height: 18,
                        child: _errorMessage != null && !widget.appLockService.isLockedOut()
                            ? Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Color(0xFFFF5252),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            : null,
                      ),


                      const Spacer(),

                      /// Numeric Keypad
                      NumericKeypad(
                        onDigit: _onDigit,
                        onBackspace: _onBackspace,
                        onBiometric: _showBiometricButton ? _authenticateBiometrics : null,
                        showBiometric: _showBiometricButton,
                      ),

                      const SizedBox(height: 12),

                      /// Forgot Passcode / Re-authenticate option
                      if (!isVerifyOnly && widget.onSignOutRequested != null)
                        TextButton(
                          onPressed: widget.onSignOutRequested,
                          child: const Text(
                            'Forgot Passcode? Sign in with Account Password',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12.0,
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 24),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
