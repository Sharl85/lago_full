import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/calculator.dart';
import '../core/insights.dart';
import '../core/models.dart';
import '../core/pdf_report.dart';
import '../core/utils.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../l10n/l10n.dart';

/// Mes statistiques : ce que LaGo a appris du journal + graphiques + rapport PDF.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return Scaffold(
      appBar: AppBar(title: const T('Statistiques & rapport')),
      body: LagoBackground(
        child: ListenableBuilder(
          listenable: state,
          builder: (context, _) => StatsView(
            name: state.user?.name ?? 'LaGo',
            age: state.user?.age,
            settings: state.settings,
            logs: state.logs,
            own: true,
          ),
        ),
      ),
    );
  }
}

/// Vue réutilisée pour l'utilisatrice et pour le suivi parental (sans notes personnelles).
class StatsView extends StatelessWidget {
  final String name;
  final int? age;
  final CycleSettings settings;
  final Map<String, DayLog> logs;
  final bool own;
  final List<Widget> header;
  const StatsView({
    super.key,
    required this.name,
    this.age,
    required this.settings,
    required this.logs,
    this.own = false,
    this.header = const [],
  });

  @override
  Widget build(BuildContext context) {
    final ins = CycleInsights.compute(logs);
    final eff = ins.apply(settings);
    final learnedCycle = ins.learnedCycleLength;
    final learnedPeriod = ins.learnedPeriodLength;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
      children: [
        ...header,
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionTitle('Ce que LaGo a appris', icon: Icons.auto_graph,
                subtitle: 'Calculé à partir des règles notées dans le journal.'),
            _row(context, 'Durée moyenne du cycle',
                learnedCycle != null ? '$learnedCycle jours' : '${settings.cycleLength} jours (déclarée)'),
            _row(context, 'Durée moyenne des règles',
                learnedPeriod != null ? '$learnedPeriod jours' : '${settings.periodDuration} jours (déclarée)'),
            if (ins.shortestCycle != null)
              _row(context, 'Cycle le plus court / le plus long', '${ins.shortestCycle} / ${ins.longestCycle} jours'),
            _row(context, 'Cycles mesurés', '${ins.cycleLengths.length}'),
            _row(context, 'Jours notés', '${ins.loggedDays}'),
            const SizedBox(height: 8),
            if (learnedCycle == null)
              T('Notez le flux de vos règles chaque mois : dès 2 cycles complets, LaGo utilise vos vraies durées pour ses prévisions.',
                  style: TextStyle(fontSize: 12.5, color: mutedColor(context)))
            else if (!settings.learnFromJournal)
              T('Apprentissage désactivé : les prévisions utilisent les durées saisies dans Profil.',
                  style: TextStyle(fontSize: 12.5, color: mutedColor(context)))
            else
              T('Les prévisions utilisent désormais ces durées réelles (cycle de ${eff.cycleLength} jours).',
                  style: const TextStyle(fontSize: 12.5, color: LagoColors.green, fontWeight: FontWeight.w600)),
            if ((ins.variation ?? 0) > 7)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: T(
                    'Vos cycles varient de plus de 7 jours : c’est fréquent les premières années, mais parlez-en à un professionnel de santé si cela persiste.',
                    style: const TextStyle(fontSize: 12.5, color: LagoColors.orange, fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
        const SizedBox(height: 14),
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionTitle('Durée des cycles', icon: Icons.bar_chart,
                subtitle: 'Zone verte : 21 à 35 jours. Pointillés : moyenne.'),
            CycleBarsChart(values: ins.cycleLengths),
          ]),
        ),
        const SizedBox(height: 14),
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionTitle('Symptômes fréquents', icon: Icons.healing_outlined),
            FrequencyBars(items: [for (final e in ins.symptomCounts) MapEntry(Symptom.of(e.key).label, e.value)]),
            const SizedBox(height: 12),
            const T('Humeurs', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            FrequencyBars(items: [for (final e in ins.moodCounts) MapEntry(Mood.of(e.key).label, e.value)], max: 4),
          ]),
        ),
        const SizedBox(height: 14),
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionTitle('Température basale', icon: Icons.thermostat,
                subtitle: 'Une hausse durable d’environ 0,3 °C signale souvent que l’ovulation a eu lieu.'),
            TemperatureChart(points: ins.temperatures),
          ]),
        ),
        const SizedBox(height: 14),
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionTitle('Rapport pour une consultation', icon: Icons.picture_as_pdf_outlined,
                subtitle: 'Un PDF clair à montrer à votre médecin, sage-femme ou gynécologue.'),
            FilledButton.icon(
              onPressed: () => _export(context, includeNotes: false),
              icon: const Icon(Icons.picture_as_pdf),
              label: const T('Créer le PDF'),
            ),
            if (own)
              TextButton.icon(
                onPressed: () => _export(context, includeNotes: true),
                icon: const Icon(Icons.sticky_note_2_outlined),
                label: const T('Créer le PDF avec mes notes personnelles'),
              ),
            if (L.isRtl)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: T('Le rapport PDF est rédigé en français.', style: TextStyle(fontSize: 12, color: mutedColor(context))),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        T('Prochaines règles estimées : ${Dates.long(CycleCalculator.calculate(eff.lastPeriodDate, eff.cycleLength, eff.periodDuration).nextPeriodStart)}',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: mutedColor(context))),
      ],
    );
  }

  Future<void> _export(BuildContext context, {required bool includeNotes}) async {
    try {
      await PdfReport.share(name: name, age: age, settings: settings, logs: logs, includeNotes: includeNotes);
    } catch (e) {
      if (context.mounted) showToast(context, 'Création du PDF impossible.', type: ToastType.error);
    }
  }

  Widget _row(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: T(label, style: TextStyle(color: mutedColor(context)))),
          T(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );
}
