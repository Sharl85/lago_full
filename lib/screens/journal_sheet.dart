import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/utils.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../l10n/l10n.dart';

/// Ouvre le journal d'un jour (feuille qui monte du bas de l'écran).
Future<void> showJournalSheet(BuildContext context, String dateIso) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: isDark(context) ? LagoColors.cardDark : Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (_) => JournalSheet(dateIso: dateIso),
  );
}

class JournalSheet extends StatefulWidget {
  final String dateIso;
  const JournalSheet({super.key, required this.dateIso});

  @override
  State<JournalSheet> createState() => _JournalSheetState();
}

class _JournalSheetState extends State<JournalSheet> {
  final state = AppState.instance;
  late String _flow;
  late String _mood;
  late Set<String> _symptoms;
  late String _lh; // v5 : test d'ovulation
  late String _mucus; // v5 : glaire cervicale
  late final TextEditingController _temp;
  late final TextEditingController _notes;
  DayLog? _existing;

  @override
  void initState() {
    super.initState();
    _existing = state.logs[widget.dateIso];
    _flow = _existing?.flow ?? 'none';
    _mood = _existing?.mood ?? 'calm';
    _symptoms = {...?_existing?.symptoms};
    _lh = _existing?.ovulationTest ?? '';
    _mucus = _existing?.mucus ?? '';
    _temp = TextEditingController(text: _existing?.temperature ?? '');
    _notes = TextEditingController(text: _existing?.notes ?? '');
  }

  @override
  void dispose() {
    _temp.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _temp.text.trim().replaceAll(',', '.');
    if (raw.isNotEmpty) {
      final t = double.tryParse(raw);
      if (t == null || t < 34 || t > 43) {
        showToast(context, 'Température invalide (entre 34 et 43 °C).', type: ToastType.error);
        return;
      }
    }
    final notes = _notes.text.trim();
    await state.saveLog(
      widget.dateIso,
      DayLog(
        flow: _flow,
        mood: _mood,
        temperature: raw,
        symptoms: _symptoms.toList(),
        notes: notes.length > 2000 ? notes.substring(0, 2000) : notes,
        ovulationTest: _lh,
        mucus: _mucus,
        updatedAt: DateTime.now().toIso8601String(),
      ),
    );
    if (!mounted) return;
    showToast(context, '✨ Journal LaGo enregistré avec succès !');
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context, 'Supprimer cette entrée du journal ?', danger: true, okLabel: 'Supprimer');
    if (!ok) return;
    await state.deleteLog(widget.dateIso);
    if (!mounted) return;
    showToast(context, 'Entrée du journal supprimée.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final date = Dates.parseIso(widget.dateIso) ?? DateTime.now();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Icon(Icons.edit_calendar, color: LagoColors.pink),
              const SizedBox(width: 8),
              Expanded(child: T('Journal du ${Dates.long(date)}', style: Theme.of(context).textTheme.titleLarge)),
            ]),
            const SizedBox(height: 18),
            _label(Icons.water_drop_outlined, 'Intensité du flux menstruel'),
            DropdownButtonFormField<String>(
              value: _flow,
              isExpanded: true,
              items: FlowLevel.values.map((o) => DropdownMenuItem(value: o.key, child: T(o.label))).toList(),
              onChanged: (v) => setState(() => _flow = v ?? 'none'),
            ),
            const SizedBox(height: 16),
            _label(Icons.sentiment_satisfied_alt_outlined, "Humeur & état d'esprit"),
            DropdownButtonFormField<String>(
              value: _mood,
              isExpanded: true,
              items: Mood.values.map((o) => DropdownMenuItem(value: o.key, child: T('${o.emoji}  ${o.label}'))).toList(),
              onChanged: (v) => setState(() => _mood = v ?? 'calm'),
            ),
            const SizedBox(height: 16),
            _label(Icons.favorite_border, 'Symptômes & sensations corporelles'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: Symptom.values.map((o) {
                final selected = _symptoms.contains(o.key);
                return FilterChip(
                  avatar: Icon(o.icon, size: 16, color: selected ? Colors.white : LagoColors.pink),
                  label: T(o.label, style: TextStyle(color: selected ? Colors.white : null)),
                  selected: selected,
                  showCheckmark: false,
                  onSelected: (on) => setState(() => on ? _symptoms.add(o.key) : _symptoms.remove(o.key)),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _label(Icons.thermostat, 'Température basale (°C, optionnel)'),
            TextField(
              controller: _temp,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(hintText: tr('Ex : 36,6')),
            ),
            const SizedBox(height: 16),
            // v5 — signes de fertilité : ils permettent à LaGo de confirmer l'ovulation
            _label(Icons.science_outlined, 'Test d’ovulation (optionnel)'),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _lh,
              isExpanded: true,
              items: OvulationTest.values.map((o) => DropdownMenuItem(value: o.key, child: T('${o.emoji}  ${o.label}'))).toList(),
              onChanged: (v) => setState(() => _lh = v ?? ''),
            ),
            const SizedBox(height: 16),
            _label(Icons.opacity, 'Glaire cervicale (optionnel)'),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _mucus,
              isExpanded: true,
              items: Mucus.values.map((o) => DropdownMenuItem(value: o.key, child: T('${o.emoji}  ${o.label}'))).toList(),
              onChanged: (v) => setState(() => _mucus = v ?? ''),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: T('Un test positif, une hausse de température ou une glaire « blanc d’œuf » aident LaGo à confirmer votre ovulation.',
                  style: TextStyle(fontSize: 12, color: mutedColor(context))),
            ),
            const SizedBox(height: 16),
            _label(Icons.edit_note, 'Notes personnelles & pensées'),
            TextField(
              controller: _notes,
              maxLines: 4,
              maxLength: 2000,
              decoration: InputDecoration(hintText: tr("Comment vous sentez-vous aujourd'hui ? Gratitude, envies, sensations…")),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const T('Enregistrer')),
              ),
              if (_existing != null) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: LagoColors.danger),
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const T('Supprimer'),
                ),
              ],
            ]),
          ],
        ),
      ),
    );
  }

  Widget _label(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, size: 17, color: LagoColors.pink),
          const SizedBox(width: 6),
          Expanded(child: T(text, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}
