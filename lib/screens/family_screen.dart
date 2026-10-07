import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';
import '../core/calculator.dart';
import '../core/family.dart';
import '../core/insights.dart';
import '../core/models.dart';
import '../core/utils.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'stats_screen.dart';
import '../l10n/l10n.dart';

// =====================================================================================
// Côté parent : « Mes enfants »
// =====================================================================================
class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});
  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final state = AppState.instance;
  List<ChildData>? _children;
  String? _error;
  bool _loading = true;

  FamilyService get _svc => FamilyService(state.user!);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _svc.children();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _children = res.value ?? _children;
      _error = res.error;
    });
  }

  Future<void> _addChild() async {
    final code = TextEditingController();
    final entered = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const T('Suivre mon enfant'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const T('Sur le téléphone de votre enfant : Profil › Suivi parental › Créer un code. Saisissez ce code ci-dessous (valable 48 heures).'),
          const SizedBox(height: 12),
          TextField(
            controller: code,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 6, fontWeight: FontWeight.w700),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]'))],
            decoration: InputDecoration(hintText: 'ABC123', counterText: ''),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const T('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, code.text), child: const T('Valider')),
        ],
      ),
    );
    if (entered == null || entered.trim().isEmpty) return;
    final res = await _svc.link(entered);
    if (!mounted) return;
    if (!res.ok) {
      showToast(context, res.error!, type: ToastType.error);
      return;
    }
    showToast(context, 'Vous suivez maintenant ${res.value} 🌸');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final kids = _children ?? const <ChildData>[];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
        children: [
          SectionTitle('Mes enfants', icon: Icons.family_restroom,
              subtitle: 'Suivez le cycle de votre enfant pour l’accompagner, avec son accord.',
              trailing: IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))),
          if (_loading && _children == null) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
          if (_error != null)
            GlassCard(child: T(_error!, style: const TextStyle(color: LagoColors.danger, fontWeight: FontWeight.w600))),
          if (!_loading && kids.isEmpty && _error == null)
            GlassCard(
              child: Column(children: [
                const Text('👨‍👩‍👧', style: TextStyle(fontSize: 42)),
                const SizedBox(height: 8),
                const T('Aucun enfant suivi pour le moment.', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                T('Demandez à votre enfant de créer un code dans son application LaGo (Profil › Suivi parental), puis touchez « Ajouter un enfant ».',
                    textAlign: TextAlign.center, style: TextStyle(color: mutedColor(context), fontSize: 13)),
              ]),
            ),
          for (final c in kids) ...[_ChildCard(child: c, onChanged: _load), const SizedBox(height: 12)],
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: _addChild, icon: const Icon(Icons.person_add_alt_1), label: const T('Ajouter un enfant')),
          const SizedBox(height: 12),
          T('Par respect de son intimité, vous ne voyez jamais ses notes personnelles. Votre enfant peut retirer votre accès à tout moment.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: mutedColor(context))),
          if (!(state.user?.isServer ?? false))
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: T('Mode sans serveur : le compte de votre enfant doit être sur ce même téléphone. Pour suivre son téléphone à distance, configurez un serveur LaGo (Profil › Synchronisation).',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: mutedColor(context))),
            ),
        ],
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  final ChildData child;
  final VoidCallback onChanged;
  const _ChildCard({required this.child, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final s = child.settings;
    CycleData? cycle;
    if (s != null) {
      final eff = CycleInsights.compute(child.logs).apply(s);
      cycle = CycleCalculator.calculate(eff.lastPeriodDate, eff.cycleLength, eff.periodDuration);
    }
    return GlassCard(
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChildDetailScreen(child: child, onUnlinked: onChanged))),
        child: Row(children: [
          CircleAvatar(radius: 26, backgroundColor: LagoColors.pinkLight, child: Text(child.name.isEmpty ? '?' : child.name.characters.first.toUpperCase(),
              style: const TextStyle(fontSize: 22, color: LagoColors.pink, fontWeight: FontWeight.w700))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${child.name}${child.age != null ? tr(' · ${child.age} ans') : ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 4),
              if (cycle == null)
                T('Cycle pas encore renseigné.', style: TextStyle(color: mutedColor(context), fontSize: 13))
              else ...[
                PhaseBadge(cycle.phase, fontSize: 12),
                const SizedBox(height: 4),
                T(cycle.daysUntilNextPeriod <= 0
                    ? 'Règles prévues aujourd’hui'
                    : 'Jour ${cycle.currentCycleDay} · règles dans ${cycle.daysUntilNextPeriod} jour${cycle.daysUntilNextPeriod > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 13)),
              ],
            ]),
          ),
          const Icon(Icons.chevron_right),
        ]),
      ),
    );
  }
}

