import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../l10n/l10n.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// v5 — « Vos données » : ce que LaGo garde, où, et ce qu'il ne fait jamais.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AppState.instance.user;
    final server = user?.isServer ?? false;
    Widget item(IconData icon, Color color, String title, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                T(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                T(text, style: const TextStyle(fontSize: 13.5, height: 1.35)),
              ]),
            ),
          ]),
        );
    return Scaffold(
      appBar: AppBar(title: const T('Vos données')),
      body: LagoBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
          children: [
            GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle('Nos engagements', icon: Icons.verified_user_outlined, iconColor: LagoColors.green),
                item(Icons.block, LagoColors.danger, 'Aucune publicité', 'LaGo n’affiche aucune publicité et n’en affichera jamais.'),
                item(Icons.money_off, LagoColors.danger, 'Aucune revente', 'Vos données ne sont ni vendues, ni louées, ni partagées avec des annonceurs.'),
                item(Icons.lock_outline, LagoColors.pink, 'Code PIN sur le téléphone',
                    'Votre code PIN ne quitte jamais votre téléphone. Le bouton cadenas masque l’application en un geste.'),
                item(Icons.visibility_off_outlined, LagoColors.purple, 'Notes personnelles privées',
                    'Même avec le suivi parental, vos notes ne sont jamais partagées.'),
                item(Icons.groups_outlined, LagoColors.teal, 'Statistiques anonymes uniquement',
                    'Les ONG partenaires ne reçoivent que des chiffres globaux, calculés sur des groupes d’au moins 10 personnes, sans nom ni email.'),
              ]),
            ),
            const SizedBox(height: 14),
            GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle('Où sont vos données ?', icon: Icons.storage_outlined),
                if (user?.isAnonymous ?? false)
                  item(Icons.phone_android, LagoColors.green, 'Mode anonyme',
                      'Votre compte n’a pas d’email et rien n’est envoyé sur internet. Pensez à exporter une sauvegarde : si vous perdez le téléphone, les données sont perdues.')
                else if (server)
                  item(Icons.cloud_outlined, LagoColors.pink, 'Téléphone + serveur LaGo',
                      'Vos données sont sur votre téléphone et synchronisées de façon chiffrée (HTTPS) avec le serveur LaGo, pour les retrouver sur un nouveau téléphone.')
                else
                  item(Icons.phone_android, LagoColors.green, 'Uniquement sur ce téléphone',
                      'Votre compte est local : rien n’est envoyé sur internet.'),
                item(Icons.download_outlined, LagoColors.gold, 'Export et suppression',
                    'Dans Profil › Confidentialité & sauvegarde : exportez vos données, effacez-les ou supprimez votre compte à tout moment.'),
                item(Icons.sms_outlined, LagoColors.teal, 'Rappels SMS / WhatsApp',
                    'Votre numéro n’est utilisé que si vous activez ces rappels, et il est effacé dès que vous les arrêtez.'),
              ]),
            ),
            const SizedBox(height: 14),
            T('Pour toute question sur vos données, écrivez à l’équipe LaGo depuis la fiche de l’application.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: mutedColor(context))),
          ],
        ),
      ),
    );
  }
}

/// v5 — Création d'un compte anonyme (sans email, sur ce téléphone uniquement).
class AnonymousSignupScreen extends StatefulWidget {
  const AnonymousSignupScreen({super.key});

  @override
  State<AnonymousSignupScreen> createState() => _AnonymousSignupScreenState();
}

class _AnonymousSignupScreenState extends State<AnonymousSignupScreen> {
  final state = AppState.instance;
  final _pseudo = TextEditingController();
  final _secret = TextEditingController();
  final _age = TextEditingController();
  bool _accept = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pseudo.dispose();
    _secret.dispose();
    _age.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final age = int.tryParse(_age.text.trim());
    if (age != null && (age < 10 || age > 99)) {
      setState(() => _error = 'Âge invalide.');
      return;
    }
    if (!_accept) {
      setState(() => _error = 'Merci de cocher la case pour continuer.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await state.auth.registerAnonymous(_pseudo.text, _secret.text, age);
    if (!mounted) return;
    if (!res.success) {
      setState(() {
        _busy = false;
        _error = res.message;
      });
      return;
    }
    final navigator = Navigator.of(context);
    showToast(context, '🌸 Votre identifiant : ${res.user!.email} — notez-le avec votre code secret.');
    await state.afterLogin();
    navigator.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const T('Utiliser LaGo anonymement')),
      body: LagoBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
          children: [
            GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle('Sans email, rien sur internet', icon: Icons.privacy_tip_outlined,
                    subtitle: 'Vos données restent uniquement sur ce téléphone.'),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: T(_error!, style: const TextStyle(color: LagoColors.danger, fontWeight: FontWeight.w600)),
                  ),
                TextField(controller: _pseudo, decoration: InputDecoration(labelText: tr('Pseudo (ex. lune42)'))),
                const SizedBox(height: 10),
                TextField(
                  controller: _secret,
                  obscureText: true,
                  decoration: InputDecoration(labelText: tr('Code secret (4 caractères minimum)')),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _age,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: tr('Âge (optionnel, pour adapter les conseils)')),
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _accept,
                  onChanged: (v) => setState(() => _accept = v ?? false),
                  title: const T(
                      'J’ai compris : sans email, il n’y a pas de récupération possible. Si je perds le téléphone ou le code, mes données sont perdues (sauf sauvegarde exportée).',
                      style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _busy ? null : _create,
                  icon: const Icon(Icons.check),
                  label: const T('Commencer'),
                ),
                const SizedBox(height: 8),
                T('Pour vous reconnecter : identifiant « pseudo@anonyme » et votre code secret.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: mutedColor(context))),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
