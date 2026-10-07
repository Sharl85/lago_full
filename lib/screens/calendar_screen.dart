import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/calculator.dart';
import '../core/models.dart';
import '../core/utils.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'journal_sheet.dart';
import '../l10n/l10n.dart';

/// Calendrier menstruel interactif + journal (toucher un jour pour le noter).
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  void _shift(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta, 1));

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final s = state.effective; // prévisions ajustées avec le journal
        final cycles = CycleCalculator.forecast(s.lastPeriodDate, s.cycleLength, s.periodDuration, count: 24);
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: T(Dates.capitalize(Dates.monthYear(_month)), style: Theme.of(context).textTheme.headlineSmall),
                    ),
                    IconButton.outlined(tooltip: tr('Mois précédent'), onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
                    const SizedBox(width: 4),
                    IconButton.outlined(
                      tooltip: tr("Aujourd'hui"),
                      onPressed: () => setState(() => _month = DateTime(DateTime.now().year, DateTime.now().month, 1)),
                      icon: const Icon(Icons.today),
                    ),
                    const SizedBox(width: 4),
                    IconButton.outlined(tooltip: tr('Mois suivant'), onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
                  ]),
                  T('Touchez un jour pour noter ou voir vos symptômes et émotions.',
                      style: TextStyle(fontSize: 12.5, color: mutedColor(context))),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onHorizontalDragEnd: (d) {
                      final v = d.primaryVelocity ?? 0;
                      if (v.abs() > 250) _shift(v < 0 ? 1 : -1);
                    },
                    child: _grid(context, cycles, state.logs),
                  ),
                  const SizedBox(height: 16),
                  const _Legend(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _grid(BuildContext context, List<ForecastCycle> cycles, Map<String, DayLog> logs) {
    final first = _month;
    final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
    final leading = first.weekday - 1; // lundi = 0
    final todayIso = Dates.toIso(DateTime.now());
    final cells = <Widget>[
      for (final w in Dates.weekdaysShort)
        Center(child: T(w, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: mutedColor(context)))),
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++)
        _DayCell(
          date: DateTime(first.year, first.month, day),
          type: CycleCalculator.dayType(DateTime(first.year, first.month, day), cycles),
          log: logs[Dates.toIso(DateTime(first.year, first.month, day))],
          isToday: Dates.toIso(DateTime(first.year, first.month, day)) == todayIso,
        ),
    ];
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 5,
      crossAxisSpacing: 5,
      childAspectRatio: 0.82,
      children: cells,
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final DayType type;
  final DayLog? log;
  final bool isToday;
  const _DayCell({required this.date, required this.type, required this.log, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    var effective = type;
    if (log != null && log!.hasPeriodFlow) effective = DayType.period;

    Color bg = dark ? Colors.white.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.7);
    Color border = LagoColors.pinkSoft.withValues(alpha: 0.2);
    var dashed = false;
    switch (effective) {
      case DayType.period:
        bg = const Color(0xFFFFCDD2);
        border = const Color(0xFFEF9A9A);
      case DayType.periodPredicted:
        bg = const Color(0x99FFEBEE);
        border = const Color(0xFFE57373);
        dashed = true;
      case DayType.fertile:
        bg = const Color(0xFFE0F2F1);
        border = const Color(0xFF80CBC4);
      case DayType.ovulation:
        bg = const Color(0xFFF3E5F5);
        border = LagoColors.purple;
      case DayType.normal:
        break;
    }
    final coloredBg = effective != DayType.normal;
    final textColor = coloredBg ? LagoColors.textDark : null;

    return Semantics(
      button: true,
      label: '${Dates.long(date)}${log != null ? tr(', journal rempli') : ''}',
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isToday ? LagoColors.pink : border,
            width: isToday ? 2 : (dashed ? 1.2 : 1),
            style: BorderStyle.solid,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => showJournalSheet(context, Dates.toIso(date)),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                T('${date.day}',
                    style: TextStyle(fontWeight: isToday ? FontWeight.w800 : FontWeight.w600, fontSize: 13, color: textColor)),
                if (log != null)
                  FittedBox(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (log!.flow != 'none') const _Dot(Color(0xFFE53935)),
                      if (log!.symptoms.isNotEmpty) const _Dot(LagoColors.gold),
                      T(Mood.of(log!.mood).emoji, style: const TextStyle(fontSize: 11)),
                    ]),
                  )
                else
                  const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot(this.color);
  @override
  Widget build(BuildContext context) => Container(
        width: 6,
        height: 6,
        margin: const EdgeInsets.only(right: 2),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _Legend extends StatelessWidget {
  const _Legend();
  @override
  Widget build(BuildContext context) {
    Widget item(Color bg, Color border, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 6),
          T(label, style: const TextStyle(fontSize: 12)),
        ]);
    return Wrap(spacing: 14, runSpacing: 8, children: [
      item(const Color(0xFFFFCDD2), const Color(0xFFEF9A9A), 'Règles'),
      item(const Color(0x99FFEBEE), const Color(0xFFE57373), 'Règles prévues'),
      item(const Color(0xFFE0F2F1), const Color(0xFF80CBC4), 'Période fertile'),
      item(const Color(0xFFF3E5F5), LagoColors.purple, "Jour d'ovulation"),
      item(LagoColors.gold.withValues(alpha: 0.2), LagoColors.gold, 'Journal / symptômes'),
    ]);
  }
}
