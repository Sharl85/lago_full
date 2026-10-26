import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'storage.dart';
import 'utils.dart';

/// Types d'alertes pour les moments importants du cycle.
class AlertType {
  final String key;
  final String label;
  final String description;
  final String emoji;
  final bool defaultOn;
  final String defaultSound;
  const AlertType(this.key, this.label, this.description, this.emoji, this.defaultOn, this.defaultSound);

  static const periodSoon = AlertType('periodSoon', 'Règles bientôt', 'Quelques jours avant les règles prévues.', '🩸', true, 'lago_lotus');
  static const periodStart = AlertType('periodStart', 'Jour des règles', 'Le jour où les règles sont prévues.', '🌸', true, 'lago_carillon');
  static const fertileStart = AlertType('fertileStart', 'Début de la fenêtre fertile', 'Premier jour où une grossesse est possible.', '🌱', true, 'lago_harpe');
  static const ovulation = AlertType('ovulation', "Jour d'ovulation", 'Jour de fertilité maximale estimé.', '✨', true, 'lago_cristal');
  static const pms = AlertType('pms', 'Début du SPM probable', '5 jours avant les règles : humeur, fringales, seins sensibles…', '🍂', false, 'lago_douce');
  static const dailyLog = AlertType('dailyLog', 'Rappel du journal', 'Chaque jour, pour noter flux, humeur et symptômes.', '📝', false, 'lago_goutte');
  static const dailyTip = AlertType('dailyTip', 'Conseil santé intime du jour', 'Un conseil par jour sur la sexualité, le corps et les relations (adapté à votre âge).', '💡', false, 'lago_marimba');

  static const pill = AlertType('pill', 'Prise de la pilule', 'Chaque jour à la même heure, pour ne pas oublier votre pilule.', '💊', false, 'lago_eveil');
  static const appointment = AlertType('appointment', 'Rendez-vous médicaux', 'La veille et 2 heures avant chaque rendez-vous noté dans LaGo.', '🩺', true, 'lago_carillon');

  static const monthlyReport = AlertType('monthlyReport', 'Bilan du mois', 'Le 1er de chaque mois, un résumé de votre cycle, de vos symptômes et de votre humeur.', '📊', true, 'lago_douce');

  static const all = [periodSoon, periodStart, fertileStart, ovulation, pms, dailyLog, dailyTip, pill, appointment, monthlyReport];
  static AlertType of(String key) => all.firstWhere((a) => a.key == key, orElse: () => periodSoon);
}

/// Réglage d'une alerte.
class AlertSetting {
  final bool enabled;
  final String sound; // id de sonnerie : 'lago_xxx', 'default', 'silent', 'custom_xxx'
  final bool vibrate;
  const AlertSetting({required this.enabled, required this.sound, this.vibrate = true});

  Map<String, dynamic> toJson() => {'enabled': enabled, 'sound': sound, 'vibrate': vibrate};
  factory AlertSetting.fromJson(Map<String, dynamic> j, AlertType t) => AlertSetting(
        enabled: j['enabled'] is bool ? j['enabled'] as bool : t.defaultOn,
        sound: j['sound'] is String ? j['sound'] as String : t.defaultSound,
        vibrate: j['vibrate'] != false,
      );
  AlertSetting copyWith({bool? enabled, String? sound, bool? vibrate}) =>
      AlertSetting(enabled: enabled ?? this.enabled, sound: sound ?? this.sound, vibrate: vibrate ?? this.vibrate);
}

/// Préférences d'alertes d'une utilisatrice (stockées sur le téléphone : les sonneries sont propres à l'appareil).
class AlertPrefs {
  final Map<String, AlertSetting> alerts;
  final int periodSoonDays; // 1 à 5 jours avant
  final int alertHour, alertMinute; // heure des alertes du cycle
  final int logHour, logMinute; // rappel du journal
  final int tipHour, tipMinute; // conseil du jour
  final int pillHour, pillMinute; // prise de la pilule
  final int pillBreakDays; // 0 = en continu ; 7 = 21 jours de prise puis 7 jours de pause
  final String? pillStartDate; // 1er jour de la plaquette en cours (AAAA-MM-JJ)

