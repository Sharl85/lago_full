// v5 — Contenus éditoriaux complémentaires (écrits à la main, contrairement à content.dart qui est généré).
// À faire relire par une sage-femme ou un médecin avant publication.

class Guide {
  final String key;
  final String title;
  final String emoji;
  final String intro;
  final List<String> points;
  final String consult;
  const Guide(this.key, this.title, this.emoji, this.intro, this.points, this.consult);
}

class Faq {
  final String question;
  final String answer;
  final List<String> keywords;
  const Faq(this.question, this.answer, this.keywords);
}

class ExtraContent {
  static const guides = [
    Guide(
      'ramadan',
      'Ramadan et cycle',
      '🌙',
      'Pendant les règles, le jeûne n’est pas pratiqué selon la plupart des traditions religieuses. Les jours de jeûne demandent d’adapter l’alimentation à chaque phase.',
      [
        'Au s’hour (avant l’aube) : céréales complètes, œufs, haricots, fruits — pour une énergie qui dure.',
        'À la rupture : boire d’abord de l’eau, puis dattes et soupe, avant un repas équilibré.',
        'Phase menstruelle : aliments riches en fer (lentilles, poisson, feuilles vertes) pour compenser les pertes.',
        'Phase lutéale : fringales plus fortes — préférez patate douce, banane plantain, arachides plutôt que le sucre.',
        'Buvez régulièrement entre la rupture et le s’hour : la déshydratation aggrave maux de tête et crampes.',
      ],
      'Si vous êtes enceinte, allaitez, avez des règles très abondantes ou une maladie chronique, demandez conseil à un professionnel de santé avant de jeûner.',
    ),
    Guide(
      'hygiene',
      'Hygiène des règles quand les protections manquent',
      '🧺',
      'Les protections coûtent cher et ne sont pas toujours disponibles. Voici des solutions sûres et économiques.',
      [
        'Serviettes lavables en tissu : coton propre, lavé à l’eau et au savon, séché au soleil (le soleil désinfecte).',
        'Ne jamais utiliser de papier journal, de sable, de feuilles ou de chiffons sales : risque d’infection.',
        'Coupe menstruelle : réutilisable plusieurs années, à faire bouillir entre deux cycles.',
        'Changer de protection toutes les 4 à 6 heures, et se laver les mains avant et après.',
        'Toilette intime à l’eau claire, sans savon parfumé ni produit à l’intérieur du vagin.',
      ],
      'Consultez en cas de démangeaisons, de pertes qui changent d’odeur ou de couleur, ou de fièvre.',
    ),
    Guide(
      'myths',
      'Mythes et tabous',
      '💬',
      'Beaucoup d’idées reçues circulent sur les règles. Démêlons le vrai du faux.',
      [
        'FAUX : « Une fille qui a ses règles est sale. » Les règles sont un phénomène naturel et sain.',
        'FAUX : « On ne peut pas tomber enceinte pendant les règles. » C’est rare, mais possible, surtout avec un cycle court.',
        'FAUX : « Il ne faut pas se laver ni faire de sport pendant les règles. » Se laver est important ; le sport peut soulager les crampes.',
        'FAUX : « La douleur intense est normale, il faut la supporter. » Une douleur qui empêche de vivre normalement doit être soignée.',
        'VRAI : le stress, la fatigue ou un changement de poids peuvent décaler les règles.',
        'VRAI : les premières années après les premières règles, les cycles sont souvent irréguliers.',
      ],
      'Vous pouvez poser vos questions anonymement dans l’espace Communauté de LaGo.',
    ),
    Guide(
      'contraception',
      'Bien choisir sa contraception',
      '🛡️',
      'Il existe de nombreuses méthodes. La bonne est celle qui vous convient, choisie avec un professionnel de santé.',
      [
        'Le préservatif est la seule méthode qui protège aussi des infections sexuellement transmissibles (IST), dont le VIH.',
        'Implant, stérilet et injection sont très efficaces et durent longtemps (de 3 mois à plusieurs années).',
        'La pilule doit être prise tous les jours, à heure fixe : LaGo peut vous le rappeler.',
        'La contraception d’urgence (« pilule du lendemain ») se prend le plus tôt possible après un rapport non protégé.',
        'Le calcul de LaGo n’est PAS une méthode de contraception.',
      ],
      'Les centres de santé et de planification familiale conseillent gratuitement ou à petit prix, en toute confidentialité.',
    ),
  ];

  static Guide guide(String key) => guides.firstWhere((g) => g.key == key, orElse: () => guides.first);

