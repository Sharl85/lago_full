import 'package:flutter/material.dart';

import 'utils.dart';

enum PhaseKey { menstrual, follicular, ovulation, luteal }

class Phase {
  final PhaseKey key;
  final String name;
  final String summary;
  final Color color;
  final Color background;
  const Phase(this.key, this.name, this.summary, this.color, this.background);
}

class Wisdom {
  final String title;
  final String energy;
  final String hormones;
  final String nutrition;
  final String sport;
  final String advice;
  const Wisdom(this.title, this.energy, this.hormones, this.nutrition, this.sport, this.advice);
}

class CycleData {
  final int currentCycleDay;
  final int cycleLength;
  final int periodDuration;
  final int progressPercent;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final DateTime nextPeriodStart;
  final DateTime nextPeriodEnd;
  final DateTime ovulationDate;
  final DateTime fertileStart;
  final DateTime fertileEnd;
  final int daysUntilNextPeriod;
  final int daysUntilOvulation;

  /// Règles attendues mais pas encore notées (comme « en retard » dans Flo).
  final bool isLate;
  final int daysLate;

  /// Date à laquelle les règles étaient attendues (= nextPeriodStart hors retard).
  final DateTime expectedPeriodStart;

  /// v5 — ovulation confirmée par un signe noté (test LH, température, glaire) plutôt qu'estimée.
  final bool ovulationConfirmed;
  final Phase phase;
  final String pregnancyChance;
  final Wisdom wisdom;

  const CycleData({
    required this.currentCycleDay,
    required this.cycleLength,
    required this.periodDuration,
    required this.progressPercent,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.nextPeriodStart,
    required this.nextPeriodEnd,
    required this.ovulationDate,
    required this.fertileStart,
    required this.fertileEnd,
    required this.daysUntilNextPeriod,
    required this.daysUntilOvulation,
    this.isLate = false,
    this.daysLate = 0,
    required this.expectedPeriodStart,
    this.ovulationConfirmed = false,
    required this.phase,
    required this.pregnancyChance,
    required this.wisdom,
  });
}

class ForecastCycle {
  final int index;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime ovulationDate;
  final DateTime fertileStart;
  final DateTime fertileEnd;
  const ForecastCycle(this.index, this.periodStart, this.periodEnd, this.ovulationDate, this.fertileStart, this.fertileEnd);
}

enum DayType { normal, period, periodPredicted, fertile, ovulation }

/// Moteur de calcul du cycle (même algorithme que la version web testée).
class CycleCalculator {
  static const lutealPhase = 14;

  /// Jours de retard pendant lesquels on affiche « règles en retard » (comme Flo)
  /// avant de basculer automatiquement sur le cycle suivant.
  static const lateTolerance = 14;

  static const phases = {
    PhaseKey.menstrual: Phase(PhaseKey.menstrual, 'Phase Menstruelle', 'Repos, écoute de son corps et douceur.',
        Color(0xFFE57373), Color(0xFFFFEBEE)),
    PhaseKey.follicular: Phase(PhaseKey.follicular, 'Phase Folliculaire', 'Énergie montante, créativité et renouveau.',
        Color(0xFF66BB6A), Color(0xFFE8F5E9)),
    PhaseKey.ovulation: Phase(PhaseKey.ovulation, 'Phase Ovulatoire', 'Pic d’énergie, sociabilité et fertilité maximale.',
        Color(0xFFBA68C8), Color(0xFFF3E5F5)),
    PhaseKey.luteal: Phase(PhaseKey.luteal, 'Phase Lutéale', 'Ralentissement, cocooning et préparation au nouveau cycle.',
        Color(0xFFFFA726), Color(0xFFFFF3E0)),
  };

  static int _clampCycle(int v) => v.clamp(15, 60).toInt();
  static int _clampPeriod(int v, int cycle) => v.clamp(1, cycle - 1).toInt();

  /// Jours entre le Jour 1 des règles et l'ovulation.
  /// Ovulation au Jour (cycle − 14), soit Jour 1 + (cycle − 14 − 1) : J14 pour 28 jours, comme Flo.
  /// (Correction : l'ancien calcul donnait J15, un jour trop tard, fenêtre fertile comprise.)
  static int ovulationOffset(int cycleLength, int periodDuration) {
    final o = cycleLength - lutealPhase - 1;
    return o < periodDuration ? periodDuration : o;
  }

