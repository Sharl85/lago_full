# LaGo 🌸 — Application Flutter (Android & iOS) · v5.0

Réécriture complète de LaGo en **Flutter** : un seul code Dart pour **Android** et **iOS**, entièrement natif (plus de page web dans l'app).

## Nouveautés 5.0

**Prévisions plus justes (comme Flo)**
- Ovulation au jour 14 pour un cycle de 28 jours ; « règles en retard de X jours » au lieu d'un nouveau cycle silencieux.
- **Fourchette** des prochaines règles (« 3 – 6 nov. »), plus large si les cycles notés varient.
- Journal : **test d'ovulation** et **glaire cervicale**. Un test positif, une hausse de température (3 jours ≥ +0,2 °C) ou la glaire « blanc d'œuf » **confirment l'ovulation** et recalculent les prochaines règles (ovulation + 14 j).
- **Signaux de santé** (« À surveiller ») : cycles courts/longs répétés, règles longues ou abondantes, douleurs fréquentes, saignements entre les règles, absence de règles > 3 mois. LaGo ne pose jamais de diagnostic.

**Modes de vie** (Profil › Mode de vie & contraception) : cycle, **grossesse** (SA, trimestre, terme, semaine par semaine), **post-partum**, **préménopause**, et **contraception** (avec une méthode hormonale, la fenêtre fertile et ses alertes sont masquées). **Mode Ramadan**.

**Pensé pour l'Afrique francophone**
- **LaGo Premium par Mobile Money** (MTN MoMo, Orange Money… via CinetPay). Par défaut **aucune fonction existante n'est réservée** au Premium (`Premium.gatedFeatures` dans `lib/core/premium.dart`).
- **Rappels SMS / WhatsApp** sur consentement, message discret par défaut.
- **Économie de données** : synchronisation seulement en glissant l'accueil vers le bas.
- Guides : Ramadan, hygiène quand les protections manquent, mythes et tabous, contraception.

**Confiance** : **mode anonyme** (sans email, rien sur internet), page **Vos données**, **accord parental** demandé sous 15 ans.

**Fidélisation** : **assistante** (hors ligne à partir des contenus validés ; en ligne si activée), **communauté** anonyme modérée, **bilan du mois** (+ notification le 1er), **partage des dates** sans les notes, **partenaires santé** (pharmacies, codes promo, téléconsultation), outils Super Admin (modération, partenaires, **statistiques anonymisées pour les ONG**, groupes ≥ 10).

Tout est regroupé dans **Accueil › Plus de LaGo**.

### Activer les services côté serveur (`server/`)

Chaque service est désactivé tant que ses variables ne sont pas définies (détails en tête de `server/features.js`) :

| Service | Variables |
|---|---|
| Premium CinetPay | `PUBLIC_URL`, `CINETPAY_APIKEY`, `CINETPAY_SITE_ID`, `CINETPAY_SECRET_KEY`, `PREMIUM_CURRENCY` (XAF), `PREMIUM_PRICE_MONTH` (500), `PREMIUM_PRICE_YEAR` (4000) |
| SMS / WhatsApp | `MESSAGING_PROVIDER` (`twilio` ou `webhook`), `TWILIO_*` ou `MESSAGING_WEBHOOK_URL`, `MESSAGING_HOUR` |
| Assistante en ligne | `ANTHROPIC_API_KEY`, `ASSISTANT_MODEL` |

Dans le tableau de bord CinetPay, l'URL de notification est `PUBLIC_URL/api/premium/notify`. Tests du serveur : `cd server && npm test`.

> Les contenus santé (guides, grossesse, réponses de l'assistante) sont à faire relire par une sage-femme ou un médecin avant la publication sur les stores.

## Nouveautés 4.3

- **Comptes parent** : à l'inscription, « Suivre mon enfant ». L'enfant crée un code (Profil › Suivi parental, 6 caractères, 48 h, usage unique) ;
  le parent le saisit dans « Mes enfants » et voit cycle, journal (sans les notes), graphiques et PDF. L'enfant peut retirer l'accès.
  Avec serveur : à distance (`/api/family/*`). Sans serveur : comptes sur le même téléphone.
- **Apprentissage** : durées réelles du cycle et des règles calculées depuis le journal (`lib/core/insights.dart`), désactivable.
- **Graphiques** : durées des cycles, symptômes et humeurs, température (`lib/widgets/charts.dart`, sans dépendance).
- **Langues** : + espagnol, portugais, arabe (droite à gauche) — dictionnaires `lib/l10n/es.dart`, `pt.dart`, `ar.dart`.
- **Pilule & rendez-vous** : rappel quotidien (plaquette continue ou 21 + 7), rendez-vous rappelés la veille et 2 h avant.
- **Rapport PDF** pour une consultation (paquet `pdf`), partagé via le téléphone.
- **Widget** d'écran d'accueil Android (créé par `tool/setup.dart`) ; iPhone : voir `ios_widget/README.md`. Les alertes s'affichent sur la montre connectée.
- **Sauvegarde chiffrée de la photo de profil** (avec consentement) : AES-256-GCM, clé dérivée du mot de passe, `/api/profile/avatar`.

## Nouveautés 4.2

- **Photo de profil** : avatar (16 emojis × 8 couleurs) ou photo (galerie / appareil photo). La photo reste sur le téléphone.
  Profil › Mon compte › « Changer ma photo de profil ».
- **Langues français / anglais** : l'app suit automatiquement la langue du téléphone (français → français, toute autre langue → anglais),
  ou une langue choisie dans Profil › Préférences › Langue (aussi sur l'écran de connexion). Les notifications sont réécrites dans la langue choisie.
  Traductions : `lib/l10n/en.dart` (le texte français du code sert de clé ; `{}` = valeur variable).

## Fonctionnalités

Toutes celles de la version web sont conservées :

- **Accueil** : cadran du cycle animé avec fleur de lotus, phase actuelle, compte à rebours, prochaines règles, ovulation, fertilité, conseil bien-être du jour
- **Journal** : calendrier mensuel (règles notées / prévues, fenêtre fertile, ovulation, humeur), balayage gauche/droite, feuille de saisie (flux, humeur, 10 symptômes, température, notes)
- **Phases** : les 4 saisons intérieures (phase en cours mise en avant) et les 6 prochains cycles
- **Bien-être** : herboristerie, seed cycling, questions fréquentes
- **Profil** : paramètres du cycle, mode nuit, pétales, mode discret, **rappels par notification**, **code PIN**, changement de mot de passe, export / import / effacement des données, suppression du compte, adresse du serveur
- **Super Admin 👑** : statistiques, liste des comptes, promotion / rétrogradation, suspension, suppression, création, journal d'événements
- Pluie de pétales, bouton cadenas de masquage rapide, comptes démo 1-clic

**Fonctionnement sans serveur** : l'app marche entièrement sur le téléphone, avec des comptes locaux dont les mots de passe sont hachés.

**Avec serveur** : si l'adresse est définie au build ou dans Profil › Synchronisation, les données se synchronisent avec l'API fournie dans `server/`. Les modifications faites hors-ligne sont renvoyées au retour du réseau.

## Structure

```
lib/
  main.dart               Démarrage, thème, verrouillage PIN au retour dans l'app
  theme.dart              Couleurs et polices LaGo (Cormorant Garamond, Plus Jakarta Sans)
  core/                   Logique : calculs du cycle, stockage, API, comptes, sync, rappels
  screens/                Écrans (accueil, journal, phases, bien-être, profil, admin, connexion, PIN)
  widgets/                Cadran, fleur de lotus, pétales, cartes, avatar, langue
  l10n/                   Langues : l10n.dart (moteur), en.dart (dictionnaire anglais)
assets/                   Polices, icône, écran de démarrage
test/                     Tests (calculs, dates, PIN, export/import, traductions)
tool/setup.dart           Génère et configure les projets android/ et ios/
server/                   API Node.js (optionnelle) pour la synchronisation
.github/workflows/        Compilation automatique APK / AAB / IPA
codemagic.yaml            Compilation + signature iOS sans Mac
```

---


## Nouveautés 4.1

- **Connexion obligatoire** : l'application ne s'ouvre qu'après connexion. Le mode invitée et la connexion automatique du compte démo sont supprimés ; les boutons démo 1-clic restent.
- **Création de compte en 4 étapes** :
  1. Compte : prénom, date de naissance, email, mot de passe avec indicateur de solidité et confirmation.
  2. **Informations de cycle obligatoires** : dernières règles, durée du cycle, durée des règles, régularité, avec un aperçu immédiat.
  3. Alertes : choix des moments, heure et sonnerie.
  4. Consentements.
- **Compte existant sans informations de cycle** : l'écran « Mon cycle » est demandé avant d'accéder à l'app (sauf Super Admin).
- **Alertes des moments importants** :
  - règles bientôt (1 à 5 jours avant) ;
  - jour des règles ;
  - début de la fenêtre fertile ;
  - ovulation ;
  - début du SPM ;
  - rappel du journal ;
  - conseil du jour.

  Chaque alerte a son heure, son interrupteur, son vibreur et un bouton « Tester ».
- **Sonneries** : 8 sonneries LaGo originales (Lotus, Carillon, Harpe, Goutte, Marimba, Cristal, Douceur, Éveil) avec écoute, plus le son du téléphone ou le mode silencieux. On peut **importer son propre son** pour chaque alerte :
  - Android 10+ : mp3, wav, ogg ou m4a ;
  - iPhone (version Flutter) : wav, caf ou aiff.
- **Conseils quotidiens de santé sexuelle** (35 conseils), en notification et dans l'onglet Bien-être, **adaptés à l'âge** :
  - moins de 18 ans : corps, consentement, relations, hygiène, protection ;
  - 18 ans et plus : en plus, contraception, dépistage, désir et couple, grossesse.

  Ils sont désactivés par défaut et ne s'activent que si l'utilisatrice le choisit.
- **Phases expliquées clairement**, avec une frise de *votre* cycle (« vous êtes ici ») et les jours de chaque phase calculés pour vous. Pour chaque phase :
  - quand ;
  - ce qui se passe dans le corps ;
  - hormones ;
  - ressentis ;
  - conseils ;
  - fertilité ;
  - quand consulter.

  S'y ajoutent une introduction « C'est quoi le cycle ? » et un lexique de 12 mots.
- **Serveur** : l'inscription enregistre directement les informations de cycle.

## 1. Compiler sur votre ordinateur

Prérequis : [Flutter](https://docs.flutter.dev/get-started/install) 3.29 ou plus récent, Android Studio (pour Android) et Xcode sur Mac (pour iOS).

```bash
dart run tool/setup.dart      # une seule fois : crée android/ et ios/ configurés + icônes
flutter test
flutter run                   # sur un téléphone branché ou un émulateur
```

### Android

```bash
flutter build apk --release          # APK à installer directement
flutter build appbundle --release    # AAB pour le Google Play Store
```

Fichiers produits : `build/app/outputs/flutter-apk/app-release.apk` et `build/app/outputs/bundle/release/app-release.aab`.

> Pour le Play Store, signez avec votre propre clé : voir https://docs.flutter.dev/deployment/android#sign-the-app

### iOS (Mac obligatoire)

```bash
open ios/Runner.xcworkspace          # Signing & Capabilities : choisissez votre équipe Apple
flutter build ipa --release          # -> build/ios/ipa/*.ipa pour TestFlight / App Store
```

Un compte Apple Developer (99 $/an) est nécessaire pour publier ou installer sur un iPhone hors mode développeur.

## 2. Compiler sans rien installer (dans le cloud)

### GitHub Actions (Android + iOS)

1. Poussez ce dossier dans un dépôt GitHub.
2. Allez dans **Actions › Build LaGo › Run workflow**. Vous pouvez y indiquer l'URL de votre serveur.
3. Téléchargez dans **Artifacts** :
   - `lago-android` : APK et AAB
   - `lago-ios-unsigned` : IPA **non signée**, à signer avec Sideloadly, AltStore ou Xcode

### Codemagic (iOS signé → TestFlight, sans Mac)

Connectez le dépôt sur codemagic.io, liez votre compte Apple Developer, puis lancez le workflow `lago-ios` défini dans `codemagic.yaml`.

## 3. Synchronisation avec le serveur (optionnel)

```bash
cd server
DEMO_MODE=false ADMIN_EMAIL=vous@domaine.com ADMIN_PASSWORD='MotDePasseSolide' \
LAGO_SECRET=$(node -e "console.log(require('crypto').randomBytes(48).toString('hex'))") \
node server.js
```

Placez-le derrière **HTTPS**, indispensable pour iOS, puis :

- soit compilez avec l'adresse : `flutter build apk --dart-define=LAGO_API_URL=https://api.votre-domaine.com`
- soit saisissez l'adresse dans l'app : **Profil › Synchronisation**

L'API est la même que celle de la version web v3 : mots de passe hachés, jetons signés, droits admin vérifiés côté serveur.

## 4. Options de compilation

| Option | Effet |
|---|---|
| `--dart-define=LAGO_API_URL=https://…` | Serveur de synchronisation par défaut |
| `--dart-define=DEMO_MODE=false` | Masque les comptes démo et la connexion automatique de Sarah (**à faire en production**) |

## Comptes démo (si `DEMO_MODE` est actif)

| Compte | Email | Mot de passe |
|---|---|---|
| 👑 Super Admin | `admin@lago.app` | `admin123` |
| 🌸 Utilisatrice | `sarah@lago.app` | `user123` |

## Confidentialité

- Le code PIN reste uniquement sur le téléphone.
- La sauvegarde Android dans le cloud est désactivée.
- Le mode discret neutralise le texte des notifications.
- Les données de santé de mineures demandent une politique de confidentialité, le consentement parental selon l'âge, et le respect des règles des stores sur les apps de santé (formulaire « Health apps » de Google Play, étiquettes de confidentialité de l'App Store).

*Les prévisions sont indicatives et ne remplacent pas un avis médical. LaGo n'est pas une méthode de contraception.*