  const AlertPrefs({
    required this.alerts,
    this.periodSoonDays = 2,
    this.alertHour = 9,
    this.alertMinute = 0,
    this.logHour = 20,
    this.logMinute = 30,
    this.tipHour = 12,
    this.tipMinute = 0,
    this.pillHour = 21,
    this.pillMinute = 0,
    this.pillBreakDays = 0,
    this.pillStartDate,
  });

  factory AlertPrefs.defaults() =>
      AlertPrefs(alerts: {for (final t in AlertType.all) t.key: AlertSetting(enabled: t.defaultOn, sound: t.defaultSound)});

  static String _key(String uid) => 'lago_alerts_$uid';

  static AlertPrefs load(String uid) {
    final j = Store.readMap(_key(uid));
    if (j == null) return AlertPrefs.defaults();
    final raw = (j['alerts'] is Map) ? Map<String, dynamic>.from(j['alerts'] as Map) : <String, dynamic>{};
    int n(String k, int fb, int min, int max) {
      final v = j[k];
      return v is int ? v.clamp(min, max).toInt() : fb;
    }

    return AlertPrefs(
      alerts: {
        for (final t in AlertType.all)
          t.key: raw[t.key] is Map
              ? AlertSetting.fromJson(Map<String, dynamic>.from(raw[t.key] as Map), t)
              : AlertSetting(enabled: t.defaultOn, sound: t.defaultSound)
      },
      periodSoonDays: n('periodSoonDays', 2, 1, 5),
      alertHour: n('alertHour', 9, 0, 23),
      alertMinute: n('alertMinute', 0, 0, 59),
      logHour: n('logHour', 20, 0, 23),
      logMinute: n('logMinute', 30, 0, 59),
      tipHour: n('tipHour', 12, 0, 23),
      tipMinute: n('tipMinute', 0, 0, 59),
      pillHour: n('pillHour', 21, 0, 23),
      pillMinute: n('pillMinute', 0, 0, 59),
      pillBreakDays: n('pillBreakDays', 0, 0, 7) == 7 ? 7 : 0,
      pillStartDate: Dates.parseIso(j['pillStartDate'] as String?) != null ? j['pillStartDate'] as String : null,
    );
  }

  Future<void> save(String uid) => Store.writeJson(_key(uid), toJson());

  Map<String, dynamic> toJson() => {
        'alerts': alerts.map((k, v) => MapEntry(k, v.toJson())),
        'periodSoonDays': periodSoonDays,
        'alertHour': alertHour,
        'alertMinute': alertMinute,
        'logHour': logHour,
        'logMinute': logMinute,
        'tipHour': tipHour,
        'tipMinute': tipMinute,
        'pillHour': pillHour,
        'pillMinute': pillMinute,
        'pillBreakDays': pillBreakDays,
        if (pillStartDate != null) 'pillStartDate': pillStartDate,
      };

  /// Faut-il prendre la pilule ce jour-là ? (plaquette 21 + 7 : pas de rappel pendant la pause)
  bool pillDay(DateTime day) {
    if (pillBreakDays == 0) return true;
    final start = Dates.parseIso(pillStartDate);
    if (start == null) return true;
    final d = Dates.diffInDays(day, start);
    if (d < 0) return true;
    return d % 28 < 21;
  }

  AlertSetting of(AlertType t) => alerts[t.key] ?? AlertSetting(enabled: t.defaultOn, sound: t.defaultSound);

  AlertPrefs withAlert(AlertType t, AlertSetting s) => copyWith(alerts: {...alerts, t.key: s});

