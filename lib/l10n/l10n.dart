import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';

import '../core/storage.dart';
import 'ar.dart';
import 'en.dart';
import 'es.dart';
import 'pt.dart';

/// LaGo — langues : français (langue source), anglais, espagnol, portugais et arabe.
///
/// Le texte est écrit en français dans le code ; [tr] le traduit dans la langue active
/// à l'aide des dictionnaires `en.dart`, `es.dart`, `pt.dart` et `ar.dart`.
/// Ajouter une langue = ajouter un dictionnaire et l'inscrire dans [L.dictionaries].
/// Les phrases contenant des valeurs (« Jour 12 ») sont reconnues grâce aux
/// modèles `{}` du dictionnaire (« Jour {} » → « Day {0} »).
class L {
  static const _key = 'lago_lang';

  /// 'system' (langue du téléphone) ou un code de langue.
  static String preference = 'system';

  /// Langue effectivement utilisée.
  static String lang = 'fr';

  /// Langues proposées : code → nom dans sa propre langue.
  static const languages = {
    'fr': 'Français',
    'en': 'English',
    'es': 'Español',
    'pt': 'Português',
    'ar': 'العربية',
  };

  static const Map<String, Map<String, String>> dictionaries = {
    'en': enStrings,
    'es': esStrings,
    'pt': ptStrings,
    'ar': arStrings,
  };

  static bool get isEn => lang == 'en';
  static bool get isRtl => lang == 'ar';

  static final Map<String, List<_Template>> _templates = {};

  static void init() {
    preference = Store.getString(_key) ?? 'system';
    lang = resolve(preference);
  }

  /// Langue du téléphone si LaGo la propose, anglais sinon.
  static String get systemLang {
    final code = PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    return languages.containsKey(code) ? code : 'en';
  }

  static String resolve(String pref) => languages.containsKey(pref) ? pref : systemLang;

  static Future<void> setPreference(String pref) async {
    preference = pref;
    lang = resolve(pref);
    await Store.setString(_key, pref);
  }

  static Locale get locale => Locale(lang);

  static List<_Template> _buildTemplates(Map<String, String> dict) {
    final list = <_Template>[];
    dict.forEach((fr, en) {
      if (!fr.contains('{}')) return;
      final parts = fr.split('{}');
      // Un modèle sans texte fixe (ex. « {} {} ») reconnaîtrait n'importe quelle phrase : ignoré.
      if (parts.join().trim().isEmpty) return;
      final pattern = parts.map(RegExp.escape).join('(.*?)');
      list.add(_Template(RegExp('^$pattern\$', dotAll: true), en, parts.length - 1));
    });
    // Les modèles les plus longs (les plus précis) d'abord
    list.sort((a, b) => b.re.pattern.length.compareTo(a.re.pattern.length));
    return list;
  }

  static String translate(String fr) {
    if (lang == 'fr' || fr.isEmpty) return fr;
    final dict = dictionaries[lang];
    if (dict == null) return fr;
    final direct = dict[fr];
    if (direct != null) return direct;
    final templates = _templates.putIfAbsent(lang, () => _buildTemplates(dict));
    for (final t in templates) {
      final m = t.re.firstMatch(fr);
      if (m == null) continue;
      var out = t.en;
      for (var i = 0; i < t.count; i++) {
        out = out.replaceAll('{$i}', translate(m.group(i + 1) ?? ''));
      }
      return out;
    }
    return fr;
  }
}

class _Template {
  final RegExp re;
  final String en;
  final int count;
  _Template(this.re, this.en, this.count);
}

/// Traduit un texte écrit en français vers la langue active.
String tr(String fr) => L.translate(fr);

/// Remplace `Text` : traduit automatiquement son contenu (compatible `const`).
class T extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;
  final bool? softWrap;
  const T(this.data, {super.key, this.style, this.textAlign, this.overflow, this.maxLines, this.softWrap});

  @override
  Widget build(BuildContext context) =>
      Text(tr(data), style: style, textAlign: textAlign, overflow: overflow, maxLines: maxLines, softWrap: softWrap);
}
