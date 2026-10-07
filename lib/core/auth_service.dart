import 'api.dart';
import 'avatar.dart';
import 'appointments.dart';
import 'avatar_vault.dart';
import 'family.dart';
import 'models.dart';
import 'storage.dart';
import 'tracker.dart';
import 'utils.dart';

class AuthResult {
  final bool success;
  final String? message;
  final AppUser? user;
  final bool offline;
  const AuthResult.ok(this.user, {this.offline = false})
      : success = true,
        message = null;
  const AuthResult.fail(this.message)
      : success = false,
        user = null,
        offline = false;
}

/// Authentification :
///  - mode serveur : comptes gérés par l'API (jeton signé)
///  - mode local : repli hors-ligne / sans serveur (comptes sur l'appareil, mots de passe hachés)
class AuthService {
  static const kSession = 'lago_current_session';
  static const kLocalUsers = 'lago_local_users';
  static const kActivity = 'lago_admin_activity_logs';
  static const kDemoDone = 'lago_demo_autologin_done';

  /// Comptes de démonstration (désactivables au build : --dart-define=DEMO_MODE=false)
  static const demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: true);

  static const demoAccounts = [
    {'id': 'usr_admin_001', 'name': 'Directrice LaGo', 'email': 'admin@lago.app', 'password': 'admin123', 'role': 'superadmin', 'age': 28},
    {'id': 'usr_sarah_002', 'name': 'Sarah', 'email': 'sarah@lago.app', 'password': 'user123', 'role': 'user', 'age': 17},
    {'id': 'usr_lea_003', 'name': 'Léa', 'email': 'lea@lago.app', 'password': 'user123', 'role': 'user', 'age': 16},
  ];

  // ------------------------------------------------------------------ Session
  AppUser? get currentUser {
    final m = Store.readMap(kSession);
    return m == null ? null : AppUser.fromJson(m);
  }

  Future<void> saveSession(AppUser u) async {
    await Store.writeJson(kSession, u.toJson());
    Api.token = u.token;
  }

  Future<void> clearSession() async {
    await Store.remove(kSession);
    Api.token = null;
  }

  /// Au démarrage : vérifie la session serveur et connecte Sarah au tout premier lancement (démo).
  Future<void> init() async {
    final s = currentUser;
    if (s != null && s.isServer) {
      Api.token = s.token;
      final res = await Api.me();
      if (res.ok && res.data?['user'] is Map) {
        await saveSession(AppUser.fromJson(Map<String, dynamic>.from(res.data!['user'] as Map), mode: 'server', token: s.token));
      } else if (!res.offline && (res.status == 401 || res.status == 403)) {
        await clearSession();
      }
    }
    // La connexion est obligatoire : plus de connexion automatique au compte démo.
  }

  // ------------------------------------------------------------------ Comptes locaux
  List<Map<String, dynamic>> get localUsers =>
      Store.readList(kLocalUsers).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  Future<void> saveLocalUsers(List<Map<String, dynamic>> users) => Store.writeJson(kLocalUsers, users);

  Future<void> ensureLocalDemoAccounts() async {
    if (!demoMode) return;
    final users = localUsers;
    var changed = false;
    for (final d in demoAccounts) {
      if (users.any((u) => u['email'] == d['email'])) continue;
      users.add({
        'id': d['id'],
        'name': d['name'],
        'email': d['email'],
        'role': d['role'],
        'age': d['age'],
        'status': 'active',
        'createdAt': DateTime.now().toIso8601String(),
        'passwordHash': Secrets.hash('${d['password']}'),
      });
      changed = true;
      if (d['id'] == 'usr_sarah_002') await Tracker.seedSample('usr_sarah_002');
    }
    if (changed) await saveLocalUsers(users);
  }

  // ------------------------------------------------------------------ Connexion / inscription
  Future<AuthResult> login(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || password.isEmpty) return const AuthResult.fail('Email et mot de passe requis.');

    final res = await Api.login(cleanEmail, password);
    if (res.ok && res.data?['user'] is Map) {
      final u = AppUser.fromJson(Map<String, dynamic>.from(res.data!['user'] as Map), mode: 'server', token: res.data!['token'] as String?);
      await saveSession(u);
      await AvatarVault.rememberKey(u.id, password);
      return AuthResult.ok(u);
    }
    if (!res.offline) return AuthResult.fail(res.message('Connexion impossible.'));

    // Repli local
    await ensureLocalDemoAccounts();
    final match = localUsers.where((u) => u['email'] == cleanEmail).toList();
    if (match.isEmpty || !Secrets.verify(password, match.first['passwordHash'] as String?)) {
      return AuthResult.fail(Api.enabled ? 'Email ou mot de passe incorrect (mode hors-ligne).' : 'Email ou mot de passe incorrect.');
    }
    final u = AppUser.fromJson(match.first, mode: 'local');
    if (u.isBlocked) return const AuthResult.fail('Ce compte a été suspendu par le Super Admin.');
    await saveSession(u);
    await logActivity('Connexion de ${u.name} (${u.role})');
    return AuthResult.ok(u, offline: Api.enabled);
  }

  Future<AuthResult> register(String name, String email, String password, int? age,
      {Map<String, dynamic>? settings, String accountType = 'member'}) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    if (cleanName.isEmpty) return const AuthResult.fail('Le prénom est obligatoire.');
    if (!isValidEmail(cleanEmail)) return const AuthResult.fail('Adresse email invalide.');
    if (password.length < 6) return const AuthResult.fail('Le mot de passe doit contenir au moins 6 caractères.');

    final res = await Api.register(cleanName, cleanEmail, password, age, settings: settings, accountType: accountType);
    if (res.ok && res.data?['user'] is Map) {
      final u = AppUser.fromJson(Map<String, dynamic>.from(res.data!['user'] as Map), mode: 'server', token: res.data!['token'] as String?);
      await saveSession(u);
      await AvatarVault.rememberKey(u.id, password);
      return AuthResult.ok(u);
    }
    if (!res.offline) return AuthResult.fail(res.message('Inscription impossible.'));

    final users = localUsers;
    if (users.any((u) => u['email'] == cleanEmail)) {
      return const AuthResult.fail('Un compte existe déjà avec cette adresse email sur cet appareil.');
    }
    final data = {
      'id': newId(),
      'name': cleanName.length > 60 ? cleanName.substring(0, 60) : cleanName,
      'email': cleanEmail,
      'role': 'user',
      'accountType': accountType == 'parent' ? 'parent' : 'member',
      'age': age,
      'status': 'active',
      'createdAt': DateTime.now().toIso8601String(),
      'passwordHash': Secrets.hash(password),
    };
    users.add(data);
    await saveLocalUsers(users);
    await logActivity('Inscription de ${data['name']}');
    final u = AppUser.fromJson(data, mode: 'local');
    await saveSession(u);
    return AuthResult.ok(u, offline: Api.enabled);
  }

  Future<void> logout() async {
    final u = currentUser;
    if (u != null) {
      await logActivity('Déconnexion de ${u.name}');
      if (u.isServer) await Tracker.clearCacheIfSynced(u.id);
    }
    await clearSession();
  }

  Future<AuthResult> changePassword(String current, String next) async {
    final u = currentUser;
    if (u == null) return const AuthResult.fail('Non connectée.');
    if (next.length < 6) return const AuthResult.fail('Le nouveau mot de passe doit contenir au moins 6 caractères.');
    if (u.isServer) {
      final res = await Api.changePassword(current, next);
      if (res.ok) {
        // La clé de chiffrement de la photo dépend du mot de passe : on la renouvelle.
        await AvatarVault.onPasswordChanged(u.id, next);
        return AuthResult.ok(u);
      }
      return AuthResult.fail(res.offline ? 'Connexion au serveur requise.' : res.message('Échec.'));
    }
    final users = localUsers;
    final idx = users.indexWhere((x) => x['id'] == u.id);
    if (idx < 0 || !Secrets.verify(current, users[idx]['passwordHash'] as String?)) {
      return const AuthResult.fail('Mot de passe actuel incorrect.');
    }
    users[idx]['passwordHash'] = Secrets.hash(next);
    await saveLocalUsers(users);
    return AuthResult.ok(u);
  }

  Future<AuthResult> deleteOwnAccount() async {
    final u = currentUser;
    if (u == null) return const AuthResult.fail('Non connectée.');
    if (u.isServer) {
      final res = await Api.deleteAccount();
      if (!res.ok) return AuthResult.fail(res.offline ? 'Connexion au serveur requise.' : res.message('Échec.'));
    } else {
      final users = localUsers;
      final admins = users.where((x) => x['role'] == 'superadmin').length;
      if (u.isAdmin && admins <= 1) return const AuthResult.fail('Impossible de supprimer le dernier Super Admin.');
      users.removeWhere((x) => x['id'] == u.id);
      await saveLocalUsers(users);
    }
    await Tracker.purge(u.id);
    await FamilyService.forgetLocal(u.id);
    await Appointments.purge(u.id);
    await AvatarVault.forget(u.id);
    await Store.remove('lago_avatar_${u.id}');
    await AvatarPref.deletePhotos(u.id);
    await clearSession();
    return const AuthResult.ok(null);
  }

  // ------------------------------------------------------------------ Journal d'activité local
  Future<void> logActivity(String action) async {
    final logs = Store.readList(kActivity);
    logs.insert(0, {'timestamp': DateTime.now().toIso8601String(), 'action': action});
    await Store.writeJson(kActivity, logs.take(50).toList());
  }

  List<ActivityLog> get activityLogs => Store.readList(kActivity)
      .whereType<Map>()
      .map((e) => ActivityLog.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}
