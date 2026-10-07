import 'dart:convert';

import 'api.dart';
import 'models.dart';
import 'storage.dart';
import 'utils.dart';

enum SyncState { synced, syncing, offline, error, local, guest }

/// Données du cycle et journal de l'utilisatrice connectée.
/// Tout est lu depuis l'appareil (fonctionne hors-ligne) puis synchronisé
/// avec le serveur quand la session est en ligne.
class Tracker {
  String userId = 'default';
  bool isServerSession = false;
  bool _syncing = false;

  String get _kSettings => 'lago_settings_$userId';
  String get _kLogs => 'lago_logs_$userId';
  String get _kPending => 'lago_pending_$userId';
  String get _kPin => 'lago_pin_$userId';

  // ------------------------------------------------------------------ Réglages
  CycleSettings get settings => CycleSettings.fromJson(Store.readMap(_kSettings));

  bool get hasStoredSettings => Store.readMap(_kSettings) != null;

  Future<CycleSettings> saveSettings(CycleSettings s) async {
    final updated = s.copyWith(updatedAt: DateTime.now().toIso8601String());
    await Store.writeJson(_kSettings, updated.toJson());
    await _markPending(settings: true);
    return updated;
  }

  // ------------------------------------------------------------------ Journal
  Map<String, DayLog> get logs {
    final raw = Store.readMap(_kLogs) ?? {};
    final out = <String, DayLog>{};
    raw.forEach((date, v) {
      if (v is Map && Dates.parseIso(date) != null) out[date] = DayLog.fromJson(Map<String, dynamic>.from(v));
    });
    return out;
  }

  DayLog? logFor(String date) => logs[date];

  Future<void> _writeLogs(Map<String, DayLog> l) =>
      Store.writeJson(_kLogs, l.map((k, v) => MapEntry(k, v.toJson())));

  Future<void> saveLog(String date, DayLog log) async {
    final l = logs;
    l[date] = log;
    await _writeLogs(l);
    await _markPending(dates: [date]);
  }

  Future<void> deleteLog(String date) async {
    final l = logs;
    if (l.remove(date) == null) return;
    await _writeLogs(l);
    await _markPending(dates: [date]);
  }

  /// Données de démonstration de Sarah (mode local, créées une seule fois).
  static Future<void> seedSample(String uid) async {
    if (Store.readMap('lago_logs_$uid') != null) return;
    final today = Dates.today();
    final lmp = Dates.addDays(today, -12);
    final now = DateTime.now().toIso8601String();
    String iso(DateTime d) => Dates.toIso(d);
    await Store.writeJson('lago_settings_$uid', {'lastPeriodDate': iso(lmp), 'cycleLength': 28, 'periodDuration': 5});
    await Store.writeJson('lago_logs_$uid', {
      iso(lmp): {'flow': 'heavy', 'mood': 'tired', 'temperature': '36.4', 'symptoms': ['cramps', 'fatigue', 'backpain'], 'notes': 'Premier jour de mes règles. Tisane de framboisier et bouillotte.', 'updatedAt': now},
      iso(Dates.addDays(lmp, 1)): {'flow': 'medium', 'mood': 'calm', 'temperature': '36.5', 'symptoms': ['cramps', 'headache'], 'notes': 'Moins mal aujourd’hui. Repos.', 'updatedAt': now},
      iso(Dates.addDays(lmp, 2)): {'flow': 'light', 'mood': 'calm', 'temperature': '36.5', 'symptoms': ['fatigue'], 'notes': 'Flux très léger.', 'updatedAt': now},
      iso(Dates.addDays(today, -1)): {'flow': 'none', 'mood': 'energetic', 'temperature': '36.7', 'symptoms': ['acne'], 'notes': 'Pleine forme pour les cours !', 'updatedAt': now},
      iso(today): {'flow': 'none', 'mood': 'happy', 'temperature': '36.7', 'symptoms': ['libido', 'cervical'], 'notes': 'Sensation de bien-être, beaucoup d’énergie.', 'updatedAt': now},
    });
  }

  // ------------------------------------------------------------------ Synchronisation
  Map<String, dynamic> get _pending => Store.readMap(_kPending) ?? {'settings': false, 'logs': <String, dynamic>{}};

  bool get hasPending {
    final p = _pending;
    return p['settings'] == true || ((p['logs'] as Map?)?.isNotEmpty ?? false);
  }

  Future<void> _markPending({bool settings = false, List<String> dates = const []}) async {
    final p = _pending;
    if (settings) p['settings'] = true;
    final l = Map<String, dynamic>.from((p['logs'] as Map?) ?? {});
    for (final d in dates) {
      l[d] = true;
    }
    p['logs'] = l;
    await Store.writeJson(_kPending, p);
  }

