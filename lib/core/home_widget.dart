import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'calculator.dart';
import 'models.dart';
import 'utils.dart';
import '../l10n/l10n.dart';

/// Widget d'écran d'accueil : jour du cycle et prochaines règles.
/// Android : automatique. iPhone : nécessite l'extension WidgetKit décrite dans ios_widget/README.md.
class LagoHomeWidget {
  static const androidName = 'LagoWidgetProvider';
  static const iOSName = 'LagoWidget';
  static const appGroup = 'group.app.lago.cycle';

  static bool get _supported => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Met à jour le widget. En mode discret, aucun mot lié au cycle n'apparaît.
  static Future<void> update({required CycleData? cycle, required bool discreet, bool parent = false}) async {
    if (!_supported) return;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) await HomeWidget.setAppGroupId(appGroup);
      String title = 'LaGo 🌸', main = 'LaGo', sub = '';
      if (cycle != null && !parent) {
        main = tr('Jour ${cycle.currentCycleDay}');
        if (discreet) {
          sub = tr('Touchez pour ouvrir');
        } else {
          final n = cycle.daysUntilNextPeriod;
          sub = n <= 0
              ? tr('Règles prévues aujourd’hui 🌸')
              : tr('Règles dans $n jour${n > 1 ? 's' : ''} · ${Dates.short(cycle.nextPeriodStart)}');
          title = tr(cycle.phase.name);
        }
      } else if (parent) {
        main = tr('Suivi parental');
        sub = tr('Touchez pour ouvrir');
      }
      await HomeWidget.saveWidgetData<String>('title', title);
      await HomeWidget.saveWidgetData<String>('main', main);
      await HomeWidget.saveWidgetData<String>('sub', sub);
      await HomeWidget.updateWidget(androidName: androidName, iOSName: iOSName);
    } catch (_) {
      // Widget non installé (ou extension iOS absente) : sans conséquence pour l'application.
    }
  }
}
