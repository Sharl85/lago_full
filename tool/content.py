# -*- coding: utf-8 -*-
"""Contenu éditorial partagé LaGo (phases, glossaire, conseils quotidiens).
Génère lib/core/content.dart (Flutter) et src/js/content.js (web)."""
import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT_FLUTTER = os.path.join(HERE, "..") if True else None
ROOT_WEB = os.path.join(HERE, "..") if False else None

CYCLE_INTRO = [
    "Le cycle menstruel est la période qui va du premier jour des règles jusqu'à la veille des règles suivantes. Il dure en moyenne 28 jours, mais tout cycle entre 21 et 35 jours est considéré comme normal (et de 21 à 45 jours dans les premières années après les premières règles).",
    "Chaque mois, le corps se prépare à une éventuelle grossesse : un ovule mûrit puis est libéré, et la muqueuse de l'utérus (l'endomètre) s'épaissit. S'il n'y a pas de fécondation, cette muqueuse s'élimine : ce sont les règles, et un nouveau cycle commence.",
    "Ce rythme est piloté par quatre hormones principales : les œstrogènes, la progestérone, la FSH et la LH. Leurs variations expliquent pourquoi l'énergie, l'humeur, la peau ou l'appétit changent au fil du mois.",
]

PHASES = [
    {
        "key": "menstrual",
        "title": "Phase menstruelle",
        "season": "L'hiver intérieur",
        "emoji": "🩸",
        "when": "Du 1er jour des règles à leur fin (souvent 3 à 7 jours).",
        "body": "L'endomètre, la muqueuse qui tapisse l'utérus, se détache et s'écoule avec un peu de sang : ce sont les règles. L'utérus se contracte pour l'évacuer, ce qui peut provoquer des crampes. En tout, on perd en moyenne l'équivalent de 2 à 5 cuillères à soupe de sang.",
        "hormones": "Les œstrogènes et la progestérone sont à leur niveau le plus bas. C'est cette chute qui déclenche les règles.",
        "feel": ["Crampes dans le bas du ventre ou le dos", "Fatigue, envie de calme et de sommeil", "Ballonnements, parfois maux de tête", "Humeur plus sensible les premiers jours"],
        "tips": ["Chaleur sur le ventre (bouillotte) et étirements doux", "Aliments riches en fer : lentilles, haricots, épinards, viande, poisson", "Bien s'hydrater, limiter le sel et la caféine", "Changer de protection toutes les 4 à 6 heures (8 h maximum pour un tampon)"],
        "fertility": "Fertilité faible, mais pas nulle : avec un cycle court, un rapport pendant les règles peut conduire à une grossesse, car les spermatozoïdes survivent jusqu'à 5 jours.",
        "consult": "Si vous changez de protection toutes les heures, si les règles durent plus de 7 jours, ou si la douleur vous empêche d'aller en cours ou au travail malgré un antidouleur.",
    },
    {
        "key": "follicular",
        "title": "Phase folliculaire",
        "season": "Le printemps intérieur",
        "emoji": "🌱",
        "when": "De la fin des règles jusqu'à quelques jours avant l'ovulation.",
        "body": "Sous l'effet de l'hormone FSH, plusieurs petits sacs contenant chacun un ovule (les follicules) se développent dans l'ovaire. Un seul va arriver à maturité. En parallèle, l'endomètre se reconstruit et s'épaissit.",
        "hormones": "Les œstrogènes augmentent progressivement : ils donnent de l'énergie, améliorent l'humeur et la concentration.",
        "feel": ["Plus d'énergie et de motivation", "Humeur positive, envie de sortir", "Peau souvent plus nette", "Meilleure concentration"],
        "tips": ["Bon moment pour démarrer un projet ou réviser", "Sport plus intense : cardio, danse, renforcement", "Aliments frais, protéines, légumes verts, fruits"],
        "fertility": "Fertilité en hausse à mesure que l'ovulation approche.",
        "consult": "Si les saignements reprennent en dehors des règles ou si les pertes changent d'odeur ou de couleur.",
    },
    {
        "key": "ovulation",
        "title": "Phase ovulatoire",
        "season": "L'été intérieur",
        "emoji": "✨",
        "when": "Autour du jour d'ovulation, environ 14 jours avant les règles suivantes. La fenêtre fertile couvre les 5 jours précédents, le jour même et le lendemain.",
        "body": "Un pic d'hormone LH provoque l'ovulation : l'ovaire libère l'ovule mûr, qui part dans la trompe. Il ne vit que 12 à 24 heures. Les pertes blanches deviennent plus abondantes, claires et élastiques (comme du blanc d'œuf) pour aider les spermatozoïdes à passer.",
        "hormones": "Pic d'œstrogènes et de LH, puis la progestérone commence à monter.",
        "feel": ["Pertes blanches claires et filantes", "Légère douleur d'un côté du bas-ventre (pour certaines)", "Plus d'assurance, envie de voir du monde", "Désir sexuel parfois plus fort"],
        "tips": ["Moment idéal pour les activités sociales et les prises de parole", "Bien s'hydrater", "Si vous ne voulez pas de grossesse : c'est la période où la protection est la plus importante"],
        "fertility": "Fertilité maximale. C'est la période où une grossesse est la plus probable. Le calcul de l'application est une estimation : il ne remplace pas une contraception.",
        "consult": "Si la douleur au moment de l'ovulation est forte ou dure plus de 2 jours.",
    },
    {
        "key": "luteal",
        "title": "Phase lutéale",
        "season": "L'automne intérieur",
        "emoji": "🍂",
        "when": "De l'après-ovulation jusqu'à la veille des règles (environ 12 à 14 jours).",
        "body": "Le follicule vide se transforme en « corps jaune », qui produit de la progestérone pour préparer l'utérus à accueillir un éventuel embryon. S'il n'y a pas de grossesse, le corps jaune disparaît au bout d'environ 12 jours, les hormones chutent et les règles arrivent.",
        "hormones": "La progestérone domine, puis chute avec les œstrogènes en fin de phase.",
        "feel": ["En fin de phase : syndrome prémenstruel (SPM)", "Irritabilité, émotions plus fortes, besoin de calme", "Seins sensibles, ballonnements", "Fringales (sucré, salé), boutons"],
        "tips": ["Aliments riches en magnésium : banane, chocolat noir, amandes", "Glucides complets (avoine, patate douce) pour une énergie stable", "Sport modéré : marche, yoga, natation", "Dormir suffisamment et prévoir des moments pour soi"],
        "fertility": "Fertilité faible après la fenêtre fertile.",
        "consult": "Si le SPM est très intense (tristesse profonde, anxiété, idées noires) : parlez-en à un professionnel de santé, cela se soigne.",
    },
]

