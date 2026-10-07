import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/alerts.dart';
import '../core/calculator.dart';
import '../core/utils.dart';
import '../theme.dart';
import 'common.dart';
import '../l10n/l10n.dart';

/// Données du formulaire « mon cycle » (inscription, configuration, profil).
class CycleFormData {
  DateTime? lastPeriod;
  int cycleLength;
  int periodDuration;
  String regularity; // regular | irregular | unknown
  bool unknownLength;

  CycleFormData({this.lastPeriod, this.cycleLength = 28, this.periodDuration = 5, this.regularity = 'unknown', this.unknownLength = false});

  bool get isComplete => lastPeriod != null;
}

/// Champs du cycle : date des dernières règles, durée du cycle, durée des règles, régularité.
class CycleFormFields extends StatefulWidget {
  final CycleFormData data;
  final VoidCallback? onChanged;
  const CycleFormFields({super.key, required this.data, this.onChanged});

  @override
  State<CycleFormFields> createState() => _CycleFormFieldsState();
}

class _CycleFormFieldsState extends State<CycleFormFields> {
  CycleFormData get d => widget.data;

  void _changed(VoidCallback fn) {
    setState(fn);
    widget.onChanged?.call();
  }

  Future<void> _pickDate() async {
    final today = Dates.today();
    final picked = await showDatePicker(
      context: context,
      initialDate: d.lastPeriod ?? Dates.addDays(today, -7),
      firstDate: DateTime(today.year - 1, today.month, today.day),
      lastDate: today,
      helpText: tr('Premier jour de vos dernières règles'),
    );
    if (picked != null) _changed(() => d.lastPeriod = picked);
  }

  @override
  Widget build(BuildContext context) {
    final muted = mutedColor(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(context, Icons.event, 'Premier jour de vos dernières règles *'),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.all(16),
          ),
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_month),
          label: T(d.lastPeriod == null ? 'Choisir la date' : Dates.long(d.lastPeriod!),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 4),
          child: T('Le jour où les saignements ont commencé (pas le spotting).', style: TextStyle(fontSize: 12, color: muted)),
        ),
        const SizedBox(height: 18),
        _label(context, Icons.loop, 'Durée habituelle de votre cycle'),
        T('Du 1er jour des règles à la veille des règles suivantes. La moyenne est de 28 jours.',
            style: TextStyle(fontSize: 12, color: muted)),
        const SizedBox(height: 6),
        _stepper(d.cycleLength, 20, 45, d.unknownLength ? null : (v) => _changed(() => d.cycleLength = v)),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: d.unknownLength,
          title: const T('Je ne sais pas (utiliser 28 jours, LaGo s’ajustera avec votre journal)'),
          onChanged: (v) => _changed(() {
            d.unknownLength = v ?? false;
            if (d.unknownLength) d.cycleLength = 28;
          }),
        ),
        const SizedBox(height: 8),
        _label(context, Icons.water_drop_outlined, 'Durée habituelle de vos règles'),
        _stepper(d.periodDuration, 2, 10, (v) => _changed(() => d.periodDuration = v)),
        const SizedBox(height: 14),
        _label(context, Icons.straighten, 'Vos cycles sont-ils réguliers ?'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final o in const [('regular', 'Oui, réguliers'), ('irregular', 'Non, irréguliers'), ('unknown', 'Je ne sais pas')])
            ChoiceChip(
              label: T(o.$2),
              selected: d.regularity == o.$1,
              onSelected: (_) => _changed(() => d.regularity = o.$1),
            ),
        ]),
        if (d.regularity == 'irregular')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: T(
              'Avec des cycles irréguliers, les prévisions seront moins précises. Notez vos règles chaque mois : c’est aussi très utile pour votre médecin.',
              style: TextStyle(fontSize: 12.5, color: muted),
            ),
          ),
      ],
    );
  }

  Widget _stepper(int value, int min, int max, ValueChanged<int>? onChanged) {
    return Row(children: [
      IconButton.filledTonal(onPressed: onChanged != null && value > min ? () => onChanged(value - 1) : null, icon: const Icon(Icons.remove)),
      Expanded(
        child: T('$value jours', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      ),
      IconButton.filledTonal(onPressed: onChanged != null && value < max ? () => onChanged(value + 1) : null, icon: const Icon(Icons.add)),
    ]);
  }
}

Widget _label(BuildContext context, IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 18, color: LagoColors.pink),
        const SizedBox(width: 6),
        Expanded(child: T(text, style: const TextStyle(fontWeight: FontWeight.w700))),
      ]),
    );

