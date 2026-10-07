import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/calculator.dart';
import '../core/content.dart';
import '../core/utils.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../l10n/l10n.dart';

/// Les 4 phases du cycle expliquées simplement, avec VOS jours personnels.
class PhasesScreen extends StatelessWidget {
  const PhasesScreen({super.key});

  static PhaseKey _key(String k) => PhaseKey.values.firstWhere((e) => e.name == k);

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final s = state.effective; // durées apprises du journal si disponibles
        final ranges = PhaseRanges.compute(s.cycleLength, s.periodDuration);
        final current = state.cycle.phase.key;
        final forecast = CycleCalculator.forecast(s.lastPeriodDate, s.cycleLength, s.periodDuration, count: 6, fromToday: true);
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
          children: [
            const SectionTitle('Comprendre mon cycle', icon: Icons.donut_large,
                subtitle: 'Ce qui se passe dans votre corps, phase par phase.'),
            GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const T('C’est quoi, le cycle menstruel ?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                for (final p in LagoContent.cycleIntro)
                  Padding(padding: const EdgeInsets.only(bottom: 8), child: T(p, style: const TextStyle(fontSize: 13.5, height: 1.45))),
              ]),
            ),
            const SizedBox(height: 14),
            GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                T('Votre cycle de ${s.cycleLength} jours', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                T('Vous êtes au jour ${state.cycle.currentCycleDay} : ${state.cycle.phase.name}.',
                    style: TextStyle(fontSize: 13, color: mutedColor(context))),
                const SizedBox(height: 14),
                _Timeline(ranges: ranges, cycleLength: s.cycleLength, today: state.cycle.currentCycleDay),
                const SizedBox(height: 10),
                for (final r in ranges.list)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(children: [
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: CycleCalculator.phases[r.key]!.color, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(child: T(CycleCalculator.phases[r.key]!.name, style: const TextStyle(fontSize: 13))),
                      T(r.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: 14),
            for (final pc in LagoContent.phases) ...[
              _PhaseCard(content: pc, range: ranges.of(_key(pc.key)), current: current == _key(pc.key)),
              const SizedBox(height: 12),
            ],
            const LotusDivider(),
            const SectionTitle('Petit lexique', icon: Icons.menu_book_outlined),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: Column(children: [
                  for (final g in LagoContent.glossary)
                    ExpansionTile(
                      shape: const Border(),
                      title: T(g[0], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      expandedAlignment: Alignment.centerLeft,
                      children: [T(g[1], style: const TextStyle(fontSize: 13.5))],
                    ),
                ]),
              ),
            ),
            const LotusDivider(),
            const SectionTitle('Prévisions des 6 prochains cycles', icon: Icons.date_range),
            for (final c in forecast) ...[_forecastCard(context, c), const SizedBox(height: 10)],
          ],
        );
      },
    );
  }

  Widget _forecastCard(BuildContext context, ForecastCycle c) {
    Widget line(IconData icon, Color color, String label, String value) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            T('$label : ', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            Expanded(child: T(value, style: const TextStyle(fontSize: 13.5))),
          ]),
        );
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.local_florist, color: LagoColors.pink, size: 18),
          const SizedBox(width: 6),
          T('Cycle n°${c.index}',
              style: const TextStyle(fontFamily: LagoTheme.serif, fontSize: 19, fontWeight: FontWeight.w700, color: LagoColors.pink)),
          const Spacer(),
          T(Dates.capitalize(Dates.monthYear(c.periodStart)), style: TextStyle(fontSize: 12, color: mutedColor(context))),
        ]),
        line(Icons.water_drop_outlined, LagoColors.pink, 'Règles', '${Dates.short(c.periodStart)} – ${Dates.short(c.periodEnd)}'),
        line(Icons.spa_outlined, LagoColors.teal, 'Fenêtre fertile', '${Dates.short(c.fertileStart)} – ${Dates.short(c.fertileEnd)}'),
        line(Icons.auto_awesome, LagoColors.purple, 'Ovulation', Dates.short(c.ovulationDate)),
      ]),
    );
  }
}

/// Jours de chaque phase pour un cycle donné (numéros de jour du cycle).
class PhaseRange {
  final PhaseKey key;
  final int start;
  final int end;
  const PhaseRange(this.key, this.start, this.end);
  int get length => end >= start ? end - start + 1 : 0;
  String get label => length == 0 ? 'très courte' : (start == end ? 'jour $start' : 'jours $start à $end');
}

class PhaseRanges {
  final List<PhaseRange> list;
  const PhaseRanges(this.list);

