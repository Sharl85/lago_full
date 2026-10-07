import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/utils.dart';
import '../widgets/common.dart';
import '../widgets/setup_forms.dart';
import '../l10n/l10n.dart';

/// Affiché quand un compte n'a pas encore d'informations de cycle :
/// elles sont obligatoires avant d'utiliser l'application.
class CycleSetupScreen extends StatefulWidget {
  const CycleSetupScreen({super.key});

  @override
  State<CycleSetupScreen> createState() => _CycleSetupScreenState();
}

class _CycleSetupScreenState extends State<CycleSetupScreen> {
  final state = AppState.instance;
  final _data = CycleFormData();
  bool _notifications = true;
  bool _busy = false;

  Future<void> _save() async {
    if (!_data.isComplete) {
      showToast(context, 'Indiquez la date du premier jour de vos dernières règles.', type: ToastType.error);
      return;
    }
    if (_data.periodDuration >= _data.cycleLength) {
      showToast(context, 'Les règles doivent être plus courtes que le cycle.', type: ToastType.error);
      return;
    }
    setState(() => _busy = true);
    await state.completeSetup(
      CycleSettings(
        lastPeriodDate: Dates.toIso(_data.lastPeriod!),
        cycleLength: _data.cycleLength,
        periodDuration: _data.periodDuration,
        cycleRegularity: _data.regularity,
        remindersEnabled: _notifications,
      ),
      state.alertPrefs,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const T('Mon cycle'),
        actions: [TextButton(onPressed: state.logout, child: const T('Se déconnecter'))],
      ),
      body: LagoBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  T('Bonjour ${state.user?.name ?? ''} 🌸', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  T('Pour calculer vos règles, votre ovulation et vos alertes, LaGo a besoin de quelques informations sur votre cycle.',
                      style: TextStyle(color: mutedColor(context))),
                  const SizedBox(height: 16),
                  GlassCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      CycleFormFields(data: _data, onChanged: () => setState(() {})),
                      CyclePreview(data: _data),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const T('Activer les alertes (règles, ovulation…)'),
                        value: _notifications,
                        onChanged: (v) => setState(() => _notifications = v),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: const Icon(Icons.check),
                    label: const T('Enregistrer et commencer'),
                  ),
                  const SizedBox(height: 8),
                  T('Vous pourrez modifier ces informations à tout moment dans Profil.',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: mutedColor(context))),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
