import 'dart:math';

import 'api.dart';
import 'models.dart';
import 'storage.dart';
import 'utils.dart';

/// Données d'un enfant suivie par un compte parent.
/// Les notes personnelles ne sont JAMAIS partagées.
class ChildData {
  final String id;
  final String name;
  final int? age;
  final String? linkedAt;
  final CycleSettings? settings;
  final Map<String, DayLog> logs;
  const ChildData({required this.id, required this.name, this.age, this.linkedAt, this.settings, this.logs = const {}});

  bool get hasCycle => settings != null;

  factory ChildData.fromJson(Map<String, dynamic> j) {
    final logs = <String, DayLog>{};
    if (j['logs'] is Map) {
      (j['logs'] as Map).forEach((date, v) {
        if (v is Map && Dates.parseIso('$date') != null) {
          // Par sécurité, les notes sont retirées même si elles étaient présentes.
          final m = Map<String, dynamic>.from(v)..remove('notes');
          logs['$date'] = DayLog.fromJson(m);
        }
      });
    }
    return ChildData(
      id: '${j['id']}',
      name: '${j['name'] ?? ''}',
      age: j['age'] is int ? j['age'] as int : int.tryParse('${j['age'] ?? ''}'),
      linkedAt: j['linkedAt'] as String?,
      settings: j['settings'] is Map ? CycleSettings.fromJson(Map<String, dynamic>.from(j['settings'] as Map)) : null,
      logs: logs,
    );
  }
}

/// Personne qui suit le cycle de l'utilisatrice (vue côté enfant).
class Follower {
  final String id;
  final String name;
  final String email;
  final String? linkedAt;
  const Follower({required this.id, required this.name, this.email = '', this.linkedAt});
}

class FamilyResult<T> {
  final T? value;
  final String? error;
  const FamilyResult.ok(this.value) : error = null;
  const FamilyResult.fail(this.error) : value = null;
  bool get ok => error == null;
}

/// Suivi parental :
///  1. l'enfant crée un code d'invitation (valable 48 h) dans son profil ;
///  2. le parent saisit ce code dans « Mes enfants » ;
///  3. l'enfant voit qui la suit et peut retirer l'accès à tout moment.
/// Avec un serveur, tout passe par l'API. Sans serveur, les deux comptes doivent être sur le même téléphone.
class FamilyService {
  static const _kInvites = 'lago_family_invites';
  static const _kLinks = 'lago_family_links';
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const inviteTtl = Duration(hours: 48);

  final AppUser user;
  FamilyService(this.user);

  // ------------------------------------------------------------------ Côté enfant
  Future<FamilyResult<(String, DateTime)>> createInvite() async {
    if (user.isServer) {
      final res = await Api.familyInvite();
      if (res.ok && res.data?['code'] is String) {
        final exp = DateTime.tryParse('${res.data!['expiresAt']}')?.toLocal() ?? DateTime.now().add(inviteTtl);
        return FamilyResult.ok((res.data!['code'] as String, exp));
      }
      return FamilyResult.fail(res.offline ? 'Connexion au serveur requise.' : res.message('Échec.'));
    }
    final invites = _invites..removeWhere((code, v) => v['childId'] == user.id || _expired(v));
    final rnd = Random.secure();
    String code;
    do {
      code = List.generate(6, (_) => _alphabet[rnd.nextInt(_alphabet.length)]).join();
    } while (invites.containsKey(code));
    final exp = DateTime.now().add(inviteTtl);
    invites[code] = {'childId': user.id, 'expiresAt': exp.toIso8601String()};
    await Store.writeJson(_kInvites, invites);
    return FamilyResult.ok((code, exp));
  }

