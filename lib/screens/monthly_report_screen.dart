import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/monthly_report.dart';
import '../core/utils.dart';
import '../l10n/l10n.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// v5 — Bilan mensuel : règles, cycle, symptômes et humeurs du mois.
class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  final state = AppState.instance;
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // En début de mois, on montre le bilan du mois précédent (le mois en cours vient de commencer)
    _month = now.day <= 3 ? DateTime(now.year, now.month - 1, 1) : DateTime(now.year, now.month, 1);
  }

  void _shift(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta, 1));

  String _shareText(MonthlyReport r) {
    final b = StringBuffer('${tr('Mon bilan LaGo')} — ${Dates.monthYear(r.month)}\n');
    b.writeln(tr('Jours notés : ${r.loggedDays}'));
    for (var i = 0; i < r.periodStarts.length; i++) {
      b.writeln(tr('Règles : début le ${Dates.long(r.periodStarts[i])}, ${r.periodLengths[i]} jours'));
    }
    if (r.cycleLength != null) b.writeln(tr('Durée du cycle : ${r.cycleLength} jours'));
    if (r.topSymptoms.isNotEmpty) {
      b.writeln('${tr('Symptômes fréquents :')} ${r.topSymptoms.map((e) => tr(Symptom.of(e.key).label)).join(', ')}');
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final r = MonthlyReport.compute(state.logs, _month);
        final now = DateTime.now();
        final isCurrent = _month.year == now.year && _month.month == now.month;
        return Scaffold(
          appBar: AppBar(
            title: const T('Bilan du mois'),
            actions: [
              IconButton(
                tooltip: tr('Partager'),
                icon: const Icon(Icons.share_outlined),
                onPressed: r.isEmpty ? null : () => Share.share(_shareText(r), subject: tr('Mon bilan LaGo')),
              ),
            ],
          ),
          body: LagoBackground(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
              children: [
                Row(children: [
                  IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
                  Expanded(
                    child: T(Dates.capitalize(Dates.monthYear(_month)),
                        textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                  ),
                  IconButton(onPressed: isCurrent ? null : () => _shift(1), icon: const Icon(Icons.chevron_right)),
                ]),
                const SizedBox(height: 10),
                GlassCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _row(Icons.edit_calendar, LagoColors.pink, 'Jours notés', '${r.loggedDays}'),
                    if (r.periodStarts.isEmpty)
                      _row(Icons.water_drop_outlined, LagoColors.pink, 'Règles', 'Aucune notée ce mois-ci')
                    else
                      for (var i = 0; i < r.periodStarts.length; i++)
                        _row(Icons.water_drop, LagoColors.pink, 'Règles', '${Dates.short(r.periodStarts[i])} · ${r.periodLengths[i]} j'),
                    if (r.cycleLength != null) _row(Icons.loop, LagoColors.purple, 'Durée du cycle', '${r.cycleLength} jours'),
                    if (r.averageTemperature != null)
                      _row(Icons.thermostat, LagoColors.orange, 'Température moyenne', '${r.averageTemperature!.toStringAsFixed(2)} °C'),
                    if (r.spottingDays > 0) _row(Icons.opacity, LagoColors.danger, 'Jours de spotting', '${r.spottingDays}'),
                  ]),
                ),
                const SizedBox(height: 14),
                if (r.topSymptoms.isNotEmpty || r.topMoods.isNotEmpty)
                  GlassCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (r.topSymptoms.isNotEmpty) ...[
                        const SectionTitle('Symptômes les plus fréquents', icon: Icons.favorite_border),
                        for (final e in r.topSymptoms)
                          _row(Symptom.of(e.key).icon, LagoColors.pink, Symptom.of(e.key).label, '${e.value} j'),
                      ],
                      if (r.topMoods.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const SectionTitle('Humeurs les plus fréquentes', icon: Icons.sentiment_satisfied_alt_outlined),
                        for (final e in r.topMoods)
                          _row(Mood.of(e.key).icon, LagoColors.purple, '${Mood.of(e.key).emoji} ${tr(Mood.of(e.key).label)}', '${e.value} j'),
                      ],
                    ]),
                  ),
                const SizedBox(height: 14),
                GlassCard(
                  borderColor: LagoColors.gold.withValues(alpha: 0.4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.lightbulb_outline, color: LagoColors.gold),
                    const SizedBox(width: 10),
                    Expanded(child: T(r.advice, style: const TextStyle(fontSize: 14, height: 1.4))),
                  ]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _row(IconData icon, Color color, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: T(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          T(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );
}
