import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/tracker.dart';
import '../core/utils.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../l10n/l10n.dart';

/// Espace Super Admin :
///  - session serveur : gestion via l'API (droits vérifiés côté serveur)
///  - session locale : gestion des comptes enregistrés sur ce téléphone
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminStats {
  final int totalUsers;
  final int superAdmins;
  final int blockedUsers;
  final int totalLogs;
  final String topSymptom;
  final List<ActivityLog> activity;
  const _AdminStats(this.totalUsers, this.superAdmins, this.blockedUsers, this.totalLogs, this.topSymptom, this.activity);
}

class _AdminScreenState extends State<AdminScreen> {
  final state = AppState.instance;
  List<AppUser> _users = [];
  _AdminStats? _stats;
  bool _loading = true;
  String? _error;

  bool get _remote => state.user?.isServer ?? false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_remote) {
        final u = await Api.adminUsers();
        final s = await Api.adminStats();
        if (!u.ok || !s.ok) {
          _error = (u.offline || s.offline) ? 'Serveur injoignable.' : u.message(s.message('Accès refusé.'));
        } else {
          _users = ((u.data?['users'] as List?) ?? [])
              .whereType<Map>()
              .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e), mode: 'server'))
              .toList();
          final st = Map<String, dynamic>.from((s.data?['stats'] as Map?) ?? {});
          final top = st['topSymptom'] is Map ? Map<String, dynamic>.from(st['topSymptom'] as Map) : null;
          _stats = _AdminStats(
            (st['totalUsers'] as num?)?.toInt() ?? _users.length,
            (st['superAdmins'] as num?)?.toInt() ?? 0,
            (st['blockedUsers'] as num?)?.toInt() ?? 0,
            (st['totalLogs'] as num?)?.toInt() ?? 0,
            top == null ? '—' : '${top['label']} (${top['count']})',
            ((st['activityLogs'] as List?) ?? []).whereType<Map>().map((e) => ActivityLog.fromJson(Map<String, dynamic>.from(e))).toList(),
          );
        }
      } else {
        final local = state.auth.localUsers;
        _users = local.map((m) => AppUser.fromJson({...m, 'logsCount': Tracker.countLogs('${m['id']}')}, mode: 'local')).toList();
        final counts = <String, int>{};
        var total = 0;
        for (final u in _users) {
          Tracker.rawLogs(u.id).forEach((_, v) {
            total++;
            if (v is Map && v['symptoms'] is List) {
              for (final s in v['symptoms'] as List) {
                counts['$s'] = (counts['$s'] ?? 0) + 1;
              }
            }
          });
        }
        final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        _stats = _AdminStats(
          _users.length,
          _users.where((u) => u.isAdmin).length,
          _users.where((u) => u.isBlocked).length,
          total,
          sorted.isEmpty ? '—' : '${Symptom.of(sorted.first.key).label} (${sorted.first.value})',
          state.auth.activityLogs,
        );
      }
    } catch (e) {
      _error = 'Erreur : $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  // ------------------------------------------------------------------ Actions
  Future<void> _toggleRole(AppUser u) async {
    final newRole = u.isAdmin ? 'user' : 'superadmin';
    if (!await confirmDialog(context, 'Attribuer le rôle « ${newRole == 'superadmin' ? 'Super Admin' : 'Utilisatrice'} » à ${u.name} ?')) return;
    String? err;
    if (_remote) {
      final r = await Api.adminSetRole(u.id, newRole);
      if (!r.ok) err = r.message('Serveur injoignable.');
    } else {
      final list = state.auth.localUsers;
      if (u.isAdmin && list.where((x) => x['role'] == 'superadmin').length <= 1) {
        err = 'Impossible de rétrograder le dernier Super Admin.';
      } else {
        for (final x in list) {
          if (x['id'] == u.id) x['role'] = newRole;
        }
        await state.auth.saveLocalUsers(list);
        await state.auth.logActivity('Rôle de ${u.name} changé en $newRole');
      }
    }
    _after(err, 'Rôle de ${u.name} mis à jour.');
  }

  Future<void> _toggleStatus(AppUser u) async {
    final newStatus = u.isBlocked ? 'active' : 'blocked';
    final msg = newStatus == 'blocked' ? 'Suspendre le compte de ${u.name} ? Elle ne pourra plus se connecter.' : 'Réactiver le compte de ${u.name} ?';
    if (!await confirmDialog(context, msg)) return;
    String? err;
    if (_remote) {
      final r = await Api.adminSetStatus(u.id, newStatus);
      if (!r.ok) err = r.message('Serveur injoignable.');
    } else {
      final list = state.auth.localUsers;
      for (final x in list) {
        if (x['id'] == u.id) x['status'] = newStatus;
      }
      await state.auth.saveLocalUsers(list);
      await state.auth.logActivity('Compte de ${u.name} ${newStatus == 'blocked' ? 'suspendu' : 'réactivé'}');
    }
    _after(err, 'Compte de ${u.name} ${newStatus == 'blocked' ? 'suspendu' : 'réactivé'}.');
  }

  Future<void> _delete(AppUser u) async {
    if (!await confirmDialog(context, 'Supprimer définitivement le compte de ${u.name} et toutes ses données ?', danger: true, okLabel: 'Supprimer')) {
      return;
    }
    String? err;
    if (_remote) {
      final r = await Api.adminDeleteUser(u.id);
      if (!r.ok) err = r.message('Serveur injoignable.');
    } else {
      final list = state.auth.localUsers;
      if (u.isAdmin && list.where((x) => x['role'] == 'superadmin').length <= 1) {
        err = 'Impossible de supprimer le dernier Super Admin.';
      } else {
        list.removeWhere((x) => x['id'] == u.id);
        await state.auth.saveLocalUsers(list);
        await Tracker.purge(u.id);
        await state.auth.logActivity('Utilisateur ${u.name} supprimé');
      }
    }
    _after(err, 'Compte de ${u.name} supprimé.');
  }

  Future<void> _create() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final age = TextEditingController();
    final pass = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const T('Ajouter une utilisatrice'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: InputDecoration(labelText: tr('Prénom'))),
            const SizedBox(height: 10),
            TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: tr('Adresse email'))),
            const SizedBox(height: 10),
            TextField(controller: age, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('Âge (optionnel)'))),
            const SizedBox(height: 10),
            TextField(controller: pass, decoration: InputDecoration(labelText: tr('Mot de passe temporaire (6 min.)'))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const T('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const T('Créer le compte')),
        ],
      ),
    );
    final n = name.text.trim(), e = email.text.trim().toLowerCase(), p = pass.text;
    final a = int.tryParse(age.text.trim());
    for (final c in [name, email, age, pass]) {
      c.dispose();
    }
    if (ok != true) return;
    if (n.isEmpty || !isValidEmail(e) || p.length < 6) {
      if (mounted) showToast(context, 'Prénom, email valide et mot de passe (6 caractères min.) requis.', type: ToastType.error);
      return;
    }
    String? err;
    if (_remote) {
      final r = await Api.adminCreateUser(n, e, p, a);
      if (!r.ok) err = r.message('Serveur injoignable.');
    } else {
      final list = state.auth.localUsers;
      if (list.any((x) => x['email'] == e)) {
        err = 'Un compte existe déjà avec cet email.';
      } else {
        list.add({
          'id': newId(),
          'name': n,
          'email': e,
          'role': 'user',
          'age': a,
          'status': 'active',
          'createdAt': DateTime.now().toIso8601String(),
          'passwordHash': Secrets.hash(p),
        });
        await state.auth.saveLocalUsers(list);
        await state.auth.logActivity('Création manuelle de $n par le Super Admin');
      }
    }
    _after(err, 'Utilisatrice $n créée avec succès !');
  }

  void _after(String? err, String success) {
    if (!mounted) return;
    showToast(context, err ?? success, type: err == null ? ToastType.success : ToastType.error);
    if (err == null) _refresh();
  }

  // ------------------------------------------------------------------ Interface
  @override
  Widget build(BuildContext context) {
    final me = state.user;
    return RefreshIndicator(
      color: LagoColors.pink,
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
        children: [
          SectionTitle(
            'Panneau Super Admin 👑',
            icon: Icons.admin_panel_settings,
            iconColor: LagoColors.goldDeep,
            subtitle: _remote ? 'Source : base de données serveur' : 'Source : comptes de ce téléphone (mode local)',
            trailing: IconButton(tooltip: tr('Actualiser'), onPressed: _refresh, icon: const Icon(Icons.refresh)),
          ),
          FilledButton.icon(onPressed: _create, icon: const Icon(Icons.person_add_alt_1), label: const T('Ajouter une utilisatrice')),
          const SizedBox(height: 14),
          if (_loading) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(color: LagoColors.pink))),
          if (!_loading && _error != null)
            GlassCard(child: T(_error!, style: const TextStyle(color: LagoColors.danger, fontWeight: FontWeight.w600))),
          if (!_loading && _error == null && _stats != null) ...[
            _kpis(context, _stats!),
            const SizedBox(height: 16),
            T('👥 Utilisatrices & droits d’accès', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final u in _users) _userCard(context, u, u.id == me?.id),
            const SizedBox(height: 16),
            T('Journal d’événements', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _activity(_stats!.activity),
          ],
        ],
      ),
    );
  }

  Widget _kpis(BuildContext context, _AdminStats s) {
    final items = [
      (Icons.people_outline, LagoColors.pink, '${s.totalUsers}', 'Utilisatrices'),
      (Icons.event_available, LagoColors.green, '${s.totalLogs}', 'Journaux'),
      (Icons.monitor_heart_outlined, LagoColors.purple, s.topSymptom, 'Symptôme fréquent'),
      (Icons.workspace_premium_outlined, LagoColors.goldDeep, '${s.superAdmins} admin · ${s.blockedUsers} suspendu(s)', 'Privilèges'),
    ];
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items
            .map((k) => SizedBox(
                  width: w,
                  child: GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(k.$1, color: k.$2),
                      const SizedBox(height: 6),
                      T(k.$3, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      T(k.$4.toUpperCase(), style: TextStyle(fontSize: 10.5, letterSpacing: 0.5, color: mutedColor(context))),
                    ]),
                  ),
                ))
            .toList(),
      );
    });
  }

  Widget _userCard(BuildContext context, AppUser u, bool isSelf) {
    final created = DateTime.tryParse(u.createdAt ?? '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(children: [
          UserAvatar(admin: u.isAdmin, size: 40, avatar: isSelf ? AppState.instance.avatar : null),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              T('${u.name}${isSelf ? ' (vous)' : ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
              T(u.email, style: TextStyle(fontSize: 12, color: mutedColor(context))),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _pill(u.isAdmin ? '👑 Super Admin' : '🌸 Utilisatrice', u.isAdmin ? LagoColors.goldDeep : LagoColors.pink),
                _pill(u.isBlocked ? '■ Suspendu' : '● Actif', u.isBlocked ? LagoColors.danger : LagoColors.green),
                if (u.isParent) _pill('👨‍👩‍👧 Compte parent', LagoColors.teal),
                if (u.age != null) _pill('${u.age} ans', LagoColors.purple),
                if (created != null) _pill('Inscrite le ${Dates.short(created.toLocal())}', LagoColors.textMuted),
                _pill('${u.logsCount} journaux', LagoColors.teal),
              ]),
            ]),
          ),
          if (!isSelf)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'role') _toggleRole(u);
                if (v == 'status') _toggleStatus(u);
                if (v == 'delete') _delete(u);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'role', child: T(u.isAdmin ? 'Rétrograder en utilisatrice' : 'Promouvoir Super Admin')),
                PopupMenuItem(value: 'status', child: T(u.isBlocked ? 'Réactiver le compte' : 'Suspendre le compte')),
                const PopupMenuItem(value: 'delete', child: T('Supprimer', style: TextStyle(color: LagoColors.danger))),
              ],
            ),
        ]),
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
        child: T(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );

  Widget _activity(List<ActivityLog> logs) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xEB1E141C), borderRadius: BorderRadius.circular(16)),
      child: logs.isEmpty
          ? const T('Aucune activité récente enregistrée.', style: TextStyle(color: Color(0xFFF8BBD0), fontStyle: FontStyle.italic))
          : ListView.builder(
              shrinkWrap: true,
              itemCount: logs.length,
              itemBuilder: (_, i) {
                final l = logs[i];
                final t = DateTime.tryParse(l.timestamp)?.toLocal();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: '[${t == null ? '?' : Dates.dateTime(t)}] ', style: const TextStyle(color: Color(0xFFFFB74D))),
                    TextSpan(text: l.action, style: const TextStyle(color: Color(0xFFF8BBD0))),
                  ]), style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                );
              },
            ),
    );
  }
}
