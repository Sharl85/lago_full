import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../l10n/l10n.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// v5 — Rappels de règles par SMS ou WhatsApp (pour celles qui ouvrent peu l'application).
class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  final state = AppState.instance;
  final _phone = TextEditingController(text: '+237');
  bool _loading = true;
  bool _serverEnabled = false;
  List<String> _channels = const [];
  String _channel = 'sms';
  bool _discreet = true;
  bool _consent = false;
  int _daysBefore = 2;
  bool _active = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await Api.messagingGet();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok && r.data != null) {
        _serverEnabled = r.data!['enabled'] == true;
        _channels = (r.data!['channels'] is List) ? (r.data!['channels'] as List).map((e) => '$e').toList() : const [];
        if (_channels.isNotEmpty && !_channels.contains(_channel)) _channel = _channels.first;
        final sub = r.data!['subscription'];
        if (sub is Map) {
          _active = sub['enabled'] == true;
          _phone.text = '${sub['phone'] ?? _phone.text}';
          if (_channels.contains(sub['channel'])) _channel = sub['channel'] as String;
          _discreet = sub['discreet'] != false;
          _consent = true;
          _daysBefore = sub['daysBefore'] is int ? sub['daysBefore'] as int : 2;
        }
      }
    });
  }

  Future<void> _save() async {
    if (!_consent) {
      showToast(context, 'Cochez la case d’accord pour recevoir des messages.', type: ToastType.error);
      return;
    }
    final r = await Api.messagingSet({
      'enabled': true,
      'phone': _phone.text.replaceAll(RegExp(r'[\s.-]'), ''),
      'channel': _channel,
      'consent': true,
      'discreet': _discreet,
      'daysBefore': _daysBefore,
    });
    if (!mounted) return;
    if (r.ok) {
      setState(() => _active = true);
      showToast(context, '🌸 Rappels activés.');
    } else {
      showToast(context, r.offline ? 'Connexion impossible.' : r.message('Enregistrement impossible.'), type: ToastType.error);
    }
  }

  Future<void> _disable() async {
    final r = await Api.messagingSet({'enabled': false});
    if (!mounted) return;
    if (r.ok) {
      setState(() => _active = false);
      showToast(context, 'Rappels désactivés. Votre numéro a été effacé.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final serverUser = state.user?.isServer ?? false;
    return Scaffold(
      appBar: AppBar(title: const T('Rappels SMS & WhatsApp')),
      body: LagoBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
                children: [
                  if (!serverUser || !_serverEnabled)
                    GlassCard(
                      child: T(
                        !serverUser
                            ? 'Les rappels par SMS ou WhatsApp nécessitent un compte synchronisé avec le serveur LaGo.'
                            : 'Les rappels par SMS / WhatsApp ne sont pas encore activés sur le serveur LaGo.',
                        style: TextStyle(color: mutedColor(context)),
                      ),
                    )
                  else
                    GlassCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        const SectionTitle('Recevoir un rappel par message', icon: Icons.sms_outlined,
                            subtitle: 'Avant vos règles et le jour prévu, même sans ouvrir l’application.'),
                        TextField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(labelText: tr('Numéro au format international'), hintText: '+237 6XX XX XX XX'),
                        ),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, children: [
                          for (final c in _channels)
                            ChoiceChip(
                              label: T(c == 'whatsapp' ? 'WhatsApp' : 'SMS'),
                              selected: _channel == c,
                              onSelected: (_) => setState(() => _channel = c),
                            ),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          const Expanded(child: T('Prévenir avant les règles')),
                          IconButton(onPressed: _daysBefore > 1 ? () => setState(() => _daysBefore--) : null, icon: const Icon(Icons.remove)),
                          T('$_daysBefore j', style: const TextStyle(fontWeight: FontWeight.w700)),
                          IconButton(onPressed: _daysBefore < 5 ? () => setState(() => _daysBefore++) : null, icon: const Icon(Icons.add)),
                        ]),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const T('Message discret'),
                          subtitle: const T('Aucun mot lié aux règles dans le message (recommandé si le téléphone est partagé).'),
                          value: _discreet,
                          onChanged: (v) => setState(() => _discreet = v),
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _consent,
                          onChanged: (v) => setState(() => _consent = v ?? false),
                          title: const T(
                              'J’accepte que LaGo utilise mon numéro uniquement pour m’envoyer ces rappels. Je peux les arrêter à tout moment.',
                              style: TextStyle(fontSize: 13)),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                            onPressed: _save, icon: const Icon(Icons.check), label: T(_active ? 'Mettre à jour' : 'Activer les rappels')),
                        if (_active)
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: LagoColors.danger),
                            onPressed: _disable,
                            icon: const Icon(Icons.block),
                            label: const T('Arrêter les rappels et effacer mon numéro'),
                          ),
                      ]),
                    ),
                ],
              ),
      ),
    );
  }
}