  /// [confirmedOvulation] : date d'ovulation détectée dans le journal pour le cycle en cours
  /// (voir FertilitySigns). Elle remplace l'estimation, et les prochaines règles sont
  /// alors attendues 14 jours après (durée de la phase lutéale), comme dans Flo.
  static CycleData calculate(String lastPeriodIso, int cycleLength, int periodDuration,
      {DateTime? target, DateTime? confirmedOvulation}) {
    final today = Dates.dateOnly(target ?? DateTime.now());
    var lmp = Dates.parseIso(lastPeriodIso) ?? Dates.addDays(today, -12);
    cycleLength = _clampCycle(cycleLength);
    periodDuration = _clampPeriod(periodDuration, cycleLength);

    // Règles attendues mais pas encore notées : retard affiché pendant [lateTolerance] jours.
    // Au-delà (ou date future) : recalage sur le cycle en cours (comportement d'origine).
    var since = Dates.diffInDays(today, lmp);
    var isLate = false;
    var daysLate = 0;
    if (since >= cycleLength && since < cycleLength + lateTolerance) {
      isLate = true;
      daysLate = since - cycleLength + 1;
    } else if (since >= cycleLength || since < 0) {
      final shift = (since / cycleLength).floor();
      lmp = Dates.addDays(lmp, shift * cycleLength);
      since = Dates.diffInDays(today, lmp);
    }

    final currentPeriodEnd = Dates.addDays(lmp, periodDuration - 1);
    var expectedPeriodStart = Dates.addDays(lmp, cycleLength);
    var ovulation = Dates.addDays(lmp, ovulationOffset(cycleLength, periodDuration));

    // Ovulation confirmée dans ce cycle (après les règles, pas dans le futur)
    var confirmed = false;
    final co = confirmedOvulation == null ? null : Dates.dateOnly(confirmedOvulation);
    if (co != null && co.isAfter(currentPeriodEnd) && !co.isAfter(today) && Dates.diffInDays(co, lmp) < 60) {
      confirmed = true;
      ovulation = co;
      expectedPeriodStart = Dates.addDays(co, lutealPhase);
      final overdue = Dates.diffInDays(today, expectedPeriodStart);
      isLate = overdue >= 0 && overdue < lateTolerance;
      daysLate = isLate ? overdue + 1 : 0;
    }
    final nextPeriodStart = isLate ? today : expectedPeriodStart;
    final nextPeriodEnd = Dates.addDays(nextPeriodStart, periodDuration - 1);
    final fertileStart = Dates.addDays(ovulation, -5);
    final fertileEnd = Dates.addDays(ovulation, 1);

    final day = since + 1;
    final progress = ((day / cycleLength) * 100).round().clamp(0, 100).toInt();

    bool between(DateTime d, DateTime a, DateTime b) => !d.isBefore(a) && !d.isAfter(b);

    PhaseKey key = PhaseKey.follicular;
    if (day <= periodDuration) {
      key = PhaseKey.menstrual;
    } else if (between(today, fertileStart, fertileEnd)) {
      key = PhaseKey.ovulation;
    } else if (today.isAfter(fertileEnd)) {
      key = PhaseKey.luteal;
    }

    var chance = 'Très faible';
    if (Dates.diffInDays(today, ovulation) == 0) {
      chance = "Maximale (jour d'ovulation)";
    } else if (between(today, fertileStart, fertileEnd)) {
      chance = 'Élevée (fenêtre fertile)';
    } else if (today.isBefore(fertileStart) && Dates.diffInDays(today, fertileStart) >= -2) {
      chance = 'Moyenne';
    }

    return CycleData(
      currentCycleDay: day,
      cycleLength: cycleLength,
      periodDuration: periodDuration,
      progressPercent: progress,
      currentPeriodStart: lmp,
      currentPeriodEnd: currentPeriodEnd,
      nextPeriodStart: nextPeriodStart,
      nextPeriodEnd: nextPeriodEnd,
      ovulationDate: ovulation,
      fertileStart: fertileStart,
      fertileEnd: fertileEnd,
      daysUntilNextPeriod: Dates.diffInDays(nextPeriodStart, today),
      daysUntilOvulation: Dates.diffInDays(ovulation, today),
      isLate: isLate,
      daysLate: daysLate,
      expectedPeriodStart: expectedPeriodStart,
      ovulationConfirmed: confirmed,
      phase: phases[key]!,
      pregnancyChance: chance,
      wisdom: wisdom[key]!,
    );
  }

