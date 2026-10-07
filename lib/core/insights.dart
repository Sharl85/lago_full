import 'models.dart';
import 'utils.dart';

/// Ce que LaGo apprend du journal : vraies dates de règles, durées réelles du cycle
/// et des règles, symptômes et humeurs fréquents, courbe de température.
class CycleInsights {
  /// Débuts de règles détectés dans le journal (du plus ancien au plus récent).
  final List<DateTime> periodStarts;

  /// Durée (en jours) de chaque épisode de règles, dans le même ordre.
  final List<int> periodLengths;

  /// Durées des cycles mesurés entre deux débuts de règles consécutifs (15 à 60 jours).
  final List<int> cycleLengths;

  /// Nombre de jours où chaque symptôme / humeur a été noté (trié par fréquence).
  final List<MapEntry<String, int>> symptomCounts;
  final List<MapEntry<String, int>> moodCounts;

  /// Températures basales notées (date, °C), triées par date.
  final List<MapEntry<DateTime, double>> temperatures;

  final int loggedDays;

  const CycleInsights({
    required this.periodStarts,
    required this.periodLengths,
    required this.cycleLengths,
    required this.symptomCounts,
    required this.moodCounts,
    required this.temperatures,
    required this.loggedDays,
  });

  static const minCycle = 15, maxCycle = 60;

  /// Nombre de cycles pris en compte pour la moyenne (les plus récents).
  static const window = 6;

  /// Durée moyenne apprise (au moins 2 cycles mesurés), sinon null.
  int? get learnedCycleLength {
    if (cycleLengths.length < 2) return null;
    final recent = cycleLengths.length > window ? cycleLengths.sublist(cycleLengths.length - window) : cycleLengths;
    return (recent.reduce((a, b) => a + b) / recent.length).round();
  }

  /// Durée moyenne des règles apprise (au moins 2 épisodes), sinon null.
  int? get learnedPeriodLength {
    final valid = periodLengths.where((l) => l >= 2 && l <= 10).toList();
    if (valid.length < 2) return null;
    final recent = valid.length > window ? valid.sublist(valid.length - window) : valid;
    return (recent.reduce((a, b) => a + b) / recent.length).round();
  }

  int? get shortestCycle => cycleLengths.isEmpty ? null : cycleLengths.reduce((a, b) => a < b ? a : b);
  int? get longestCycle => cycleLengths.isEmpty ? null : cycleLengths.reduce((a, b) => a > b ? a : b);

  /// Écart entre le cycle le plus court et le plus long (> 7 jours = cycles irréguliers).
  int? get variation => cycleLengths.length < 2 ? null : longestCycle! - shortestCycle!;

  DateTime? get lastPeriodStart => periodStarts.isEmpty ? null : periodStarts.last;

  /// Réglages effectivement utilisés pour les calculs : ceux de l'utilisatrice,
  /// ajustés avec le journal si l'apprentissage est activé.
  CycleSettings apply(CycleSettings s) {
    if (!s.learnFromJournal) return s;
    var lmp = s.lastPeriodDate;
    final stored = Dates.parseIso(s.lastPeriodDate);
    final logged = lastPeriodStart;
    if (logged != null && (stored == null || logged.isAfter(stored)) && !logged.isAfter(Dates.today())) {
      lmp = Dates.toIso(logged);
    }
    return s.copyWith(
      lastPeriodDate: lmp,
      cycleLength: learnedCycleLength ?? s.cycleLength,
      periodDuration: learnedPeriodLength ?? s.periodDuration,
    );
  }

  static CycleInsights compute(Map<String, DayLog> logs) {
    final entries = <MapEntry<DateTime, DayLog>>[];
    logs.forEach((iso, log) {
      final d = Dates.parseIso(iso);
      if (d != null) entries.add(MapEntry(d, log));
    });
    entries.sort((a, b) => a.key.compareTo(b.key));

    // --- Épisodes de règles : jours de flux (hors spotting), un jour sans note toléré entre deux jours de flux
    final bleeding = entries.where((e) => e.value.hasPeriodFlow).map((e) => e.key).toList();
    final starts = <DateTime>[];
    final lengths = <int>[];
    DateTime? start, last;
    for (final d in bleeding) {
      if (start == null || last == null || Dates.diffInDays(d, last) > 2) {
        if (start != null && last != null) {
          starts.add(start);
          lengths.add(Dates.diffInDays(last, start) + 1);
        }
        start = d;
      }
      last = d;
    }
    if (start != null && last != null) {
      starts.add(start);
      lengths.add(Dates.diffInDays(last, start) + 1);
    }

    final cycles = <int>[];
    for (var i = 1; i < starts.length; i++) {
      final len = Dates.diffInDays(starts[i], starts[i - 1]);
      // Un écart trop long signifie le plus souvent des règles non notées : ignoré.
      if (len >= minCycle && len <= maxCycle) cycles.add(len);
    }

    final sym = <String, int>{};
    final moods = <String, int>{};
    final temps = <MapEntry<DateTime, double>>[];
    for (final e in entries) {
      for (final s in e.value.symptoms) {
        sym[s] = (sym[s] ?? 0) + 1;
      }
      moods[e.value.mood] = (moods[e.value.mood] ?? 0) + 1;
      final t = double.tryParse(e.value.temperature.replaceAll(',', '.'));
      if (t != null && t >= 34 && t <= 43) temps.add(MapEntry(e.key, t));
    }
    List<MapEntry<String, int>> sorted(Map<String, int> m) => m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return CycleInsights(
      periodStarts: starts,
      periodLengths: lengths,
      cycleLengths: cycles,
      symptomCounts: sorted(sym),
      moodCounts: sorted(moods),
      temperatures: temps,
      loggedDays: entries.length,
    );
  }
}
