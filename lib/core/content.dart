// GÉNÉRÉ par content/content.py — ne pas modifier à la main.
// Contenu éditorial LaGo : cycle, phases, glossaire, conseils quotidiens.

class PhaseContent {
  final String key, title, season, emoji, when, body, hormones, fertility, consult;
  final List<String> feel, tips;
  const PhaseContent({required this.key, required this.title, required this.season, required this.emoji, required this.when, required this.body, required this.hormones, required this.feel, required this.tips, required this.fertility, required this.consult});
}

class Tip {
  final int id;
  final String category, age, title, body;
  const Tip(this.id, this.category, this.age, this.title, this.body);
  bool get adultOnly => age == 'adult';
}

class LagoContent {
  static const cycleIntro = ['Le cycle menstruel est la période qui va du premier jour des règles jusqu\'à la veille des règles suivantes. Il dure en moyenne 28 jours, mais tout cycle entre 21 et 35 jours est considéré comme normal (et de 21 à 45 jours dans les premières années après les premières règles).', 'Chaque mois, le corps se prépare à une éventuelle grossesse : un ovule mûrit puis est libéré, et la muqueuse de l\'utérus (l\'endomètre) s\'épaissit. S\'il n\'y a pas de fécondation, cette muqueuse s\'élimine : ce sont les règles, et un nouveau cycle commence.', 'Ce rythme est piloté par quatre hormones principales : les œstrogènes, la progestérone, la FSH et la LH. Leurs variations expliquent pourquoi l\'énergie, l\'humeur, la peau ou l\'appétit changent au fil du mois.'];

  static const phases = [
    PhaseContent(
      key: 'menstrual',
      title: 'Phase menstruelle',
      season: 'L\'hiver intérieur',
      emoji: '🩸',
      when: 'Du 1er jour des règles à leur fin (souvent 3 à 7 jours).',
      body: 'L\'endomètre, la muqueuse qui tapisse l\'utérus, se détache et s\'écoule avec un peu de sang : ce sont les règles. L\'utérus se contracte pour l\'évacuer, ce qui peut provoquer des crampes. En tout, on perd en moyenne l\'équivalent de 2 à 5 cuillères à soupe de sang.',
      hormones: 'Les œstrogènes et la progestérone sont à leur niveau le plus bas. C\'est cette chute qui déclenche les règles.',
      feel: ['Crampes dans le bas du ventre ou le dos', 'Fatigue, envie de calme et de sommeil', 'Ballonnements, parfois maux de tête', 'Humeur plus sensible les premiers jours'],
      tips: ['Chaleur sur le ventre (bouillotte) et étirements doux', 'Aliments riches en fer : lentilles, haricots, épinards, viande, poisson', 'Bien s\'hydrater, limiter le sel et la caféine', 'Changer de protection toutes les 4 à 6 heures (8 h maximum pour un tampon)'],
      fertility: 'Fertilité faible, mais pas nulle : avec un cycle court, un rapport pendant les règles peut conduire à une grossesse, car les spermatozoïdes survivent jusqu\'à 5 jours.',
      consult: 'Si vous changez de protection toutes les heures, si les règles durent plus de 7 jours, ou si la douleur vous empêche d\'aller en cours ou au travail malgré un antidouleur.',
    ),
    PhaseContent(
      key: 'follicular',
      title: 'Phase folliculaire',
      season: 'Le printemps intérieur',
      emoji: '🌱',
      when: 'De la fin des règles jusqu\'à quelques jours avant l\'ovulation.',
      body: 'Sous l\'effet de l\'hormone FSH, plusieurs petits sacs contenant chacun un ovule (les follicules) se développent dans l\'ovaire. Un seul va arriver à maturité. En parallèle, l\'endomètre se reconstruit et s\'épaissit.',
      hormones: 'Les œstrogènes augmentent progressivement : ils donnent de l\'énergie, améliorent l\'humeur et la concentration.',
      feel: ['Plus d\'énergie et de motivation', 'Humeur positive, envie de sortir', 'Peau souvent plus nette', 'Meilleure concentration'],
      tips: ['Bon moment pour démarrer un projet ou réviser', 'Sport plus intense : cardio, danse, renforcement', 'Aliments frais, protéines, légumes verts, fruits'],
      fertility: 'Fertilité en hausse à mesure que l\'ovulation approche.',
      consult: 'Si les saignements reprennent en dehors des règles ou si les pertes changent d\'odeur ou de couleur.',
    ),
    PhaseContent(
      key: 'ovulation',
      title: 'Phase ovulatoire',
      season: 'L\'été intérieur',
      emoji: '✨',
      when: 'Autour du jour d\'ovulation, environ 14 jours avant les règles suivantes. La fenêtre fertile couvre les 5 jours précédents, le jour même et le lendemain.',
      body: 'Un pic d\'hormone LH provoque l\'ovulation : l\'ovaire libère l\'ovule mûr, qui part dans la trompe. Il ne vit que 12 à 24 heures. Les pertes blanches deviennent plus abondantes, claires et élastiques (comme du blanc d\'œuf) pour aider les spermatozoïdes à passer.',
      hormones: 'Pic d\'œstrogènes et de LH, puis la progestérone commence à monter.',
      feel: ['Pertes blanches claires et filantes', 'Légère douleur d\'un côté du bas-ventre (pour certaines)', 'Plus d\'assurance, envie de voir du monde', 'Désir sexuel parfois plus fort'],
      tips: ['Moment idéal pour les activités sociales et les prises de parole', 'Bien s\'hydrater', 'Si vous ne voulez pas de grossesse : c\'est la période où la protection est la plus importante'],
      fertility: 'Fertilité maximale. C\'est la période où une grossesse est la plus probable. Le calcul de l\'application est une estimation : il ne remplace pas une contraception.',
      consult: 'Si la douleur au moment de l\'ovulation est forte ou dure plus de 2 jours.',
    ),
    PhaseContent(
      key: 'luteal',
      title: 'Phase lutéale',
      season: 'L\'automne intérieur',
      emoji: '🍂',
      when: 'De l\'après-ovulation jusqu\'à la veille des règles (environ 12 à 14 jours).',
      body: 'Le follicule vide se transforme en « corps jaune », qui produit de la progestérone pour préparer l\'utérus à accueillir un éventuel embryon. S\'il n\'y a pas de grossesse, le corps jaune disparaît au bout d\'environ 12 jours, les hormones chutent et les règles arrivent.',
      hormones: 'La progestérone domine, puis chute avec les œstrogènes en fin de phase.',
      feel: ['En fin de phase : syndrome prémenstruel (SPM)', 'Irritabilité, émotions plus fortes, besoin de calme', 'Seins sensibles, ballonnements', 'Fringales (sucré, salé), boutons'],
      tips: ['Aliments riches en magnésium : banane, chocolat noir, amandes', 'Glucides complets (avoine, patate douce) pour une énergie stable', 'Sport modéré : marche, yoga, natation', 'Dormir suffisamment et prévoir des moments pour soi'],
      fertility: 'Fertilité faible après la fenêtre fertile.',
      consult: 'Si le SPM est très intense (tristesse profonde, anxiété, idées noires) : parlez-en à un professionnel de santé, cela se soigne.',
    ),
  ];

