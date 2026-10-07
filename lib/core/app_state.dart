import 'package:flutter/foundation.dart';

import 'alerts.dart';
import 'appointments.dart';
import 'avatar_vault.dart';
import 'home_widget.dart';
import 'insights.dart';
import 'api.dart';
import 'auth_service.dart';
import 'avatar.dart';
import '../l10n/l10n.dart';
import 'calculator.dart';
import 'models.dart';
import 'notifications.dart';
import 'tracker.dart';

/// État global de l'application (source unique pour tous les écrans).
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  final auth = AuthService();
  final tracker = Tracker();

  AppUser? user;
  CycleSettings settings = CycleSettings.defaults();

  /// Réglages réellement utilisés pour les calculs (ajustés avec le journal si l'apprentissage est actif).
  CycleSettings effective = CycleSettings.defaults();

  /// Ce que LaGo a appris du journal (durées réelles, statistiques).
  CycleInsights insights = CycleInsights.compute(const {});

  /// Rendez-vous médicaux de l'utilisatrice.
  List<Appointment> appointments = const [];
  CycleData cycle = CycleCalculator.calculate(CycleSettings.defaults().lastPeriodDate, 28, 5);
  Map<String, DayLog> logs = {};
  SyncState syncState = SyncState.guest;
  bool locked = false;
  bool ready = false;
  AlertPrefs alertPrefs = AlertPrefs.defaults();
  AvatarPref avatar = const AvatarPref();

  /// Onglet demandé (ex. toucher une notification « conseil du jour » ouvre Bien-être).
  final requestedTab = ValueNotifier<int?>(null);

  /// Onglet affiché (conservé quand l'interface est reconstruite, ex. changement de langue).
  int lastTab = 0;

  /// Un compte sans informations de cycle doit les compléter avant d'utiliser l'app.
  bool get needsCycleSetup =>
      user != null && !user!.isAdmin && !user!.isParent && !loadingAccount && !tracker.hasStoredSettings;

  bool get isParent => user?.isParent ?? false;

  /// Récupération du compte en cours (évite d'afficher la configuration avant la synchronisation).
  bool loadingAccount = false;

  Future<void> init() async {
    Api.onUnauthorized = _onSessionExpired;
    Reminders.onTap = (payload) {
      if (payload == AlertType.dailyTip.key) requestedTab.value = isParent ? 1 : 3;
      if (!isParent && (payload == AlertType.dailyLog.key || payload == AlertType.periodStart.key)) requestedTab.value = 1;
    };
    try {
      await Reminders.init();
    } catch (_) {
      // Un échec du plugin de notifications ne doit pas bloquer l'écran de démarrage.
    }
    await auth.init();
    _bindUser();
    locked = user != null && tracker.hasPin;
    // Compte serveur sans données sur ce téléphone : on les récupère avant d'afficher l'app
    if (user != null && user!.isServer && !tracker.hasStoredSettings) await syncNow(pull: true);
    ready = true;
    notifyListeners();
    await syncNow(pull: true);
    await rescheduleReminders();
  }

  void _bindUser() {
    user = auth.currentUser;
    tracker.userId = user?.id ?? 'default';
    tracker.isServerSession = user?.isServer ?? false;
    Api.token = user?.token;
    alertPrefs = AlertPrefs.load(user?.id ?? 'default');
    avatar = AvatarPref.load(user?.id ?? 'default', admin: user?.isAdmin ?? false);
    appointments = Appointments.load(user?.id ?? 'default');
    reload();
  }

  /// Relit réglages et journal depuis l'appareil, recalcule le cycle.
  void reload() {
    settings = tracker.settings;
    logs = tracker.logs;
    insights = CycleInsights.compute(logs);
    effective = insights.apply(settings);
    cycle = CycleCalculator.calculate(effective.lastPeriodDate, effective.cycleLength, effective.periodDuration);
    notifyListeners();
    LagoHomeWidget.update(cycle: user == null ? null : cycle, discreet: settings.discreetMode, parent: isParent);
  }

  Future<void> syncNow({bool pull = false}) async {
    if (user == null) {
      syncState = SyncState.guest;
    } else if (!tracker.isServerSession) {
      syncState = SyncState.local;
    } else {
      syncState = SyncState.syncing;
      notifyListeners();
      syncState = await tracker.sync(pull: pull);
      reload();
    }
    notifyListeners();
  }

  void _onSessionExpired() {
    auth.clearSession().then((_) {
      _bindUser();
      syncState = SyncState.guest;
      notifyListeners();
    });
  }

  // ------------------------------------------------------------------ Session
  Future<void> afterLogin() async {
    loadingAccount = true;
    _bindUser();
    await syncNow(pull: true);
    await _restoreAvatarIfNeeded();
    loadingAccount = false;
    notifyListeners();
    await rescheduleReminders();
  }

  /// Nouveau téléphone : récupère la photo de profil chiffrée (si l'utilisatrice l'avait sauvegardée).
  Future<void> _restoreAvatarIfNeeded() async {
    final u = user;
    if (u == null || !u.isServer || AvatarPref.hasSaved(u.id)) return;
    final restored = await AvatarVault.restore(u.id);
    if (restored != null) {
      avatar = restored;
      await restored.save(u.id);
    }
  }

  Future<void> logout() async {
    await Reminders.cancelAll();
    await auth.logout();
    locked = false;
    lastTab = 0;
    _bindUser();
    syncState = SyncState.guest;
    notifyListeners();
  }

  /// Après la création du compte : enregistre le cycle et les alertes AVANT d'ouvrir l'application.
  Future<void> finishRegistration(AppUser newUser, CycleSettings s, AlertPrefs prefs) async {
    tracker.userId = newUser.id;
    tracker.isServerSession = newUser.isServer;
    Api.token = newUser.token;
    await tracker.saveSettings(s);
    await prefs.save(newUser.id);
    await afterLogin();
  }

  /// Fin de l'inscription / de la configuration : enregistre le cycle et les alertes.
  Future<void> completeSetup(CycleSettings s, AlertPrefs prefs) async {
    await tracker.saveSettings(s);
    alertPrefs = prefs;
    await prefs.save(user?.id ?? 'default');
    reload();
    await syncNow();
    await rescheduleReminders();
  }

  Future<int> updateAlertPrefs(AlertPrefs prefs) async {
    alertPrefs = prefs;
    await prefs.save(user?.id ?? 'default');
    notifyListeners();
    return rescheduleReminders();
  }

  // ------------------------------------------------------------------ Profil : photo / avatar
  Future<void> setAvatar(AvatarPref a) async {
    avatar = a;
    await a.save(user?.id ?? 'default');
    notifyListeners();
    if (user?.isServer ?? false) AvatarVault.upload(user!.id, a); // seulement si la sauvegarde est activée
  }

  // ------------------------------------------------------------------ Rendez-vous médicaux
  Future<void> saveAppointments(List<Appointment> list) async {
    appointments = [...list]..sort((a, b) => a.when.compareTo(b.when));
    await Appointments.save(user?.id ?? 'default', appointments);
    notifyListeners();
    await rescheduleReminders();
  }

  // ------------------------------------------------------------------ Langue
  /// 'system' (langue du téléphone), 'fr' ou 'en'.
  Future<void> setLanguage(String pref) async {
    await L.setPreference(pref);
    notifyListeners();
    await rescheduleReminders(); // notifications re-rédigées dans la nouvelle langue
  }

  /// Le téléphone a changé de langue (utile quand le réglage est « langue du téléphone »).
  void onSystemLocaleChanged() {
    final next = L.resolve(L.preference);
    if (next != L.lang) {
      L.lang = next;
      notifyListeners();
      rescheduleReminders();
    }
  }

  // ------------------------------------------------------------------ Données
  Future<void> updateSettings(CycleSettings s) async {
    await tracker.saveSettings(s);
    reload();
    syncNow();
  }

  Future<void> saveLog(String date, DayLog log) async {
    await tracker.saveLog(date, log);
    reload();
    syncNow();
  }

  Future<void> deleteLog(String date) async {
    await tracker.deleteLog(date);
    reload();
    syncNow();
  }

  Future<int> rescheduleReminders() async {
    try {
      // Les réglages d'affichage (mode discret, interrupteur) viennent de [settings] ; les dates, de [effective].
      return await Reminders.schedule(
        settings: effective,
        prefs: alertPrefs,
        age: user?.age,
        appointments: appointments.where((a) => !a.isPast).toList(),
        cycleAlerts: !isParent,
      );
    } catch (_) {
      return -1;
    }
  }

  // ------------------------------------------------------------------ Verrouillage
  void lock() {
    if (user != null && tracker.hasPin) {
      locked = true;
      notifyListeners();
    }
  }

  bool unlock(String pin) {
    if (tracker.checkPin(pin)) {
      locked = false;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> forgotPin() async {
    await tracker.removePin();
    await logout();
  }
}
