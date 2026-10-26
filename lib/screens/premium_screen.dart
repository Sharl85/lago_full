import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/premium.dart';
import '../core/utils.dart';
import '../l10n/l10n.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// v5 — LaGo Premium payé par Mobile Money (MTN MoMo, Orange Money…) via CinetPay.
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> with WidgetsBindingObserver {
  final state = AppState.instance;
  final _phone = TextEditingController();
  String _plan = 'month';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ServerFeatures.refresh().then((_) {
      if (mounted) setState(() {});
    });
    state.refreshPremium().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _phone.dispose();
    super.dispose();
  }

  // Retour dans l'app après la page de paiement : on vérifie le paiement.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      state.refreshPremium().then((ok) {
        if (!mounted) return;
        setState(() {});
        if (ok) showToast(context, '🌸 Merci ! LaGo Premium est activé.');
      });
    }
  }

  Future<void> _pay() async {
    final user = state.user;
    if (user == null || !user.isServer) {
      showToast(context, 'Le paiement nécessite un compte connecté au serveur LaGo.', type: ToastType.error);
      return;
    }
    setState(() => _busy = true);
    final phone = _phone.text.replaceAll(RegExp(r'[\s.-]'), '');
    final err = await Premium.checkout(user.id, _plan, phone: phone.isEmpty ? null : phone);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) showToast(context, err, type: ToastType.error);
  }

  @override
  Widget build(BuildContext context) {
    final plans = ServerFeatures.plans;
    final until = Premium.until == null ? null : DateTime.tryParse(Premium.until!);
    return Scaffold(
      appBar: AppBar(title: const T('LaGo Premium')),
      body: LagoBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
          children: [
            GlassCard(
              gradient: const LinearGradient(colors: [Color(0xFFFFF8E1), Color(0xFFFCE4EC)]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('👑', textAlign: TextAlign.center, style: TextStyle(fontSize: 40)),
                const SizedBox(height: 6),
                T(Premium.active ? 'Premium actif' : 'Soutenez LaGo',
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: LagoColors.textDark)),
                if (Premium.active && until != null)
                  T('Jusqu’au ${Dates.long(until.toLocal())}', textAlign: TextAlign.center, style: const TextStyle(color: LagoColors.textDark)),
                const SizedBox(height: 10),
                const T(
                  'Les fonctions essentielles de LaGo restent gratuites. Le Premium finance le développement, les contenus validés par des professionnels de santé et l’hébergement sécurisé de vos données.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: LagoColors.textDark),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            if (!ServerFeatures.premium)
              GlassCard(
                child: T(
                    state.user?.isServer ?? false
                        ? 'Le paiement Mobile Money n’est pas encore activé sur le serveur LaGo.'
                        : 'Connectez-vous avec un compte synchronisé (serveur LaGo) pour accéder au Premium.',
                    style: TextStyle(color: mutedColor(context))),
              )
            else ...[
              GlassCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const SectionTitle('Choisissez votre formule', icon: Icons.workspace_premium_outlined),
                  for (final p in plans)
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: p.id,
                      // ignore: deprecated_member_use
                      groupValue: _plan,
                      // ignore: deprecated_member_use
                      onChanged: (v) => setState(() => _plan = v ?? 'month'),
                      title: T(p.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: T('${p.amount} ${ServerFeatures.currency}'),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: tr('Numéro Mobile Money (optionnel)'),
                      hintText: '+237 6XX XX XX XX',
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _busy ? null : _pay,
                    icon: _busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.phone_android),
                    label: T(Premium.active ? 'Prolonger avec Mobile Money' : 'Payer avec Mobile Money'),
                  ),
                  const SizedBox(height: 8),
                  T('MTN MoMo, Orange Money, Moov, Wave ou carte bancaire selon votre pays. Paiement sécurisé par CinetPay : LaGo ne voit jamais vos codes.',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: mutedColor(context))),
                ]),
              ),
              if (state.user != null && Premium.hasPending(state.user!.id))
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await state.refreshPremium();
                      if (!context.mounted) return;
                      setState(() {});
                      showToast(context, ok ? '🌸 Premium activé !' : 'Paiement pas encore confirmé. Réessayez dans un instant.',
                          type: ok ? ToastType.success : ToastType.info);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const T('J’ai payé : vérifier mon paiement'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