  AlertPrefs copyWith({
    Map<String, AlertSetting>? alerts,
    int? periodSoonDays,
    int? alertHour,
    int? alertMinute,
    int? logHour,
    int? logMinute,
    int? tipHour,
    int? tipMinute,
    int? pillHour,
    int? pillMinute,
    int? pillBreakDays,
    String? pillStartDate,
  }) =>
      AlertPrefs(
        alerts: alerts ?? this.alerts,
        periodSoonDays: periodSoonDays ?? this.periodSoonDays,
        alertHour: alertHour ?? this.alertHour,
        alertMinute: alertMinute ?? this.alertMinute,
        logHour: logHour ?? this.logHour,
        logMinute: logMinute ?? this.logMinute,
        tipHour: tipHour ?? this.tipHour,
        tipMinute: tipMinute ?? this.tipMinute,
        pillHour: pillHour ?? this.pillHour,
        pillMinute: pillMinute ?? this.pillMinute,
        pillBreakDays: pillBreakDays ?? this.pillBreakDays,
        pillStartDate: pillStartDate ?? this.pillStartDate,
      );
}

/// Sonnerie disponible.
class SoundOption {
  final String id;
  final String label;
  final bool custom;
  final String? filePath; // fichier local (sons personnalisés, pour l'écoute)
  final String? androidUri; // content:// utilisable par les notifications Android
  final String? iosName; // nom du fichier dans Library/Sounds (iOS)
  const SoundOption(this.id, this.label, {this.custom = false, this.filePath, this.androidUri, this.iosName});

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'filePath': filePath, 'androidUri': androidUri, 'iosName': iosName};
  factory SoundOption.fromJson(Map<String, dynamic> j) => SoundOption(
        '${j['id']}',
        '${j['label']}',
        custom: true,
        filePath: j['filePath'] as String?,
        androidUri: j['androidUri'] as String?,
        iosName: j['iosName'] as String?,
      );
}

/// Catalogue des sonneries : 8 sons LaGo intégrés, son du téléphone, silencieux, sons importés.
class Sounds {
  static const builtIn = [
    SoundOption('lago_lotus', 'Lotus'),
    SoundOption('lago_carillon', 'Carillon'),
    SoundOption('lago_harpe', 'Harpe'),
    SoundOption('lago_goutte', 'Goutte'),
    SoundOption('lago_marimba', 'Marimba'),
    SoundOption('lago_cristal', 'Cristal'),
    SoundOption('lago_douce', 'Douceur'),
    SoundOption('lago_eveil', 'Éveil'),
  ];
  static const systemDefault = SoundOption('default', 'Son du téléphone');
  static const silent = SoundOption('silent', 'Silencieux (vibreur seul)');

  static const _kCustom = 'lago_custom_sounds';
  static const _channel = MethodChannel('app.lago/sounds');
  static final AudioPlayer _player = AudioPlayer();

  static List<SoundOption> get custom =>
      Store.readList(_kCustom).whereType<Map>().map((e) => SoundOption.fromJson(Map<String, dynamic>.from(e))).toList();

  static List<SoundOption> get all => [...builtIn, ...custom, systemDefault, silent];

  static SoundOption of(String id) => all.firstWhere((s) => s.id == id, orElse: () => systemDefault);

  static bool isBuiltIn(String id) => builtIn.any((s) => s.id == id);

  /// iOS : les sons des notifications doivent se trouver dans Library/Sounds.
  static Future<void> installBuiltInForIos() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    final dir = Directory('${(await getLibraryDirectory()).path}/Sounds');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    for (final s in builtIn) {
      final f = File('${dir.path}/${s.id}.wav');
      if (f.existsSync()) continue;
      final data = await rootBundle.load('assets/sounds/${s.id}.wav');
      await f.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
  }

