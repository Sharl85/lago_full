import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/calculator.dart';
import '../theme.dart';
import 'common.dart';
import '../l10n/l10n.dart';

/// Cadran circulaire de progression avec fleur de lotus animée au centre.
class CycleDial extends StatefulWidget {
  final CycleData data;
  final double size;
  const CycleDial({super.key, required this.data, this.size = 260});

  @override
  State<CycleDial> createState() => _CycleDialState();
}

class _CycleDialState extends State<CycleDial> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final dark = isDark(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: d.progressPercent / 100),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, progress, _) => CustomPaint(
          painter: _RingPainter(progress, dark),
          child: Center(
            child: Container(
              width: widget.size * 0.68,
              height: widget.size * 0.68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dark ? const Color(0xFF2B1B27) : Colors.white.withValues(alpha: 0.85),
                boxShadow: [BoxShadow(color: LagoColors.pinkSoft.withValues(alpha: 0.35), blurRadius: 24)],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) => Transform.scale(
                      scale: reduceMotion ? 1 : 1 + _pulse.value * 0.06,
                      child: SizedBox(
                        width: widget.size * 0.3,
                        height: widget.size * 0.3,
                        child: CustomPaint(painter: LotusPainter(d.phase.key)),
                      ),
                    ),
                  ),
                  T(
                    'Jour ${d.currentCycleDay}',
                    style: TextStyle(
                      fontFamily: LagoTheme.serif,
                      fontWeight: FontWeight.w700,
                      fontSize: widget.size * 0.13,
                      color: LagoColors.pink,
                      height: 1.05,
                    ),
                  ),
                  T(
                    'SUR ${d.cycleLength} JOURS',
                    style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600, color: mutedColor(context)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final bool dark;
  _RingPainter(this.progress, this.dark);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 12;
    final bg = Paint()
      ..color = dark ? const Color(0xFF3E2233) : const Color(0xFFFCE4EC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16;
    canvas.drawCircle(center, radius, bg);

    final rect = Rect.fromCircle(center: center, radius: radius);
    final fg = Paint()
      ..shader = const SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [Color(0xFFF48FB1), Color(0xFFE85D75), Color(0xFFC2185B)],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 16;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress.clamp(0.0, 1.0), false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress || old.dark != dark;
}

/// Fleur de lotus dont l'ouverture varie selon la phase du cycle.
class LotusPainter extends CustomPainter {
  final PhaseKey phase;
  LotusPainter(this.phase);

  double get _openness => switch (phase) {
        PhaseKey.menstrual => 0.45,
        PhaseKey.follicular => 0.75,
        PhaseKey.ovulation => 1.0,
        PhaseKey.luteal => 0.6,
      };

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.save();
    canvas.scale(s, s);
    final o = _openness;

    void petal(double angleDeg, Color color, double length, double width) {
      canvas.save();
      canvas.translate(50, 85);
      canvas.rotate(angleDeg * math.pi / 180 * o);
      final path = Path()
        ..moveTo(0, 0)
        ..cubicTo(-width, -length * 0.35, -width * 0.8, -length * 0.8, 0, -length)
        ..cubicTo(width * 0.8, -length * 0.8, width, -length * 0.35, 0, 0)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
      canvas.restore();
    }

    petal(-62, const Color(0xFFF8BBD0), 52, 16);
    petal(62, const Color(0xFFF8BBD0), 52, 16);
    petal(-32, const Color(0xFFF48FB1), 62, 15);
    petal(32, const Color(0xFFF48FB1), 62, 15);
    petal(0, const Color(0xFFE85D75), 70, 13);
    canvas.drawCircle(const Offset(50, 72), 5, Paint()..color = const Color(0xFFFFD54F));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LotusPainter old) => old.phase != phase;
}
