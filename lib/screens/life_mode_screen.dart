import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/life_mode.dart';
import '../core/models.dart';
import '../core/utils.dart';
import '../l10n/l10n.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// v5 — Choix du mode de vie (cycle, grossesse, post-partum, préménopause) et de la contraception.
class LifeModeScreen extends StatefulWidget {
  const LifeModeScreen({super.key});

  @override
  State<LifeModeScreen> createState() => _LifeModeScreenState();
}

class _LifeModeScreenState extends State<LifeModeScreen> {
  final state = AppState.instance;
  late String _mode;
  late String _contraception;
  DateTime? _pregnancyStart;
  DateTime? _birth;
  late bool _ramadan;

  @override
  void initState() {
    super.initState();
    final s = state.settings;
    _mode = s.lifeMode;
    _contraception = s.contraception;
    _pregnancyStart = Dates.parseIso(s.pregnancyStartDate);
    _birth = Dates.parseIso(s.babyBirthDate);
    _ramadan = s.ramadanMode;
  }

  Future<DateTime?> _pick(DateTime? initial, DateTime first, String help) {
    final today = Dates.today();
    var init = initial ?? today;
    if (init.isAfter(today)) init = today;
    if (init.isBefore(first)) init = first;
    return showDatePicker(context: context, initialDate: init, firstDate: first, lastDate: today, helpText: tr(help));
  }

  Future<void> _save() async {
    if (_mode == 'pregnancy' && _pregnancyStart == null) {
      showToast(context, 'Indiquez le 1er jour de vos dernières règles avant la grossesse.', type: ToastType.error);
      return;
    }
    if (_mode == 'postpartum' && _birth == null) {
      showToast(context, 'Indiquez la date de naissance de votre bébé.', type: ToastType.error);
      return;
    }
    await state.updateSettings(state.settings.copyWith(
      lifeMode: _mode,
      contraception: _contraception,
      pregnancyStartDate: _pregnancyStart == null ? '' : Dates.toIso(_pregnancyStart!),
      babyBirthDate: _birth == null ? '' : Dates.toIso(_birth!),
      ramadanMode: _ramadan,
    ));
    await state.rescheduleReminders();
    if (!mounted) return;
    showToast(context, '🌸 Mode enregistré.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final today = Dates.today();
    return Scaffold(
      appBar: AppBar(title: const T('Mon mode de vie')),
      body: LagoBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
          children: [
            GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle('Ce que je veux suivre', icon: Icons.favorite_outline,
                    subtitle: 'LaGo adapte l’accueil, les alertes et les conseils.'),
                for (final m in LifeMode.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setState(() => _mode = m.key),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _mode == m.key ? LagoColors.pink : LagoColors.pinkSoft.withValues(alpha: 0.3), width: _mode == m.key ? 2 : 1),
                        ),
                        child: Row(children: [
                          Text(m.emoji, style: const TextStyle(fontSize: 26)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              T(m.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                              T(m.description, style: TextStyle(fontSize: 12.5, color: mutedColor(context))),
                            ]),
                          ),
                          Icon(_mode == m.key ? Icons.radio_button_checked : Icons.radio_button_off, color: LagoColors.pink),
                        ]),
                      ),
                    ),
                  ),
                if (_mode == 'pregnancy')
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event, color: LagoColors.pink),
                    title: const T('1er jour des dernières règles'),
                    subtitle: T(_pregnancyStart == null ? 'Touchez pour choisir' : Dates.long(_pregnancyStart!),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    onTap: () async {
                      final d = await _pick(_pregnancyStart ?? Dates.parseIso(state.settings.lastPeriodDate),
                          Dates.addDays(today, -300), '1er jour des dernières règles');
                      if (d != null) setState(() => _pregnancyStart = d);
                    },
                  ),
                if (_mode == 'postpartum')
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.child_care, color: LagoColors.pink),
                    title: const T('Date de naissance du bébé'),
                    subtitle: T(_birth == null ? 'Touchez pour choisir' : Dates.long(_birth!), style: const TextStyle(fontWeight: FontWeight.w700)),
                    onTap: () async {
                      final d = await _pick(_birth, Dates.addDays(today, -730), 'Date de naissance du bébé');
                      if (d != null) setState(() => _birth = d);
                    },
                  ),
              ]),
            ),
            const SizedBox(height: 14),
            GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle('Ma contraception', icon: Icons.shield_outlined,
                    subtitle: 'Avec une méthode hormonale, LaGo n’affiche plus de fenêtre fertile.'),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: _contraception,
                  isExpanded: true,
                  items: Contraception.values.map((o) => DropdownMenuItem(value: o.key, child: T('${o.emoji}  ${o.label}'))).toList(),
                  onChanged: (v) => setState(() => _contraception = v ?? 'none'),
                ),
                if (Contraception.isHormonal(_contraception))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: T(
                        'Votre méthode agit sur l’ovulation : les saignements que vous notez sont souvent des « règles de privation », pas un vrai cycle. Les alertes de fertilité sont désactivées.',
                        style: TextStyle(fontSize: 12.5, color: mutedColor(context))),
                  ),
                if (_contraception == 'pill' || _contraception == 'minipill')
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: T('Astuce : activez le rappel de pilule dans « Pilule & rendez-vous ».',
                        style: const TextStyle(fontSize: 12.5, color: LagoColors.pink)),
                  ),
              ]),
            ),
            const SizedBox(height: 14),
            GlassCard(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Text('🌙', style: TextStyle(fontSize: 24)),
                title: const T('Mode Ramadan', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const T('Conseils d’alimentation et d’hydratation adaptés au jeûne.'),
                value: _ramadan,
                onChanged: (v) => setState(() => _ramadan = v),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const T('Enregistrer')),
          ],
        ),
      ),
    );
  }
}

