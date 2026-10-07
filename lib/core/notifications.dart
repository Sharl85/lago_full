import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'alerts.dart';
import 'appointments.dart';
import 'calculator.dart';
import 'content.dart';
import 'models.dart';
import 'utils.dart';
import '../l10n/l10n.dart';

/// Notifications locales : moments importants du cycle, rappel du journal, conseil du jour.
/// Chaque type d'alerte a sa sonnerie (sons LaGo, son importé, son du téléphone ou silencieux).
class Reminders {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// Appelé quand l'utilisatrice touche une notification (payload = type d'alerte).
  static void Function(String payload)? onTap;

  static bool get supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  static bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  static Future<void> init() async {
    if (!supported || _ready) return;
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (r) {
        final p = r.payload;
        if (p != null && onTap != null) onTap!(p);
      },
    );
    try {
      await Sounds.installBuiltInForIos();
    } catch (_) {}
    _ready = true;
  }

  static Future<bool> requestPermission() async {
    if (!supported) return false;
    await init();
    if (_isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? true;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, badge: false, sound: true) ?? false;
  }

  static Future<void> cancelAll() async {
    if (!supported) return;
    await init();
    await _plugin.cancelAll();
  }

  /// Détails de notification pour un type d'alerte et sa sonnerie.
  static NotificationDetails _details(AlertType type, AlertSetting setting) {
    final sound = Sounds.of(setting.sound);
    final silent = sound.id == 'silent';

    AndroidNotificationSound? androidSound;
    if (Sounds.isBuiltIn(sound.id)) {
      androidSound = RawResourceAndroidNotificationSound(sound.id);
    } else if (sound.custom && sound.androidUri != null) {
      androidSound = UriAndroidNotificationSound(sound.androidUri!);
    }
    // Sur Android, la sonnerie d'un canal ne peut plus changer : un canal par (type, son, vibreur).
    final channelId = channelSafe('lago_${type.key}_${sound.id}_${setting.vibrate ? 'v' : 'n'}');

    String? iosSound;
    if (Sounds.isBuiltIn(sound.id)) {
      iosSound = '${sound.id}.wav';
    } else if (sound.custom && sound.iosName != null) {
      iosSound = sound.iosName;
    }

    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        '${tr(type.label)} — ${tr(sound.label)}',
        channelDescription: tr(type.description),
        importance: Importance.high,
        priority: Priority.high,
        playSound: !silent,
        sound: silent ? null : androidSound,
        enableVibration: setting.vibrate,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: !silent,
        sound: silent ? null : iosSound,
      ),
    );
  }

  /// Supprime les anciens canaux Android LaGo qui ne sont plus utilisés.
  static Future<void> _cleanChannels(Set<String> keep) async {
    if (!_isAndroid) return;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    try {
      final channels = await android.getNotificationChannels() ?? [];
      for (final c in channels) {
        if (c.id.startsWith('lago_') && !keep.contains(c.id)) {
          await android.deleteNotificationChannel(c.id);
        }
      }
    } catch (_) {}
  }

  /// Envoie immédiatement une notification de test pour un type d'alerte.
  static Future<bool> test(AlertType type, AlertSetting setting) async {
    if (!supported) return false;
    if (!await requestPermission()) return false;
    await _plugin.show(9999, '${type.emoji} ${tr(type.label)}', tr('Voici la sonnerie choisie pour cette alerte.'), _details(type, setting),
        payload: type.key);
    return true;
  }

  /// Reprogramme toutes les notifications. Renvoie le nombre programmé, ou -1 si refusé.
  static Future<int> schedule(
      {required CycleSettings settings, required AlertPrefs prefs, int? age, List<Appointment> appointments = const [], bool cycleAlerts = true}) async {
    if (!supported) return 0;
    await cancelAll();
    if (!settings.remindersEnabled) return 0;
    if (!await requestPermission()) return -1;

    final discreet = settings.discreetMode;
    final now = DateTime.now();
    final items = <_Planned>[];
    final keep = <String>{};

    void add(AlertType type, DateTime when, String title, String body, String discreetBody) {
      final setting = prefs.of(type);
      if (!setting.enabled || !when.isAfter(now)) return;
      items.add(_Planned(type, setting, when, discreet ? 'LaGo 🌸' : tr(title), tr(discreet ? discreetBody : body)));
    }

    // --- Moments importants du cycle (3 prochains cycles) ---
    final cycles = !cycleAlerts
        ? const <ForecastCycle>[]
        : CycleCalculator.forecast(settings.lastPeriodDate, settings.cycleLength, settings.periodDuration, count: 4, fromToday: true);
    final h = prefs.alertHour, m = prefs.alertMinute;
    for (final c in cycles) {
      final soon = prefs.periodSoonDays;
      add(AlertType.periodSoon, at(dayPlus(c.periodStart, -soon), h, m), 'Règles dans $soon jour${soon > 1 ? 's' : ''} 🩸',
          'Pensez à prévoir vos protections et à prendre soin de vous.', 'Petit rappel bien-être.');
      add(AlertType.periodStart, at(c.periodStart, h, m), 'Règles prévues aujourd’hui 🌸',
          'Notez votre flux et vos sensations dans votre journal LaGo.', 'Un moment pour vous aujourd’hui.');
      add(AlertType.fertileStart, at(c.fertileStart, h, m), 'Début de la fenêtre fertile 🌱',
          'Une grossesse est possible à partir d’aujourd’hui et jusqu’au ${Dates.short(c.fertileEnd)}.', 'Nouvelle étape de votre cycle.');
      add(AlertType.ovulation, at(c.ovulationDate, h, m), 'Ovulation estimée aujourd’hui ✨',
          'Fertilité maximale. Protégez-vous si vous ne souhaitez pas de grossesse.', 'Nouvelle étape de votre cycle.');
      add(AlertType.pms, at(dayPlus(c.periodStart, -5), h, m), 'Période du SPM 🍂',
          'Humeur, fringales, seins sensibles : c’est hormonal. Soyez douce avec vous-même.', 'Prenez soin de vous cette semaine.');
    }

    // --- Rappels quotidiens (14 prochains jours) ---
    final today = Dates.today();
    for (var i = 0; i < 14; i++) {
      final day = dayPlus(today, i);
      if (cycleAlerts) {
        add(AlertType.dailyLog, at(day, prefs.logHour, prefs.logMinute), 'Comment s’est passée votre journée ? 📝',
            'Notez votre humeur et vos symptômes en 10 secondes.', 'Votre journal vous attend.');
      }
      if (prefs.pillDay(day)) {
        add(AlertType.pill, at(day, prefs.pillHour, prefs.pillMinute), 'C’est l’heure de votre pilule 💊',
            'Prenez votre pilule maintenant, à la même heure que d’habitude.', 'Petit rappel du soir.');
      }
      if (!cycleAlerts) continue;
      final tip = LagoContent.tipOfDay(day, age);
      final cat = tr(LagoContent.tipCategories[tip.category] ?? 'Conseil');
      add(AlertType.dailyTip, at(day, prefs.tipHour, prefs.tipMinute), '💡 $cat — ${tr(tip.title)}', tr(tip.body),
          'Votre conseil du jour vous attend.');
    }

    // --- Rendez-vous médicaux : la veille (heure des alertes) et 2 h avant ---
    for (final a in appointments) {
      final hour = '${a.when.hour.toString().padLeft(2, '0')}:${a.when.minute.toString().padLeft(2, '0')}';
      final place = a.place.isEmpty ? '' : ' — ${a.place}';
      add(AlertType.appointment, at(dayPlus(Dates.dateOnly(a.when), -1), h, m), 'Rendez-vous demain à $hour 🩺',
          '${a.title}$place', 'Petit rappel pour demain.');
      add(AlertType.appointment, a.when.subtract(const Duration(hours: 2)), 'Rendez-vous à $hour 🩺', '${a.title}$place',
          'Petit rappel.');
    }

    // iOS limite à 64 notifications programmées : on garde les plus proches.
    items.sort((a, b) => a.when.compareTo(b.when));
    final selected = items.take(60).toList();

    var id = 1000;
    for (final it in selected) {
      final details = _details(it.type, it.setting);
      keep.add(details.android!.channelId);
      await _plugin.zonedSchedule(
        id++,
        it.title,
        it.body,
        tz.TZDateTime.from(it.when, tz.UTC),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: it.type.key,
      );
    }
    await _cleanChannels(keep);
    return selected.length;
  }
}

class _Planned {
  final AlertType type;
  final AlertSetting setting;
  final DateTime when;
  final String title;
  final String body;
  _Planned(this.type, this.setting, this.when, this.title, this.body);
}
