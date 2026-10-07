import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'storage.dart';

/// Photo de profil : un avatar (emoji + couleur) ou une photo personnelle.
/// Stockée uniquement sur le téléphone (donnée personnelle, jamais envoyée au serveur).
class AvatarPref {
  final String kind; // 'emoji' | 'photo'
  final String emoji;
  final int color; // couleur de fond ARGB
  final String? photoPath;

  const AvatarPref({this.kind = 'emoji', this.emoji = '👧', this.color = 0xFFF8BBD0, this.photoPath});

  static const emojis = ['👧', '👩', '👧🏾', '👩🏾', '👩🏽', '👩🏻', '👩🏿', '🧕', '👸', '🌸', '🌺', '🦋', '🌙', '⭐', '🐱', '🐰'];
  static const colors = [0xFFF8BBD0, 0xFFE1BEE7, 0xFFFFE0B2, 0xFFC8E6C9, 0xFFB3E5FC, 0xFFFFF59D, 0xFFFFCDD2, 0xFFD7CCC8];

  bool get hasPhoto => kind == 'photo' && photoPath != null && File(photoPath!).existsSync();

  Map<String, dynamic> toJson() => {'kind': kind, 'emoji': emoji, 'color': color, 'photoPath': photoPath};

  factory AvatarPref.fromJson(Map<String, dynamic>? j, {bool admin = false}) {
    if (j == null) return AvatarPref(emoji: admin ? '👑' : '👧', color: admin ? 0xFFFFE082 : 0xFFF8BBD0);
    return AvatarPref(
      kind: j['kind'] == 'photo' ? 'photo' : 'emoji',
      emoji: j['emoji'] is String ? j['emoji'] as String : '👧',
      color: j['color'] is int ? j['color'] as int : 0xFFF8BBD0,
      photoPath: j['photoPath'] as String?,
    );
  }

  AvatarPref copyWith({String? kind, String? emoji, int? color, String? photoPath, bool clearPhoto = false}) => AvatarPref(
        kind: kind ?? this.kind,
        emoji: emoji ?? this.emoji,
        color: color ?? this.color,
        photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
      );

  static String _key(String uid) => 'lago_avatar_$uid';

  /// Un avatar a-t-il déjà été choisi sur ce téléphone ?
  static bool hasSaved(String uid) => Store.readMap(_key(uid)) != null;

  static AvatarPref load(String uid, {bool admin = false}) => AvatarPref.fromJson(Store.readMap(_key(uid)), admin: admin);

  Future<void> save(String uid) => Store.writeJson(_key(uid), toJson());

  /// Choisit une photo (galerie ou appareil photo), la recadre en taille raisonnable
  /// et la copie dans l'espace privé de l'application. Renvoie null si annulé.
  static Future<String?> pickPhoto(String uid, {required bool camera}) async {
    final picked = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 720,
      maxHeight: 720,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.front,
    );
    if (picked == null) return null;
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/avatars');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    // Supprime les anciennes photos de ce compte
    for (final f in dir.listSync().whereType<File>()) {
      if (f.uri.pathSegments.last.startsWith('${uid}_')) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }
    final target = '${dir.path}/${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(picked.path).copy(target);
    return target;
  }

  static Future<void> deletePhotos(String uid) async {
    try {
      final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/avatars');
      if (!dir.existsSync()) return;
      for (final f in dir.listSync().whereType<File>()) {
        if (f.uri.pathSegments.last.startsWith('${uid}_')) f.deleteSync();
      }
    } catch (_) {}
  }
}
