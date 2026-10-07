import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Pluie de pétales de lotus en arrière-plan (désactivable dans l'app).
class PetalsOverlay extends StatefulWidget {
  final bool enabled;
  const PetalsOverlay({super.key, required this.enabled});

  @override
  State<PetalsOverlay> createState() => _PetalsOverlayState();
}

class _Petal {
  double x, y, size, speedY, speedX, rotation, rotationSpeed, opacity;
  _Petal(this.x, this.y, this.size, this.speedY, this.speedX, this.rotation, this.rotationSpeed, this.opacity);
}

class _PetalsOverlayState extends State<PetalsOverlay> with SingleTickerProviderStateMixin {
  final _rnd = math.Random();
  final List<_Petal> _petals = [];
  late final Ticker _ticker;
  Size _size = Size.zero;
  final _repaint = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    if (widget.enabled) _ticker.start();
  }

  @override
  void didUpdateWidget(covariant PetalsOverlay old) {
    super.didUpdateWidget(old);
    if (widget.enabled && !_ticker.isActive) _ticker.start();
    if (!widget.enabled && _ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  _Petal _newPetal({bool top = false}) => _Petal(
        _rnd.nextDouble() * _size.width,
        top ? -20 : -_rnd.nextDouble() * _size.height,
        8 + _rnd.nextDouble() * 12,
        0.5 + _rnd.nextDouble() * 1.0,
        -0.4 + _rnd.nextDouble() * 0.8,
        _rnd.nextDouble() * math.pi * 2,
        (_rnd.nextDouble() - 0.5) * 0.02,
        0.3 + _rnd.nextDouble() * 0.4,
      );

  void _tick(Duration _) {
    if (_size == Size.zero) return;
    final count = _size.width < 600 ? 14 : 24;
    while (_petals.length < count) {
      _petals.add(_newPetal());
    }
    for (var i = 0; i < _petals.length; i++) {
      final p = _petals[i];
      p.y += p.speedY;
      p.x += math.sin(p.y * 0.005) * 0.6 + p.speedX;
      p.rotation += p.rotationSpeed;
      if (p.y > _size.height + 20 || p.x < -30 || p.x > _size.width + 30) _petals[i] = _newPetal(top: true);
    }
    _repaint.value++;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || MediaQuery.of(context).disableAnimations) return const SizedBox.shrink();
    return IgnorePointer(
      child: LayoutBuilder(builder: (context, c) {
        _size = Size(c.maxWidth, c.maxHeight);
        return RepaintBoundary(child: CustomPaint(size: _size, painter: _PetalPainter(_petals, _repaint)));
      }),
    );
  }
}

class _PetalPainter extends CustomPainter {
  final List<_Petal> petals;
  _PetalPainter(this.petals, Listenable repaint) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in petals) {
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);
      final rect = Rect.fromCircle(center: Offset.zero, radius: p.size);
      final paint = Paint()
        ..shader = RadialGradient(colors: [
          Colors.white.withValues(alpha: p.opacity),
          const Color(0xFFF8BBD0).withValues(alpha: p.opacity),
          const Color(0xFFF48FB1).withValues(alpha: p.opacity),
        ], stops: const [0, 0.4, 1]).createShader(rect);
      final s = p.size;
      final path = Path()
        ..moveTo(0, -s)
        ..quadraticBezierTo(s * 0.6, -s * 0.3, s * 0.5, s * 0.5)
        ..quadraticBezierTo(0, s, 0, s)
        ..quadraticBezierTo(-s * 0.5, s * 0.5, -s * 0.6, -s * 0.3)
        ..close();
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PetalPainter oldDelegate) => false;
}
