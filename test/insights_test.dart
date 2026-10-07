import 'package:flutter_test/flutter_test.dart';
import 'package:lago/core/alerts.dart';
import 'package:lago/core/insights.dart';
import 'package:lago/core/models.dart';
import 'package:lago/core/utils.dart';

DayLog _flow(String f, {List<String> symptoms = const [], String temp = ''}) =>
    DayLog(flow: f, symptoms: symptoms, temperature: temp, updatedAt: '2026-01-01T00:00:00Z');

Map<String, DayLog> _periods(List<String> starts, {int days = 5}) {
  final m = <String, DayLog>{};
  for (final s in starts) {
    final d = Dates.parseIso(s)!;
    for (var i = 0; i < days; i++) {
      m[Dates.toIso(Dates.addDays(d, i))] = _flow(i == 0 ? 'heavy' : 'medium', symptoms: i == 0 ? ['cramps'] : const []);
    }
  }
  return m;
}

void main() {
  group('Apprentissage du cycle', () {
    test('durées réelles mesurées depuis le journal', () {
      final ins = CycleInsights.compute(_periods(['2026-06-01', '2026-07-01', '2026-07-31', '2026-08-30']));
      expect(ins.periodStarts.length, 4);
      expect(ins.cycleLengths, [30, 30, 30]);
      expect(ins.learnedCycleLength, 30);
      expect(ins.learnedPeriodLength, 5);
    });

    test('un seul cycle mesuré : pas encore d’apprentissage', () {
      final ins = CycleInsights.compute(_periods(['2026-08-01', '2026-08-29']));
      expect(ins.cycleLengths, [28]);
      expect(ins.learnedCycleLength, isNull);
    });

    test('le spotting ne compte pas comme des règles', () {
      final logs = _periods(['2026-08-01']);
      logs['2026-08-15'] = _flow('spotting');
      expect(CycleInsights.compute(logs).periodStarts.length, 1);
    });

    test('apply : date des dernières règles et durées mises à jour', () {
      final ins = CycleInsights.compute(_periods(['2026-06-01', '2026-07-01', '2026-07-31']));
      const s = CycleSettings(lastPeriodDate: '2026-06-01', cycleLength: 28, periodDuration: 4);
      final eff = ins.apply(s);
      expect(eff.lastPeriodDate, '2026-07-31');
      expect(eff.cycleLength, 30);
      expect(eff.periodDuration, 5);
      // Apprentissage désactivé : réglages inchangés
      expect(ins.apply(s.copyWith(learnFromJournal: false)).cycleLength, 28);
    });

    test('symptômes et températures', () {
      final logs = _periods(['2026-08-01', '2026-08-29']);
      logs['2026-08-10'] = _flow('none', temp: '36,6');
      logs['2026-08-11'] = _flow('none', temp: '36.9');
      final ins = CycleInsights.compute(logs);
      expect(ins.symptomCounts.first.key, 'cramps');
      expect(ins.symptomCounts.first.value, 2);
      expect(ins.temperatures.length, 2);
    });
  });

  group('Pilule', () {
    test('plaquette 21 + 7 : pas de rappel pendant la pause', () {
      final p = AlertPrefs.defaults().copyWith(pillBreakDays: 7, pillStartDate: '2026-09-01');
      expect(p.pillDay(DateTime(2026, 9, 1)), isTrue);
      expect(p.pillDay(DateTime(2026, 9, 21)), isTrue);
      expect(p.pillDay(DateTime(2026, 9, 22)), isFalse);
      expect(p.pillDay(DateTime(2026, 9, 28)), isFalse);
      expect(p.pillDay(DateTime(2026, 9, 29)), isTrue);
    });

    test('pilule en continu', () {
      final p = AlertPrefs.defaults();
      expect(p.pillDay(DateTime(2026, 9, 25)), isTrue);
    });
  });
}