  static PhaseRanges compute(int cycleLength, int periodDuration) {
    // Mêmes bornes que CycleCalculator (évite un clamp(min > max) qui lève une ArgumentError)
    cycleLength = cycleLength.clamp(15, 60).toInt();
    periodDuration = periodDuration.clamp(1, cycleLength - 1).toInt();
    final ovDay = CycleCalculator.ovulationOffset(cycleLength, periodDuration) + 1;
    final fertileStart = (ovDay - 5).clamp(periodDuration + 1, cycleLength).toInt();
    final fertileEnd = (ovDay + 1).clamp(fertileStart, cycleLength).toInt();
    return PhaseRanges([
      PhaseRange(PhaseKey.menstrual, 1, periodDuration),
      PhaseRange(PhaseKey.follicular, periodDuration + 1, fertileStart - 1),
      PhaseRange(PhaseKey.ovulation, fertileStart, fertileEnd),
      PhaseRange(PhaseKey.luteal, fertileEnd + 1, cycleLength),
    ]);
  }

  PhaseRange of(PhaseKey k) => list.firstWhere((r) => r.key == k);
}

class _Timeline extends StatelessWidget {
  final PhaseRanges ranges;
  final int cycleLength;
  final int today;
  const _Timeline({required this.ranges, required this.cycleLength, required this.today});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final marker = ((today - 0.5) / cycleLength * w).clamp(0.0, w);
      return SizedBox(
        height: 46,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Row(children: [
                for (final r in ranges.list)
                  if (r.length > 0)
                    Expanded(
                      flex: r.length,
                      child: Container(height: 16, color: CycleCalculator.phases[r.key]!.color.withValues(alpha: 0.85)),
                    ),
              ]),
            ),
          ),
          Positioned(
            left: marker - 14,
            top: 0,
            child: const Column(children: [
              T('vous', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: LagoColors.pink)),
              Icon(Icons.arrow_drop_down, color: LagoColors.pink, size: 18),
            ]),
          ),
          Positioned(left: 0, bottom: 0, child: T('J1', style: TextStyle(fontSize: 10, color: mutedColor(context)))),
          Positioned(right: 0, bottom: 0, child: T('J$cycleLength', style: TextStyle(fontSize: 10, color: mutedColor(context)))),
        ]),
      );
    });
  }
}

class _PhaseCard extends StatelessWidget {
  final PhaseContent content;
  final PhaseRange range;
  final bool current;
  const _PhaseCard({required this.content, required this.range, required this.current});

  @override
  Widget build(BuildContext context) {
    final phase = CycleCalculator.phases[range.key]!;
    final dark = isDark(context);
    return GlassCard(
      padding: EdgeInsets.zero,
      borderColor: phase.color.withValues(alpha: current ? 0.9 : 0.35),
      gradient: LinearGradient(
        colors: dark ? [phase.color.withValues(alpha: 0.18), LagoColors.cardDark] : [phase.background, Colors.white.withValues(alpha: 0.92)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: current,
          shape: const Border(),
          tilePadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          leading: T(content.emoji, style: const TextStyle(fontSize: 26)),
          title: T(content.title, style: const TextStyle(fontFamily: LagoTheme.serif, fontSize: 21, fontWeight: FontWeight.w700)),
          subtitle: T('${content.season} · pour vous : ${range.label}${current ? ' · EN COURS' : ''}',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color.lerp(phase.color, Colors.black, 0.3))),
          children: [
            _section(Icons.schedule, 'Quand ?', content.when),
            _section(Icons.biotech_outlined, 'Ce qui se passe dans votre corps', content.body),
            _section(Icons.science_outlined, 'Les hormones', content.hormones),
            _list(Icons.sentiment_satisfied_alt_outlined, 'Ce que vous pouvez ressentir', content.feel, phase.color),
            _list(Icons.tips_and_updates_outlined, 'Nos conseils', content.tips, phase.color),
            _section(Icons.spa_outlined, 'Fertilité', content.fertility),
            _section(Icons.local_hospital_outlined, 'Quand consulter ?', content.consult),
          ],
        ),
      ),
    );
  }

  Widget _title(IconData icon, String t) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Row(children: [
          Icon(icon, size: 17, color: LagoColors.pink),
          const SizedBox(width: 6),
          Expanded(child: T(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
        ]),
      );

  Widget _section(IconData icon, String t, String body) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title(icon, t),
        T(body, style: const TextStyle(fontSize: 13.5, height: 1.45)),
      ]);

  Widget _list(IconData icon, String t, List<String> items, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title(icon, t),
        for (final i in items)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 6, color: color)),
              const SizedBox(width: 8),
              Expanded(child: T(i, style: const TextStyle(fontSize: 13.5, height: 1.4))),
            ]),
          ),
      ]);
}
