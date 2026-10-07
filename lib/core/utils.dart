import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../l10n/l10n.dart';

/// Utilitaires de dates (toujours en heure locale, à minuit).
class Dates {
  // Mois et jours dans chaque langue de l'application
  static const Map<String, List<String>> _monthsL = {
    'fr': ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'],
    'en': ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
    'es': ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'],
    'pt': ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'],
    'ar': ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'],
  };
  static const Map<String, List<String>> _monthsShortL = {
    'fr': ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'],
    'en': ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
    'es': ['ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.', 'jul.', 'ago.', 'sept.', 'oct.', 'nov.', 'dic.'],
    'pt': ['jan.', 'fev.', 'mar.', 'abr.', 'mai.', 'jun.', 'jul.', 'ago.', 'set.', 'out.', 'nov.', 'dez.'],
    'ar': ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'],
  };
  static const Map<String, List<String>> _weekdaysL = {
    'fr': ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'],
    'en': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    'es': ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'],
    'pt': ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'],
    'ar': ['إثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت', 'أحد'],
  };

  static List<String> get _months => _monthsL[L.lang] ?? _monthsL['fr']!;
  static List<String> get _monthsShort => _monthsShortL[L.lang] ?? _monthsShortL['fr']!;

  static List<String> get weekdaysShort => _weekdaysL[L.lang] ?? _weekdaysL['fr']!;

  static DateTime today() => dateOnly(DateTime.now());

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Ajoute des jours sans être affecté par les changements d'heure.
  static DateTime addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

  static int diffInDays(DateTime a, DateTime b) {
    final ua = DateTime.utc(a.year, a.month, a.day);
    final ub = DateTime.utc(b.year, b.month, b.day);
    return ua.difference(ub).inDays;
  }

  static String toIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? parseIso(String? s) {
    if (s == null) return null;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    final dt = DateTime(y, mo, d);
    if (dt.year != y || dt.month != mo || dt.day != d) return null;
    return dt;
  }

  /// 3 octobre 2026 / October 3, 2026 / 3 de octubre de 2026 / 3 أكتوبر 2026
  static String long(DateTime d) {
    final m = _months[d.month - 1];
    switch (L.lang) {
      case 'en':
        return '$m ${d.day}, ${d.year}';
      case 'es':
      case 'pt':
        return '${d.day} de $m de ${d.year}';
      default:
        return '${d.day} $m ${d.year}';
    }
  }

  /// 3 oct. / Oct 3
  static String short(DateTime d) => L.lang == 'en' ? '${_monthsShort[d.month - 1]} ${d.day}' : '${d.day} ${_monthsShort[d.month - 1]}';

  /// octobre 2026 / October 2026
  static String monthYear(DateTime d) => (L.lang == 'es' || L.lang == 'pt') ? '${_months[d.month - 1]} de ${d.year}' : '${_months[d.month - 1]} ${d.year}';

  static String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// 30/09 14:05 (09/30 en anglais)
  static String dateTime(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    final date = L.lang == 'en' ? '${two(d.month)}/${two(d.day)}' : '${two(d.day)}/${two(d.month)}';
    return '$date ${two(d.hour)}:${two(d.minute)}';
  }
}

/// Hachage PBKDF2-HMAC-SHA256 pour les comptes locaux et le code PIN.
class Secrets {
  static const _iterations = 10000;

  static String hash(String secret, {String? saltHex}) {
    final salt = saltHex != null ? _fromHex(saltHex) : _randomBytes(16);
    final derived = _pbkdf2(utf8.encode(secret), salt, _iterations, 32);
    return 'pbkdf2\$${_toHex(salt)}\$${_toHex(derived)}';
  }

  static bool verify(String secret, String? stored) {
    if (stored == null) return false;
    final parts = stored.split(r'$');
    if (parts.length != 3 || parts[0] != 'pbkdf2') return false;
    final recomputed = hash(secret, saltHex: parts[1]);
    return _constantTimeEquals(recomputed, stored);
  }

  static Uint8List _pbkdf2(List<int> password, List<int> salt, int iterations, int length) {
    final hmac = Hmac(sha256, password);
    final out = <int>[];
    var block = 1;
    while (out.length < length) {
      final blockIndex = ByteData(4)..setUint32(0, block);
      var u = hmac.convert([...salt, ...blockIndex.buffer.asUint8List()]).bytes;
      final t = List<int>.from(u);
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      out.addAll(t);
      block++;
    }
    return Uint8List.fromList(out.sublist(0, length));
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var r = 0;
    for (var i = 0; i < a.length; i++) {
      r |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return r == 0;
  }

  static List<int> _randomBytes(int n) {
    final rnd = Random.secure();
    return List<int>.generate(n, (_) => rnd.nextInt(256));
  }

  static String _toHex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static List<int> _fromHex(String hex) =>
      List<int>.generate(hex.length ~/ 2, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16));
}

bool isValidEmail(String email) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(email.trim());

String newId() {
  final rnd = Random.secure();
  return 'usr_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${rnd.nextInt(1 << 20).toRadixString(36)}';
}