  static const glossary = [
    ['Cycle menstruel', 'Période entre le 1er jour des règles et la veille des règles suivantes.'],
    ['Règles (menstruations)', 'Écoulement de sang et de la muqueuse de l\'utérus quand il n\'y a pas de grossesse.'],
    ['Endomètre', 'Muqueuse qui tapisse l\'intérieur de l\'utérus. Elle s\'épaissit chaque mois puis s\'élimine avec les règles.'],
    ['Ovulation', 'Libération d\'un ovule par l\'ovaire, environ 14 jours avant les règles suivantes.'],
    ['Fenêtre fertile', 'Les jours où un rapport sexuel peut entraîner une grossesse : les 5 jours avant l\'ovulation, le jour même et le lendemain.'],
    ['Glaire cervicale', 'Pertes blanches produites par le col de l\'utérus. Leur aspect change au fil du cycle.'],
    ['Œstrogènes', 'Hormones produites par les ovaires. Elles font mûrir l\'ovule et reconstruisent l\'endomètre.'],
    ['Progestérone', 'Hormone produite après l\'ovulation. Elle prépare l\'utérus à une éventuelle grossesse.'],
    ['LH et FSH', 'Hormones du cerveau qui commandent aux ovaires de faire mûrir puis de libérer l\'ovule.'],
    ['SPM', 'Syndrome prémenstruel : ensemble de signes physiques et émotionnels dans les jours qui précèdent les règles.'],
    ['Spotting', 'Petits saignements en dehors des règles. Ils peuvent être normaux, mais il faut consulter s\'ils se répètent.'],
    ['Aménorrhée', 'Absence de règles pendant plus de 3 mois (hors grossesse). Elle nécessite une consultation.'],
  ];

