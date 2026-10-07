import 'package:flutter/material.dart';

import 'utils.dart';

/// Compte utilisatrice (session serveur ou compte local).
class AppUser {
  final String id;
  final String name;
  final String email;
  final String role; // 'user' | 'superadmin'
  /// 'member' (suit son propre cycle) | 'parent' (suit le cycle de ses enfants)
  final String accountType;
  final int? age;
  final String status; // 'active' | 'blocked'
  final String? createdAt;
  final String mode; // 'server' | 'local'
  final String? token;
  final int logsCount;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.role = 'user',
    this.accountType = 'member',
    this.age,
    this.status = 'active',
    this.createdAt,
    this.mode = 'local',
    this.token,
    this.logsCount = 0,
  });

  bool get isAdmin => role == 'superadmin';
  bool get isParent => accountType == 'parent';
  bool get isBlocked => status == 'blocked';
  bool get isServer => mode == 'server' && token != null;

  factory AppUser.fromJson(Map<String, dynamic> j, {String? mode, String? token}) => AppUser(
        id: '${j['id']}',
        name: '${j['name'] ?? ''}',
        email: '${j['email'] ?? ''}',
        role: j['role'] == 'superadmin' ? 'superadmin' : 'user',
        accountType: j['accountType'] == 'parent' ? 'parent' : 'member',
        age: j['age'] is int ? j['age'] as int : int.tryParse('${j['age'] ?? ''}'),
        status: j['status'] == 'blocked' ? 'blocked' : 'active',
        createdAt: j['createdAt'] as String?,
        mode: mode ?? (j['mode'] as String? ?? 'local'),
        token: token ?? j['token'] as String?,
        logsCount: j['logsCount'] is int ? j['logsCount'] as int : 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'accountType': accountType,
        'age': age,
        'status': status,
        'createdAt': createdAt,
        'mode': mode,
        'token': token,
      };

  AppUser copyWith({String? role, String? status, String? name, int? age}) => AppUser(
        id: id,
        name: name ?? this.name,
        email: email,
        role: role ?? this.role,
        accountType: accountType,
        age: age ?? this.age,
        status: status ?? this.status,
        createdAt: createdAt,
        mode: mode,
        token: token,
        logsCount: logsCount,
      );
}

/// Paramètres du cycle et préférences d'affichage.
class CycleSettings {
  final String lastPeriodDate;
  final int cycleLength;
  final int periodDuration;
  final bool petalsEnabled;
  final bool darkMode;
  final bool discreetMode;
  final bool remindersEnabled;
  /// Ajuster automatiquement les prévisions avec les règles notées dans le journal.
  final bool learnFromJournal;
  /// 'regular' | 'irregular' | 'unknown' (renseigné à l'inscription)
  final String cycleRegularity;
  final String? updatedAt;

  const CycleSettings({
    required this.lastPeriodDate,
    this.cycleLength = 28,
    this.periodDuration = 5,
    this.petalsEnabled = true,
    this.darkMode = false,
    this.discreetMode = false,
    this.remindersEnabled = false,
    this.learnFromJournal = true,
    this.cycleRegularity = 'unknown',
    this.updatedAt,
  });

  factory CycleSettings.defaults() =>
      CycleSettings(lastPeriodDate: Dates.toIso(Dates.addDays(Dates.today(), -12)));

