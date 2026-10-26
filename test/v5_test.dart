import 'package:flutter_test/flutter_test.dart';
import 'package:lago/core/calculator.dart';
import 'package:lago/core/content_extra.dart';
import 'package:lago/core/insights.dart';
import 'package:lago/core/life_mode.dart';
import 'package:lago/core/models.dart';
import 'package:lago/core/monthly_report.dart';
import 'package:lago/core/prediction.dart';
import 'package:lago/core/utils.dart';

const _ts = '2026-01-01T00:00:00Z';

DayLog _log({String flow = 'none', String temp = '', String lh = '', String mucus = '', List<String> symptoms = const []}) =>
    DayLog(flow: flow, temperature: temp, ovulationTest: lh, mucus: mucus, symptoms: symptoms, updatedAt: _ts);

Map<String, DayLog> _episode(String start, int days, String flow, {List<String> symptoms = const []}) {
  final d = Dates.parseIso(start)!;
  return {for (var i = 0; i < days; i++) Dates.toIso(Dates.addDays(d, i)): _log(flow: flow, symptoms: symptoms)};
}

void main() {
  group('Ovulation confirmée', () {
    test('remplace l’estimation et décale les prochaines règles (ovulation + 14 j)', () {
      final r = CycleCalculator.calculate('2026-09-01', 28, 5,
          target: DateTime(2026, 9, 20), confirmedOvulation: DateTime(2026, 9, 17));
      expect(r.ovulationConfirmed, isTrue);
      expect(Dates.toIso(r.ovulationDate), '2026-09-17');
      expect(Dates.toIso(r.nextPeriodStart), '2026-10-01');
      expect(Dates.toIso(r.fertileStart), '2026-09-12');
    });

    test('une date future ou pendant les règles est ignorée', () {
      final future = CycleCalculator.calculate('2026-09-01', 28, 5,
          target: DateTime(2026, 9, 20), confirmedOvulation: DateTime(2026, 9, 25));
      expect(future.ovulationConfirmed, isFalse);
      expect(Dates.toIso(future.ovulationDate), '2026-09-14');
      final duringPeriod = CycleCalculator.calculate('2026-09-01', 28, 5,
          target: DateTime(2026, 9, 20), confirmedOvulation: DateTime(2026, 9, 3));
      expect(duringPeriod.ovulationConfirmed, isFalse);
    });
  });

  group('Signes de fertilité', () {
    final from = DateTime(2026, 9, 1);
    final to = DateTime(2026, 9, 25);

    test('test LH positif → ovulation le lendemain', () {
      final s = FertilitySigns.detect({'2026-09-15': _log(lh: 'positive')}, from, to)!;
      expect(Dates.toIso(s.date), '2026-09-16');
      expect(s.method, 'lh');
    });

    test('décalage thermique (3 températures hautes)', () {
      final logs = <String, DayLog>{};
      for (var d = 5; d <= 10; d++) {
        logs['2026-09-${d.toString().padLeft(2, '0')}'] = _log(temp: '36.4');
      }
      for (var d = 11; d <= 13; d++) {
        logs['2026-09-$d'] = _log(temp: '36,8');
      }
      final s = FertilitySigns.detect(logs, from, to)!;
      expect(s.method, 'temperature');
      expect(Dates.toIso(s.date), '2026-09-10');
    });

    test('glaire : jour sommet', () {
      final s = FertilitySigns.detect({'2026-09-12': _log(mucus: 'eggwhite'), '2026-09-13': _log(mucus: 'sticky')}, from, to)!;
      expect(s.method, 'mucus');
      expect(Dates.toIso(s.date), '2026-09-12');
    });

    test('aucun signe → null', () {
      expect(FertilitySigns.detect({'2026-09-12': _log(temp: '36.5')}, from, to), isNull);
    });
  });

  group('Fourchette de prévision', () {
    test('sans historique : selon la régularité déclarée', () {
      final cycle = CycleCalculator.calculate('2026-09-01', 28, 5, target: DateTime(2026, 9, 10));
      final settings = CycleSettings(lastPeriodDate: '2026-09-01', cycleRegularity: 'regular');
      final w = PeriodWindow.compute(cycle, CycleInsights.compute(const {}), settings);
      expect(w.spread, 1);
      expect(Dates.toIso(w.earliest), '2026-09-28');
      expect(Dates.toIso(w.latest), '2026-09-30');
      expect(w.confidence, 'low');
    });

    test('cycles variables → fourchette plus large', () {
      final logs = <String, DayLog>{
        ..._episode('2026-05-01', 4, 'medium'),
        ..._episode('2026-05-27', 4, 'medium'), // 26 j
        ..._episode('2026-06-30', 4, 'medium'), // 34 j
        ..._episode('2026-07-26', 4, 'medium'), // 26 j
      };
      final ins = CycleInsights.compute(logs);
      final cycle = CycleCalculator.calculate('2026-07-26', 29, 4, target: DateTime(2026, 8, 5));
      final w = PeriodWindow.compute(cycle, ins, const CycleSettings(lastPeriodDate: '2026-07-26'));
      expect(w.spread, greaterThanOrEqualTo(3));
    });
  });

  group('Signaux de santé', () {
    test('règles abondantes répétées → consulter', () {
      final logs = {..._episode('2026-08-01', 5, 'heavy'), ..._episode('2026-08-29', 5, 'heavy')};
      final ins = CycleInsights.compute(logs);
      final settings = const CycleSettings(lastPeriodDate: '2026-08-29');
      final cycle = CycleCalculator.calculate('2026-08-29', 28, 5, target: DateTime(2026, 9, 10));
      final sig = HealthSignals.evaluate(logs: logs, insights: ins, settings: settings, cycle: cycle, today: DateTime(2026, 9, 10));
      expect(sig.map((s) => s.key), contains('heavyPeriods'));
      expect(sig.firstWhere((s) => s.key == 'heavyPeriods').isConsult, isTrue);
    });

    test('rien en mode grossesse', () {
      final logs = {..._episode('2026-08-01', 9, 'heavy'), ..._episode('2026-08-29', 9, 'heavy')};
      final sig = HealthSignals.evaluate(
          logs: logs,
          insights: CycleInsights.compute(logs),
          settings: const CycleSettings(lastPeriodDate: '2026-08-29', lifeMode: 'pregnancy'),
          cycle: CycleCalculator.calculate('2026-08-29', 28, 5));
      expect(sig, isEmpty);
    });

    test('absence de règles > 90 jours', () {
      final logs = _episode('2026-05-01', 4, 'medium');
      final sig = HealthSignals.evaluate(
          logs: logs,
          insights: CycleInsights.compute(logs),
          settings: const CycleSettings(lastPeriodDate: '2026-05-01'),
          cycle: CycleCalculator.calculate('2026-05-01', 28, 4, target: DateTime(2026, 9, 1)),
          today: DateTime(2026, 9, 1));
      expect(sig.map((s) => s.key), contains('amenorrhea'));
    });
  });

  group('Modes de vie', () {
    test('grossesse : semaines, terme et trimestre', () {
      final p = PregnancyInfo.fromIso('2026-01-01', today: DateTime(2026, 3, 12))!;
      expect(p.weeks, 10);
      expect(p.extraDays, 0);
      expect(Dates.toIso(p.dueDate), '2026-10-08');
      expect(p.trimester, 1);
      expect(p.step.fromWeek, 10);
    });

    test('réglages v5 : lecture, écriture, effacement des dates', () {
      final s = CycleSettings.fromJson({
        'lastPeriodDate': '2026-09-01',
        'lifeMode': 'pregnancy',
        'contraception': 'implant',
        'pregnancyStartDate': '2026-08-01',
        'dataSaver': true,
        'ramadanMode': true,
      });
      expect(s.isPregnant, isTrue);
      expect(s.tracksPeriods, isFalse);
      expect(s.contraception, 'implant');
      expect(s.dataSaver, isTrue);
      expect(CycleSettings.fromJson(s.toJson()).pregnancyStartDate, '2026-08-01');
      expect(s.copyWith(pregnancyStartDate: '').pregnancyStartDate, isNull);
      expect(s.copyWith(lifeMode: 'cycle').pregnancyStartDate, '2026-08-01');
      expect(CycleSettings.fromJson({'lifeMode': 'nimporte', 'contraception': '??'}).lifeMode, 'cycle');
      expect(Contraception.isHormonal('implant'), isTrue);
      expect(Contraception.isHormonal('iud_copper'), isFalse);
    });

    test('journal v5 : test d’ovulation et glaire', () {
      final l = DayLog.fromJson({'flow': 'none', 'ovulationTest': 'peak', 'mucus': 'eggwhite', 'updatedAt': _ts});
      expect(l.hasPositiveLh, isTrue);
      expect(l.hasFertileMucus, isTrue);
      expect(DayLog.fromJson(l.toJson()).mucus, 'eggwhite');
      expect(DayLog.fromJson({'ovulationTest': 'x', 'mucus': '<b>'}).ovulationTest, '');
    });
  });

  group('Bilan et contenus', () {
    test('bilan du mois', () {
      final logs = _episode('2026-09-01', 4, 'medium', symptoms: ['cramps']);
      final r = MonthlyReport.compute(logs, DateTime(2026, 9, 15));
      expect(r.loggedDays, 4);
      expect(r.periodStarts.length, 1);
      expect(r.periodLengths.first, 4);
      expect(r.topSymptoms.first.key, 'cramps');
      expect(r.advice, contains('crampes'));
      expect(MonthlyReport.compute(logs, DateTime(2026, 10, 1)).isEmpty, isTrue);
    });

    test('assistant hors ligne : recherche par mots-clés (accents ignorés)', () {
      final hits = ExtraContent.search('Comment calmer les douleurs de règles ?');
      expect(hits, isNotEmpty);
      expect(hits.first.question, contains('douleurs'));
      expect(ExtraContent.search('zz'), isEmpty);
    });
  });
}
