import 'insights.dart';
import 'models.dart';
import 'utils.dart';

/// v5 — Bilan d'un mois : jours notés, règles, symptômes et humeurs les plus fréquents.
class MonthlyReport {
  final DateTime month; // 1er jour du mois
  final int loggedDays;
  final List<DateTime> periodStarts;
  final List<int> periodLengths;
  final int? cycleLength; // dernier cycle terminé dans le mois
  final List<MapEntry<String, int>> topSymptoms;
  final List<MapEntry<String, int>> topMoods;
  final double? averageTemperature;
  final int spottingDays;

  const MonthlyReport({
    required this.month,
    required this.loggedDays,
    required this.periodStarts,
    required this.periodLengths,
    required this.cycleLength,
    required this.topSymptoms,
    required this.topMoods,
    required this.averageTemperature,
    required this.spottingDays,
  });

  bool get isEmpty => loggedDays == 0;

  static MonthlyReport compute(Map<String, DayLog> logs, DateTime anyDayInMonth) {
    final month = DateTime(anyDayInMonth.year, anyDayInMonth.month, 1);
    final next = DateTime(month.year, month.month + 1, 1);
    bool inMonth(DateTime d) => !d.isBefore(month) && d.isBefore(next);

    final all = CycleInsights.compute(logs);
    final starts = <DateTime>[];
    final lengths = <int>[];
    for (var i = 0; i < all.periodStarts.length; i++) {
      if (inMonth(all.periodStarts[i])) {
        starts.add(all.periodStarts[i]);
        lengths.add(all.periodLengths[i]);
      }
    }
    int? cycle;
    for (var i = 1; i < all.periodStarts.length; i++) {
      if (inMonth(all.periodStarts[i])) {
        final len = Dates.diffInDays(all.periodStarts[i], all.periodStarts[i - 1]);
        if (len >= CycleInsights.minCycle && len <= CycleInsights.maxCycle) cycle = len;
      }
    }

    var logged = 0;
    var spotting = 0;
    final sym = <String, int>{};
    final moods = <String, int>{};
    final temps = <double>[];
    logs.forEach((iso, l) {
      final d = Dates.parseIso(iso);
      if (d == null || !inMonth(d)) return;
      logged++;
      if (l.flow == 'spotting') spotting++;
      for (final s in l.symptoms) {
        sym[s] = (sym[s] ?? 0) + 1;
      }
      moods[l.mood] = (moods[l.mood] ?? 0) + 1;
      final t = double.tryParse(l.temperature.replaceAll(',', '.'));
      if (t != null && t >= 34 && t <= 43) temps.add(t);
    });
    List<MapEntry<String, int>> top(Map<String, int> m) => (m.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(3).toList();

    return MonthlyReport(
      month: month,
      loggedDays: logged,
      periodStarts: starts,
      periodLengths: lengths,
      cycleLength: cycle,
      topSymptoms: top(sym),
      topMoods: top(moods),
      averageTemperature: temps.isEmpty ? null : temps.reduce((a, b) => a + b) / temps.length,
      spottingDays: spotting,
    );
  }

  /// Conseil personnalisé simple, selon ce qui a été noté.
  String get advice {
    if (isEmpty) return 'Notez votre journal quelques secondes par jour : vos bilans et vos prévisions deviendront plus précis.';
    final symptoms = topSymptoms.map((e) => e.key).toList();
    if (symptoms.contains('cramps')) return 'Les crampes reviennent souvent : chaleur, étirements doux et hydratation aident. Consultez si la douleur vous empêche d’aller en cours ou au travail.';
    if (symptoms.contains('fatigue')) return 'Fatigue fréquente ce mois-ci : privilégiez le sommeil et les aliments riches en fer (haricots, feuilles vertes, poisson).';
    if (symptoms.contains('headache')) return 'Maux de tête fréquents : buvez régulièrement et notez s’ils reviennent avant les règles.';
    final moods = topMoods.map((e) => e.key).toList();
    if (moods.contains('stressed') || moods.contains('irritated')) return 'Beaucoup de stress noté : respiration lente, marche et moments pour vous peuvent aider. Parlez-en à quelqu’un de confiance si cela pèse.';
    if (loggedDays < 10) return 'Bravo pour ces $loggedDays jours notés ! Plus le journal est complet, plus LaGo apprend votre cycle.';
    return 'Très beau suivi ce mois-ci ! Continuez : LaGo affine vos prévisions avec chaque jour noté.';
  }
}