  /// Questions-réponses validées, utilisées par l'assistant hors ligne.
  static const faqs = [
    Faq('Est-ce normal d’avoir des règles irrégulières ?',
        'Oui, surtout les 2 à 3 premières années après les premières règles, ou en cas de stress, de voyage ou de changement de poids. Un cycle entre 21 et 35 jours est considéré comme normal (jusqu’à 45 jours chez les adolescentes). Consultez si vos règles disparaissent plus de 3 mois.',
        ['irregulier', 'irreguliere', 'irregulieres', 'cycle', 'normal', 'decale']),
    Faq('Comment soulager les douleurs de règles ?',
        'Chaleur sur le ventre (bouillotte), repos, étirements doux, marche, tisane chaude et bonne hydratation. Un antidouleur comme le paracétamol peut aider : demandez conseil à un pharmacien. Si la douleur vous empêche d’aller en cours ou au travail, consultez.',
        ['douleur', 'douleurs', 'crampe', 'crampes', 'mal', 'ventre', 'soulager']),
    Faq('Mes règles sont en retard, que faire ?',
        'Un retard de quelques jours est fréquent (stress, fatigue, maladie). Si vous avez eu un rapport sans protection, faites un test de grossesse environ 3 semaines après ce rapport ou dès le retard. Consultez si le retard dépasse quelques semaines.',
        ['retard', 'enceinte', 'grossesse', 'test', 'pas', 'regles']),
    Faq('Peut-on tomber enceinte pendant les règles ?',
        'C’est peu probable mais possible, notamment avec un cycle court : les spermatozoïdes peuvent survivre jusqu’à 5 jours. Seule une contraception protège réellement.',
        ['enceinte', 'pendant', 'regles', 'rapport', 'risque']),
    Faq('Qu’est-ce que la fenêtre fertile ?',
        'Ce sont les jours où un rapport peut conduire à une grossesse : les 5 jours avant l’ovulation, le jour de l’ovulation et le lendemain. LaGo l’estime, mais ce n’est pas une méthode de contraception.',
        ['fertile', 'fenetre', 'ovulation', 'fertilite']),
    Faq('Combien de temps durent des règles normales ?',
        'En général de 3 à 7 jours. Consultez si elles durent plus de 7 jours, ou si vous devez changer de protection toutes les heures.',
        ['duree', 'combien', 'jours', 'longues', 'abondantes']),
    Faq('Les pertes blanches sont-elles normales ?',
        'Oui. Leur aspect change au fil du cycle : plus abondantes, claires et filantes autour de l’ovulation. Consultez si elles changent d’odeur, de couleur (jaune, vert, grisâtre) ou s’accompagnent de démangeaisons.',
        ['pertes', 'blanches', 'glaire', 'ecoulement', 'odeur']),
    Faq('Qu’est-ce que le syndrome prémenstruel (SPM) ?',
        'Ce sont des signes qui apparaissent quelques jours avant les règles : seins sensibles, ballonnements, irritabilité, fringales, fatigue. Ils disparaissent avec les règles. Activité physique, sommeil et alimentation équilibrée les atténuent.',
        ['spm', 'premenstruel', 'humeur', 'irritable', 'seins', 'fringales']),
    Faq('Quand faut-il consulter un gynécologue ?',
        'En cas de douleur forte, de règles très abondantes ou très longues, de saignements entre les règles, d’absence de règles depuis plus de 3 mois, de pertes anormales, ou pour choisir une contraception.',
        ['consulter', 'gynecologue', 'medecin', 'quand', 'sage-femme']),
    Faq('La pilule du lendemain, comment ça marche ?',
        'C’est une contraception d’urgence à prendre le plus tôt possible après un rapport non protégé (jusqu’à 3 à 5 jours selon le produit). Elle est disponible en pharmacie et dans les centres de santé. Elle ne protège pas des IST.',
        ['lendemain', 'urgence', 'pilule', 'contraception', 'rapport', 'protege']),
    Faq('Comment se protéger des IST ?',
        'Le préservatif (masculin ou féminin) est la seule protection contre les infections sexuellement transmissibles, dont le VIH. Un dépistage régulier est recommandé, il est souvent gratuit dans les centres de santé.',
        ['ist', 'vih', 'sida', 'preservatif', 'infection', 'depistage']),
    Faq('À quel âge arrivent les premières règles ?',
        'Le plus souvent entre 10 et 15 ans. Consultez si elles ne sont pas arrivées à 15 ans, ou si elles arrivent avant 8 ans.',
        ['premieres', 'age', 'puberte', 'arrivent']),
  ];

  static String _normalize(String s) {
    const from = 'àâäáãéèêëíìîïóòôöõúùûüçñœ’';
    const to = 'aaaaaeeeeiiiiooooouuuucno\'';
    final lower = s.toLowerCase();
    final b = StringBuffer();
    for (final ch in lower.split('')) {
      final i = from.indexOf(ch);
      b.write(i >= 0 ? to[i] : ch);
    }
    return b.toString();
  }

  /// Recherche hors ligne : les questions dont les mots-clés correspondent le mieux.
  static List<Faq> search(String query, {int limit = 3}) {
    final words = _normalize(query).split(RegExp(r"[^a-z0-9-]+")).where((w) => w.length >= 3).toSet();
    if (words.isEmpty) return const [];
    final scored = <MapEntry<Faq, int>>[];
    for (final f in faqs) {
      final text = _normalize('${f.question} ${f.keywords.join(' ')}');
      var score = 0;
      for (final w in words) {
        if (f.keywords.contains(w)) score += 3;
        if (text.contains(w)) score += 1;
      }
      if (score > 0) scored.add(MapEntry(f, score));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(limit).map((e) => e.key).toList();
  }
}