  /// Écoute d'une sonnerie.
  static Future<void> preview(String id) async {
    try {
      await _player.stop();
      if (isBuiltIn(id)) {
        await _player.play(AssetSource('sounds/$id.wav'));
        return;
      }
      final s = of(id);
      if (s.custom && s.filePath != null && File(s.filePath!).existsSync()) {
        await _player.play(DeviceFileSource(s.filePath!));
      }
    } catch (_) {}
  }

  static Future<void> stopPreview() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  /// Importe un son personnel. Renvoie la sonnerie créée ou lève une exception au message lisible.
  static Future<SoundOption> importCustom(String sourcePath, String originalName) async {
    final ext = originalName.contains('.') ? originalName.split('.').last.toLowerCase() : '';
    final ios = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    const iosFormats = ['wav', 'caf', 'aiff', 'aif'];
    const androidFormats = ['mp3', 'wav', 'ogg', 'm4a', 'aac'];
    if (ios && !iosFormats.contains(ext)) {
      throw Exception('Sur iPhone, choisissez un fichier .wav, .caf ou .aiff (30 secondes maximum).');
    }
    if (!ios && !androidFormats.contains(ext)) {
      throw Exception('Formats acceptés : mp3, wav, ogg, m4a.');
    }
    final src = File(sourcePath);
    if (!src.existsSync()) throw Exception('Fichier introuvable.');
    if (src.lengthSync() > 5 * 1024 * 1024) throw Exception('Fichier trop volumineux (5 Mo maximum).');

    final id = 'custom_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    final baseLabel = originalName.replaceAll(RegExp(r'\.[^.]+$'), '');
    final label = baseLabel.length > 30 ? baseLabel.substring(0, 30) : baseLabel;

    // Copie privée pour l'écoute dans l'application
    final docs = await getApplicationDocumentsDirectory();
    final soundsDir = Directory('${docs.path}/sounds');
    if (!soundsDir.existsSync()) soundsDir.createSync(recursive: true);
    final local = await src.copy('${soundsDir.path}/$id.$ext');

    String? androidUri;
    String? iosName;
    if (ios) {
      final lib = Directory('${(await getLibraryDirectory()).path}/Sounds');
      if (!lib.existsSync()) lib.createSync(recursive: true);
      iosName = '$id.$ext';
      await src.copy('${lib.path}/$iosName');
    } else {
      // Android : le son est ajouté aux sonneries de notification du téléphone (dossier Notifications/LaGo)
      try {
        androidUri = await _channel.invokeMethod<String>('importSound', {'path': local.path, 'name': '$label.$ext', 'id': id});
      } on PlatformException catch (e) {
        await local.delete();
        throw Exception(e.message ?? 'Import impossible sur ce téléphone.');
      } on MissingPluginException {
        await local.delete();
        throw Exception('Relancez « dart run tool/setup.dart » puis recompilez l’application.');
      }
      if (androidUri == null) {
        await local.delete();
        throw Exception('Import impossible sur ce téléphone.');
      }
    }

    final option = SoundOption(id, label, custom: true, filePath: local.path, androidUri: androidUri, iosName: iosName);
    final list = custom..add(option);
    await Store.writeJson(_kCustom, list.map((e) => e.toJson()).toList());
    return option;
  }

  static Future<void> removeCustom(String id) async {
    final list = custom;
    final s = list.where((e) => e.id == id).toList();
    for (final o in s) {
      try {
        if (o.filePath != null) File(o.filePath!).deleteSync();
      } catch (_) {}
    }
    list.removeWhere((e) => e.id == id);
    await Store.writeJson(_kCustom, list.map((e) => e.toJson()).toList());
  }
}

String formatTime(int h, int m) => '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

/// Identifiant sûr pour un canal Android.
String channelSafe(String s) => s.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');

/// Quelques dates utiles.
DateTime at(DateTime day, int h, int m) => DateTime(day.year, day.month, day.day, h, m);
DateTime dayPlus(DateTime d, int n) => Dates.addDays(d, n);
