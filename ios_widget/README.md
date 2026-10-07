# Widget LaGo pour iPhone (facultatif)

Sur **Android**, le widget est installé automatiquement par `dart run tool/setup.dart`
(appui long sur l'écran d'accueil › Widgets › LaGo).

Sur **iPhone**, Apple impose une « extension de widget » créée dans Xcode (une seule fois, sur un Mac) :

1. `open ios/Runner.xcworkspace`
2. File › New › Target › **Widget Extension** — nom : `LagoWidget` (décocher « Include Configuration App Intent »).
3. Remplacer le fichier Swift généré par `ios_widget/LagoWidget.swift`.
4. Cible **Runner** et cible **LagoWidget** › Signing & Capabilities › **+ App Groups** › `group.app.lago.cycle`.
5. Compiler normalement (`flutter build ipa`).

Sans ces étapes, l'application iPhone fonctionne normalement, simplement sans widget.
L'application écrit les textes du widget (jour du cycle, prochaines règles, mode discret respecté)
dans l'App Group `group.app.lago.cycle` via le paquet `home_widget`.
