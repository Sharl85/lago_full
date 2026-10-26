import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/calculator.dart';
import '../core/content_extra.dart';
import '../core/life_mode.dart';
import '../core/models.dart';
import '../core/prediction.dart';
import '../core/utils.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/cycle_dial.dart';
import 'explore_screen.dart';
import 'health_reminders_screen.dart';
import 'life_mode_screen.dart';
import 'monthly_report_screen.dart';
import 'stats_screen.dart';
import '../l10n/l10n.dart';

/// Tableau de bord : cadran du cycle, aperçu, conseil du jour.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final d = state.cycle;
        // v5 — modes de vie : grossesse et post-partum remplacent le cadran du cycle
        final s = state.effective;
        final preg = s.isPregnant ? PregnancyInfo.fromIso(s.pregnancyStartDate) : null;
        final cycleView = s.tracksPeriods || (s.isPregnant && preg == null);
        return RefreshIndicator(
          color: LagoColors.pink,
          onRefresh: () => state.syncNow(pull: true),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
            children: [
              if (preg != null) PregnancyCard(info: preg),
              if (s.lifeMode == 'postpartum') LifeStageCard(settings: s),
              if (cycleView) ...[
                _heroCard(context, d),
                const SizedBox(height: 14),
                _predictionCard(context, state),
              ],
              if (s.lifeMode == 'perimenopause') ...[const SizedBox(height: 14), LifeStageCard(settings: s)],
              if (state.healthSignals.isNotEmpty) ...[const SizedBox(height: 14), _signalsCard(context, state.healthSignals)],
              if (s.ramadanMode) ...[const SizedBox(height: 14), _ramadanCard(context)],
              if (cycleView) ...[
                const SizedBox(height: 14),
                _statsCard(context, d),
              ],
              const SizedBox(height: 14),
              _wisdomCard(context, d),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: _shortcut(context, Icons.insights, 'Statistiques',
                      () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StatsScreen()))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _shortcut(context, Icons.medication_outlined, 'Pilule & RDV',
                      () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HealthRemindersScreen()))),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: _shortcut(context, Icons.calendar_view_month, 'Bilan du mois',
                      () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MonthlyReportScreen()))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _shortcut(context, Icons.apps, 'Plus de LaGo',
                      () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExploreScreen()))),
                ),
              ]),
              const SizedBox(height: 16),
              T(
                'Les prévisions sont données à titre indicatif et ne remplacent pas un avis médical. '
                'LaGo n’est pas une méthode de contraception.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: mutedColor(context)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _shortcut(BuildContext context, IconData icon, String label, VoidCallback onTap) => GlassCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: LagoColors.pink),
              const SizedBox(width: 8),
              Flexible(child: T(label, style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
            ]),
          ),
        ),
      );

  Widget _heroCard(BuildContext context, CycleData d) {
    final dark = isDark(context);
    final n = d.daysUntilNextPeriod;
    final countdown = d.isLate
        ? 'Règles en retard de ${d.daysLate} jour${d.daysLate > 1 ? 's' : ''} (attendues le ${Dates.long(d.expectedPeriodStart)}). Notez-les dans le journal dès leur arrivée.'
        : n == 0
        ? "Vos règles sont prévues aujourd'hui. Prenez soin de vous !"
        : n > 0
            ? 'Prochaines règles estimées dans $n jour${n > 1 ? 's' : ''} (${Dates.long(d.nextPeriodStart)}).'
            : 'Cycle en cours. Prochaines règles : ${Dates.long(d.nextPeriodStart)}.';
    final width = MediaQuery.of(context).size.width;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      gradient: LinearGradient(
        colors: dark
            ? [const Color(0xF22B1B27), const Color(0xD9412234)]
            : [Colors.white.withValues(alpha: 0.92), const Color(0xCCFEEBF1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.monitor_heart_outlined, size: 16, color: LagoColors.pink),
                const SizedBox(width: 6),
                T('STATUT DU CYCLE',
                    style: TextStyle(fontSize: 12, letterSpacing: 1, fontWeight: FontWeight.w600, color: mutedColor(context))),
              ]),
              PhaseBadge(d.phase),
            ],
          ),
          const SizedBox(height: 14),
          CycleDial(data: d, size: width < 380 ? 230 : 260),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: LagoColors.pink.withValues(alpha: 0.5)),
            ),
            child: Row(children: [
              Icon(n == 0 ? Icons.auto_awesome : Icons.schedule, color: LagoColors.pink, size: 18),
              const SizedBox(width: 10),
              Expanded(child: T(countdown, style: const TextStyle(fontSize: 14.5))),
            ]),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ v5
  /// Fourchette des prochaines règles, ovulation confirmée, contraception.
  Widget _predictionCard(BuildContext context, AppState state) {
    final w = state.periodWindow;
    final sign = state.ovulationSign;
    final hormonal = Contraception.isHormonal(state.effective.contraception);
    final conf = switch (w?.confidence) { 'high' => 'fiabilité élevée', 'medium' => 'fiabilité moyenne', _ => 'à affiner avec votre journal' };
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (w != null)
          Row(children: [
            const Icon(Icons.date_range, color: LagoColors.pink, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                T('Prochaines règles probables : ${w.label}', style: const TextStyle(fontWeight: FontWeight.w700)),
                T('Fourchette de ±${w.spread} j · $conf', style: TextStyle(fontSize: 12, color: mutedColor(context))),
              ]),
            ),
          ]),
        if (sign != null && !hormonal) ...[
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.verified_outlined, color: LagoColors.purple, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: T('Ovulation confirmée le ${Dates.long(sign.date)} (${sign.methodLabel}). Prévisions recalculées.',
                  style: const TextStyle(fontSize: 13.5)),
            ),
          ]),
        ],
        if (hormonal) ...[
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.shield_outlined, color: LagoColors.teal, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: T('Contraception hormonale : la fenêtre fertile affichée ne s’applique pas à vous.',
                  style: TextStyle(fontSize: 13, color: mutedColor(context))),
            ),
          ]),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LifeModeScreen())),
            child: const T('Mode de vie & contraception'),
          ),
        ),
      ]),
    );
  }

  Widget _signalsCard(BuildContext context, List<HealthSignal> signals) {
    return GlassCard(
      borderColor: LagoColors.orange.withValues(alpha: 0.5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('À surveiller', icon: Icons.health_and_safety_outlined, iconColor: LagoColors.orange,
            subtitle: 'Repères calculés d’après votre journal. LaGo ne pose pas de diagnostic.'),
        for (final sig in signals)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(sig.isConsult ? Icons.medical_services_outlined : Icons.info_outline,
                  size: 18, color: sig.isConsult ? LagoColors.orange : LagoColors.teal),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  T(sig.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  T(sig.message, style: const TextStyle(fontSize: 13, height: 1.35)),
                ]),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _ramadanCard(BuildContext context) {
    final g = ExtraContent.guide('ramadan');
    return GlassCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: const Text('🌙', style: TextStyle(fontSize: 26)),
        title: const T('Mode Ramadan', style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: T(g.points.first, style: const TextStyle(fontSize: 12.5)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GuideScreen(guide: g))),
      ),
    );
  }

  Widget _statsCard(BuildContext context, CycleData d) {
    final items = [
      _Stat(Icons.water_drop_outlined, LagoColors.pink, 'Prochaines règles', Dates.short(d.nextPeriodStart), 'Début estimé'),
      _Stat(Icons.auto_awesome, LagoColors.purple, 'Ovulation', Dates.short(d.ovulationDate), "Jour d'ovulation"),
      _Stat(Icons.spa_outlined, LagoColors.teal, 'Fertilité', d.pregnancyChance, 'Probabilité de conception'),
      _Stat(Icons.nightlight_outlined, LagoColors.gold, 'Phase actuelle', d.phase.name, d.phase.summary),
    ];
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Aperçu de votre cycle', icon: Icons.auto_awesome),
          LayoutBuilder(builder: (context, c) {
            final w = (c.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: items.map((s) => SizedBox(width: w, child: _statTile(context, s))).toList(),
            );
          }),
        ],
      ),
    );
  }

  Widget _statTile(BuildContext context, _Stat s) {
    return Container(
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(minHeight: 118),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark(context) ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        border: Border.all(color: LagoColors.pinkSoft.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: s.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(s.icon, size: 15, color: s.color),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: T(s.title.toUpperCase(),
                  style: TextStyle(fontSize: 10.5, letterSpacing: 0.5, fontWeight: FontWeight.w600, color: mutedColor(context))),
            ),
          ]),
          const SizedBox(height: 8),
          T(s.value, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          T(s.sub, style: TextStyle(fontSize: 11.5, color: mutedColor(context))),
        ],
      ),
    );
  }

  Widget _wisdomCard(BuildContext context, CycleData d) {
    final w = d.wisdom;
    return GlassCard(
      gradient: LinearGradient(
        colors: isDark(context)
            ? [const Color(0xFF3A2A1F), const Color(0xFF2B1B27)]
            : [const Color(0xFFFFFBEB), const Color(0xFFFFF3F5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: LagoColors.gold.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.eco_outlined, color: LagoColors.gold, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: T(w.title,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: LagoColors.gold, fontSize: 15)),
            ),
          ]),
          const SizedBox(height: 10),
          T('« ${w.advice} »',
              style: const TextStyle(fontFamily: LagoTheme.serif, fontStyle: FontStyle.italic, fontSize: 18, height: 1.35)),
          const SizedBox(height: 12),
          _line(Icons.apple, LagoColors.green, 'Nutrition', w.nutrition),
          const SizedBox(height: 8),
          _line(Icons.bolt, LagoColors.pink, 'Mouvement', w.sport),
          const SizedBox(height: 8),
          _line(Icons.battery_charging_full, LagoColors.purple, 'Énergie', '${w.energy} — ${w.hormones}'),
        ],
      ),
    );
  }

  Widget _line(IconData icon, Color color, String label, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: tr('$label : '), style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: tr(text)),
            ]), style: const TextStyle(fontSize: 13.5, height: 1.4)),
          ),
        ],
      );
}

class _Stat {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String sub;
  const _Stat(this.icon, this.color, this.title, this.value, this.sub);
}
