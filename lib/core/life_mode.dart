import 'utils.dart';

/// v5 — Modes de vie : cycle, grossesse, post-partum, préménopause.
class LifeMode {
  final String key;
  final String label;
  final String emoji;
  final String description;
  const LifeMode(this.key, this.label, this.emoji, this.description);

  static const values = [
    LifeMode('cycle', 'Suivre mon cycle', '🌸', 'Règles, ovulation, fenêtre fertile et alertes.'),
    LifeMode('pregnancy', 'Je suis enceinte', '🤰', 'Suivi semaine par semaine et date prévue d’accouchement.'),
    LifeMode('postpartum', 'Après l’accouchement', '👶', 'Récupération, retour des règles et contraception.'),
    LifeMode('perimenopause', 'Préménopause', '🍂', 'Cycles qui changent, symptômes et repères.'),
  ];

  static LifeMode of(String key) => values.firstWhere((m) => m.key == key, orElse: () => values.first);
}

/// Étape de grossesse (semaines d'aménorrhée, comptées depuis le 1er jour des dernières règles).
class PregnancyStep {
  final int fromWeek;
  final String size;
  final String baby;
  final String mother;
  final String tip;
  const PregnancyStep(this.fromWeek, this.size, this.baby, this.mother, this.tip);
}

class PregnancyInfo {
  final DateTime start; // 1er jour des dernières règles
  final DateTime today;
  const PregnancyInfo(this.start, this.today);

  static PregnancyInfo? fromIso(String? iso, {DateTime? today}) {
    final s = Dates.parseIso(iso);
    if (s == null) return null;
    return PregnancyInfo(s, Dates.dateOnly(today ?? DateTime.now()));
  }

  int get daysPregnant => Dates.diffInDays(today, start).clamp(0, 320).toInt();

  /// Semaines d'aménorrhée (SA) révolues et jours.
  int get weeks => daysPregnant ~/ 7;
  int get extraDays => daysPregnant % 7;

  /// Date prévue d'accouchement : règle de Naegele (dernières règles + 280 jours).
  DateTime get dueDate => Dates.addDays(start, 280);
  int get daysToDue => Dates.diffInDays(dueDate, today);

  /// 1er trimestre : jusqu'à 14 SA ; 2e : jusqu'à 28 SA ; 3e ensuite.
  int get trimester => weeks < 14 ? 1 : (weeks < 28 ? 2 : 3);

  double get progress => (daysPregnant / 280).clamp(0.0, 1.0).toDouble();

  PregnancyStep get step => steps.lastWhere((s) => weeks >= s.fromWeek, orElse: () => steps.first);

  static const steps = [
    PregnancyStep(0, 'une graine de pavot', 'L’ovule fécondé s’implante dans l’utérus.',
        'Retard de règles, seins sensibles, fatigue, parfois nausées.',
        'Faites confirmer la grossesse et prenez rendez-vous pour la première consultation prénatale.'),
    PregnancyStep(6, 'un grain de riz', 'Le cœur commence à battre ; les ébauches des organes se forment.',
        'Nausées, envie fréquente d’uriner, grande fatigue.',
        'Acide folique, pas d’alcool ni de tabac, et pas de médicament sans avis médical.'),
    PregnancyStep(10, 'une datte', 'Tous les organes sont en place ; ils vont maintenant grandir.',
        'Les nausées diminuent souvent vers la fin du 1er trimestre.',
        'Première échographie et bilan sanguin si ce n’est pas encore fait.'),
    PregnancyStep(14, 'un citron', 'Bébé bouge déjà, même si vous ne le sentez pas encore.',
        'Souvent plus d’énergie ; le ventre commence à s’arrondir.',
        'Moustiquaire imprégnée chaque nuit : le paludisme est plus dangereux pendant la grossesse.'),
    PregnancyStep(18, 'une mangue', 'Bébé entend les sons ; ses mouvements deviennent perceptibles.',
        'Premiers mouvements ressentis entre 18 et 22 SA environ.',
        'Échographie morphologique et traitement préventif du paludisme selon les recommandations de votre centre de santé.'),
    PregnancyStep(24, 'un épi de maïs', 'Les poumons se développent ; bébé a des cycles de sommeil.',
        'Mal de dos, brûlures d’estomac, jambes lourdes.',
        'Consultez en urgence si : saignements, perte de liquide, fièvre, forts maux de tête ou bébé qui ne bouge plus.'),
    PregnancyStep(28, 'une aubergine', 'Bébé ouvre les yeux et prend du poids.',
        'Essoufflement, sommeil plus difficile, contractions irrégulières possibles.',
        'Dormez de préférence sur le côté gauche ; préparez votre sac pour la maternité.'),
    PregnancyStep(32, 'une noix de coco', 'Bébé se place souvent la tête en bas.',
        'Ventre lourd, envie fréquente d’uriner.',
        'Choisissez votre lieu d’accouchement et prévoyez le transport.'),
    PregnancyStep(37, 'une pastèque', 'Bébé est prêt à naître.',
        'Contractions de plus en plus régulières à l’approche du terme.',
        'Partez à la maternité si les contractions sont régulières et rapprochées, si vous perdez les eaux ou saignez.'),
  ];
}

/// Repères après l'accouchement.
class PostpartumInfo {
  final DateTime birth;
  final DateTime today;
  const PostpartumInfo(this.birth, this.today);

  static PostpartumInfo? fromIso(String? iso, {DateTime? today}) {
    final b = Dates.parseIso(iso);
    if (b == null) return null;
    return PostpartumInfo(b, Dates.dateOnly(today ?? DateTime.now()));
  }

  int get days => Dates.diffInDays(today, birth).clamp(0, 3650).toInt();
  int get weeks => days ~/ 7;

  String get stage {
    if (weeks < 6) return 'Les suites de couches : saignements (lochies) normaux jusqu’à environ 6 semaines, repos et aide de l’entourage.';
    if (weeks < 26) return 'Les règles reviennent en général 6 à 8 semaines après l’accouchement sans allaitement, plus tard en cas d’allaitement exclusif.';
    return 'Le cycle se régule progressivement. Vous pouvez repasser en mode « Suivre mon cycle » dès le retour de vos règles.';
  }

  static const keyPoints = [
    'Une grossesse est possible AVANT le retour des premières règles : parlez contraception lors de la visite postnatale.',
    'Consultez rapidement en cas de fièvre, saignements très abondants, douleur intense ou tristesse qui ne passe pas.',
    'Le baby blues des premiers jours est fréquent ; s’il dure plus de 2 semaines, parlez-en à un professionnel.',
  ];
}

/// Repères pendant la préménopause.
class PerimenopauseInfo {
  static const keyPoints = [
    'La préménopause commence souvent après 40 ans : les cycles deviennent plus courts, plus longs ou irréguliers.',
    'Bouffées de chaleur, sueurs nocturnes, sommeil perturbé et changements d’humeur sont fréquents : notez-les dans le journal.',
    'Une grossesse reste possible tant que les règles n’ont pas disparu depuis 12 mois : gardez une contraception si besoin.',
    'Consultez si vous saignez après 12 mois sans règles, ou si les saignements sont très abondants.',
  ];
}