/// Détail du suivi d'un enfant : cycle, journal récent (sans notes), graphiques, rapport PDF.
class ChildDetailScreen extends StatelessWidget {
  final ChildData child;
  final VoidCallback onUnlinked;
  const ChildDetailScreen({super.key, required this.child, required this.onUnlinked});

  @override
  Widget build(BuildContext context) {
    final s = child.settings;
    final recent = child.logs.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    return Scaffold(
      appBar: AppBar(
        title: Text(child.name),
        actions: [
          IconButton(
            tooltip: tr('Arrêter le suivi'),
            icon: const Icon(Icons.link_off),
            onPressed: () async {
              final ok = await confirmDialog(context, 'Arrêter de suivre ${child.name} ? Il faudra un nouveau code pour la suivre à nouveau.',
                  danger: true, okLabel: 'Arrêter le suivi');
              if (!ok) return;
              final res = await FamilyService(AppState.instance.user!).unlink(child.id);
              if (!context.mounted) return;
              if (!res.ok) {
                showToast(context, res.error!, type: ToastType.error);
                return;
              }
              onUnlinked();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: LagoBackground(
        child: s == null
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: T('${child.name} n’a pas encore renseigné son cycle.', textAlign: TextAlign.center)))
            : StatsView(
                name: child.name,
                age: child.age,
                settings: s,
                logs: child.logs,
                header: [
                  _summary(context, s),
                  const SizedBox(height: 14),
                  GlassCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const SectionTitle('Journal récent', icon: Icons.calendar_month, subtitle: 'Les notes personnelles restent privées.'),
                      if (recent.isEmpty) T('Aucune entrée pour le moment.', style: TextStyle(color: mutedColor(context))),
                      for (final e in recent.take(14)) _logRow(context, e.key, e.value),
                    ]),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
      ),
    );
  }

  Widget _summary(BuildContext context, CycleSettings s) {
    final eff = CycleInsights.compute(child.logs).apply(s);
    final c = CycleCalculator.calculate(eff.lastPeriodDate, eff.cycleLength, eff.periodDuration);
    Widget line(String a, String b) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [Expanded(child: T(a, style: TextStyle(color: mutedColor(context)))), T(b, style: const TextStyle(fontWeight: FontWeight.w700))]),
        );
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: T('Jour ${c.currentCycleDay} sur ${c.cycleLength}', style: Theme.of(context).textTheme.titleLarge)),
          PhaseBadge(c.phase, fontSize: 12),
        ]),
        const SizedBox(height: 8),
        line('Prochaines règles', Dates.long(c.nextPeriodStart)),
        line('Début de la fenêtre fertile', Dates.long(c.fertileStart)),
        line('Ovulation estimée', Dates.long(c.ovulationDate)),
        line('Dernières règles', Dates.long(c.currentPeriodStart)),
      ]),
    );
  }

  Widget _logRow(BuildContext context, String iso, DayLog l) {
    final d = Dates.parseIso(iso);
    final flow = FlowLevel.values.firstWhere((o) => o.key == l.flow, orElse: () => FlowLevel.values.first);
    final mood = Mood.of(l.mood);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 70, child: Text(d == null ? iso : Dates.short(d), style: const TextStyle(fontWeight: FontWeight.w700))),
        Expanded(
          child: Wrap(spacing: 6, runSpacing: 4, children: [
            if (l.flow != 'none') _chip('${flow.emoji} ${tr(flow.label)}'),
            _chip('${mood.emoji} ${tr(mood.label)}'),
            for (final sy in l.symptoms) _chip('${Symptom.of(sy).emoji} ${tr(Symptom.of(sy).label)}'),
            if (l.temperature.isNotEmpty) _chip('🌡️ ${l.temperature} °C'),
          ]),
        ),
      ]),
    );
  }

  Widget _chip(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: LagoColors.pinkLight, borderRadius: BorderRadius.circular(999)),
        child: Text(t, style: const TextStyle(fontSize: 12, color: LagoColors.textDark)),
      );
}