  factory CycleSettings.fromJson(Map<String, dynamic>? j) {
    final d = CycleSettings.defaults();
    if (j == null) return d;
    int clampInt(dynamic v, int min, int max, int fb) {
      final n = v is int ? v : int.tryParse('$v');
      if (n == null) return fb;
      return n.clamp(min, max).toInt();
    }

    return CycleSettings(
      lastPeriodDate: Dates.parseIso(j['lastPeriodDate'] as String?) != null ? j['lastPeriodDate'] as String : d.lastPeriodDate,
      cycleLength: clampInt(j['cycleLength'], 15, 60, 28),
      periodDuration: clampInt(j['periodDuration'], 1, 15, 5),
      petalsEnabled: j['petalsEnabled'] is bool ? j['petalsEnabled'] as bool : true,
      darkMode: j['darkMode'] == true,
      discreetMode: j['discreetMode'] == true,
      remindersEnabled: j['remindersEnabled'] == true,
      learnFromJournal: j['learnFromJournal'] != false,
      cycleRegularity: const ['regular', 'irregular', 'unknown'].contains(j['cycleRegularity']) ? j['cycleRegularity'] as String : 'unknown',
      updatedAt: j['updatedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'lastPeriodDate': lastPeriodDate,
        'cycleLength': cycleLength,
        'periodDuration': periodDuration,
        'petalsEnabled': petalsEnabled,
        'darkMode': darkMode,
        'discreetMode': discreetMode,
        'remindersEnabled': remindersEnabled,
        'learnFromJournal': learnFromJournal,
        'cycleRegularity': cycleRegularity,
        if (updatedAt != null) 'updatedAt': updatedAt,
      };

  CycleSettings copyWith({
    String? lastPeriodDate,
    int? cycleLength,
    int? periodDuration,
    bool? petalsEnabled,
    bool? darkMode,
    bool? discreetMode,
    bool? remindersEnabled,
    bool? learnFromJournal,
    String? cycleRegularity,
    String? updatedAt,
  }) =>
      CycleSettings(
        lastPeriodDate: lastPeriodDate ?? this.lastPeriodDate,
        cycleLength: cycleLength ?? this.cycleLength,
        periodDuration: periodDuration ?? this.periodDuration,
        petalsEnabled: petalsEnabled ?? this.petalsEnabled,
        darkMode: darkMode ?? this.darkMode,
        discreetMode: discreetMode ?? this.discreetMode,
        remindersEnabled: remindersEnabled ?? this.remindersEnabled,
        learnFromJournal: learnFromJournal ?? this.learnFromJournal,
        cycleRegularity: cycleRegularity ?? this.cycleRegularity,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// Entrée du journal quotidien.
class DayLog {
  final String flow;
  final String mood;
  final String temperature;
  final List<String> symptoms;
  final String notes;
  final String updatedAt;

  const DayLog({
    this.flow = 'none',
    this.mood = 'calm',
    this.temperature = '',
    this.symptoms = const [],
    this.notes = '',
    required this.updatedAt,
  });

  factory DayLog.fromJson(Map<String, dynamic> j) => DayLog(
        flow: FlowLevel.keys.contains(j['flow']) ? j['flow'] as String : 'none',
        mood: Mood.keys.contains(j['mood']) ? j['mood'] as String : 'calm',
        temperature: j['temperature'] == null ? '' : '${j['temperature']}',
        symptoms: (j['symptoms'] is List)
            ? (j['symptoms'] as List).map((e) => '$e').where(Symptom.keys.contains).toSet().toList()
            : const [],
        notes: j['notes'] is String ? j['notes'] as String : '',
        updatedAt: j['updatedAt'] is String ? j['updatedAt'] as String : DateTime.now().toIso8601String(),
      );

  Map<String, dynamic> toJson() => {
        'flow': flow,
        'mood': mood,
        'temperature': temperature,
        'symptoms': symptoms,
        'notes': notes,
        'updatedAt': updatedAt,
      };

  bool get hasPeriodFlow => flow != 'none' && flow != 'spotting';
}

class Option {
  final String key;
  final String label;
  final String emoji;
  final IconData icon;
  const Option(this.key, this.label, this.emoji, this.icon);
}

class FlowLevel {
  static const values = [
    Option('none', 'Aucun écoulement', '○', Icons.water_drop_outlined),
    Option('spotting', 'Spotting / légères pertes rosées', '·', Icons.opacity),
    Option('light', 'Flux léger', '💧', Icons.water_drop),
    Option('medium', 'Flux moyen', '💧💧', Icons.water_drop),
    Option('heavy', 'Flux abondant', '💧💧💧', Icons.water_drop),
  ];
  static List<String> get keys => values.map((e) => e.key).toList();
}

class Mood {
  static const values = [
    Option('calm', 'Sereine & calme', '🌸', Icons.spa_outlined),
    Option('happy', 'Joyeuse & épanouie', '✨', Icons.sentiment_very_satisfied_outlined),
    Option('energetic', "Pleine d'énergie", '⚡', Icons.bolt),
    Option('romantic', 'Romantique & sensuelle', '💖', Icons.favorite_border),
    Option('sensitive', 'Sensible & émotive', '🥺', Icons.sentiment_neutral),
    Option('tired', 'Fatiguée / besoin de sommeil', '😴', Icons.bedtime_outlined),
    Option('stressed', 'Stressée / anxieuse', '🌧️', Icons.cloud_outlined),
    Option('irritated', 'Irritable (SPM)', '⚡', Icons.whatshot_outlined),
  ];
  static List<String> get keys => values.map((e) => e.key).toList();
  static Option of(String key) => values.firstWhere((e) => e.key == key, orElse: () => values.first);
}

class Symptom {
  static const values = [
    Option('cramps', 'Crampes', '🩸', Icons.water_drop_outlined),
    Option('breasts', 'Seins sensibles', '💗', Icons.favorite_border),
    Option('headache', 'Maux de tête', '🤕', Icons.bolt_outlined),
    Option('bloating', 'Ballonnements', '🎈', Icons.air),
    Option('fatigue', 'Fatigue intense', '😴', Icons.bed_outlined),
    Option('acne', 'Acné', '✨', Icons.auto_awesome_outlined),
    Option('cravings', 'Fringales', '🍫', Icons.cookie_outlined),
    Option('backpain', 'Mal de dos', '🧍', Icons.accessibility_new),
    Option('libido', 'Libido accrue', '🔥', Icons.local_fire_department_outlined),
    Option('cervical', 'Glaire cervicale', '🌊', Icons.waves),
  ];
  static List<String> get keys => values.map((e) => e.key).toList();
  static Option of(String key) => values.firstWhere((e) => e.key == key, orElse: () => values.first);
}

class ActivityLog {
  final String timestamp;
  final String action;
  const ActivityLog(this.timestamp, this.action);
  factory ActivityLog.fromJson(Map<String, dynamic> j) => ActivityLog('${j['timestamp']}', '${j['action']}');
  Map<String, dynamic> toJson() => {'timestamp': timestamp, 'action': action};
}
