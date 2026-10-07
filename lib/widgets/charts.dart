import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'common.dart';
import '../l10n/l10n.dart';

/// Graphiques LaGo dessinés sans bibliothèque externe (légers et toujours compatibles).

/// Barres verticales : une barre par cycle mesuré, ligne pointillée = moyenne.
class CycleBarsChart extends StatelessWidget {
  final List<int> values; // durées des cycles, du plus ancien au plus récent
  final double height;
  const CycleBarsChart({super.key, required this.values, this.height = 170});

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const _EmptyChart('Notez au moins deux débuts de règles pour voir vos cycles.');
    final shown = values.length > 12 ? values.sublist(values.length - 12) : values;
    return Semantics(
      label: tr('Durées des cycles : ${shown.join(', ')} jours'),
      child: SizedBox(
        height: height,
        child: CustomPaint(
          size: Size.infinite,
          painter: _BarsPainter(shown, isDark(context), Directionality.of(context) == TextDirection.rtl),
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  final List<int> v;
  final bool dark;
  final bool rtl;
  _BarsPainter(this.v, this.dark, this.rtl);

  @override
  void paint(Canvas canvas, Size size) {
    final textColor = dark ? const Color(0xFFE8D5E0) : LagoColors.textDark;
    const top = 18.0, bottom = 22.0;
    final maxV = math.max(v.reduce(math.max), 35).toDouble();
    final minV = math.max(0, v.reduce(math.min) - 6).toDouble();
    final h = size.height - top - bottom;
    final n = v.length;
    final slot = size.width / n;
    final barW = math.min(slot * 0.6, 34.0);
    double y(num value) => top + h - (value - minV) / (maxV - minV) * h;

    // Zone « habituelle » 21 à 35 jours
    final band = Paint()..color = LagoColors.green.withValues(alpha: dark ? 0.10 : 0.08);
    canvas.drawRect(Rect.fromLTRB(0, y(35), size.width, y(21)), band);

    final avg = v.reduce((a, b) => a + b) / n;
    for (var i = 0; i < n; i++) {
      final idx = rtl ? n - 1 - i : i;
      final cx = slot * i + slot / 2;
      final value = v[idx];
      final irregular = value < 21 || value > 35;
      final paint = Paint()..color = irregular ? LagoColors.orange : LagoColors.pink;
      final r = RRect.fromRectAndCorners(Rect.fromLTRB(cx - barW / 2, y(value), cx + barW / 2, top + h),
          topLeft: const Radius.circular(6), topRight: const Radius.circular(6));
      canvas.drawRRect(r, paint);
      _text(canvas, '$value', Offset(cx, y(value) - 15), textColor, 11, bold: true);
      _text(canvas, '${idx + 1}', Offset(cx, size.height - 16), textColor.withValues(alpha: 0.7), 10);
    }
    // Moyenne
    final dash = Paint()
      ..color = LagoColors.purple
      ..strokeWidth = 1.5;
    final ay = y(avg);
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, ay), Offset(math.min(x + 4, size.width), ay), dash);
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) => old.v != v || old.dark != dark;
}

/// Barres horizontales : fréquence de chaque élément (symptômes, humeurs).
class FrequencyBars extends StatelessWidget {
  final List<MapEntry<String, int>> items; // libellé (français) → nombre de jours
  final int max;
  const FrequencyBars({super.key, required this.items, this.max = 6});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyChart('Aucun symptôme noté pour le moment.');
    final shown = items.take(max).toList();
    final top = shown.first.value;
    return Column(children: [
      for (final e in shown)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(width: 120, child: T(e.key, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis)),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: top == 0 ? 0 : e.value / top,
                  minHeight: 12,
                  color: LagoColors.pink,
                  backgroundColor: LagoColors.pinkSoft.withValues(alpha: 0.2),
                ),
              ),
            ),
            SizedBox(width: 44, child: T('${e.value} j', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
          ]),
        ),
    ]);
  }
}

/// Courbe de température basale (60 derniers relevés).
class TemperatureChart extends StatelessWidget {
  final List<MapEntry<DateTime, double>> points;
  final double height;
  const TemperatureChart({super.key, required this.points, this.height = 170});

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const _EmptyChart('Notez votre température au réveil pendant quelques jours pour voir la courbe.');
    final shown = points.length > 60 ? points.sublist(points.length - 60) : points;
    return SizedBox(
      height: height,
      child: CustomPaint(size: Size.infinite, painter: _TempPainter(shown, isDark(context))),
    );
  }
}

class _TempPainter extends CustomPainter {
  final List<MapEntry<DateTime, double>> p;
  final bool dark;
  _TempPainter(this.p, this.dark);

  @override
  void paint(Canvas canvas, Size size) {
    final textColor = dark ? const Color(0xFFE8D5E0) : LagoColors.textDark;
    const left = 34.0, top = 10.0, bottom = 20.0;
    final temps = p.map((e) => e.value).toList();
    var lo = temps.reduce(math.min) - 0.2, hi = temps.reduce(math.max) + 0.2;
    if (hi - lo < 0.8) {
      final mid = (hi + lo) / 2;
      lo = mid - 0.4;
      hi = mid + 0.4;
    }
    final first = p.first.key, last = p.last.key;
    final span = math.max(1, last.difference(first).inDays);
    final w = size.width - left, h = size.height - top - bottom;
    Offset pt(MapEntry<DateTime, double> e) =>
        Offset(left + e.key.difference(first).inDays / span * w, top + h - (e.value - lo) / (hi - lo) * h);

    final grid = Paint()
      ..color = textColor.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final v = lo + (hi - lo) * i / 3;
      final yy = top + h - h * i / 3;
      canvas.drawLine(Offset(left, yy), Offset(size.width, yy), grid);
      _text(canvas, v.toStringAsFixed(1), Offset(left / 2, yy - 7), textColor.withValues(alpha: 0.7), 9.5);
    }
    final path = Path()..moveTo(pt(p.first).dx, pt(p.first).dy);
    for (final e in p.skip(1)) {
      path.lineTo(pt(e).dx, pt(e).dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = LagoColors.pink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round);
    final dot = Paint()..color = LagoColors.pink;
    for (final e in p) {
      canvas.drawCircle(pt(e), 2.8, dot);
    }
    _text(canvas, '${first.day}/${first.month}', Offset(left + 12, size.height - 14), textColor.withValues(alpha: 0.7), 9.5);
    _text(canvas, '${last.day}/${last.month}', Offset(size.width - 14, size.height - 14), textColor.withValues(alpha: 0.7), 9.5);
  }

  @override
  bool shouldRepaint(covariant _TempPainter old) => old.p != p || old.dark != dark;
}

void _text(Canvas canvas, String s, Offset center, Color color, double size, {bool bold = false}) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: TextStyle(color: color, fontSize: size, fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy));
}

class _EmptyChart extends StatelessWidget {
  final String message;
  const _EmptyChart(this.message);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: T(message, textAlign: TextAlign.center, style: TextStyle(color: mutedColor(context), fontSize: 13)),
      );
}
