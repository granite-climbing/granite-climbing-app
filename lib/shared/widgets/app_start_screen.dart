import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'granite_logo.dart';

class AppStartScreen extends StatelessWidget {
  const AppStartScreen({super.key});

  static const _backgroundColor = Color(0xFF2F312D);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GraniteLogo(),
              const SizedBox(height: 24),
              const GraniteLoadingSpinner(),
            ],
          ),
        ),
      ),
    );
  }
}

class GraniteLoadingSpinner extends StatefulWidget {
  const GraniteLoadingSpinner({
    this.size = 28,
    this.color = Colors.white,
    super.key,
  });

  final double size;
  final Color color;

  @override
  State<GraniteLoadingSpinner> createState() => _GraniteLoadingSpinnerState();
}

class _GraniteLoadingSpinnerState extends State<GraniteLoadingSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: RotationTransition(
        turns: _controller,
        child: CustomPaint(
          painter: _GraniteSpinnerPainter(color: widget.color),
        ),
      ),
    );
  }
}

class _GraniteSpinnerPainter extends CustomPainter {
  const _GraniteSpinnerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 2.6;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2);

    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    final activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas
      ..drawArc(arcRect, 0, math.pi * 2, false, trackPaint)
      ..drawArc(arcRect, -math.pi / 2, math.pi * 1.35, false, activePaint);
  }

  @override
  bool shouldRepaint(_GraniteSpinnerPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
