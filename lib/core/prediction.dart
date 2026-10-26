import 'dart:math' as math;

import 'calculator.dart';
import 'insights.dart';
import 'models.dart';
import 'utils.dart';

/// v5 — Fourchette des prochaines règles (au lieu d'une seule date).
///
/// Plus les cycles notés varient, plus la fourchette est large. Sans historique,
/// on se base sur la régularité déclarée à l'inscription.
class PeriodWindow {
  final DateTime earliest;
  final DateTime latest;

  /// Nombre de jours de part et d'autre de la date estimée.
  final int spread;

  /// 'high' (≥ 3 cycles réguliers notés), 'medium', 'low'.
  final String confidence;

  const PeriodWindow(this.earliest, this.latest, this.spread, this.confidence);

  static PeriodWindow compute(CycleData cycle, CycleInsights insights, CycleSettings settings) {
    final lengths = insights.cycleLengths;
    final recent = lengths.length > CycleInsights.window ? lengths.sublist(lengths.length - CycleInsights.window) : lengths;
    int spread;
    String confidence;
    if (recent.length >= 2) {
      final mean = recent.reduce((a, b) => a + b) / recent.length;
      final variance = recent.map((l) => (l - mean) * (l - mean)).reduce((a, b) => a + b) / recent.length;
      spread = math.sqrt(variance).round().clamp(1, 7).toInt();
      confidence = recent.length >= 3 && spread <= 2 ? 'high' : 'medium';
    } else {
      spread = switch (settings.cycleRegularity) { 'regular' => 1, 'irregular' => 5, _ => 2 };
      confidence = 'low';
    }
    if (cycle.isLate) {
      // En retard : la fourchette commence aujourd'hui
      return PeriodWindow(cycle.nextPeriodStart, Dates.addDays(cycle.nextPeriodStart, spread), spread, confidence);
    }
    return PeriodWindow(
      Dates.addDays(cycle.nextPeriodStart, -spread),
      Dates.addDays(cycle.nextPeriodStart, spread),
      spread,
      confidence,
    );
  }

  String get label => Dates.diffInDays(latest, earliest) == 0 ? Dates.short(earliest) : '${Dates.short(earliest)} – ${Dates.short(latest)}';
}

/// v5 — Ovulation détectée à partir des signes notés dans le journal.
class OvulationSign {
  final DateTime date;

  /// 'lh' (test d'ovulation), 'temperature' (décalage thermique), 'mucus' (glaire)
  final String method;
  const OvulationSign(this.date, this.method);

  String get methodLabel => switch (method) {
        'lh' => 'test d’ovulation positif',
        'temperature' => 'hausse de la température basale',
        _ => 'glaire cervicale',
      };
}

class FertilitySigns {
  /// Cherche une ovulation dans la période [from] → [to] (cycle en cours).
  /// Priorité : test LH > température > glaire.
  static OvulationSign? detect(Map<String, DayLog> logs, DateTime from, DateTime to) {
    final days = <MapEntry<DateTime, DayLog>>[];
    logs.forEach((iso, log) {
      final d = Dates.parseIso(iso);
      if (d != null && !d.isBefore(from) && !d.isAfter(to)) days.add(MapEntry(d, log));
    });
    if (days.isEmpty) return null;
    days.sort((a, b) => a.key.compareTo(b.key));

    // 1) Test LH positif : l'ovulation survient en général 24 à 36 h après → lendemain
    for (final e in days) {
      if (e.value.hasPositiveLh) return OvulationSign(Dates.addDays(e.key, 1), 'lh');
    }

    // 2) Décalage thermique : 3 températures consécutives au moins 0,2 °C au-dessus
    //    des 6 précédentes → ovulation la veille de la première température haute
    final temps = <MapEntry<DateTime, double>>[];
    for (final e in days) {
      final t = double.tryParse(e.value.temperature.replaceAll(',', '.'));
      if (t != null && t >= 34 && t <= 43) temps.add(MapEntry(e.key, t));
    }
    for (var i = 6; i + 2 < temps.length; i++) {
      final baseline = temps.sublist(i - 6, i).map((e) => e.value).reduce(math.max);
      if (temps[i].value >= baseline + 0.2 && temps[i + 1].value >= baseline + 0.2 && temps[i + 2].value >= baseline + 0.2) {
        // Mesures trop espacées : signe peu fiable
        if (Dates.diffInDays(temps[i + 2].key, temps[i].key) > 4) continue;
        return OvulationSign(Dates.addDays(temps[i].key, -1), 'temperature');
      }
    }

    // 3) Glaire : dernier jour de glaire fertile suivi d'un jour non fertile (« jour sommet »)
    for (var i = 0; i + 1 < days.length; i++) {
      final cur = days[i].value;
      final next = days[i + 1].value;
      if (cur.hasFertileMucus && next.mucus.isNotEmpty && !next.hasFertileMucus && Dates.diffInDays(days[i + 1].key, days[i].key) <= 2) {
        return OvulationSign(days[i].key, 'mucus');
      }
    }
    return null;
  }
}

/// v5 — Signal de santé à surveiller. LaGo ne pose jamais de diagnostic :
/// il invite seulement à en parler à un professionnel.
class HealthSignal {
  final String key;

  /// 'info' (à surveiller) ou 'consult' (en parler à un professionnel)
  final String level;
  final String title;
  final String message;
  const HealthSignal(this.key, this.level, this.title, this.message);

  bool get isConsult => level == 'consult';
}

class _Episode {
  final DateTime start;
  final DateTime end;
  final int heavyDays;
  final int crampDays;
  _Episode(this.start, this.end, this.heavyDays, this.crampDays);
  int get length => Dates.diffInDays(end, start) + 1;
}