/// Aperçu personnalisé des phases pour les valeurs saisies.
class CyclePreview extends StatelessWidget {
  final CycleFormData data;
  const CyclePreview({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.lastPeriod == null) return const SizedBox.shrink();
    final c = CycleCalculator.calculate(Dates.toIso(data.lastPeriod!), data.cycleLength, data.periodDuration);
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.phase.background, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        T('Aujourd’hui : jour ${c.currentCycleDay} — ${c.phase.name}',
            style: const TextStyle(fontWeight: FontWeight.w700, color: LagoColors.textDark)),
        const SizedBox(height: 4),
        T('Prochaines règles : ${Dates.long(c.nextPeriodStart)}\nOvulation estimée : ${Dates.long(c.ovulationDate)}',
            style: const TextStyle(fontSize: 13, color: LagoColors.textDark)),
      ]),
    );
  }
}

/// Sélecteur de sonnerie avec écoute et import d'un son personnel.
Future<String?> showSoundPicker(BuildContext context, String current) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: isDark(context) ? LagoColors.cardDark : Colors.white,
    builder: (_) => _SoundPicker(current: current),
  ).whenComplete(Sounds.stopPreview);
}

class _SoundPicker extends StatefulWidget {
  final String current;
  const _SoundPicker({required this.current});
  @override
  State<_SoundPicker> createState() => _SoundPickerState();
}

class _SoundPickerState extends State<_SoundPicker> {
  late String _selected = widget.current;
  bool _importing = false;

  Future<void> _import() async {
    setState(() => _importing = true);
    try {
      final ios = Theme.of(context).platform == TargetPlatform.iOS;
      // iPhone : sélecteur de fichiers (la bibliothèque Musique n'autorise pas l'export des sons)
      final res = ios
          ? await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['wav', 'caf', 'aiff', 'aif'])
          : await FilePicker.platform.pickFiles(type: FileType.audio);
      final f = res?.files.single;
      if (f == null || f.path == null) return;
      final s = await Sounds.importCustom(f.path!, f.name);
      if (!mounted) return;
      setState(() => _selected = s.id);
      showToast(context, '🎵 Son « ${s.label} » ajouté.');
    } catch (e) {
      if (mounted) showToast(context, '$e'.replaceFirst('Exception: ', ''), type: ToastType.error);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sounds = Sounds.all;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(children: [
            const Icon(Icons.music_note, color: LagoColors.pink),
            const SizedBox(width: 8),
            Expanded(child: T('Choisir une sonnerie', style: Theme.of(context).textTheme.titleLarge)),
          ]),
        ),
        Expanded(
          child: ListView(controller: scroll, children: [
            for (final s in sounds)
              ListTile(
                leading: Icon(
                  _selected == s.id ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: _selected == s.id ? LagoColors.pink : null,
                ),
                title: T(s.label),
                subtitle: s.custom ? const T('Son personnel') : null,
                onTap: () {
                  setState(() => _selected = s.id);
                  Sounds.preview(s.id);
                },
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (s.id != 'silent' && s.id != 'default')
                    IconButton(tooltip: tr('Écouter'), icon: const Icon(Icons.play_circle_outline), onPressed: () => Sounds.preview(s.id)),
                  if (s.custom)
                    IconButton(
                      tooltip: tr('Supprimer ce son'),
                      icon: const Icon(Icons.delete_outline, color: LagoColors.danger),
                      onPressed: () async {
                        await Sounds.removeCustom(s.id);
                        if (!mounted) return;
                        setState(() {
                          if (_selected == s.id) _selected = 'lago_lotus';
                        });
                      },
                    ),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: OutlinedButton.icon(
                onPressed: _importing ? null : _import,
                icon: _importing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.library_music_outlined),
                label: const T('Importer mon propre son…'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: T(
                'Android : mp3, wav, ogg ou m4a (Android 10 ou plus récent). iPhone : wav, caf ou aiff de 30 secondes maximum.',
                style: TextStyle(fontSize: 11.5, color: mutedColor(context)),
              ),
            ),
          ]),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.pop(context, _selected), child: const T('Choisir cette sonnerie')),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Choix d'une heure.
Future<TimeOfDay?> pickTime(BuildContext context, int h, int m, String help) =>
    showTimePicker(context: context, initialTime: TimeOfDay(hour: h, minute: m), helpText: tr(help));
