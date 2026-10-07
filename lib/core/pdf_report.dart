import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'calculator.dart';
import 'insights.dart';
import 'models.dart';
import 'utils.dart';
import '../l10n/l10n.dart';

/// Rapport PDF à présenter lors d'une consultation (médecin, sage-femme, gynécologue).
class PdfReport {
  static const _pink = PdfColor.fromInt(0xFFC2185B);
  static const _soft = PdfColor.fromInt(0xFFFCE4EC);
  static const _muted = PdfColor.fromInt(0xFF7D6B79);

  /// Crée le PDF puis ouvre le partage du téléphone (email, WhatsApp, Fichiers, imprimante…).
  static Future<void> share({
    required String name,
    int? age,
    required CycleSettings settings,
    required Map<String, DayLog> logs,
    bool includeNotes = false,
    int days = 180,
  }) async {
    // L'arabe n'est pas pris en charge par la police du PDF : le rapport est alors rédigé en français.
    final savedLang = L.lang;
    if (L.isRtl) L.lang = 'fr';
    try {
      final bytes = await build(name: name, age: age, settings: settings, logs: logs, includeNotes: includeNotes, days: days);
      final dir = await getTemporaryDirectory();
      final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final file = File('${dir.path}/LaGo_${safe}_${Dates.toIso(DateTime.now())}.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')], subject: tr('Rapport de cycle LaGo'));
    } finally {
      L.lang = savedLang;
    }
  }

  static Future<List<int>> build({
    required String name,
    int? age,
    required CycleSettings settings,
    required Map<String, DayLog> logs,
    bool includeNotes = false,
    int days = 180,
  }) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/PlusJakartaSans_400Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/PlusJakartaSans_700Bold.ttf'));
    final theme = pw.ThemeData.withFont(base: regular, bold: bold);

    final insights = CycleInsights.compute(logs);
    final eff = insights.apply(settings);
    final cycle = CycleCalculator.calculate(eff.lastPeriodDate, eff.cycleLength, eff.periodDuration);
    final since = Dates.addDays(Dates.today(), -days);
    final recent = logs.entries.where((e) {
      final d = Dates.parseIso(e.key);
      return d != null && !d.isBefore(since);
    }).toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    String flowLabel(String k) => tr(FlowLevel.values.firstWhere((o) => o.key == k, orElse: () => FlowLevel.values.first).label);
    String sym(String k) => tr(Symptom.of(k).label);
    String reg(String r) => tr(switch (r) { 'regular' => 'Réguliers', 'irregular' => 'Irréguliers', _ => 'Non précisé' });

    final doc = pw.Document(title: tr('Rapport de cycle LaGo'), author: 'LaGo');
    doc.addPage(pw.MultiPage(
      theme: theme,
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 6),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _soft, width: 2))),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('LaGo', style: pw.TextStyle(color: _pink, fontWeight: pw.FontWeight.bold, fontSize: 14)),
          pw.Text(tr('Rapport de cycle — $name'), style: const pw.TextStyle(color: _muted, fontSize: 9)),
        ]),
      ),
      footer: (ctx) => pw.Column(children: [
        pw.Text(
          tr('Données saisies par l’utilisatrice dans LaGo. Les prévisions sont indicatives et ne remplacent pas un avis médical.'),
          style: const pw.TextStyle(color: _muted, fontSize: 7.5),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 2),
        pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(color: _muted, fontSize: 8)),
      ]),
      build: (ctx) => [
        pw.Text(tr('Rapport de cycle'), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _pink)),
        pw.SizedBox(height: 4),
        pw.Text('$name${age != null ? tr(' · $age ans') : ''} · ${tr('édité le ${Dates.long(DateTime.now())}')}',
            style: const pw.TextStyle(fontSize: 10, color: _muted)),
        pw.SizedBox(height: 14),

        _h(tr('Résumé')),
        _kv([
          [tr('Durée moyenne du cycle'), '${eff.cycleLength} ${tr('jours')}${insights.learnedCycleLength != null ? tr(' (mesurée sur ${insights.cycleLengths.length} cycles)') : tr(' (déclarée)')}'],
          [tr('Durée moyenne des règles'), '${eff.periodDuration} ${tr('jours')}${insights.learnedPeriodLength != null ? tr(' (mesurée)') : tr(' (déclarée)')}'],
          if (insights.shortestCycle != null)
            [tr('Cycle le plus court / le plus long'), '${insights.shortestCycle} / ${insights.longestCycle} ${tr('jours')}'],
          if (insights.variation != null) [tr('Variation entre les cycles'), '${insights.variation} ${tr('jours')}'],
          [tr('Cycles réguliers (déclaré)'), reg(settings.cycleRegularity)],
          [tr('Dernières règles'), Dates.long(cycle.currentPeriodStart)],
          [tr('Prochaines règles estimées'), Dates.long(cycle.nextPeriodStart)],
          [tr('Jours notés dans le journal'), '${insights.loggedDays}'],
        ]),
        if (insights.variation != null && insights.variation! > 7)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 6),
            child: pw.Text(tr('Cycles irréguliers : écart de plus de 7 jours entre le cycle le plus court et le plus long.'),
                style: pw.TextStyle(fontSize: 9, color: _pink, fontWeight: pw.FontWeight.bold)),
          ),
        pw.SizedBox(height: 14),

        if (insights.periodStarts.isNotEmpty) ...[
          _h(tr('Règles notées')),
          _table(
            [tr('Début des règles'), tr('Durée des règles'), tr('Durée du cycle')],
            [
              for (var i = insights.periodStarts.length - 1; i >= 0 && i >= insights.periodStarts.length - 12; i--)
                [
                  Dates.long(insights.periodStarts[i]),
                  '${insights.periodLengths[i]} ${tr('j')}',
                  i + 1 < insights.periodStarts.length
                      ? '${Dates.diffInDays(insights.periodStarts[i + 1], insights.periodStarts[i])} ${tr('j')}'
                      : tr('en cours'),
                ],
            ],
          ),
          pw.SizedBox(height: 14),
        ],

        if (insights.symptomCounts.isNotEmpty) ...[
          _h(tr('Symptômes les plus fréquents')),
          _table([tr('Symptôme'), tr('Nombre de jours')], [
            for (final e in insights.symptomCounts.take(10)) [sym(e.key), '${e.value}'],
          ]),
          pw.SizedBox(height: 14),
        ],

        if (insights.temperatures.isNotEmpty) ...[
          _h(tr('Température basale (°C)')),
          pw.Wrap(spacing: 6, runSpacing: 4, children: [
            for (final t in insights.temperatures.reversed.take(60))
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                decoration: pw.BoxDecoration(color: _soft, borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Text('${Dates.short(t.key)} : ${t.value.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
              ),
          ]),
          pw.SizedBox(height: 14),
        ],

        _h(tr('Journal des $days derniers jours')),
        if (recent.isEmpty)
          pw.Text(tr('Aucune entrée sur cette période.'), style: const pw.TextStyle(fontSize: 10, color: _muted))
        else
          _table(
            [tr('Date'), tr('Flux'), tr('Humeur'), tr('Symptômes'), '°C', if (includeNotes) tr('Notes')],
            [
              for (final e in recent)
                [
                  Dates.short(Dates.parseIso(e.key)!),
                  flowLabel(e.value.flow),
                  tr(Mood.of(e.value.mood).label),
                  e.value.symptoms.map(sym).join(', '),
                  e.value.temperature,
                  if (includeNotes) e.value.notes,
                ],
            ],
            small: true,
          ),
      ],
    ));
    return doc.save();
  }

  static pw.Widget _h(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(t, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _pink)),
      );

  static pw.Widget _kv(List<List<String>> rows) => pw.Table(
        columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(3)},
        children: [
          for (final r in rows)
            pw.TableRow(children: [
              pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 3), child: pw.Text(r[0], style: const pw.TextStyle(fontSize: 10, color: _muted))),
              pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 3), child: pw.Text(r[1], style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
            ]),
        ],
      );

  static pw.Widget _table(List<String> header, List<List<String>> rows, {bool small = false}) => pw.TableHelper.fromTextArray(
        headers: header,
        data: rows,
        headerStyle: pw.TextStyle(fontSize: small ? 8.5 : 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: _pink),
        cellStyle: pw.TextStyle(fontSize: small ? 8 : 9.5),
        oddRowDecoration: const pw.BoxDecoration(color: _soft),
        cellAlignment: pw.Alignment.centerLeft,
        border: null,
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      );
}
