import 'package:flutter/material.dart';

import '../core/alerts.dart';
import '../core/app_state.dart';
import '../core/appointments.dart';
import '../core/notifications.dart';
import '../core/utils.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/setup_forms.dart';
import '../l10n/l10n.dart';

/// Rappels santé : prise de la pilule et rendez-vous médicaux.
class HealthRemindersScreen extends StatelessWidget {
  const HealthRemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return Scaffold(
      appBar: AppBar(title: const T('Pilule & rendez-vous')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editAppointment(context, null),
        icon: const Icon(Icons.add),
        label: const T('Rendez-vous'),
      ),
      body: LagoBackground(
        child: ListenableBuilder(
          listenable: state,
          builder: (context, _) {
            final p = state.alertPrefs;
            final pill = p.of(AlertType.pill);
            final upcoming = state.appointments.where((a) => !a.isPast).toList();
            final past = state.appointments.where((a) => a.isPast).toList().reversed.toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
              children: [
                if (!state.settings.remindersEnabled)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassCard(
                      child: Row(children: [
                        const Icon(Icons.notifications_off_outlined, color: LagoColors.orange),
                        const SizedBox(width: 10),
                        const Expanded(child: T('Les notifications LaGo sont désactivées : activez-les pour recevoir ces rappels.')),
                        TextButton(
                          onPressed: () async {
                            await state.updateSettings(state.settings.copyWith(remindersEnabled: true));
                            final n = await state.rescheduleReminders();
                            if (n < 0 && context.mounted) {
                              showToast(context, 'Autorisez les notifications de LaGo dans les réglages du téléphone.', type: ToastType.error);
                            }
                          },
                          child: const T('Activer'),
                        ),
                      ]),
                    ),
                  ),
                GlassCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const SectionTitle('Rappel de pilule', icon: Icons.medication_outlined,
                        subtitle: 'Une notification chaque jour à la même heure.'),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const T('💊  Me rappeler de prendre ma pilule', style: TextStyle(fontWeight: FontWeight.w700)),
                      value: pill.enabled,
                      onChanged: (v) => state.updateAlertPrefs(p.withAlert(AlertType.pill, pill.copyWith(enabled: v))),
                    ),
                    if (pill.enabled) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.schedule, color: LagoColors.pink),
                        title: const T('Heure de la prise'),
                        trailing: T(formatTime(p.pillHour, p.pillMinute), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        onTap: () async {
                          final t = await pickTime(context, p.pillHour, p.pillMinute, 'Heure de la prise');
                          if (t != null) await state.updateAlertPrefs(p.copyWith(pillHour: t.hour, pillMinute: t.minute));
                        },
                      ),
                      const T('Ma plaquette', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      SegmentedButton<int>(
                        segments: [
                          ButtonSegment(value: 0, label: T('En continu')),
                          ButtonSegment(value: 7, label: T('21 j + 7 j de pause')),
                        ],
                        selected: {p.pillBreakDays},
                        onSelectionChanged: (v) => state.updateAlertPrefs(p.copyWith(
                            pillBreakDays: v.first, pillStartDate: p.pillStartDate ?? Dates.toIso(Dates.today()))),
                      ),
                      if (p.pillBreakDays == 7)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event, color: LagoColors.pink),
                          title: const T('1er comprimé de la plaquette en cours'),
                          subtitle: T(Dates.long(Dates.parseIso(p.pillStartDate) ?? Dates.today())),
                          trailing: const Icon(Icons.edit_calendar_outlined),
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: Dates.parseIso(p.pillStartDate) ?? Dates.today(),
                              firstDate: Dates.addDays(Dates.today(), -60),
                              lastDate: Dates.addDays(Dates.today(), 7),
                            );
                            if (d != null) await state.updateAlertPrefs(p.copyWith(pillStartDate: Dates.toIso(d)));
                          },
                        ),
                      Row(children: [
                        const Icon(Icons.music_note, size: 18, color: LagoColors.pink),
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(alignment: Alignment.centerLeft),
                            onPressed: () async {
                              final id = await showSoundPicker(context, pill.sound);
                              if (id != null) await state.updateAlertPrefs(p.withAlert(AlertType.pill, pill.copyWith(sound: id)));
                            },
                            child: T(Sounds.of(pill.sound).label),
                          ),
                        ),
                        IconButton(
                          tooltip: tr('Tester cette alerte'),
                          icon: const Icon(Icons.play_circle_fill, color: LagoColors.pink),
                          onPressed: () => Reminders.test(AlertType.pill, pill),
                        ),
                      ]),
                      T('En cas d’oubli, suivez la notice de votre pilule ou demandez conseil à votre pharmacien.',
                          style: TextStyle(fontSize: 12, color: mutedColor(context))),
                    ],
                  ]),
                ),
                const SizedBox(height: 14),
                GlassCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const SectionTitle('Rendez-vous médicaux', icon: Icons.medical_services_outlined,
                        subtitle: 'Rappel la veille et 2 heures avant.'),
                    if (upcoming.isEmpty)
                      T('Aucun rendez-vous à venir. Touchez « + Rendez-vous » pour en ajouter un.',
                          style: TextStyle(color: mutedColor(context), fontSize: 13)),
                    for (final a in upcoming) _tile(context, a),
                    if (past.isNotEmpty) ...[
                      const Divider(height: 24),
                      T('Passés', style: TextStyle(fontWeight: FontWeight.w700, color: mutedColor(context))),
                      for (final a in past.take(5)) _tile(context, a, past: true),
                    ],
                  ]),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, Appointment a, {bool past = false}) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: past ? Colors.black12 : LagoColors.pinkLight,
          child: const Text('🩺'),
        ),
        title: Text(a.title, style: TextStyle(fontWeight: FontWeight.w700, color: past ? mutedColor(context) : null)),
        subtitle: Text('${Dates.long(a.when)} · ${formatTime(a.when.hour, a.when.minute)}${a.place.isEmpty ? '' : ' · ${a.place}'}'),
        trailing: const Icon(Icons.edit_outlined, size: 20),
        onTap: () => _editAppointment(context, a),
      );

  static Future<void> _editAppointment(BuildContext context, Appointment? existing) async {
    final state = AppState.instance;
    final title = TextEditingController(text: existing?.title ?? '');
    final place = TextEditingController(text: existing?.place ?? '');
    final note = TextEditingController(text: existing?.note ?? '');
    var when = existing?.when ?? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 7, 10);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              T(existing == null ? 'Nouveau rendez-vous' : 'Modifier le rendez-vous',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final s in ['Gynécologue', 'Sage-femme', 'Médecin traitant', 'Dépistage', 'Prise de sang', 'Échographie'])
                  ActionChip(label: T(s), onPressed: () => setSheet(() => title.text = tr(s))),
              ]),
              const SizedBox(height: 10),
              TextField(controller: title, maxLength: 80, decoration: InputDecoration(labelText: tr('Motif / praticien *'))),
              TextField(controller: place, maxLength: 120, decoration: InputDecoration(labelText: tr('Lieu (optionnel)'))),
              TextField(controller: note, maxLength: 300, maxLines: 2, decoration: InputDecoration(labelText: tr('Note (optionnel)'))),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(Dates.long(when)),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: when,
                        firstDate: Dates.addDays(Dates.today(), -365),
                        lastDate: Dates.addDays(Dates.today(), 730),
                      );
                      if (d != null) setSheet(() => when = DateTime(d.year, d.month, d.day, when.hour, when.minute));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text(formatTime(when.hour, when.minute)),
                  onPressed: () async {
                    final t = await pickTime(ctx, when.hour, when.minute, 'Heure du rendez-vous');
                    if (t != null) setSheet(() => when = DateTime(when.year, when.month, when.day, t.hour, t.minute));
                  },
                ),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                if (existing != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: LagoColors.danger),
                    onPressed: () => Navigator.pop(ctx, 'delete'),
                    icon: const Icon(Icons.delete_outline),
                    label: const T('Supprimer'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, title.text.trim().isEmpty ? null : 'save'),
                  child: const T('Enregistrer'),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
    final list = [...state.appointments];
    if (result == 'delete' && existing != null) {
      list.removeWhere((a) => a.id == existing.id);
      await state.saveAppointments(list);
    } else if (result == 'save') {
      final a = Appointment(
        id: existing?.id ?? newId(),
        title: title.text.trim(),
        when: when,
        place: place.text.trim(),
        note: note.text.trim(),
      );
      list.removeWhere((x) => x.id == a.id);
      list.add(a);
      await state.saveAppointments(list);
      if (context.mounted) showToast(context, 'Rendez-vous enregistré. Rappel la veille et 2 heures avant.');
    }
    // Les contrôleurs ne sont pas libérés ici : la feuille peut encore être en animation de fermeture.
  }
}