  /// Prévisions ; [fromToday] démarre au cycle en cours au lieu de la date saisie.
  static List<ForecastCycle> forecast(String lastPeriodIso, int cycleLength, int periodDuration,
      {int count = 6, bool fromToday = false}) {
    cycleLength = _clampCycle(cycleLength);
    periodDuration = _clampPeriod(periodDuration, cycleLength);
    var start = Dates.parseIso(lastPeriodIso) ?? Dates.today();
    if (fromToday) {
      final elapsed = Dates.diffInDays(Dates.today(), start);
      if (elapsed >= cycleLength + lateTolerance || elapsed < 0) {
        start = Dates.addDays(start, (elapsed / cycleLength).floor() * cycleLength);
      }
    }
    return List.generate(count, (i) {
      final ps = Dates.addDays(start, cycleLength * i);
      final ov = Dates.addDays(ps, ovulationOffset(cycleLength, periodDuration));
      return ForecastCycle(i + 1, ps, Dates.addDays(ps, periodDuration - 1), ov, Dates.addDays(ov, -5), Dates.addDays(ov, 1));
    });
  }

  /// Statut d'un jour pour le calendrier.
  static DayType dayType(DateTime date, List<ForecastCycle> cycles) {
    final d = Dates.dateOnly(date);
    final today = Dates.today();
    for (final c in cycles) {
      if (!d.isBefore(c.periodStart) && !d.isAfter(c.periodEnd)) {
        return d.isAfter(today) ? DayType.periodPredicted : DayType.period;
      }
      if (Dates.diffInDays(d, c.ovulationDate) == 0) return DayType.ovulation;
      if (!d.isBefore(c.fertileStart) && !d.isAfter(c.fertileEnd)) return DayType.fertile;
    }
    return DayType.normal;
  }

  static const wisdom = {
    PhaseKey.menstrual: Wisdom(
      "Phase Menstruelle (L'Hiver Intérieur)",
      'Douce & calme',
      'Baisse des œstrogènes et de la progestérone',
      'Aliments riches en fer (lentilles, épinards), bouillons chauds, chocolat noir, tisanes de feuilles de framboisier et camomille.',
      'Marche tranquille, étirements doux, yoga restauratif, respiration profonde.',
      "Accordez-vous de la bienveillance et du repos. C'est le moment idéal pour ralentir et écouter vos besoins profonds.",
    ),
    PhaseKey.follicular: Wisdom(
      'Phase Folliculaire (Le Printemps Intérieur)',
      'Montante & créative',
      'Augmentation progressive des œstrogènes',
      'Aliments frais, graines de courge et de lin (seed cycling), protéines légères, agrumes et légumes verts croquants.',
      'Cardio, danse, renforcement musculaire, randonnée rythmée.',
      'Votre clarté mentale et votre enthousiasme sont au plus haut. Idéal pour démarrer de nouveaux projets ou planifier vos objectifs.',
    ),
    PhaseKey.ovulation: Wisdom(
      "Phase Ovulatoire (L'Été Intérieur)",
      'Rayonnante & magnétique',
      "Pic d'œstrogènes et poussée de LH",
      "Aliments riches en antioxydants (baies, grenade), fibres douces, hydratation renforcée à l'eau infusée.",
      'HIIT, séances intenses, sports collectifs, dépassement de soi.',
      "Vous êtes à l'apogée de votre sociabilité et de votre confiance. Parfait pour les présentations, rencontres et moments festifs !",
    ),
    PhaseKey.luteal: Wisdom(
      "Phase Lutéale (L'Automne Intérieur)",
      'Centrée & réflexive',
      'Hausse de la progestérone puis chute avant les règles',
      'Magnésium (graines de tournesol, bananes), glucides complexes (patate douce, avoine), tisanes de mélisse et gingembre.',
      'Pilates, natation douce, renforcement modéré, étirements.',
      'Créez un environnement chaleureux et apaisant. Prenez soin de vos émotions, privilégiez le confort et les nuits réparatrices.',
    ),
  };
}