class HealthSignals {
  static List<_Episode> _episodes(Map<String, DayLog> logs) {
    final entries = <MapEntry<DateTime, DayLog>>[];
    logs.forEach((iso, l) {
      final d = Dates.parseIso(iso);
      if (d != null) entries.add(MapEntry(d, l));
    });
    entries.sort((a, b) => a.key.compareTo(b.key));
    final out = <_Episode>[];
    DateTime? start, last;
    var heavy = 0, cramps = 0;
    void close() {
      if (start != null && last != null) out.add(_Episode(start!, last!, heavy, cramps));
    }

    for (final e in entries) {
      if (!e.value.hasPeriodFlow) continue;
      if (start == null || last == null || Dates.diffInDays(e.key, last!) > 2) {
        close();
        start = e.key;
        heavy = 0;
        cramps = 0;
      }
      last = e.key;
      if (e.value.flow == 'heavy') heavy++;
      if (e.value.symptoms.contains('cramps')) cramps++;
    }
    close();
    return out;
  }

  static List<HealthSignal> evaluate({
    required Map<String, DayLog> logs,
    required CycleInsights insights,
    required CycleSettings settings,
    required CycleData cycle,
    int? age,
    DateTime? today,
  }) {
    final now = Dates.dateOnly(today ?? DateTime.now());
    final out = <HealthSignal>[];
    if (!settings.tracksPeriods) return out;
    final teen = age != null && age < 18;
    final hormonal = Contraception.isHormonal(settings.contraception);
    final last3 = insights.cycleLengths.length > 3 ? insights.cycleLengths.sublist(insights.cycleLengths.length - 3) : insights.cycleLengths;

    if (!hormonal && last3.where((l) => l < 21).length >= 2) {
      out.add(const HealthSignal('shortCycles', 'consult', 'Cycles courts répétés',
          'Plusieurs de vos derniers cycles ont duré moins de 21 jours. Ce n’est pas forcément grave, mais parlez-en à un professionnel de santé lors d’une prochaine consultation.'));
    }
    final longLimit = teen ? 45 : 35;
    if (!hormonal && last3.where((l) => l > longLimit).length >= 2) {
      out.add(HealthSignal('longCycles', 'consult', 'Cycles longs répétés',
          'Plusieurs de vos derniers cycles ont duré plus de $longLimit jours. Un avis médical permet d’en comprendre la cause (stress, poids, thyroïde, ovaires…).'));
    }
    final variation = insights.variation;
    if (!hormonal && variation != null && insights.cycleLengths.length >= 3 && variation > (teen ? 14 : 9)) {
      out.add(HealthSignal('irregular', 'info', 'Cycles irréguliers',
          'Vos cycles varient de $variation jours. Les prévisions sont donc moins précises : la fourchette affichée en tient compte.'
          '${teen ? ' Dans les premières années après les premières règles, c’est fréquent.' : ''}'));
    }

    final eps = _episodes(logs);
    final recentEps = eps.length > 3 ? eps.sublist(eps.length - 3) : eps;
    if (recentEps.where((e) => e.length > 7).length >= 2) {
      out.add(const HealthSignal('longPeriods', 'consult', 'Règles longues',
          'Vos règles ont duré plus de 7 jours à plusieurs reprises. Parlez-en à un professionnel de santé, surtout si vous vous sentez fatiguée ou essoufflée.'));
    }
    if (recentEps.where((e) => e.heavyDays >= 4).length >= 2) {
      out.add(const HealthSignal('heavyPeriods', 'consult', 'Règles abondantes',
          'Flux abondant noté plusieurs jours de suite, sur plusieurs cycles. Des règles très abondantes peuvent provoquer une anémie : un avis médical est conseillé.'));
    }
    if (recentEps.length >= 2 && recentEps.where((e) => e.crampDays >= 3).length >= 2) {
      out.add(const HealthSignal('pain', 'consult', 'Douleurs de règles fréquentes',
          'Vous notez des crampes plusieurs jours à chaque cycle. Des règles douloureuses ne sont pas une fatalité : si la douleur vous empêche d’aller en cours ou au travail, consultez. Certaines causes, comme l’endométriose, se soignent.'));
    }

    // Saignements en dehors des règles (spotting répété)
    final spotting = <DateTime>[];
    logs.forEach((iso, l) {
      final d = Dates.parseIso(iso);
      if (d == null || l.flow != 'spotting' || Dates.diffInDays(now, d) > 120) return;
      final nearPeriod = eps.any((e) => Dates.diffInDays(d, e.start) >= -2 && Dates.diffInDays(d, e.end) <= 2);
      if (!nearPeriod) spotting.add(d);
    });
    if (spotting.length >= 3) {
      out.add(const HealthSignal('spotting', 'consult', 'Saignements entre les règles',
          'Vous avez noté plusieurs saignements en dehors de vos règles ces derniers mois. Parlez-en à un professionnel de santé.'));
    }

    // Absence de règles prolongée
    final lastStart = insights.lastPeriodStart;
    if (!hormonal && lastStart != null && Dates.diffInDays(now, lastStart) > 90) {
      out.add(const HealthSignal('amenorrhea', 'consult', 'Pas de règles depuis plus de 3 mois',
          'Aucune règle notée depuis plus de 90 jours. Si une grossesse est possible, faites un test. Dans tous les cas, une consultation est recommandée.'));
    } else if (cycle.isLate && cycle.daysLate >= 7) {
      out.add(HealthSignal('late', 'info', 'Retard de règles',
          'Vos règles ont ${cycle.daysLate} jours de retard. Le stress, la fatigue ou un voyage peuvent décaler le cycle. Si vous avez eu un rapport sans protection, un test de grossesse est conseillé.'));
    }
    return out;
  }
}
