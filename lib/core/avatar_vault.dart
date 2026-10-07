import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';

import 'api.dart';
import 'avatar.dart';
import 'storage.dart';

/// Sauvegarde chiffrée de la photo de profil sur le serveur (uniquement avec l'accord de l'utilisatrice).
///
/// - La photo (et l'avatar choisi) est chiffrée SUR LE TÉLÉPHONE en AES-256-GCM.
/// - La clé est dérivée du mot de passe (PBKDF2-HMAC-SHA256) : le serveur ne la connaît jamais
///   et ne stocke qu'un bloc illisible.
/// - Sur un nouveau téléphone, la photo est restaurée automatiquement après la connexion.
class AvatarVault {
  static const _iterations = 60000;
  static String _kKey(String uid) => 'lago_avkey_$uid';
  static String _kEnabled(String uid) => 'lago_avbackup_$uid';

  static final _aes = AesGcm.with256bits();

  static bool isEnabled(String uid) => Store.getBool(_kEnabled(uid));

  /// Dérive et mémorise la clé de chiffrement (appelé à la connexion / l'inscription en ligne).
  static Future<void> rememberKey(String uid, String password) async {
    try {
      final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: _iterations, bits: 256);
      final key = await pbkdf2.deriveKeyFromPassword(password: password, nonce: utf8.encode('lago-avatar:$uid'));
      await Store.setString(_kKey(uid), base64Encode(await key.extractBytes()));
    } catch (_) {
      // Sans clé, la sauvegarde est simplement indisponible.
    }
  }

  static SecretKey? _key(String uid) {
    final k = Store.getString(_kKey(uid));
    return k == null ? null : SecretKey(base64Decode(k));
  }

  static bool hasKey(String uid) => _key(uid) != null;

  /// Active ou désactive la sauvegarde. Désactiver supprime la copie du serveur.
  static Future<String?> setEnabled(String uid, AvatarPref avatar, bool on) async {
    if (on) {
      if (!hasKey(uid)) return 'Reconnectez-vous pour activer la sauvegarde chiffrée.';
      final err = await upload(uid, avatar, force: true);
      if (err != null) return err;
      await Store.setBool(_kEnabled(uid), true);
      return null;
    }
    final res = await Api.avatarDelete();
    if (!res.ok) return res.offline ? 'Connexion au serveur requise.' : res.message('Échec.');
    await Store.setBool(_kEnabled(uid), false);
    return null;
  }

  /// Chiffre et envoie l'avatar (si la sauvegarde est activée ou [force]).
  static Future<String?> upload(String uid, AvatarPref avatar, {bool force = false}) async {
    if (!force && !isEnabled(uid)) return null;
    final key = _key(uid);
    if (key == null) return 'Reconnectez-vous pour activer la sauvegarde chiffrée.';
    try {
      String? photo;
      if (avatar.hasPhoto) photo = base64Encode(await File(avatar.photoPath!).readAsBytes());
      final clear = utf8.encode(jsonEncode({'v': 1, 'kind': avatar.kind, 'emoji': avatar.emoji, 'color': avatar.color, 'photo': photo}));
      final box = await _aes.encrypt(clear, secretKey: key);
      final res = await Api.avatarPut(base64Encode(box.concatenation()));
      if (!res.ok) return res.offline ? 'Connexion au serveur requise.' : res.message('Échec.');
      return null;
    } catch (_) {
      return 'Échec du chiffrement de la photo.';
    }
  }

  /// Récupère et déchiffre la sauvegarde du serveur. Renvoie null s'il n'y en a pas.
  static Future<AvatarPref?> restore(String uid) async {
    final key = _key(uid);
    if (key == null) return null;
    final res = await Api.avatarGet();
    if (!res.ok || res.data?['data'] is! String) return null;
    try {
      final box = SecretBox.fromConcatenation(base64Decode(res.data!['data'] as String),
          nonceLength: _aes.nonceLength, macLength: _aes.macAlgorithm.macLength);
      final clear = await _aes.decrypt(box, secretKey: key);
      final j = jsonDecode(utf8.decode(clear));
      if (j is! Map) return null;
      String? path;
      if (j['photo'] is String) {
        final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/avatars');
        if (!dir.existsSync()) dir.createSync(recursive: true);
        path = '${dir.path}/${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await File(path).writeAsBytes(base64Decode(j['photo'] as String));
      }
      await Store.setBool(_kEnabled(uid), true); // la sauvegarde avait été autorisée
      return AvatarPref(
        kind: path != null && j['kind'] == 'photo' ? 'photo' : 'emoji',
        emoji: j['emoji'] is String ? j['emoji'] as String : '👧',
        color: j['color'] is int ? j['color'] as int : 0xFFF8BBD0,
        photoPath: path,
      );
    } catch (_) {
      return null; // mot de passe changé ailleurs, données corrompues…
    }
  }

  /// Nouveau mot de passe : nouvelle clé, et nouvel envoi chiffré avec cette clé.
  static Future<void> onPasswordChanged(String uid, String newPassword) async {
    await rememberKey(uid, newPassword);
    if (isEnabled(uid)) await upload(uid, AvatarPref.load(uid));
  }

  static Future<void> forget(String uid) async {
    await Store.remove(_kKey(uid));
    await Store.remove(_kEnabled(uid));
  }
}
