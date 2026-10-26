import 'package:flutter_test/flutter_test.dart';
import 'package:lago/core/alerts.dart';
import 'package:lago/core/calculator.dart';
import 'package:lago/core/content.dart';
import 'package:lago/core/models.dart';
import 'package:lago/core/storage.dart';
import 'package:lago/core/tracker.dart';
import 'package:lago/core/utils.dart';
import 'package:lago/screens/phases_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Dates', () {
    test('lecture AAAA-MM-JJ en heure locale', () {
      final d = Dates.parseIso('2026-09-03')!;
      expect(d.day, 3);
      expect(d.month, 9);
      expect(Dates.parseIso('2026-13-45'), isNull);
    });

    test('format français', () {
      expect(Dates.long(DateTime(2026, 10, 3)), '3 octobre 2026');
      expect(Dates.short(DateTime(2026, 2, 14)), '14 févr.');
    });
  });

  group('CycleCalculator', () {
    test('cycle de 28 jours', () {
      final r = CycleCalculator.calculate('2026-09-01', 28, 5, target: DateTime(2026, 9, 12));
      expect(r.currentCycleDay, 12);
      expect(Dates.toIso(r.ovulationDate), '2026-09-14'); // Jour 14, comme Flo
      expect(Dates.toIso(r.fertileStart), '2026-09-09');
      expect(Dates.toIso(r.fertileEnd), '2026-09-15');
      expect(Dates.toIso(r.nextPeriodStart), '2026-09-29');
      expect(r.phase.key, PhaseKey.ovulation);
    });

    test('règles non notées : retard affiché au lieu d’un nouveau cycle', () {
      final r = CycleCalculator.calculate('2026-09-01', 28, 5, target: DateTime(2026, 10, 3));
      expect(r.isLate, isTrue);
      expect(r.daysLate, 5);
      expect(r.currentCycleDay, 33);
      expect(Dates.toIso(r.expectedPeriodStart), '2026-09-29');
      expect(Dates.toIso(r.nextPeriodStart), '2026-10-03');
    });

    test('plus de 14 jours de retard : recalage sur le cycle en cours', () {
      final r = CycleCalculator.calculate('2026-09-01', 28, 5, target: DateTime(2026, 10, 20));
      expect(r.isLate, isFalse);
      expect(r.currentCycleDay, inInclusiveRange(1, 28));
    });

    test('phases menstruelle, folliculaire, lutéale', () {
      expect(CycleCalculator.calculate('2026-09-01', 28, 5, target: DateTime(2026, 9, 3)).phase.key, PhaseKey.menstrual);
      expect(CycleCalculator.calculate('2026-09-01', 28, 5, target: DateTime(2026, 9, 7)).phase.key, PhaseKey.follicular);
      expect(CycleCalculator.calculate('2026-09-01', 28, 5, target: DateTime(2026, 9, 20)).phase.key, PhaseKey.luteal);
    });

    test('date ancienne ou future recalée', () {
      final old = CycleCalculator.calculate('2026-01-01', 28, 5, target: DateTime(2026, 9, 30));
      expect(old.currentCycleDay, inInclusiveRange(1, 28));
      final future = CycleCalculator.calculate('2026-10-10', 28, 5, target: DateTime(2026, 9, 30));
      expect(future.currentCycleDay, inInclusiveRange(1, 28));
    });

    test('prévisions consécutives', () {
      final c = CycleCalculator.forecast('2026-01-01', 30, 5, count: 6);
      expect(c.length, 6);
      expect(Dates.diffInDays(c[1].periodStart, c[0].periodStart), 30);
    });
  });

  group('Secrets', () {
    test('hachage et vérification', () {
      final h = Secrets.hash('2468');
      expect(h.startsWith('pbkdf2\$'), isTrue);
      expect(Secrets.verify('2468', h), isTrue);
      expect(Secrets.verify('1357', h), isFalse);
    });
  });

  group('Tracker', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Store.init();
    });

    test('journal, export et import', () async {
      final t = Tracker()..userId = 'u1';
      await t.saveLog('2026-09-10', DayLog(flow: 'medium', symptoms: const ['cramps'], updatedAt: DateTime.now().toIso8601String()));
      expect(t.logFor('2026-09-10')!.flow, 'medium');
      final json = t.exportJson(null);

      final other = Tracker()..userId = 'u2';
      final n = await other.importJson(json);
      expect(n, 1);
      expect(other.logFor('2026-09-10')!.symptoms, ['cramps']);
      await expectLater(other.importJson('{"foo":1}'), throwsFormatException);
    });

    test('code PIN local', () async {
      final t = Tracker()..userId = 'u3';
      expect(t.hasPin, isFalse);
      await t.setPin('1234');
      expect(t.checkPin('1234'), isTrue);
      expect(t.checkPin('0000'), isFalse);
    });
  });

  group('Contenu', () {
    test('conseils adaptés à l’âge', () {
      expect(LagoContent.tipsFor(15).every((t) => !t.adultOnly), isTrue);
      expect(LagoContent.tipsFor(25).length, greaterThan(LagoContent.tipsFor(15).length));
      expect(LagoContent.tipOfDay(DateTime(2026, 10, 1), 14).adultOnly, isFalse);
      expect(LagoContent.phases.length, 4);
    });

    test('jours des phases', () {
      final r = PhaseRanges.compute(28, 5);
      expect(r.of(PhaseKey.menstrual).label, 'jours 1 à 5');
      expect(r.of(PhaseKey.ovulation).start, 9);
      expect(r.of(PhaseKey.ovulation).end, 15);
      expect(r.of(PhaseKey.luteal).end, 28);
    });
  });

  group('Alertes', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Store.init();
    });

    test('préférences enregistrées et relues', () async {
      final p = AlertPrefs.defaults()
          .withAlert(AlertType.dailyTip, const AlertSetting(enabled: true, sound: 'lago_harpe', vibrate: false))
          .copyWith(tipHour: 7, tipMinute: 45, periodSoonDays: 3);
      await p.save('u9');
      final back = AlertPrefs.load('u9');
      expect(back.of(AlertType.dailyTip).sound, 'lago_harpe');
      expect(back.of(AlertType.dailyTip).vibrate, isFalse);
      expect(back.tipHour, 7);
      expect(back.periodSoonDays, 3);
      expect(Sounds.of('lago_harpe').label, 'Harpe');
    });
  });
}