GLOSSARY = [
    ["Cycle menstruel", "Période entre le 1er jour des règles et la veille des règles suivantes."],
    ["Règles (menstruations)", "Écoulement de sang et de la muqueuse de l'utérus quand il n'y a pas de grossesse."],
    ["Endomètre", "Muqueuse qui tapisse l'intérieur de l'utérus. Elle s'épaissit chaque mois puis s'élimine avec les règles."],
    ["Ovulation", "Libération d'un ovule par l'ovaire, environ 14 jours avant les règles suivantes."],
    ["Fenêtre fertile", "Les jours où un rapport sexuel peut entraîner une grossesse : les 5 jours avant l'ovulation, le jour même et le lendemain."],
    ["Glaire cervicale", "Pertes blanches produites par le col de l'utérus. Leur aspect change au fil du cycle."],
    ["Œstrogènes", "Hormones produites par les ovaires. Elles font mûrir l'ovule et reconstruisent l'endomètre."],
    ["Progestérone", "Hormone produite après l'ovulation. Elle prépare l'utérus à une éventuelle grossesse."],
    ["LH et FSH", "Hormones du cerveau qui commandent aux ovaires de faire mûrir puis de libérer l'ovule."],
    ["SPM", "Syndrome prémenstruel : ensemble de signes physiques et émotionnels dans les jours qui précèdent les règles."],
    ["Spotting", "Petits saignements en dehors des règles. Ils peuvent être normaux, mais il faut consulter s'ils se répètent."],
    ["Aménorrhée", "Absence de règles pendant plus de 3 mois (hors grossesse). Elle nécessite une consultation."],
]