  static const tipCategories = {
    'corps': 'Mon corps',
    'hygiene': 'Hygiène intime',
    'consentement': 'Consentement',
    'relations': 'Relations',
    'emotions': 'Émotions',
    'protection': 'Protection',
    'contraception': 'Contraception',
    'depistage': 'Dépistage',
    'desir': 'Désir & couple',
    'grossesse': 'Grossesse',
  };

  static const tips = [
    Tip(0, 'corps', 'all', 'Votre corps vous appartient', 'Personne n\'a le droit de toucher votre corps sans votre accord, ni de vous demander des photos intimes. Si cela arrive, parlez-en à un adulte de confiance.'),
    Tip(1, 'corps', 'all', 'Les pertes blanches sont normales', 'Elles nettoient naturellement le vagin et changent d\'aspect au fil du cycle. Consultez si elles ont une odeur forte, une couleur verte ou grise, ou si elles démangent.'),
    Tip(2, 'corps', 'all', 'Chaque corps est différent', 'Forme de la vulve, taille des seins, poils, âge des premières règles : il n\'existe pas de « normal » unique. Se comparer aux images des réseaux sociaux fausse la réalité.'),
    Tip(3, 'corps', 'all', 'Connaître son anatomie', 'La vulve est la partie extérieure (lèvres, clitoris). Le vagin est le conduit intérieur. Connaître les bons mots aide à mieux parler de sa santé.'),
    Tip(4, 'corps', 'all', 'Des règles irrégulières au début, c\'est fréquent', 'Pendant les 2 à 3 premières années, les cycles peuvent varier beaucoup. Notez-les dans LaGo : ce sera utile en consultation.'),
    Tip(5, 'corps', 'all', 'Les douleurs ne doivent pas vous empêcher de vivre', 'Des règles qui vous obligent à rester au lit ne sont pas « normales ». L\'endométriose, par exemple, peut se soigner. Parlez-en à un médecin.'),
    Tip(6, 'hygiene', 'all', 'Une toilette intime simple', 'De l\'eau et un savon doux sur l\'extérieur, une fois par jour suffisent. Les douches vaginales et produits parfumés perturbent la flore protectrice.'),
    Tip(7, 'hygiene', 'all', 'Culottes en coton', 'Le coton laisse respirer la peau et limite les mycoses. Évitez de garder longtemps un maillot mouillé ou des vêtements trop serrés.'),
    Tip(8, 'hygiene', 'all', 'Tampon : 8 heures maximum', 'Garder un tampon trop longtemps expose au syndrome du choc toxique, rare mais grave. Changez-le toutes les 4 à 6 heures, jamais plus de 8.'),
    Tip(9, 'hygiene', 'all', 'Uriner après un rapport', 'Chez les personnes sexuellement actives, uriner après un rapport aide à prévenir les infections urinaires.'),
    Tip(10, 'consentement', 'all', 'Le consentement, c\'est oui, libre et enthousiaste', 'Un « oui » obtenu sous pression, par la culpabilisation ou quand la personne a bu n\'est pas un vrai consentement. Et on a toujours le droit de changer d\'avis.'),
    Tip(11, 'consentement', 'all', 'Dire non, c\'est un droit', 'Vous n\'avez pas à vous justifier pour refuser un bisou, une caresse ou un rapport, même en couple, même si vous avez dit oui avant.'),
    Tip(12, 'relations', 'all', 'Une relation saine', 'Dans une relation saine, on se respecte, on se fait confiance et on peut parler librement. Jalousie excessive, contrôle du téléphone, insultes : ce sont des signaux d\'alerte.'),
    Tip(13, 'relations', 'all', 'Attention aux photos intimes', 'Une photo envoyée peut circuler sans votre accord. Partager la photo intime de quelqu\'un sans son consentement est interdit et puni par la loi.'),
    Tip(14, 'relations', 'all', 'Vous pouvez en parler', 'Parent, infirmière scolaire, médecin, sage-femme : des adultes formés peuvent répondre à vos questions sans vous juger, et en toute confidentialité.'),
    Tip(15, 'relations', 'all', 'Pas de pression sur la « première fois »', 'Il n\'y a pas d\'âge idéal. Le bon moment, c\'est quand vous vous sentez prête, informée, protégée et en confiance avec la personne.'),
    Tip(16, 'emotions', 'all', 'Le SPM n\'est pas « dans la tête »', 'Les variations d\'humeur avant les règles sont liées aux hormones. Les reconnaître aide à être plus douce avec soi-même.'),
    Tip(17, 'emotions', 'all', 'Prendre soin de son moral', 'Dormir, bouger, voir des personnes qui vous font du bien : la santé mentale fait partie de la santé intime.'),
    Tip(18, 'protection', 'all', 'Le préservatif protège aussi des IST', 'C\'est le seul moyen de contraception qui protège aussi des infections sexuellement transmissibles (VIH, chlamydia, gonorrhée…).'),
    Tip(19, 'protection', 'all', 'Le vaccin HPV', 'Le vaccin contre les papillomavirus protège de plusieurs cancers. Il est recommandé dès 9 à 14 ans, avant tout contact sexuel. Parlez-en à votre médecin.'),
    Tip(20, 'protection', 'all', 'Les IST ne se voient pas toujours', 'Beaucoup d\'infections ne donnent aucun symptôme. Seul un dépistage permet de savoir. Il est souvent gratuit dans les centres de santé.'),
    Tip(21, 'contraception', 'adult', 'Il existe de nombreuses contraceptions', 'Pilule, stérilet (DIU), implant, patch, anneau, préservatif… Un professionnel de santé peut vous aider à choisir celle qui correspond à votre vie.'),
    Tip(22, 'contraception', 'adult', 'Le calendrier n\'est pas une contraception fiable', 'Les dates de LaGo sont des estimations : l\'ovulation peut se décaler avec le stress, un voyage ou une maladie. Utilisez une vraie méthode contraceptive.'),
    Tip(23, 'contraception', 'adult', 'Contraception d\'urgence', 'En cas de rapport non protégé, la pilule du lendemain est plus efficace si elle est prise tôt (jusqu\'à 3 à 5 jours selon le type). Elle est disponible en pharmacie.'),
    Tip(24, 'contraception', 'adult', 'Oubli de pilule', 'En cas d\'oubli, suivez la notice de votre pilule ou demandez conseil à votre pharmacien. Utilisez des préservatifs les jours suivants si nécessaire.'),
    Tip(25, 'depistage', 'adult', 'Se faire dépister régulièrement', 'Un dépistage des IST est conseillé à chaque nouveau partenaire, et une fois par an en cas de partenaires multiples.'),
    Tip(26, 'depistage', 'adult', 'Le frottis de dépistage', 'Le frottis (ou test HPV) détecte tôt les lésions du col de l\'utérus. Il est recommandé régulièrement à partir de 25 ans.'),
    Tip(27, 'desir', 'adult', 'Le désir varie avec le cycle', 'Beaucoup de femmes ressentent plus de désir autour de l\'ovulation et moins avant les règles. C\'est normal, et chaque personne est différente.'),
    Tip(28, 'desir', 'adult', 'Communiquer avec son ou sa partenaire', 'Parler de ses envies, de ses limites et de ce qui fait du bien renforce la complicité. Le consentement se redemande à chaque fois.'),
    Tip(29, 'desir', 'adult', 'La douleur pendant les rapports n\'est pas normale', 'Des douleurs pendant ou après un rapport (dyspareunie) ont souvent une cause qui se traite : sécheresse, infection, endométriose… Consultez.'),
    Tip(30, 'desir', 'adult', 'Rapports pendant les règles', 'C\'est une question de confort personnel. Cela reste possible si vous le souhaitez tous les deux, mais le risque d\'IST et de grossesse n\'est pas nul.'),
    Tip(31, 'desir', 'adult', 'Le stress influence la libido', 'Fatigue, stress et soucis diminuent souvent le désir. Prendre du temps pour soi et pour le couple aide à le retrouver.'),
    Tip(32, 'hygiene', 'adult', 'Lubrifiant : à base d\'eau avec les préservatifs', 'Les huiles et crèmes grasses fragilisent le latex. Avec un préservatif, choisissez un lubrifiant à base d\'eau ou de silicone.'),
    Tip(33, 'grossesse', 'adult', 'Projet de grossesse', 'Si vous souhaitez un enfant, une consultation préconceptionnelle et l\'acide folique (à commencer avant la grossesse) sont recommandés.'),
    Tip(34, 'grossesse', 'adult', 'Retard de règles', 'Si vos règles ont plus de 5 jours de retard après un rapport, un test de grossesse urinaire (en pharmacie) donne une réponse fiable.'),
  ];

  static PhaseContent phase(String key) => phases.firstWhere((p) => p.key == key, orElse: () => phases.first);

  /// Conseils adaptés à l'âge (contenu adulte réservé aux 18 ans et plus).
  static List<Tip> tipsFor(int? age) => tips.where((t) => !t.adultOnly || (age != null && age >= 18)).toList();

  /// Conseil du jour : rotation déterministe sur la liste adaptée.
  static Tip tipOfDay(DateTime day, int? age) {
    final list = tipsFor(age);
    final index = DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/ 86400000;
    return list[index % list.length];
  }
}
