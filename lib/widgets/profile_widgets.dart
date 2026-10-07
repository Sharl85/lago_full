import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/avatar.dart';
import '../core/avatar_vault.dart';
import '../l10n/l10n.dart';
import '../theme.dart';
import 'common.dart';

/// Choix de la langue : langue du téléphone (automatique), français, anglais, espagnol, portugais ou arabe.
class LanguageSelector extends StatelessWidget {
  final bool compact;
  const LanguageSelector({super.key, this.compact = false});

  static const options = [
    ('system', '📱', 'Langue du téléphone'),
    ('fr', '🇫🇷', 'Français'),
    ('en', '🇬🇧', 'English'),
    ('es', '🇪🇸', 'Español'),
    ('pt', '🇵🇹', 'Português'),
    ('ar', '🌍', 'العربية'),
  ];

  static String label(String pref) {
    final o = options.firstWhere((o) => o.$1 == pref, orElse: () => options.first);
    // Le nom de chaque langue reste écrit dans sa propre langue
    return o.$1 == 'system' ? '${o.$2} ${tr(o.$3)}' : '${o.$2} ${o.$3}';
  }

  Future<void> _choose(BuildContext context) async {
    final current = L.preference;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: T('Langue de l’application', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          for (final o in options)
            ListTile(
              leading: Text(o.$2, style: const TextStyle(fontSize: 22)),
              title: Text(o.$1 == 'system' ? tr(o.$3) : o.$3),
              subtitle: o.$1 == 'system'
                  ? T('Actuellement : ${L.languages[L.systemLang]}')
                  : null,
              trailing: current == o.$1 ? const Icon(Icons.check_circle, color: LagoColors.pink) : null,
              onTap: () => Navigator.pop(ctx, o.$1),
            ),
          const SizedBox(height: 8),
        ])),
      ),
    );
    if (picked == null || picked == current) return;
    await AppState.instance.setLanguage(picked);
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return TextButton.icon(
        onPressed: () => _choose(context),
        icon: const Icon(Icons.language, size: 18),
        label: Text(label(L.preference)),
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.language, color: LagoColors.pink),
      title: const T('Langue', style: TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(label(L.preference)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _choose(context),
    );
  }
}

/// Fenêtre de modification de la photo de profil (avatar ou photo).
Future<void> showAvatarEditor(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _AvatarEditor(),
  );
}

class _AvatarEditor extends StatefulWidget {
  const _AvatarEditor();
  @override
  State<_AvatarEditor> createState() => _AvatarEditorState();
}

class _AvatarEditorState extends State<_AvatarEditor> {
  final state = AppState.instance;
  late AvatarPref _a = state.avatar;
  bool _busy = false;

  String get _uid => state.user?.id ?? 'default';
  late bool _backup = AvatarVault.isEnabled(_uid);

  Future<void> _toggleBackup(bool on) async {
    if (on) {
      final ok = await confirmDialog(
        context,
        'Autoriser LaGo à conserver une copie chiffrée de votre photo de profil sur le serveur ? Vous pourrez la supprimer à tout moment en désactivant cette option.',
        okLabel: 'J’accepte',
      );
      if (!ok) return;
    }
    setState(() => _busy = true);
    final err = await AvatarVault.setEnabled(_uid, _a, on);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (err == null) _backup = on;
    });
    if (err != null) {
      showToast(context, err, type: ToastType.error);
    } else {
      showToast(context, on ? 'Photo sauvegardée et chiffrée 🔒' : 'Copie supprimée du serveur.');
    }
  }

  Future<void> _save(AvatarPref a) async {
    setState(() => _a = a);
    await state.setAvatar(a);
  }

  Future<void> _pick(bool camera) async {
    setState(() => _busy = true);
    try {
      final path = await AvatarPref.pickPhoto(_uid, camera: camera);
      if (path != null) {
        await _save(_a.copyWith(kind: 'photo', photoPath: path));
        if (mounted) showToast(context, 'Photo de profil mise à jour 🌸');
      }
    } catch (_) {
      if (mounted) {
        showToast(context, camera ? 'Impossible d’ouvrir l’appareil photo. Vérifiez les autorisations.' : 'Impossible d’ouvrir la galerie. Vérifiez les autorisations.',
            type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePhoto() async {
    await AvatarPref.deletePhotos(_uid);
    await _save(_a.copyWith(kind: 'emoji', clearPhoto: true));
  }

  @override
  Widget build(BuildContext context) {
    final admin = state.user?.isAdmin ?? false;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const T('Photo de profil', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Center(child: UserAvatar(admin: admin, size: 96, avatar: _a)),
          const SizedBox(height: 16),
          // --- Photo personnelle
          const T('Une photo', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _pick(false),
                icon: const Icon(Icons.photo_library_outlined),
                label: const T('Galerie'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _pick(true),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const T('Appareil photo'),
              ),
            ),
          ]),
          if (_a.hasPhoto)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: LagoColors.danger),
              onPressed: _busy ? null : _removePhoto,
              icon: const Icon(Icons.delete_outline),
              label: const T('Supprimer la photo'),
            ),
          if (!(state.user?.isServer ?? false))
            T('La photo reste uniquement sur votre téléphone : elle n’est jamais envoyée sur internet.',
                style: TextStyle(fontSize: 12, color: mutedColor(context)))
          else
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const T('Sauvegarde chiffrée sur le serveur', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: T(
                  'Retrouvez votre photo sur un nouveau téléphone. Elle est chiffrée sur votre téléphone avec votre mot de passe : personne d’autre, pas même le serveur, ne peut la voir.',
                  style: TextStyle(fontSize: 12, color: mutedColor(context))),
              value: _backup,
              onChanged: _busy ? null : _toggleBackup,
            ),
          const SizedBox(height: 18),
          // --- Avatar
          const T('Ou un avatar', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in [if (admin) '👑', ...AvatarPref.emojis])
              InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () => _save(_a.copyWith(kind: 'emoji', emoji: e)),
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(_a.color),
                    border: Border.all(
                        color: !_a.hasPhoto && _a.emoji == e ? LagoColors.pink : Colors.transparent, width: 3),
                  ),
                  child: Text(e, style: const TextStyle(fontSize: 24)),
                ),
              ),
          ]),
          const SizedBox(height: 14),
          const T('Couleur de fond', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final c in AvatarPref.colors)
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _save(_a.copyWith(kind: 'emoji', color: c)),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(c),
                    border: Border.all(color: _a.color == c ? LagoColors.pink : Colors.black12, width: _a.color == c ? 3 : 1),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 18),
          FilledButton(onPressed: () => Navigator.pop(context), child: const T('Terminé')),
        ]),
      ),
    );
  }
}