  Future<FamilyResult<List<Follower>>> followers() async {
    if (user.isServer) {
      final res = await Api.familyFollowers();
      if (!res.ok) return FamilyResult.fail(res.offline ? 'Connexion au serveur requise.' : res.message('Échec.'));
      final list = (res.data?['followers'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => Follower(id: '${m['id']}', name: '${m['name'] ?? ''}', email: '${m['email'] ?? ''}', linkedAt: m['linkedAt'] as String?))
          .toList();
      return FamilyResult.ok(list);
    }
    final users = _localUsers;
    final list = _links.where((l) => l['childId'] == user.id).map((l) {
      final p = users.firstWhere((u) => u['id'] == l['parentId'], orElse: () => const {});
      return Follower(id: '${l['parentId']}', name: '${p['name'] ?? '?'}', email: '${p['email'] ?? ''}', linkedAt: l['createdAt'] as String?);
    }).toList();
    return FamilyResult.ok(list);
  }

  // ------------------------------------------------------------------ Côté parent
  Future<FamilyResult<String>> link(String rawCode) async {
    final code = rawCode.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (code.length != 6) return const FamilyResult.fail('Le code contient 6 caractères.');
    if (user.isServer) {
      final res = await Api.familyLink(code);
      if (res.ok) return FamilyResult.ok('${(res.data?['child'] as Map?)?['name'] ?? ''}');
      return FamilyResult.fail(res.offline ? 'Connexion au serveur requise.' : res.message('Code invalide ou expiré.'));
    }
    final invites = _invites;
    final inv = invites[code];
    if (inv == null || _expired(inv) || inv['childId'] == user.id) return const FamilyResult.fail('Code invalide ou expiré.');
    final childId = '${inv['childId']}';
    final child = _localUsers.firstWhere((u) => u['id'] == childId, orElse: () => const {});
    if (child.isEmpty) return const FamilyResult.fail('Code invalide ou expiré.');
    final links = _links;
    if (!links.any((l) => l['parentId'] == user.id && l['childId'] == childId)) {
      links.add({'parentId': user.id, 'childId': childId, 'createdAt': DateTime.now().toIso8601String()});
      await Store.writeJson(_kLinks, links);
    }
    invites.remove(code);
    await Store.writeJson(_kInvites, invites);
    return FamilyResult.ok('${child['name'] ?? ''}');
  }

  Future<FamilyResult<List<ChildData>>> children() async {
    if (user.isServer) {
      final res = await Api.familyChildren();
      if (!res.ok) return FamilyResult.fail(res.offline ? 'Connexion au serveur requise.' : res.message('Échec.'));
      return FamilyResult.ok((res.data?['children'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => ChildData.fromJson(Map<String, dynamic>.from(m)))
          .toList());
    }
    final users = _localUsers;
    final list = <ChildData>[];
    for (final l in _links.where((l) => l['parentId'] == user.id)) {
      final u = users.firstWhere((x) => x['id'] == l['childId'], orElse: () => const {});
      if (u.isEmpty || u['status'] == 'blocked') continue;
      final id = '${u['id']}';
      list.add(ChildData.fromJson({
        'id': id,
        'name': u['name'],
        'age': u['age'],
        'linkedAt': l['createdAt'],
        'settings': Store.readMap('lago_settings_$id'),
        'logs': Store.readMap('lago_logs_$id') ?? {},
      }));
    }
    return FamilyResult.ok(list);
  }

  // ------------------------------------------------------------------ Les deux
  /// Retire le lien avec [otherId] (parent → enfant ou enfant → parent).
  Future<FamilyResult<bool>> unlink(String otherId) async {
    if (user.isServer) {
      final res = await Api.familyUnlink(otherId);
      return res.ok ? const FamilyResult.ok(true) : FamilyResult.fail(res.offline ? 'Connexion au serveur requise.' : res.message('Échec.'));
    }
    final links = _links
      ..removeWhere((l) =>
          (l['parentId'] == user.id && l['childId'] == otherId) || (l['childId'] == user.id && l['parentId'] == otherId));
    await Store.writeJson(_kLinks, links);
    return const FamilyResult.ok(true);
  }

  /// Suppression d'un compte local : retire ses liens et invitations.
  static Future<void> forgetLocal(String uid) async {
    final links = Store.readList(_kLinks).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      ..removeWhere((l) => l['parentId'] == uid || l['childId'] == uid);
    await Store.writeJson(_kLinks, links);
    final invites = (Store.readMap(_kInvites) ?? {})..removeWhere((k, v) => v is Map && v['childId'] == uid);
    await Store.writeJson(_kInvites, invites);
  }

  // ------------------------------------------------------------------ Stockage local
  Map<String, dynamic> get _invites => Map<String, dynamic>.from(Store.readMap(_kInvites) ?? {});
  List<Map<String, dynamic>> get _links => Store.readList(_kLinks).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  List<Map<String, dynamic>> get _localUsers =>
      Store.readList('lago_local_users').whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  static bool _expired(dynamic v) {
    final exp = v is Map ? DateTime.tryParse('${v['expiresAt']}') : null;
    return exp == null || exp.isBefore(DateTime.now());
  }
}
