import 'package:flutter/material.dart';

import '../core/alerts.dart';
import '../core/app_state.dart';
import '../core/notifications.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/setup_forms.dart';
import '../l10n/l10n.dart';

/// Alertes & sonneries : moments importants, rappels, conseil du jour, sonnerie par alerte.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final state = AppState.instance;

  Future<void> _apply(AlertPrefs p, {String? toast}) async {
    final n = await state.updateAlertPrefs(p);
    if (!mounted) return;
    if (n < 0) {
      showToast(context, 'Autorisez les notifications de LaGo dans les réglages du téléphone.', type: ToastType.error);
    } else if (toast != null) {
      showToast(context, toast);
    }
  }

  Future<void> _setMaster(bool on) async {
    await state.updateSettings(state.settings.copyWith(remindersEnabled: on));
    final n = await state.rescheduleReminders();
    if (!mounted) return;
    if (on && n < 0) {
      await state.updateSettings(state.settings.copyWith(remindersEnabled: false));
      if (mounted) showToast(context, 'Autorisez les notifications de LaGo dans les réglages du téléphone.', type: ToastType.error);
    } else {
      showToast(context, on ? '🔔 Notifications activées ($n programmées).' : 'Notifications désactivées.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final s = state.settings;
        final p = state.alertPrefs;
        final adult = (state.user?.age ?? 0) >= 18;
        return Scaffold(
          appBar: AppBar(title: const T('Alertes & sonneries')),
          body: LagoBackground(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
              children: [
                if (!Reminders.supported)
                  const GlassCard(child: T('Les notifications sont disponibles dans l’application Android et iOS.')),
                GlassCard(
                  child: Column(children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const T('Notifications LaGo', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const T('Interrupteur général de toutes les alertes.'),
                      value: s.remindersEnabled,
                      onChanged: _setMaster,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const T('Mode discret'),
                      subtitle: const T('Le texte des notifications ne mentionne ni le cycle ni la sexualité.'),
                      value: s.discreetMode,
                      onChanged: (v) async {
                        await state.updateSettings(s.copyWith(discreetMode: v));
                        await state.rescheduleReminders();
                      },
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                if (s.remindersEnabled) ...[
                  GlassCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const SectionTitle('Horaires', icon: Icons.schedule),
                      _timeTile('Alertes du cycle', p.alertHour, p.alertMinute,
                          (t) => _apply(p.copyWith(alertHour: t.hour, alertMinute: t.minute), toast: 'Horaire mis à jour.')),
                      _timeTile('Rappel du journal', p.logHour, p.logMinute,
                          (t) => _apply(p.copyWith(logHour: t.hour, logMinute: t.minute), toast: 'Horaire mis à jour.')),
                      _timeTile('Conseil du jour', p.tipHour, p.tipMinute,
                          (t) => _apply(p.copyWith(tipHour: t.hour, tipMinute: t.minute), toast: 'Horaire mis à jour.')),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const T('Prévenir avant les règles'),
                        subtitle: T('${p.periodSoonDays} jour${p.periodSoonDays > 1 ? 's' : ''} avant'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            onPressed: p.periodSoonDays > 1 ? () => _apply(p.copyWith(periodSoonDays: p.periodSoonDays - 1)) : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          IconButton(
                            onPressed: p.periodSoonDays < 5 ? () => _apply(p.copyWith(periodSoonDays: p.periodSoonDays + 1)) : null,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  const SectionTitle('Moments importants', icon: Icons.notifications_active_outlined,
                      subtitle: 'Choisissez les alertes et leur sonnerie. Touchez ▶ pour tester.'),
                  for (final t in state.isParent ? const [AlertType.pill, AlertType.appointment] : AlertType.all) ...[
                    _alertCard(t, p, adult),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _timeTile(String label, int h, int m, void Function(TimeOfDay) onPicked) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: T(label),
        trailing: T(formatTime(h, m), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        onTap: () async {
          final t = await pickTime(context, h, m, label);
          if (t != null) onPicked(t);
        },
      );

  Widget _alertCard(AlertType t, AlertPrefs p, bool adult) {
    final a = p.of(t);
    final description = t == AlertType.dailyTip
        ? (adult
            ? 'Un conseil par jour : sexualité, contraception, désir, dépistage et santé intime.'
            : 'Un conseil par jour : mon corps, consentement, relations et santé intime, adapté à votre âge.')
        : t.description;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Column(children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: T('${t.emoji}  ${t.label}', style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: T(description, style: const TextStyle(fontSize: 12.5)),
          value: a.enabled,
          onChanged: (v) => _apply(p.withAlert(t, a.copyWith(enabled: v))),
        ),
        if (a.enabled)
          Row(children: [
            const Icon(Icons.music_note, size: 18, color: LagoColors.pink),
            const SizedBox(width: 6),
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(alignment: Alignment.centerLeft, padding: EdgeInsets.zero),
                onPressed: () async {
                  final id = await showSoundPicker(context, a.sound);
                  if (id != null) await _apply(p.withAlert(t, a.copyWith(sound: id)), toast: 'Sonnerie : ${Sounds.of(id).label}');
                },
                child: T(Sounds.of(a.sound).label, overflow: TextOverflow.ellipsis),
              ),
            ),
            IconButton(
              tooltip: tr(a.vibrate ? 'Vibreur activé' : 'Vibreur désactivé'),
              icon: Icon(a.vibrate ? Icons.vibration : Icons.mobile_off, color: a.vibrate ? LagoColors.pink : null),
              onPressed: () => _apply(p.withAlert(t, a.copyWith(vibrate: !a.vibrate))),
            ),
            IconButton(
              tooltip: tr('Tester cette alerte'),
              icon: const Icon(Icons.play_circle_fill, color: LagoColors.pink),
              onPressed: () async {
                final ok = await Reminders.test(t, a);
                if (!ok && mounted) {
                  showToast(context, 'Autorisez les notifications de LaGo dans les réglages du téléphone.', type: ToastType.error);
                }
              },
            ),
          ]),
      ]),
    );
  }
}