# Conseils quotidiens santé sexuelle & relations.
# age = "all" (dès 10 ans, informatif et protecteur) | "adult" (18 ans et plus)
TIPS = [
    # --- Corps & connaissance de soi (tous) ---
    ("corps", "all", "Votre corps vous appartient", "Personne n'a le droit de toucher votre corps sans votre accord, ni de vous demander des photos intimes. Si cela arrive, parlez-en à un adulte de confiance."),
    ("corps", "all", "Les pertes blanches sont normales", "Elles nettoient naturellement le vagin et changent d'aspect au fil du cycle. Consultez si elles ont une odeur forte, une couleur verte ou grise, ou si elles démangent."),
    ("corps", "all", "Chaque corps est différent", "Forme de la vulve, taille des seins, poils, âge des premières règles : il n'existe pas de « normal » unique. Se comparer aux images des réseaux sociaux fausse la réalité."),
    ("corps", "all", "Connaître son anatomie", "La vulve est la partie extérieure (lèvres, clitoris). Le vagin est le conduit intérieur. Connaître les bons mots aide à mieux parler de sa santé."),
    ("corps", "all", "Des règles irrégulières au début, c'est fréquent", "Pendant les 2 à 3 premières années, les cycles peuvent varier beaucoup. Notez-les dans LaGo : ce sera utile en consultation."),
    ("corps", "all", "Les douleurs ne doivent pas vous empêcher de vivre", "Des règles qui vous obligent à rester au lit ne sont pas « normales ». L'endométriose, par exemple, peut se soigner. Parlez-en à un médecin."),
    # --- Hygiène intime (tous) ---
    ("hygiene", "all", "Une toilette intime simple", "De l'eau et un savon doux sur l'extérieur, une fois par jour suffisent. Les douches vaginales et produits parfumés perturbent la flore protectrice."),
    ("hygiene", "all", "Culottes en coton", "Le coton laisse respirer la peau et limite les mycoses. Évitez de garder longtemps un maillot mouillé ou des vêtements trop serrés."),
    ("hygiene", "all", "Tampon : 8 heures maximum", "Garder un tampon trop longtemps expose au syndrome du choc toxique, rare mais grave. Changez-le toutes les 4 à 6 heures, jamais plus de 8."),
    ("hygiene", "all", "Uriner après un rapport", "Chez les personnes sexuellement actives, uriner après un rapport aide à prévenir les infections urinaires."),
    # --- Consentement & relations (tous) ---
    ("consentement", "all", "Le consentement, c'est oui, libre et enthousiaste", "Un « oui » obtenu sous pression, par la culpabilisation ou quand la personne a bu n'est pas un vrai consentement. Et on a toujours le droit de changer d'avis."),
    ("consentement", "all", "Dire non, c'est un droit", "Vous n'avez pas à vous justifier pour refuser un bisou, une caresse ou un rapport, même en couple, même si vous avez dit oui avant."),
    ("relations", "all", "Une relation saine", "Dans une relation saine, on se respecte, on se fait confiance et on peut parler librement. Jalousie excessive, contrôle du téléphone, insultes : ce sont des signaux d'alerte."),
    ("relations", "all", "Attention aux photos intimes", "Une photo envoyée peut circuler sans votre accord. Partager la photo intime de quelqu'un sans son consentement est interdit et puni par la loi."),
    ("relations", "all", "Vous pouvez en parler", "Parent, infirmière scolaire, médecin, sage-femme : des adultes formés peuvent répondre à vos questions sans vous juger, et en toute confidentialité."),
    ("relations", "all", "Pas de pression sur la « première fois »", "Il n'y a pas d'âge idéal. Le bon moment, c'est quand vous vous sentez prête, informée, protégée et en confiance avec la personne."),
    ("emotions", "all", "Le SPM n'est pas « dans la tête »", "Les variations d'humeur avant les règles sont liées aux hormones. Les reconnaître aide à être plus douce avec soi-même."),
    ("emotions", "all", "Prendre soin de son moral", "Dormir, bouger, voir des personnes qui vous font du bien : la santé mentale fait partie de la santé intime."),
    # --- Protection & dépistage (tous, formulation informative) ---
    ("protection", "all", "Le préservatif protège aussi des IST", "C'est le seul moyen de contraception qui protège aussi des infections sexuellement transmissibles (VIH, chlamydia, gonorrhée…)."),
    ("protection", "all", "Le vaccin HPV", "Le vaccin contre les papillomavirus protège de plusieurs cancers. Il est recommandé dès 9 à 14 ans, avant tout contact sexuel. Parlez-en à votre médecin."),
    ("protection", "all", "Les IST ne se voient pas toujours", "Beaucoup d'infections ne donnent aucun symptôme. Seul un dépistage permet de savoir. Il est souvent gratuit dans les centres de santé."),
    # --- Adultes ---
    ("contraception", "adult", "Il existe de nombreuses contraceptions", "Pilule, stérilet (DIU), implant, patch, anneau, préservatif… Un professionnel de santé peut vous aider à choisir celle qui correspond à votre vie."),
    ("contraception", "adult", "Le calendrier n'est pas une contraception fiable", "Les dates de LaGo sont des estimations : l'ovulation peut se décaler avec le stress, un voyage ou une maladie. Utilisez une vraie méthode contraceptive."),
    ("contraception", "adult", "Contraception d'urgence", "En cas de rapport non protégé, la pilule du lendemain est plus efficace si elle est prise tôt (jusqu'à 3 à 5 jours selon le type). Elle est disponible en pharmacie."),
    ("contraception", "adult", "Oubli de pilule", "En cas d'oubli, suivez la notice de votre pilule ou demandez conseil à votre pharmacien. Utilisez des préservatifs les jours suivants si nécessaire."),
    ("depistage", "adult", "Se faire dépister régulièrement", "Un dépistage des IST est conseillé à chaque nouveau partenaire, et une fois par an en cas de partenaires multiples."),
    ("depistage", "adult", "Le frottis de dépistage", "Le frottis (ou test HPV) détecte tôt les lésions du col de l'utérus. Il est recommandé régulièrement à partir de 25 ans."),
    ("desir", "adult", "Le désir varie avec le cycle", "Beaucoup de femmes ressentent plus de désir autour de l'ovulation et moins avant les règles. C'est normal, et chaque personne est différente."),
    ("desir", "adult", "Communiquer avec son ou sa partenaire", "Parler de ses envies, de ses limites et de ce qui fait du bien renforce la complicité. Le consentement se redemande à chaque fois."),
    ("desir", "adult", "La douleur pendant les rapports n'est pas normale", "Des douleurs pendant ou après un rapport (dyspareunie) ont souvent une cause qui se traite : sécheresse, infection, endométriose… Consultez."),
    ("desir", "adult", "Rapports pendant les règles", "C'est une question de confort personnel. Cela reste possible si vous le souhaitez tous les deux, mais le risque d'IST et de grossesse n'est pas nul."),
    ("desir", "adult", "Le stress influence la libido", "Fatigue, stress et soucis diminuent souvent le désir. Prendre du temps pour soi et pour le couple aide à le retrouver."),
    ("hygiene", "adult", "Lubrifiant : à base d'eau avec les préservatifs", "Les huiles et crèmes grasses fragilisent le latex. Avec un préservatif, choisissez un lubrifiant à base d'eau ou de silicone."),
    ("grossesse", "adult", "Projet de grossesse", "Si vous souhaitez un enfant, une consultation préconceptionnelle et l'acide folique (à commencer avant la grossesse) sont recommandés."),
    ("grossesse", "adult", "Retard de règles", "Si vos règles ont plus de 5 jours de retard après un rapport, un test de grossesse urinaire (en pharmacie) donne une réponse fiable."),
]

