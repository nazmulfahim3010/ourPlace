import 'dart:math';
import 'package:flutter/material.dart';

/// Single floating heart particle data
class _HeartParticle {
  final double startX;
  final double startY;
  final double targetX;
  final double targetY;
  final double size;
  final double rotation;
  final String emoji;
  final double curveFactor;

  _HeartParticle({
    required this.startX,
    required this.startY,
    required this.targetX,
    required this.targetY,
    required this.size,
    required this.rotation,
    required this.emoji,
    required this.curveFactor,
  });
}

/// Particle-based floating heart burst animation overlay for "Send luv" (Phase 18)
class FloatingHeartsOverlay extends StatefulWidget {
  final Widget child;

  const FloatingHeartsOverlay({super.key, required this.child});

  /// Static helper to trigger a burst on any active State
  static void burst(BuildContext context) {
    final state = context.findAncestorStateOfType<_FloatingHeartsOverlayState>();
    state?.spawnBurst();
  }

  @override
  State<FloatingHeartsOverlay> createState() => _FloatingHeartsOverlayState();
}

class _FloatingHeartsOverlayState extends State<FloatingHeartsOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_HeartParticle> _particles = [];
  final Random _random = Random();

  static const List<String> _heartEmojis = [
    '❤️',
    '💕',
    '💖',
    '🥰',
    '✨',
    '💓',
    '🔥',
    '💘',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..addListener(() {
        if (mounted) setState(() {});
      })
     ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _particles.clear();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Spawn a burst of animated hearts floating upward
  void spawnBurst([Offset? origin]) {
    final size = MediaQuery.of(context).size;
    final startX = origin?.dx ?? (size.width / 2);
    final startY = origin?.dy ?? (size.height * 0.75);

    _particles.clear();
    const count = 26;

    for (int i = 0; i < count; i++) {
      final spreadX = (_random.nextDouble() - 0.5) * (size.width * 0.85);
      final riseY = -(_random.nextDouble() * (size.height * 0.6) + 200);

      _particles.add(
        _HeartParticle(
          startX: startX + (_random.nextDouble() - 0.5) * 60,
          startY: startY + (_random.nextDouble() - 0.5) * 40,
          targetX: startX + spreadX,
          targetY: startY + riseY,
          size: 18.0 + _random.nextDouble() * 20.0,
          rotation: (_random.nextDouble() - 0.5) * 0.8,
          emoji: _heartEmojis[_random.nextInt(_heartEmojis.length)],
          curveFactor: (_random.nextDouble() - 0.5) * 80.0,
        ),
      );
    }

    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_controller.isAnimating && _particles.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _FloatingHeartsPainter(
                  particles: _particles,
                  progress: _controller.value,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FloatingHeartsPainter extends CustomPainter {
  final List<_HeartParticle> particles;
  final double progress;

  _FloatingHeartsPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Ease out movement
      final t = Curves.easeOutCubic.transform(progress);

      // Interpolate position with gentle sine wave wobble
      final currentX = p.startX + (p.targetX - p.startX) * t + sin(progress * pi * 3) * p.curveFactor;
      final currentY = p.startY + (p.targetY - p.startY) * t;

      // Opacity: fade in quickly, fade out at end
      double opacity = 1.0;
      if (progress < 0.15) {
        opacity = progress / 0.15;
      } else if (progress > 0.6) {
        opacity = (1.0 - progress) / 0.4;
      }
      opacity = opacity.clamp(0.0, 1.0);

      // Scale: start medium, grow slightly, shrink
      final scale = (0.5 + 0.8 * sin(progress * pi)).clamp(0.2, 1.3);

      final textSpan = TextSpan(
        text: p.emoji,
        style: TextStyle(
          fontSize: p.size * scale,
          color: Colors.white.withValues(alpha: opacity),
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(p.rotation * progress);
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingHeartsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