  /// Envoie les modifications en attente puis récupère la version serveur.
  Future<SyncState> sync({bool pull = false}) async {
    if (!isServerSession) return SyncState.local;
    if (_syncing) return SyncState.syncing;
    _syncing = true;
    try {
      if (hasPending) {
        final p = _pending;
        final current = logs;
        final payloadLogs = <String, dynamic>{};
        for (final d in ((p['logs'] as Map?) ?? {}).keys) {
          payloadLogs['$d'] = current['$d']?.toJson();
        }
        final res = await Api.importData({
          if (p['settings'] == true) 'settings': settings.toJson(),
          'logs': payloadLogs,
          'mode': 'merge',
        });
        if (res.offline) return SyncState.offline;
        if (!res.ok) return SyncState.error;
        await Store.writeJson(_kPending, {'settings': false, 'logs': {}});
        await _applyServer(res.data?['settings'], res.data?['logs']);
        return SyncState.synced;
      }
      if (!pull) return SyncState.synced;

      final s = await Api.getSettings();
      final l = await Api.getLogs();
      if (s.offline || l.offline) return SyncState.offline;
      if (!s.ok || !l.ok) return SyncState.error;
      if (s.data?['settings'] == null && hasStoredSettings) {
        await _markPending(settings: true);
        _syncing = false;
        return sync();
      }
      await _applyServer(s.data?['settings'], l.data?['logs']);
      return SyncState.synced;
    } catch (_) {
      return SyncState.error;
    } finally {
      _syncing = false;
    }
  }

  Future<void> _applyServer(dynamic serverSettings, dynamic serverLogs) async {
    if (serverSettings is Map) {
      final local = Store.readMap(_kSettings) ?? {};
      await Store.writeJson(_kSettings, {...local, ...Map<String, dynamic>.from(serverSettings)});
    }
    if (serverLogs is Map) await Store.writeJson(_kLogs, serverLogs);
  }

  // ------------------------------------------------------------------ Code PIN (appareil uniquement)
  bool get hasPin => Store.getString(_kPin) != null;
  Future<void> setPin(String pin) => Store.setString(_kPin, Secrets.hash(pin));
  Future<void> removePin() => Store.remove(_kPin);
  bool checkPin(String pin) => Secrets.verify(pin, Store.getString(_kPin));

  // ------------------------------------------------------------------ Export / import / effacement
  String exportJson(AppUser? user) => const JsonEncoder.withIndent('  ').convert({
        'app': 'LaGo',
        'version': '4.0',
        'user': user == null ? 'anonymous' : {'name': user.name, 'email': user.email},
        'exportedAt': DateTime.now().toIso8601String(),
        'settings': settings.toJson(),
        'logs': logs.map((k, v) => MapEntry(k, v.toJson())),
      });

  String get exportFileName => 'lago_sauvegarde_${Dates.toIso(DateTime.now())}.json';

  /// Renvoie le nombre de jours importés, ou lève une [FormatException].
  Future<int> importJson(String content) async {
    final parsed = jsonDecode(content);
    if (parsed is! Map || (parsed['settings'] == null && parsed['logs'] == null)) {
      throw const FormatException('Ce fichier n’est pas une sauvegarde LaGo.');
    }
    if (parsed['settings'] is Map) {
      final s = CycleSettings.fromJson(Map<String, dynamic>.from(parsed['settings'] as Map));
      await saveSettings(s);
    }
    var count = 0;
    if (parsed['logs'] is Map) {
      final l = logs;
      final dates = <String>[];
      (parsed['logs'] as Map).forEach((date, entry) {
        if (Dates.parseIso('$date') == null || entry is! Map) return;
        l['$date'] = DayLog.fromJson(Map<String, dynamic>.from(entry));
        dates.add('$date');
        count++;
      });
      await _writeLogs(l);
      await _markPending(dates: dates);
    }
    return count;
  }

  /// Efface les données du cycle. Renvoie false si le serveur n'a pas pu être mis à jour.
  Future<bool> clearAll() async {
    await Store.remove(_kSettings);
    await Store.remove(_kLogs);
    await Store.remove(_kPending);
    if (isServerSession) {
      final res = await Api.clearData();
      return res.ok;
    }
    return true;
  }

  static Future<void> clearCacheIfSynced(String uid) async {
    final p = Store.readMap('lago_pending_$uid');
    final pending = p != null && (p['settings'] == true || ((p['logs'] as Map?)?.isNotEmpty ?? false));
    if (pending) return;
    await Store.remove('lago_settings_$uid');
    await Store.remove('lago_logs_$uid');
  }

  static Future<void> purge(String uid) async {
    for (final k in ['settings', 'logs', 'pending', 'pin']) {
      await Store.remove('lago_${k}_$uid');
    }
  }

  static int countLogs(String uid) => (Store.readMap('lago_logs_$uid') ?? {}).length;

  static Map<String, dynamic> rawLogs(String uid) => Store.readMap('lago_logs_$uid') ?? {};
}