// =====================================================================================
// Côté enfant : « Suivi parental » dans le profil
// =====================================================================================
class ParentalSharingCard extends StatefulWidget {
  const ParentalSharingCard({super.key});
  @override
  State<ParentalSharingCard> createState() => _ParentalSharingCardState();
}

class _ParentalSharingCardState extends State<ParentalSharingCard> {
  final state = AppState.instance;
  List<Follower> _followers = const [];
  String? _code;
  DateTime? _expires;
  bool _busy = false;

  FamilyService get _svc => FamilyService(state.user!);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _svc.followers();
    if (mounted && res.ok) setState(() => _followers = res.value!);
  }

  Future<void> _createCode() async {
    final ok = await confirmDialog(
      context,
      'La personne qui saisira ce code verra votre cycle, vos règles, votre humeur, vos symptômes et votre température — jamais vos notes personnelles. Vous pourrez retirer son accès à tout moment. Continuer ?',
      okLabel: 'Créer le code',
    );
    if (!ok) return;
    setState(() => _busy = true);
    final res = await _svc.createInvite();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (res.ok) {
        _code = res.value!.$1;
        _expires = res.value!.$2;
      }
    });
    if (!res.ok) showToast(context, res.error!, type: ToastType.error);
  }

  Future<void> _remove(Follower f) async {
    final ok = await confirmDialog(context, '${f.name} ne pourra plus voir votre cycle. Retirer l’accès ?', danger: true, okLabel: 'Retirer');
    if (!ok) return;
    final res = await _svc.unlink(f.id);
    if (!mounted) return;
    if (!res.ok) {
      showToast(context, res.error!, type: ToastType.error);
      return;
    }
    showToast(context, 'Accès retiré.');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Suivi parental', icon: Icons.family_restroom,
            subtitle: 'Permettre à un parent de suivre votre cycle (sans vos notes).'),
        if (_followers.isEmpty)
          T('Personne ne suit votre cycle.', style: TextStyle(color: mutedColor(context), fontSize: 13))
        else
          for (final f in _followers)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.visibility_outlined, color: LagoColors.pink),
              title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: T(f.email.isEmpty ? 'Peut voir votre cycle' : '${f.email} · peut voir votre cycle'),
              trailing: TextButton(
                style: TextButton.styleFrom(foregroundColor: LagoColors.danger),
                onPressed: () => _remove(f),
                child: const T('Retirer'),
              ),
            ),
        const SizedBox(height: 10),
        if (_code != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: LagoColors.pinkLight, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              const T('Code à donner à votre parent', style: TextStyle(color: LagoColors.textDark)),
              const SizedBox(height: 6),
              SelectableText(_code!,
                  style: const TextStyle(fontSize: 30, letterSpacing: 6, fontWeight: FontWeight.w800, color: LagoColors.pink)),
              T('Valable jusqu’au ${Dates.dateTime(_expires!)} · une seule utilisation',
                  style: const TextStyle(fontSize: 12, color: LagoColors.textDark)),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _code!));
                  showToast(context, 'Code copié.');
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const T('Copier'),
              ),
            ]),
          ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _createCode,
          icon: const Icon(Icons.qr_code_2),
          label: T(_code == null ? 'Créer un code pour un parent' : 'Créer un nouveau code'),
        ),
        TextButton(onPressed: _load, child: const T('Actualiser la liste')),
      ]),
    );
  }
}
