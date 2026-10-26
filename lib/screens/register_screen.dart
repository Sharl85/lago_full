import 'package:flutter/material.dart';

import '../core/alerts.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/utils.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/setup_forms.dart';
import '../l10n/l10n.dart';

/// Création de compte en 4 étapes : compte, cycle, alertes, confirmation.
/// Compte parent : 2 étapes (compte, confirmation) — le cycle suivi est celui de l'enfant.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final state = AppState.instance;
  int _step = 0;

  /// v5 — âge en dessous duquel l'accord d'un parent est demandé (à adapter à la loi du pays).
  static const parentalConsentAge = 15;
  bool _parentalConsent = false;
  bool _busy = false;
  String? _error;

  // Étape 1
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  DateTime? _birthDate;
  bool _showPassword = false;
  bool _parent = false; // compte parent (suivi d'un enfant)

  // Étape 2
  final _cycle = CycleFormData();

  // Étape 3
  bool _notifications = true;
  AlertPrefs _prefs = AlertPrefs.defaults();
  String _mainSound = 'lago_lotus';

  // Étape 4
  bool _acceptTerms = false;
  bool _acceptMedical = false;

  static const _titles = ['Votre compte', 'Votre cycle', 'Vos alertes', 'Confirmation'];

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  int? get _age {
    final b = _birthDate;
    if (b == null) return null;
    final now = DateTime.now();
    var a = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) a--;
    return a;
  }

  int _strength(String p) {
    var s = 0;
    if (p.length >= 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p)) s++;
    if (RegExp(r'\d').hasMatch(p)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) s++;
    return s;
  }

  String? _validateStep() {
    switch (_step) {
      case 0:
        if (_name.text.trim().isEmpty) return 'Indiquez votre prénom.';
        if (_birthDate == null) return 'Indiquez votre date de naissance.';
        final a = _age!;
        if (a < 10) return 'LaGo est destinée aux personnes de 10 ans et plus.';
        if (_parent && a < 18) return 'Un compte parent est réservé aux adultes (18 ans et plus).';
        if (a > 99) return 'Date de naissance invalide.';
        if (!isValidEmail(_email.text)) return 'Adresse email invalide.';
        if (_password.text.length < 6) return 'Le mot de passe doit contenir au moins 6 caractères.';
        if (_password.text != _confirm.text) return 'Les deux mots de passe ne correspondent pas.';
        return null;
      case 1:
        if (!_cycle.isComplete) return 'Indiquez la date du premier jour de vos dernières règles.';
        if (_cycle.periodDuration >= _cycle.cycleLength) return 'Les règles doivent être plus courtes que le cycle.';
        return null;
      case 3:
        if (!_acceptTerms || !_acceptMedical) return 'Merci de cocher les deux cases pour continuer.';
        // v5 — consentement parental pour les plus jeunes
        if (!_parent && (_age ?? 99) < parentalConsentAge && !_parentalConsent) {
          return 'Un parent ou un adulte responsable doit donner son accord (case à cocher).';
        }
        return null;
    }
    return null;
  }

  void _next() {
    final err = _validateStep();
    setState(() => _error = err);
    if (err != null) return;
    if (_step < 3) {
      setState(() => _step = _parent ? 3 : _step + 1);
    } else {
      _create();
    }
  }

  CycleSettings _buildSettings() => CycleSettings(
        lastPeriodDate: Dates.toIso(_cycle.lastPeriod!),
        cycleLength: _cycle.cycleLength,
        periodDuration: _cycle.periodDuration,
        cycleRegularity: _cycle.regularity,
        remindersEnabled: _notifications,
      );

  AlertPrefs _buildPrefs() {
    var p = _prefs;
    for (final t in [AlertType.periodSoon, AlertType.periodStart, AlertType.fertileStart, AlertType.ovulation, AlertType.pms]) {
      p = p.withAlert(t, p.of(t).copyWith(sound: _mainSound));
    }
    return p;
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final settings = _parent ? null : _buildSettings();
    final res = await state.auth.register(_name.text, _email.text, _password.text, _age,
        settings: settings?.toJson(), accountType: _parent ? 'parent' : 'member');
    if (!mounted) return;
    if (!res.success) {
      setState(() {
        _busy = false;
        _error = res.message;
        if ((res.message ?? '').toLowerCase().contains('email')) _step = 0;
      });
      return;
    }
    final navigator = Navigator.of(context);
    showToast(context, '🌸 Bienvenue sur LaGo, ${res.user!.name} !');
    if (settings == null) {
      await state.afterLogin(); // compte parent : pas de cycle personnel à enregistrer
    } else {
      await state.finishRegistration(res.user!, settings, _buildPrefs());
    }
    navigator.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: T('Créer mon compte — ${_titles[_step]}')),
      body: LagoBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(children: [
                for (var i = 0; i < _stepCount; i++)
                  Expanded(
                    child: Container(
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i <= _stepIndex ? LagoColors.pink : LagoColors.pinkSoft.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      T('Étape ${_stepIndex + 1} sur $_stepCount', style: TextStyle(color: mutedColor(context), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      T(_titles[_step], style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 16),
                      if (_error != null) _errorBox(_error!),
                      GlassCard(child: switch (_step) { 0 => _accountStep(), 1 => _cycleStep(), 2 => _alertsStep(), _ => _confirmStep() }),
                    ]),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(children: [
                if (_step > 0)
                  OutlinedButton(
                    onPressed: _busy ? null : () => setState(() {
                      _step = _parent ? 0 : _step - 1;
                      _error = null;
                    }),
                    child: const T('Retour'),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _busy ? null : _next,
                  icon: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(_step < 3 ? Icons.arrow_forward : Icons.how_to_reg),
                  label: T(_step < 3 ? 'Continuer' : 'Créer mon compte'),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _errorBox(String msg) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: LagoColors.danger.withValues(alpha: 0.3)),
        ),
        child: T(msg, style: const TextStyle(color: Color(0xFFB71C1C), fontWeight: FontWeight.w600)),
      );

  int get _stepCount => _parent ? 2 : 4;
  int get _stepIndex => _parent ? (_step == 0 ? 0 : 1) : _step;

  // ------------------------------------------------------------------ Étape 1
  Widget _accountStep() {
    final strength = _strength(_password.text);
    const labels = ['Très faible', 'Faible', 'Moyen', 'Bon', 'Excellent'];
    const colors = [LagoColors.danger, LagoColors.orange, LagoColors.gold, LagoColors.green, LagoColors.green];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const T('Ce compte est pour…', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      SegmentedButton<bool>(
        segments: [
          ButtonSegment(value: false, icon: const Icon(Icons.local_florist_outlined), label: T('Suivre mon cycle')),
          ButtonSegment(value: true, icon: const Icon(Icons.family_restroom), label: T('Suivre mon enfant')),
        ],
        selected: {_parent},
        onSelectionChanged: (v) => setState(() => _parent = v.first),
      ),
      if (_parent)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: T(
              'Compte parent : après l’inscription, votre enfant vous donne un code depuis son application. Vous verrez son cycle, son humeur et ses symptômes, jamais ses notes personnelles. Elle peut retirer l’accès à tout moment.',
              style: TextStyle(fontSize: 12.5, color: mutedColor(context))),
        ),
      const SizedBox(height: 16),
      TextField(
        controller: _name,
        textCapitalization: TextCapitalization.words,
        maxLength: 60,
        decoration: InputDecoration(labelText: tr('Prénom *'), prefixIcon: Icon(Icons.person_outline), counterText: ''),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.all(16)),
        onPressed: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: _birthDate ?? DateTime(now.year - 16, now.month, now.day),
            firstDate: DateTime(now.year - 99),
            lastDate: DateTime(now.year - 10, now.month, now.day),
            initialDatePickerMode: DatePickerMode.year,
            helpText: tr('Votre date de naissance'),
          );
          if (picked != null) setState(() => _birthDate = picked);
        },
        icon: const Icon(Icons.cake_outlined),
        label: T(_birthDate == null ? 'Date de naissance *' : '${Dates.long(_birthDate!)} ($_age ans)'),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 4, left: 4),
        child: T('Votre âge permet d’adapter les conseils de santé intime.', style: TextStyle(fontSize: 12, color: mutedColor(context))),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        decoration: InputDecoration(labelText: tr('Adresse email *'), prefixIcon: Icon(Icons.mail_outline)),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _password,
        obscureText: !_showPassword,
        autofillHints: const [AutofillHints.newPassword],
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: tr('Mot de passe * (6 caractères minimum)'),
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _showPassword = !_showPassword),
          ),
        ),
      ),
      if (_password.text.isNotEmpty) ...[
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: LinearProgressIndicator(
              value: (strength + 1) / 5,
              color: colors[strength],
              backgroundColor: colors[strength].withValues(alpha: 0.15),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          T(labels[strength], style: TextStyle(fontSize: 12, color: colors[strength], fontWeight: FontWeight.w700)),
        ]),
      ],
      const SizedBox(height: 12),
      TextField(
        controller: _confirm,
        obscureText: !_showPassword,
        decoration: InputDecoration(labelText: tr('Confirmer le mot de passe *'), prefixIcon: Icon(Icons.lock_reset)),
      ),
    ]);
  }

  // ------------------------------------------------------------------ Étape 2
  Widget _cycleStep() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        T('Ces informations permettent de calculer vos règles, votre ovulation et vos alertes. Vous pourrez les modifier à tout moment.',
            style: TextStyle(fontSize: 13, color: mutedColor(context))),
        const SizedBox(height: 16),
        CycleFormFields(data: _cycle, onChanged: () => setState(() {})),
        CyclePreview(data: _cycle),
      ]);

  // ------------------------------------------------------------------ Étape 3
  Widget _alertsStep() {
    final age = _age;
    final tipLabel = (age ?? 0) >= 18
        ? 'Conseil quotidien : sexualité, contraception, désir et santé intime'
        : 'Conseil quotidien : mon corps, consentement, relations et santé intime (adapté à mon âge)';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const T('Recevoir des notifications', style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: const T('Vous pourrez tout modifier plus tard dans Profil › Alertes & sonneries.'),
        value: _notifications,
        onChanged: (v) => setState(() => _notifications = v),
      ),
      if (_notifications) ...[
        const Divider(),
        const T('Moments importants', style: TextStyle(fontWeight: FontWeight.w700)),
        for (final t in [AlertType.periodSoon, AlertType.periodStart, AlertType.fertileStart, AlertType.ovulation, AlertType.pms, AlertType.dailyLog])
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _prefs.of(t).enabled,
            title: T('${t.emoji}  ${t.label}'),
            subtitle: T(t.description, style: const TextStyle(fontSize: 12)),
            onChanged: (v) => setState(() => _prefs = _prefs.withAlert(t, _prefs.of(t).copyWith(enabled: v ?? false))),
          ),
        const Divider(),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _prefs.of(AlertType.dailyTip).enabled,
          title: T('💡  $tipLabel'),
          subtitle: T('Chaque jour à ${formatTime(_prefs.tipHour, _prefs.tipMinute)}', style: const TextStyle(fontSize: 12)),
          onChanged: (v) => setState(() => _prefs = _prefs.withAlert(AlertType.dailyTip, _prefs.of(AlertType.dailyTip).copyWith(enabled: v ?? false))),
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule, color: LagoColors.pink),
          title: const T('Heure des alertes du cycle'),
          trailing: T(formatTime(_prefs.alertHour, _prefs.alertMinute), style: const TextStyle(fontWeight: FontWeight.w700)),
          onTap: () async {
            final t = await pickTime(context, _prefs.alertHour, _prefs.alertMinute, 'Heure des alertes');
            if (t != null) setState(() => _prefs = _prefs.copyWith(alertHour: t.hour, alertMinute: t.minute));
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.music_note, color: LagoColors.pink),
          title: const T('Sonnerie des alertes'),
          subtitle: T(Sounds.of(_mainSound).label),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final id = await showSoundPicker(context, _mainSound);
            if (id != null) setState(() => _mainSound = id);
          },
        ),
      ],
    ]);
  }

  // ------------------------------------------------------------------ Étape 4
  Widget _confirmStep() {
    final c = _parent ? null : _buildSettings();
    final age = _age ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _summary(Icons.person_outline, 'Compte', '${_name.text.trim()} · ${_email.text.trim()} · $age ans'),
      if (_parent)
        _summary(Icons.family_restroom, 'Type', 'Compte parent')
      else ...[
        _summary(Icons.event, 'Dernières règles', Dates.long(_cycle.lastPeriod!)),
        _summary(Icons.loop, 'Cycle', '${c!.cycleLength} jours, règles de ${c.periodDuration} jours'),
        _summary(Icons.notifications_active_outlined, 'Alertes', _notifications ? 'Activées (${Sounds.of(_mainSound).label})' : 'Désactivées'),
      ],
      const Divider(height: 28),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _acceptTerms,
        onChanged: (v) => setState(() => _acceptTerms = v ?? false),
        title: T(_parent
            ? 'J’accepte que LaGo enregistre mon compte. Je ne verrai que ce que mon enfant accepte de partager, jamais ses notes personnelles.'
            : 'J’accepte que LaGo enregistre mes données de cycle pour me fournir ce service. Je peux les exporter ou les supprimer à tout moment.'),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _acceptMedical,
        onChanged: (v) => setState(() => _acceptMedical = v ?? false),
        title: const T('J’ai compris que les prévisions sont indicatives, ne remplacent pas un avis médical et ne sont pas une méthode de contraception.'),
      ),
      if (age < parentalConsentAge && !_parent)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _parentalConsent,
          onChanged: (v) => setState(() => _parentalConsent = v ?? false),
          title: const T('Un parent ou un adulte responsable a lu ces conditions et donne son accord pour que j’utilise LaGo.'),
        ),
      if (age < 15 && !_parent)
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: LagoColors.pinkLight, borderRadius: BorderRadius.circular(12)),
          child: const T('Vous avez moins de 15 ans : nous vous conseillons d’en parler avec un parent ou un adulte de confiance.',
              style: TextStyle(color: LagoColors.textDark, fontSize: 13)),
        ),
    ]);
  }

  Widget _summary(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: LagoColors.pink),
          const SizedBox(width: 10),
          SizedBox(width: 110, child: T(label, style: const TextStyle(fontWeight: FontWeight.w700))),
          Expanded(child: T(value)),
        ]),
      );
}
