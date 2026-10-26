import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'storage.dart';

/// Ouvre un lien externe (paiement, WhatsApp, téléphone, site d'un partenaire).
Future<bool> openExternal(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

class PremiumPlan {
  final String id;
  final String label;
  final int days;
  final int amount;
  const PremiumPlan(this.id, this.label, this.days, this.amount);

  factory PremiumPlan.fromJson(Map<String, dynamic> j) => PremiumPlan(
        '${j['id']}',
        '${j['label']}',
        j['days'] is int ? j['days'] as int : 30,
        j['amount'] is int ? j['amount'] as int : 0,
      );
}

/// v5 — Fonctions activées sur le serveur (paiement, SMS/WhatsApp, assistant…).
/// Sans serveur, tout ce qui fonctionne hors ligne reste disponible.
class ServerFeatures {
  static const _key = 'lago_server_features';

  static bool premium = false;
  static bool messaging = false;
  static bool assistant = false;
  static List<String> messagingChannels = const [];
  static String currency = 'XAF';
  static List<PremiumPlan> plans = const [];

  static void _apply(Map<String, dynamic> d) {
    final p = d['premium'] is Map ? Map<String, dynamic>.from(d['premium'] as Map) : const <String, dynamic>{};
    final m = d['messaging'] is Map ? Map<String, dynamic>.from(d['messaging'] as Map) : const <String, dynamic>{};
    final a = d['assistant'] is Map ? Map<String, dynamic>.from(d['assistant'] as Map) : const <String, dynamic>{};
    premium = p['enabled'] == true;
    currency = p['currency'] is String ? p['currency'] as String : 'XAF';
    plans = (p['plans'] is List)
        ? (p['plans'] as List).whereType<Map>().map((e) => PremiumPlan.fromJson(Map<String, dynamic>.from(e))).toList()
        : const [];
    messaging = m['enabled'] == true;
    messagingChannels = (m['channels'] is List) ? (m['channels'] as List).map((e) => '$e').toList() : const [];
    assistant = a['enabled'] == true;
  }

  static void loadCache() {
    final c = Store.readMap(_key);
    if (c != null) _apply(c);
  }

  static Future<void> refresh() async {
    if (!Api.enabled) return;
    final r = await Api.features();
    if (r.ok && r.data != null) {
      _apply(r.data!);
      await Store.writeJson(_key, r.data);
    }
  }
}

/// v5 — Abonnement Premium payé par Mobile Money (CinetPay).
///
/// Par défaut, AUCUNE fonction existante n'est réservée au Premium : la liste
/// [gatedFeatures] est vide. Pour réserver une fonction, ajoutez sa clé
/// (ex. 'pdf', 'assistant', 'pregnancy') — c'est une décision commerciale.
class Premium {
  static const gatedFeatures = <String>{};

  static bool active = false;
  static String? until;

  static String _key(String uid) => 'lago_premium_$uid';
  static String _pendingKey(String uid) => 'lago_premium_pending_$uid';

  static void load(String uid) {
    final c = Store.readMap(_key(uid));
    until = c?['until'] as String?;
    final u = until == null ? null : DateTime.tryParse(until!);
    active = u != null && u.isAfter(DateTime.now());
  }

  static bool allows(String feature) => !gatedFeatures.contains(feature) || active;

  static Future<void> refresh(String uid) async {
    if (!Api.enabled || Api.token == null) return;
    final r = await Api.premiumStatus();
    if (r.ok && r.data != null) {
      until = r.data!['until'] as String?;
      active = r.data!['premium'] == true;
      await Store.writeJson(_key(uid), {'until': until});
    }
  }

  /// Lance le paiement. Renvoie null si la page de paiement est ouverte, sinon un message d'erreur.
  static Future<String?> checkout(String uid, String plan, {String? phone}) async {
    final r = await Api.premiumCheckout(plan, phone: phone);
    if (r.offline) return 'Connexion impossible. Vérifiez votre accès à internet.';
    if (!r.ok || r.data?['paymentUrl'] is! String) return r.message('Le paiement n’a pas pu démarrer.');
    await Store.setString(_pendingKey(uid), '${r.data!['transactionId']}');
    final opened = await openExternal(r.data!['paymentUrl'] as String);
    return opened ? null : 'Impossible d’ouvrir la page de paiement.';
  }

  /// Au retour dans l'app : vérifie le dernier paiement lancé. Renvoie true si le Premium est actif.
  static Future<bool> verifyPending(String uid) async {
    final tx = Store.getString(_pendingKey(uid));
    if (tx == null || tx.isEmpty) return active;
    final r = await Api.premiumVerify(tx);
    if (r.ok && r.data != null) {
      final status = r.data!['status'];
      if (status == 'ACCEPTED' || status == 'REFUSED') await Store.remove(_pendingKey(uid));
      until = r.data!['until'] as String?;
      active = r.data!['premium'] == true;
      await Store.writeJson(_key(uid), {'until': until});
    }
    return active;
  }

  static bool hasPending(String uid) => (Store.getString(_pendingKey(uid)) ?? '').isNotEmpty;
}
