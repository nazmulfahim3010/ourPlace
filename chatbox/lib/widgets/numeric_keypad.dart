import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Touch-friendly numeric keypad adhering to ourPlace charcoal aesthetic
class NumericKeypad extends StatelessWidget {
  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;
  final bool showBiometric;

  const NumericKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.onBiometric,
    this.showBiometric = false,
  });

  Widget _buildKey({
    required Widget content,
    required VoidCallback onTap,
    Color backgroundColor = const Color(0xFF282828),
  }) {
    return SizedBox(
      width: 70,
      height: 70,
      child: Material(
        color: backgroundColor,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          splashColor: Colors.white24,
          highlightColor: Colors.white12,
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Center(child: content),
        ),
      ),
    );
  }

  Widget _buildDigitKey(int digit) {
    return _buildKey(
      content: Text(
        '$digit',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () => onDigit(digit),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDigitKey(1),
              _buildDigitKey(2),
              _buildDigitKey(3),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDigitKey(4),
              _buildDigitKey(5),
              _buildDigitKey(6),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDigitKey(7),
              _buildDigitKey(8),
              _buildDigitKey(9),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              /// Left bottom slot: Biometric or empty
              if (showBiometric && onBiometric != null)
                _buildKey(
                  backgroundColor: const Color(0xFF1E1E1E),
                  content: const Icon(
                    Icons.fingerprint,
                    color: Colors.white,
                    size: 30,
                  ),
                  onTap: onBiometric!,
                )
              else
                const SizedBox(width: 70, height: 70),

              _buildDigitKey(0),

              /// Right bottom slot: Backspace
              _buildKey(
                backgroundColor: const Color(0xFF1E1E1E),
                content: const Icon(
                  Icons.backspace_outlined,
                  color: Colors.white,
                  size: 22,
                ),
                onTap: onBackspace,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