TIP_CATEGORIES = {
    "corps": "Mon corps", "hygiene": "Hygiène intime", "consentement": "Consentement",
    "relations": "Relations", "emotions": "Émotions", "protection": "Protection",
    "contraception": "Contraception", "depistage": "Dépistage", "desir": "Désir & couple",
    "grossesse": "Grossesse",
}

def dart_str(s):
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"

def gen_dart():
    L = []
    L.append("// GÉNÉRÉ par content/content.py — ne pas modifier à la main.")
    L.append("// Contenu éditorial LaGo : cycle, phases, glossaire, conseils quotidiens.")
    L.append("")
    L.append("class PhaseContent {")
    L.append("  final String key, title, season, emoji, when, body, hormones, fertility, consult;")
    L.append("  final List<String> feel, tips;")
    L.append("  const PhaseContent({required this.key, required this.title, required this.season, required this.emoji, required this.when, required this.body, required this.hormones, required this.feel, required this.tips, required this.fertility, required this.consult});")
    L.append("}")
    L.append("")
    L.append("class Tip {")
    L.append("  final int id;")
    L.append("  final String category, age, title, body;")
    L.append("  const Tip(this.id, this.category, this.age, this.title, this.body);")
    L.append("  bool get adultOnly => age == 'adult';")
    L.append("}")
    L.append("")
    L.append("class LagoContent {")
    L.append("  static const cycleIntro = [" + ", ".join(dart_str(p) for p in CYCLE_INTRO) + "];")
    L.append("")
    L.append("  static const phases = [")
    for p in PHASES:
        L.append("    PhaseContent(")
        for k in ["key","title","season","emoji","when","body","hormones"]:
            L.append(f"      {k}: {dart_str(p[k])},")
        L.append("      feel: [" + ", ".join(dart_str(x) for x in p["feel"]) + "],")
        L.append("      tips: [" + ", ".join(dart_str(x) for x in p["tips"]) + "],")
        L.append(f"      fertility: {dart_str(p['fertility'])},")
        L.append(f"      consult: {dart_str(p['consult'])},")
        L.append("    ),")
    L.append("  ];")
    L.append("")
    L.append("  static const glossary = [")
    for t, d in GLOSSARY:
        L.append(f"    [{dart_str(t)}, {dart_str(d)}],")
    L.append("  ];")
    L.append("")
    L.append("  static const tipCategories = {")
    for k, v in TIP_CATEGORIES.items():
        L.append(f"    {dart_str(k)}: {dart_str(v)},")
    L.append("  };")
    L.append("")
    L.append("  static const tips = [")
    for i, (c, a, t, b) in enumerate(TIPS):
        L.append(f"    Tip({i}, {dart_str(c)}, {dart_str(a)}, {dart_str(t)}, {dart_str(b)}),")
    L.append("  ];")
    L.append("")
    L.append("  static PhaseContent phase(String key) => phases.firstWhere((p) => p.key == key, orElse: () => phases.first);")
    L.append("")
    L.append("  /// Conseils adaptés à l'âge (contenu adulte réservé aux 18 ans et plus).")
    L.append("  static List<Tip> tipsFor(int? age) => tips.where((t) => !t.adultOnly || (age != null && age >= 18)).toList();")
    L.append("")
    L.append("  /// Conseil du jour : rotation déterministe sur la liste adaptée.")
    L.append("  static Tip tipOfDay(DateTime day, int? age) {")
    L.append("    final list = tipsFor(age);")
    L.append("    final index = DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/ 86400000;")
    L.append("    return list[index % list.length];")
    L.append("  }")
    L.append("}")
    return "\n".join(L) + "\n"

