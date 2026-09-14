import 'package:flutter/material.dart';
import 'package:chatbox/core/theme/app_theme.dart';
import 'package:chatbox/services/app_lock_service.dart';
import 'package:chatbox/widgets/numeric_keypad.dart';
import 'package:chatbox/widgets/passcode_dots.dart';

/// Screen for creating and confirming a local 4-digit device passcode
class PasscodeSetupScreen extends StatefulWidget {
  final AppLockService appLockService;
  final VoidCallback onSetupComplete;
  final bool isChangingPasscode;

  const PasscodeSetupScreen({
    super.key,
    required this.appLockService,
    required this.onSetupComplete,
    this.isChangingPasscode = false,
  });

  @override
  State<PasscodeSetupScreen> createState() => _PasscodeSetupScreenState();
}

class _PasscodeSetupScreenState extends State<PasscodeSetupScreen> {
  int _step = 1; // 1 = Create, 2 = Confirm
  String _firstCode = '';
  String _confirmCode = '';
  bool _hasError = false;
  String? _errorMessage;

  void _onDigit(int digit) {
    if (_hasError) {
      setState(() {
        _hasError = false;
        _errorMessage = null;
      });
    }

    if (_step == 1) {
      if (_firstCode.length < 4) {
        setState(() => _firstCode += digit.toString());
        if (_firstCode.length == 4) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              setState(() {
                _step = 2;
                _errorMessage = null;
              });
            }
          });
        }
      }
    } else {
      if (_confirmCode.length < 4) {
        setState(() => _confirmCode += digit.toString());
        if (_confirmCode.length == 4) {
          _verifyAndSave();
        }
      }
    }
  }

  void _onBackspace() {
    if (_step == 1) {
      if (_firstCode.isNotEmpty) {
        setState(() => _firstCode = _firstCode.substring(0, _firstCode.length - 1));
      }
    } else {
      if (_confirmCode.isNotEmpty) {
        setState(() => _confirmCode = _confirmCode.substring(0, _confirmCode.length - 1));
      } else {
        // Go back to step 1
        setState(() {
          _step = 1;
          _confirmCode = '';
        });
      }
    }
  }

  Future<void> _verifyAndSave() async {
    if (_firstCode == _confirmCode) {
      await widget.appLockService.setPasscode(_confirmCode);

      final biometricsAvailable = await widget.appLockService.isBiometricsAvailable();

      if (mounted) {
        if (biometricsAvailable && !widget.isChangingPasscode) {
          _showBiometricsPrompt();
        } else {
          widget.appLockService.unlockApp();
          widget.onSetupComplete();
        }
      }
    } else {
      setState(() {
        _hasError = true;
        _errorMessage = 'Passcodes do not match. Try again.';
        _confirmCode = '';
        _firstCode = '';
        _step = 1;
      });
    }
  }

  void _showBiometricsPrompt() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF2E2E2E),
                  ),
                  child: const Icon(Icons.fingerprint, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Enable Biometric Unlock?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Unlock ourPlace securely using fingerprint or face authentication.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await widget.appLockService.setBiometricsEnabled(true);
                      widget.appLockService.unlockApp();
                      widget.onSetupComplete();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Enable Biometrics',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await widget.appLockService.setBiometricsEnabled(false);
                    widget.appLockService.unlockApp();
                    widget.onSetupComplete();
                  },
                  child: const Text(
                    'Skip for Now',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _step == 1
        ? (widget.isChangingPasscode ? 'Enter New Passcode' : 'Create App Passcode')
        : 'Confirm Passcode';

    final subtitle = _step == 1
        ? 'Enter a 4-digit code to protect the app on this device'
        : 'Re-enter your 4-digit passcode';

    final currentLength = _step == 1 ? _firstCode.length : _confirmCode.length;

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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          children: [
                            if (widget.isChangingPasscode)
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
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF282828),
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      PasscodeDots(
                        length: 4,
                        filledCount: currentLength,
                        hasError: _hasError,
                        onAnimationComplete: () {
                          if (mounted) setState(() => _hasError = false);
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 18,
                        child: _errorMessage != null
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
                      NumericKeypad(
                        onDigit: _onDigit,
                        onBackspace: _onBackspace,
                      ),
                      const SizedBox(height: 36),
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