/// Carte d'accueil en mode grossesse.
class PregnancyCard extends StatelessWidget {
  final PregnancyInfo info;
  const PregnancyCard({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    final step = info.step;
    return GlassCard(
      gradient: LinearGradient(
        colors: isDark(context) ? [const Color(0xF22B1B27), const Color(0xD9412234)] : [Colors.white.withValues(alpha: 0.92), const Color(0xCCFEEBF1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Text('🤰', style: TextStyle(fontSize: 30)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              T('${info.weeks} SA + ${info.extraDays} j', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: LagoColors.pink)),
              T('Trimestre ${info.trimester} · terme prévu le ${Dates.long(info.dueDate)}', style: TextStyle(fontSize: 13, color: mutedColor(context))),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: info.progress, minHeight: 10, color: LagoColors.pink, backgroundColor: LagoColors.pinkLight),
        ),
        const SizedBox(height: 12),
        T('Bébé a à peu près la taille d’${step.size}.', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        T(step.baby, style: const TextStyle(fontSize: 13.5)),
        const SizedBox(height: 8),
        T('💡 ${step.tip}', style: const TextStyle(fontSize: 13.5)),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PregnancyScreen(info: info))),
            icon: const Icon(Icons.chevron_right),
            label: const T('Semaine par semaine'),
          ),
        ),
      ]),
    );
  }
}

class PregnancyScreen extends StatelessWidget {
  final PregnancyInfo info;
  const PregnancyScreen({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const T('Ma grossesse')),
      body: LagoBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
          children: [
            PregnancyCard(info: info),
            const SizedBox(height: 14),
            for (final s in PregnancyInfo.steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  borderColor: info.weeks >= s.fromWeek && identical(info.step, s) ? LagoColors.pink : null,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    T('À partir de ${s.fromWeek} SA — ${s.size}', style: const TextStyle(fontWeight: FontWeight.w700, color: LagoColors.pink)),
                    const SizedBox(height: 6),
                    T('👶 ${s.baby}', style: const TextStyle(fontSize: 13.5)),
                    const SizedBox(height: 4),
                    T('🤰 ${s.mother}', style: const TextStyle(fontSize: 13.5)),
                    const SizedBox(height: 4),
                    T('💡 ${s.tip}', style: const TextStyle(fontSize: 13.5)),
                  ]),
                ),
              ),
            T('SA = semaines d’aménorrhée, comptées depuis le 1er jour des dernières règles. '
                'Ces repères sont indicatifs : suivez les consultations prénatales de votre centre de santé.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: mutedColor(context))),
          ],
        ),
      ),
    );
  }
}

/// Repères en mode post-partum ou préménopause.
class LifeStageCard extends StatelessWidget {
  final CycleSettings settings;
  const LifeStageCard({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final mode = LifeMode.of(settings.lifeMode);
    final pp = settings.lifeMode == 'postpartum' ? PostpartumInfo.fromIso(settings.babyBirthDate) : null;
    final points = settings.lifeMode == 'postpartum' ? PostpartumInfo.keyPoints : PerimenopauseInfo.keyPoints;
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text(mode.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Expanded(child: T(mode.label, style: Theme.of(context).textTheme.titleLarge)),
        ]),
        if (pp != null) ...[
          const SizedBox(height: 8),
          T('Bébé a ${pp.weeks} semaine${pp.weeks > 1 ? 's' : ''}.', style: const TextStyle(fontWeight: FontWeight.w700, color: LagoColors.pink)),
          const SizedBox(height: 4),
          T(pp.stage, style: const TextStyle(fontSize: 13.5)),
        ],
        const SizedBox(height: 8),
        for (final p in points)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(top: 3), child: Icon(Icons.check_circle_outline, size: 16, color: LagoColors.green)),
              const SizedBox(width: 8),
              Expanded(child: T(p, style: const TextStyle(fontSize: 13.5))),
            ]),
          ),
      ]),
    );
  }
}
