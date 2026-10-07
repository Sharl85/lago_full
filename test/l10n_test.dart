import 'package:flutter_test/flutter_test.dart';
import 'package:lago/core/utils.dart';
import 'package:lago/l10n/en.dart';
import 'package:lago/l10n/l10n.dart';

void main() {
  tearDown(() => L.lang = 'fr');

  test('français : le texte reste inchangé', () {
    L.lang = 'fr';
    expect(tr('Mon compte'), 'Mon compte');
  });

  test('anglais : traduction directe', () {
    L.lang = 'en';
    expect(tr('Mon compte'), 'My account');
    expect(tr('Phase Lutéale'), 'Luteal Phase');
  });

  test('anglais : phrases avec valeurs', () {
    L.lang = 'en';
    expect(tr('Jour 12'), 'Day 12');
    expect(tr('Règles dans 2 jours 🩸'), 'Period in 2 days 🩸');
    expect(tr('Règles dans 1 jour 🩸'), 'Period in 1 day 🩸');
    expect(tr('Votre cycle de 30 jours'), 'Your 30-day cycle');
    expect(tr('Attribuer le rôle « Utilisatrice » à Léa ?'), 'Give the role “User” to Léa?');
  });

  test('anglais : texte inconnu laissé tel quel', () {
    L.lang = 'en';
    expect(tr('Sarah Dupont'), 'Sarah Dupont');
  });

  test('dates en anglais', () {
    L.lang = 'en';
    expect(Dates.long(DateTime(2026, 10, 3)), 'October 3, 2026');
  });

  test('espagnol, portugais et arabe', () {
    L.lang = 'es';
    expect(tr('Jour 12'), contains('12'));
    expect(Dates.long(DateTime(2026, 10, 3)), '3 de octubre de 2026');
    L.lang = 'pt';
    expect(Dates.long(DateTime(2026, 10, 3)), '3 de outubro de 2026');
    L.lang = 'ar';
    expect(L.isRtl, isTrue);
    expect(tr('Mon compte'), isNot('Mon compte'));
  });

  test('toutes les langues ont les mêmes clés', () {
    for (final entry in L.dictionaries.entries) {
      if (entry.key == 'en') continue;
      for (final k in L.dictionaries['es']!.keys) {
        expect(entry.value.containsKey(k), isTrue, reason: '${entry.key}: $k');
      }
    }
  });

  test('chaque modèle anglais utilise toutes ses valeurs', () {
    enStrings.forEach((fr, en) {
      final n = '{}'.allMatches(fr).length;
      for (var i = 0; i < n; i++) {
        expect(en.contains('{$i}'), isTrue, reason: fr);
      }
    });
  });
}
