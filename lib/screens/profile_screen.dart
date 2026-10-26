import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../core/utils.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/profile_widgets.dart';
import 'alerts_screen.dart';
import 'explore_screen.dart';
import 'life_mode_screen.dart';
import 'privacy_screen.dart';
import 'family_screen.dart';
import 'health_reminders_screen.dart';
import 'stats_screen.dart';
import 'auth_screen.dart';
import '../l10n/l10n.dart';

/// Profil : paramètres du cycle, préférences, sécurité, sauvegarde, compte.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final state = AppState.instance;
  late DateTime _lmp;
  late int _cycleLength;
  late int _periodDuration;
  String _loadedFor = '';

  void _loadForm() {
    final key = '${state.user?.id}|${state.settings.updatedAt}|${state.settings.lastPeriodDate}';
    if (key == _loadedFor) return;
    _loadedFor = key;
    final s = state.settings;
    _lmp = Dates.parseIso(s.lastPeriodDate) ?? Dates.today();
    _cycleLength = s.cycleLength.clamp(20, 45).toInt();
    _periodDuration = s.periodDuration.clamp(2, 10).toInt();
  }

  Future<void> _pickDate() async {
    final first = DateTime(Dates.today().year - 2);
    final picked = await showDatePicker(
      context: context,
      initialDate: _lmp.isAfter(Dates.today()) ? Dates.today() : (_lmp.isBefore(first) ? first : _lmp),
      firstDate: first,
      lastDate: Dates.today(),
      helpText: tr('Premier jour des dernières règles'),
    );
    if (picked != null) setState(() => _lmp = picked);
  }

  Future<void> _saveCycle() async {
    if (_periodDuration >= _cycleLength) {
      showToast(context, 'Les règles doivent être plus courtes que le cycle.', type: ToastType.error);
      return;
    }
    await state.updateSettings(state.settings.copyWith(
      lastPeriodDate: Dates.toIso(_lmp),
      cycleLength: _cycleLength,
      periodDuration: _periodDuration,
    ));
    _loadedFor = '';
    await state.rescheduleReminders();
    if (mounted) showToast(context, '🌸 Paramètres du cycle enregistrés avec succès !');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        _loadForm();
        final user = state.user;
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
          children: [
            if (!state.isParent) ...[_cycleCard(context), const SizedBox(height: 14)],
            _preferencesCard(context),
            const SizedBox(height: 14),
            if (user != null && !state.isParent) ...[const ParentalSharingCard(), const SizedBox(height: 14)],
            if (user != null) ...[_securityCard(context), const SizedBox(height: 14)],
            if (!state.isParent) ...[_dataCard(context), const SizedBox(height: 14)],
            _serverCard(context),
            const SizedBox(height: 14),
            _accountCard(context),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------------ Cycle
  Widget _cycleCard(BuildContext context) {
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Paramètres & calculs', icon: Icons.tune, subtitle: 'Ajustez les données de référence de votre corps.'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event, color: LagoColors.pink),
          title: const T('1er jour des dernières règles'),
          subtitle: T(Dates.long(_lmp), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          trailing: const Icon(Icons.edit_calendar_outlined),
          onTap: _pickDate,
        ),
        _stepper('Durée moyenne du cycle', 'Moyenne : 28 jours', _cycleLength, 20, 45, (v) => setState(() => _cycleLength = v)),
        _stepper('Durée moyenne des règles', 'Moyenne : 5 jours', _periodDuration, 2, 10, (v) => setState(() => _periodDuration = v)),
        const SizedBox(height: 10),
        FilledButton.icon(onPressed: _saveCycle, icon: const Icon(Icons.save_outlined), label: const T('Enregistrer et recalculer')),
        const Divider(height: 28),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const T('Apprendre de mon journal', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: T(_learnSubtitle()),
          value: state.settings.learnFromJournal,
          onChanged: (v) async {
            await state.updateSettings(state.settings.copyWith(learnFromJournal: v));
            await state.rescheduleReminders();
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.insights, color: LagoColors.pink),
          title: const T('Statistiques & rapport PDF', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const T('Durées des cycles, symptômes, température, PDF pour une consultation'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StatsScreen())),
        ),
      ]),
    );
  }

  String _learnSubtitle() {
    final i = state.insights;
    final c = i.learnedCycleLength;
    if (c == null) return 'Dès 2 cycles notés dans le journal, LaGo utilise vos vraies durées.';
    return 'Cycle réel : $c jours${i.learnedPeriodLength != null ? ' · règles : ${i.learnedPeriodLength} jours' : ''} (${i.cycleLengths.length} cycles mesurés)';
  }

  Widget _stepper(String title, String hint, int value, int min, int max, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            T(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            T(hint, style: TextStyle(fontSize: 12, color: mutedColor(context))),
          ]),
        ),
        IconButton.filledTonal(onPressed: value > min ? () => onChanged(value - 1) : null, icon: const Icon(Icons.remove)),
        SizedBox(
          width: 64,
          child: T('$value j', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        IconButton.filledTonal(onPressed: value < max ? () => onChanged(value + 1) : null, icon: const Icon(Icons.add)),
      ]),
    );
  }

  // ------------------------------------------------------------------ Préférences
  Widget _preferencesCard(BuildContext context) {
    final s = state.settings;
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Préférences & rappels', icon: Icons.notifications_active_outlined),
        const LanguageSelector(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const T('Mode nuit rosé'),
          value: s.darkMode,
          onChanged: (v) => state.updateSettings(s.copyWith(darkMode: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const T('Pluie de pétales'),
          value: s.petalsEnabled,
          onChanged: (v) => state.updateSettings(s.copyWith(petalsEnabled: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const T('Mode discret'),
          subtitle: const T('Les notifications n’affichent aucun mot lié au cycle.'),
          value: s.discreetMode,
          onChanged: (v) async {
            await state.updateSettings(s.copyWith(discreetMode: v));
            await state.rescheduleReminders();
          },
        ),
        // v5 — économie de données
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const T('Économie de données'),
          subtitle: const T('Synchronisation seulement quand vous glissez l’accueil vers le bas.'),
          value: s.dataSaver,
          onChanged: (v) => state.updateSettings(s.copyWith(dataSaver: v)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notifications_active_outlined, color: LagoColors.pink),
          title: const T('Alertes & sonneries', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: T(s.remindersEnabled
              ? 'Règles, ovulation, SPM, journal, conseil du jour — sonnerie au choix'
              : 'Désactivées — touchez pour configurer'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AlertsScreen())),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.medication_outlined, color: LagoColors.pink),
          title: const T('Pilule & rendez-vous médicaux', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: T(state.appointments.where((a) => !a.isPast).isEmpty
              ? 'Rappel de pilule et rappels de rendez-vous'
              : '${state.appointments.where((a) => !a.isPast).length} rendez-vous à venir'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HealthRemindersScreen())),
        ),
        // v5
        if (!state.isParent)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.swap_horiz, color: LagoColors.pink),
            title: const T('Mode de vie & contraception', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const T('Cycle, grossesse, post-partum, préménopause, Ramadan'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LifeModeScreen())),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.apps, color: LagoColors.pink),
          title: const T('Plus de LaGo', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const T('Assistante, communauté, partenaires, SMS/WhatsApp, Premium'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExploreScreen())),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.verified_user_outlined, color: LagoColors.green),
          title: const T('Vos données', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const T('Aucune publicité, aucune revente : nos engagements'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyScreen())),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: T('⌚ Montre connectée : les alertes LaGo s’affichent et vibrent aussi sur votre montre (Wear OS, Apple Watch, Galaxy Watch…) si elle reçoit les notifications du téléphone.',
              style: TextStyle(fontSize: 12, color: mutedColor(context))),
        ),
      ]),
    );
  }

  // ------------------------------------------------------------------ Sécurité
  Widget _securityCard(BuildContext context) {
    final hasPin = state.tracker.hasPin;
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Sécurité & verrouillage', icon: Icons.lock_outline,
            subtitle: 'Protégez votre journal intime avec un code PIN.'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(hasPin ? Icons.lock : Icons.lock_open, color: hasPin ? LagoColors.green : LagoColors.pink),
          title: const T('Code PIN de l’application'),
          subtitle: T(hasPin ? 'Activé — demandé à l’ouverture' : 'Désactivé'),
          trailing: Wrap(spacing: 4, children: [
            TextButton(onPressed: _setPin, child: T(hasPin ? 'Changer' : 'Activer')),
            if (hasPin)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: LagoColors.danger),
                onPressed: () async {
                  if (!await confirmDialog(context, 'Désactiver le verrouillage par code PIN ?')) return;
                  await state.tracker.removePin();
                  if (!mounted) return;
                  setState(() {});
                  showToast(context, 'Code PIN désactivé.');
                },
                child: const T('Retirer'),
              ),
          ]),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.password, color: LagoColors.pink),
          title: const T('Changer mon mot de passe'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _changePassword,
        ),
      ]),
    );
  }

  Future<void> _setPin() async {
    final a = TextEditingController();
    final b = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const T('Code PIN'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: a,
            obscureText: true,
            maxLength: 6,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: tr('Nouveau code (4 à 6 chiffres)')),
          ),
          TextField(
            controller: b,
            obscureText: true,
            maxLength: 6,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: tr('Confirmer le code')),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const T('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const T('Activer')),
        ],
      ),
    );
    final pin = a.text;
    final confirm = b.text;
    a.dispose();
    b.dispose();
    if (ok != true || !mounted) return;
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      showToast(context, 'Le code doit contenir 4 à 6 chiffres.', type: ToastType.error);
      return;
    }
    if (pin != confirm) {
      showToast(context, 'Les deux codes ne correspondent pas.', type: ToastType.error);
      return;
    }
    await state.tracker.setPin(pin);
    if (!mounted) return;
    setState(() {});
    showToast(context, '🔒 Code PIN activé.');
  }

  Future<void> _changePassword() async {
    final cur = TextEditingController();
    final next = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const T('Mot de passe'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: cur, obscureText: true, decoration: InputDecoration(labelText: tr('Mot de passe actuel'))),
          const SizedBox(height: 12),
          TextField(controller: next, obscureText: true, decoration: InputDecoration(labelText: tr('Nouveau (6 caractères min.)'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const T('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const T('Mettre à jour')),
        ],
      ),
    );
    final c = cur.text;
    final n = next.text;
    cur.dispose();
    next.dispose();
    if (ok != true) return;
    final res = await state.auth.changePassword(c, n);
    if (!mounted) return;
    showToast(context, res.success ? 'Mot de passe modifié.' : (res.message ?? 'Échec.'),
        type: res.success ? ToastType.success : ToastType.error);
  }

  // ------------------------------------------------------------------ Données
  Widget _dataCard(BuildContext context) {
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Confidentialité & sauvegarde', icon: Icons.verified_user_outlined, iconColor: LagoColors.green,
            subtitle: 'Sauvegardez et restaurez vos cycles à tout moment.'),
        Wrap(spacing: 10, runSpacing: 10, children: [
          OutlinedButton.icon(onPressed: _export, icon: const Icon(Icons.ios_share), label: const T('Exporter (JSON)')),
          OutlinedButton.icon(onPressed: _import, icon: const Icon(Icons.file_open_outlined), label: const T('Importer')),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: LagoColors.danger),
            onPressed: _reset,
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const T('Réinitialiser mes données'),
          ),
        ]),
      ]),
    );
  }

  Future<void> _export() async {
    try {
      final json = state.tracker.exportJson(state.user);
      final bytes = Uint8List.fromList(utf8.encode(json));
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: state.tracker.exportFileName, mimeType: 'application/json')],
        fileNameOverrides: [state.tracker.exportFileName],
        subject: tr('Sauvegarde LaGo'),
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (e) {
      if (mounted) showToast(context, 'Export impossible : $e', type: ToastType.error);
    }
  }

  Future<void> _import() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
      final file = result?.files.single;
      if (file == null || file.bytes == null) return;
      if (file.size > 2 * 1024 * 1024) {
        if (mounted) showToast(context, 'Fichier trop volumineux (2 Mo max).', type: ToastType.error);
        return;
      }
      final count = await state.tracker.importJson(utf8.decode(file.bytes!));
      state.reload();
      state.syncNow();
      if (mounted) showToast(context, 'Sauvegarde restaurée ($count jour${count > 1 ? 's' : ''} de journal).');
    } on FormatException catch (e) {
      if (mounted) showToast(context, e.message.isEmpty ? 'Fichier JSON invalide.' : e.message, type: ToastType.error);
    } catch (e) {
      if (mounted) showToast(context, 'Import impossible : $e', type: ToastType.error);
    }
  }

  Future<void> _reset() async {
    final ok = await confirmDialog(context, 'Effacer vos données personnelles LaGo (paramètres et journal) ?', danger: true, okLabel: 'Effacer');
    if (!ok) return;
    final serverOk = await state.tracker.clearAll();
    _loadedFor = '';
    state.reload();
    if (mounted) {
      showToast(context, serverOk ? 'Vos données ont été réinitialisées.' : 'Effacé sur le téléphone ; le serveur n’a pas pu être mis à jour.',
          type: serverOk ? ToastType.success : ToastType.info);
    }
  }

  // ------------------------------------------------------------------ Serveur
  Widget _serverCard(BuildContext context) {
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Synchronisation', icon: Icons.cloud_outlined),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Api.enabled ? Icons.cloud_done_outlined : Icons.smartphone, color: LagoColors.pink),
          title: T(Api.enabled ? 'Serveur LaGo' : 'Mode 100 % téléphone'),
          subtitle: T(Api.enabled ? Api.baseUrl : 'Aucun serveur : vos données restent sur ce téléphone.'),
          trailing: const Icon(Icons.edit_outlined),
          onTap: _editServer,
        ),
      ]),
    );
  }

  Future<void> _editServer() async {
    final ctrl = TextEditingController(text: Api.baseUrl);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const T('Adresse du serveur'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(hintText: tr('https://api.mon-site.com'), helperText: tr('Laisser vide pour le mode local')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const T('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const T('Enregistrer')),
        ],
      ),
    );
    final url = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true) return;
    if (url.isNotEmpty && !url.startsWith('https://') && !url.startsWith('http://')) {
      if (mounted) showToast(context, 'L’adresse doit commencer par https://', type: ToastType.error);
      return;
    }
    await Api.setBaseUrl(url);
    if (url.isNotEmpty) {
      final res = await Api.health();
      if (mounted) {
        showToast(context, res.ok ? 'Serveur joignable ✅ — reconnectez-vous pour synchroniser.' : 'Serveur injoignable pour le moment.',
            type: res.ok ? ToastType.success : ToastType.info);
      }
    }
    if (mounted) setState(() {});
  }

  // ------------------------------------------------------------------ Compte
  Widget _accountCard(BuildContext context) {
    final user = state.user;
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Mon compte', icon: Icons.person_outline),
        if (user == null)
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen())),
            icon: const Icon(Icons.login),
            label: const T('Se connecter / créer un compte'),
          )
        else ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: GestureDetector(
              onTap: () => showAvatarEditor(context),
              child: Stack(clipBehavior: Clip.none, children: [
                UserAvatar(admin: user.isAdmin, size: 52, avatar: state.avatar),
                const Positioned(
                  right: -4,
                  bottom: -4,
                  child: CircleAvatar(radius: 11, backgroundColor: LagoColors.pink, child: Icon(Icons.edit, size: 12, color: Colors.white)),
                ),
              ]),
            ),
            title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(user.email),
          ),
          OutlinedButton.icon(
            onPressed: () => showAvatarEditor(context),
            icon: const Icon(Icons.face_retouching_natural),
            label: const T('Changer ma photo de profil'),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () async {
              await state.logout();
              if (context.mounted) showToast(context, 'Déconnexion réussie.');
            },
            icon: const Icon(Icons.logout),
            label: const T('Se déconnecter'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: LagoColors.danger),
            onPressed: _deleteAccount,
            icon: const Icon(Icons.person_remove_outlined),
            label: const T('Supprimer mon compte'),
          ),
        ],
        const SizedBox(height: 12),
        T(
          'LaGo 4.3 • Les prévisions sont indicatives et ne remplacent pas un avis médical.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, color: mutedColor(context)),
        ),
      ]),
    );
  }

  Future<void> _deleteAccount() async {
    final ok = await confirmDialog(context, 'Supprimer définitivement votre compte LaGo et toutes vos données ? Cette action est irréversible.',
        danger: true, okLabel: 'Supprimer mon compte');
    if (!ok) return;
    final res = await state.auth.deleteOwnAccount();
    if (!mounted) return;
    if (!res.success) {
      showToast(context, res.message ?? 'Échec.', type: ToastType.error);
      return;
    }
    showToast(context, 'Votre compte a été supprimé.');
    await state.logout();
  }
}
