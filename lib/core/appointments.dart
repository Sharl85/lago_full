import 'storage.dart';
import 'utils.dart';

/// Rendez-vous médical (gynécologue, sage-femme, médecin, dépistage…), stocké sur le téléphone.
class Appointment {
  final String id;
  final String title;
  final DateTime when;
  final String place;
  final String note;
  const Appointment({required this.id, required this.title, required this.when, this.place = '', this.note = ''});

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'when': when.toIso8601String(), 'place': place, 'note': note};

  static Appointment? fromJson(dynamic j) {
    if (j is! Map) return null;
    final when = DateTime.tryParse('${j['when']}');
    if (when == null) return null;
    return Appointment(
      id: '${j['id'] ?? newId()}',
      title: '${j['title'] ?? ''}',
      when: when,
      place: '${j['place'] ?? ''}',
      note: '${j['note'] ?? ''}',
    );
  }

  bool get isPast => when.isBefore(DateTime.now());
}

class Appointments {
  static String _key(String uid) => 'lago_appointments_$uid';

  static List<Appointment> load(String uid) {
    final list = Store.readList(_key(uid)).map(Appointment.fromJson).whereType<Appointment>().toList()
      ..sort((a, b) => a.when.compareTo(b.when));
    return list;
  }

  static Future<void> save(String uid, List<Appointment> list) =>
      Store.writeJson(_key(uid), list.map((a) => a.toJson()).toList());

  static Future<void> purge(String uid) => Store.remove(_key(uid));
}