def gen_js():
    data = {
        "cycleIntro": CYCLE_INTRO, "phases": PHASES, "glossary": GLOSSARY,
        "tipCategories": TIP_CATEGORIES,
        "tips": [{"id": i, "category": c, "age": a, "title": t, "body": b} for i, (c, a, t, b) in enumerate(TIPS)],
    }
    return ("/* GÉNÉRÉ par content/content.py — ne pas modifier à la main. */\n"
            "const LagoContent = " + json.dumps(data, ensure_ascii=False, indent=2) + ";\n\n"
            "LagoContent.phase = function (key) { return this.phases.find(p => p.key === key) || this.phases[0]; };\n"
            "LagoContent.tipsFor = function (age) { return this.tips.filter(t => t.age !== 'adult' || (Number(age) >= 18)); };\n"
            "LagoContent.tipOfDay = function (day, age) {\n"
            "  const list = this.tipsFor(age);\n"
            "  const index = Math.floor(Date.UTC(day.getFullYear(), day.getMonth(), day.getDate()) / 86400000);\n"
            "  return list[index % list.length];\n"
            "};\n\n"
            "if (typeof module !== 'undefined' && module.exports) { module.exports = LagoContent; }\n")

if __name__ == "__main__":
    if ROOT_FLUTTER: open(os.path.join(ROOT_FLUTTER, "lib/core/content.dart"), "w").write(gen_dart())
    if ROOT_WEB: open(os.path.join(ROOT_WEB, "src/js/content.js"), "w").write(gen_js())
    print(len(TIPS), "conseils,", sum(1 for t in TIPS if t[1]=="all"), "tous âges")
