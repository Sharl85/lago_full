import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/premium.dart';
import '../core/storage.dart';
import '../l10n/l10n.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'community_screen.dart';

const partnerTypes = {
  'pharmacy': ('Pharmacie', Icons.local_pharmacy_outlined),
  'teleconsultation': ('Téléconsultation', Icons.video_call_outlined),
  'clinic': ('Centre de santé', Icons.local_hospital_outlined),
  'ngo': ('Association / ONG', Icons.volunteer_activism_outlined),
  'other': ('Autre', Icons.storefront_outlined),
};

/// v5 — Partenaires : pharmacies (codes promo), centres de santé, téléconsultation, ONG.
class PartnersScreen extends StatefulWidget {
  const PartnersScreen({super.key});

  @override
  State<PartnersScreen> createState() => _PartnersScreenState();
}

class _PartnersScreenState extends State<PartnersScreen> {
  static const _cacheKey = 'lago_partners_cache';
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _items = Store.readList(_cacheKey).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    _load();
  }

  Future<void> _load() async {
    final r = await Api.partners();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok && r.data?['partners'] is List) {
        _items = (r.data!['partners'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        Store.writeJson(_cacheKey, _items);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const T('Partenaires santé')),
      body: LagoBackground(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
            children: [
              if (_loading && _items.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
              if (!_loading && _items.isEmpty)
                GlassCard(
                  child: T(
                      Api.enabled
                          ? 'Aucun partenaire pour l’instant dans votre région.'
                          : 'Les partenaires s’affichent quand l’application est connectée au serveur LaGo.',
                      style: TextStyle(color: mutedColor(context))),
                ),
              for (final p in _items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Icon((partnerTypes[p['type']] ?? partnerTypes['other']!).$2, color: LagoColors.pink),
                        const SizedBox(width: 8),
                        Expanded(child: Text('${p['name']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                      ]),
                      const SizedBox(height: 2),
                      T('${(partnerTypes[p['type']] ?? partnerTypes['other']!).$1}${'${p['city'] ?? ''}'.isEmpty ? '' : ' · ${p['city']}'}',
                          style: TextStyle(fontSize: 12, color: mutedColor(context))),
                      if ('${p['description'] ?? ''}'.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('${p['description']}', style: const TextStyle(fontSize: 13.5)),
                      ],
                      if ('${p['promoCode'] ?? ''}'.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: LagoColors.pinkLight, borderRadius: BorderRadius.circular(10)),
                          child: Text('🎁 ${tr('Code promo')} : ${p['promoCode']}',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: LagoColors.textDark)),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(spacing: 8, children: [
                        if ('${p['phone'] ?? ''}'.isNotEmpty)
                          TextButton.icon(
                            onPressed: () => openExternal('tel:${p['phone']}'),
                            icon: const Icon(Icons.call_outlined),
                            label: const T('Appeler'),
                          ),
                        if ('${p['whatsapp'] ?? ''}'.isNotEmpty)
                          TextButton.icon(
                            onPressed: () => openExternal('https://wa.me/${'${p['whatsapp']}'.replaceAll(RegExp(r'[^0-9]'), '')}'),
                            icon: const Icon(Icons.chat_outlined),
                            label: const T('WhatsApp'),
                          ),
                        if ('${p['url'] ?? ''}'.startsWith('https://'))
                          TextButton.icon(
                            onPressed: () => openExternal('${p['url']}'),
                            icon: const Icon(Icons.open_in_new),
                            label: const T('Site web'),
                          ),
                      ]),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// v5 — Outils Super Admin : partenaires, modération, statistiques anonymisées pour les ONG.
class AdminToolsScreen extends StatefulWidget {
  const AdminToolsScreen({super.key});

  @override
  State<AdminToolsScreen> createState() => _AdminToolsScreenState();
}

class _AdminToolsScreenState extends State<AdminToolsScreen> {
  Map<String, dynamic>? _aggregate;
  List<Map<String, dynamic>> _partners = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await Api.adminAggregate();
    final p = await Api.partners();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (a.ok && a.data?['aggregate'] is Map) _aggregate = Map<String, dynamic>.from(a.data!['aggregate'] as Map);
      if (p.ok && p.data?['partners'] is List) {
        _partners = (p.data!['partners'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    });
  }

  Future<void> _editPartner([Map<String, dynamic>? existing]) async {
    final fields = ['name', 'description', 'city', 'phone', 'whatsapp', 'url', 'promoCode'];
    final labels = {
      'name': 'Nom *',
      'description': 'Description',
      'city': 'Ville',
      'phone': 'Téléphone',
      'whatsapp': 'WhatsApp (+237…)',
      'url': 'Site web (https://…)',
      'promoCode': 'Code promo',
    };
    final ctrls = {for (final f in fields) f: TextEditingController(text: '${existing?[f] ?? ''}')};
    var type = '${existing?['type'] ?? 'pharmacy'}';
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: T(existing == null ? 'Nouveau partenaire' : 'Modifier le partenaire'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: partnerTypes.containsKey(type) ? type : 'other',
                items: partnerTypes.entries.map((e) => DropdownMenuItem(value: e.key, child: T(e.value.$1))).toList(),
                onChanged: (v) => setD(() => type = v ?? 'other'),
              ),
              for (final f in fields) TextField(controller: ctrls[f], decoration: InputDecoration(labelText: tr(labels[f]!))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const T('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const T('Enregistrer')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final body = <String, dynamic>{
      if (existing?['id'] != null) 'id': existing!['id'],
      'type': type,
      for (final f in fields) f: ctrls[f]!.text.trim(),
    };
    final r = await Api.adminSavePartner(body);
    if (!mounted) return;
    showToast(context, r.ok ? 'Partenaire enregistré.' : r.message('Enregistrement impossible.'), type: r.ok ? ToastType.success : ToastType.error);
    _load();
  }

  Future<void> _deletePartner(Map<String, dynamic> p) async {
    final ok = await confirmDialog(context, 'Supprimer ${p['name']} ?', danger: true, okLabel: 'Supprimer');
    if (!ok) return;
    await Api.adminDeletePartner('${p['id']}');
    _load();
  }

  Widget _kv(String k, Object? v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [Expanded(child: T(k)), Text('${v ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w700))]),
      );

  @override
  Widget build(BuildContext context) {
    final a = _aggregate;
    Map<String, dynamic> sub(String k) => a?[k] is Map ? Map<String, dynamic>.from(a![k] as Map) : const {};
    return Scaffold(
      appBar: AppBar(title: const T('Outils Super Admin')),
      body: LagoBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
                children: [
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.forum_outlined, color: LagoColors.pink),
                      title: const T('Modérer la communauté', style: TextStyle(fontWeight: FontWeight.w700)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CommunityModerationScreen())),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GlassCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      SectionTitle('Partenaires', icon: Icons.storefront_outlined,
                          trailing: IconButton(onPressed: () => _editPartner(), icon: const Icon(Icons.add_circle_outline))),
                      if (_partners.isEmpty) const T('Aucun partenaire.'),
                      for (final p in _partners)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon((partnerTypes[p['type']] ?? partnerTypes['other']!).$2),
                          title: Text('${p['name']}'),
                          subtitle: Text('${p['city'] ?? ''}'),
                          onTap: () => _editPartner(p),
                          trailing: IconButton(icon: const Icon(Icons.delete_outline, color: LagoColors.danger), onPressed: () => _deletePartner(p)),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  GlassCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const SectionTitle('Statistiques anonymisées (ONG)', icon: Icons.bar_chart,
                          subtitle: 'Groupes de moins de 10 personnes masqués. Aucune donnée personnelle.'),
                      if (a == null)
                        const T('Indisponible (serveur requis).')
                      else ...[
                        _kv('Utilisatrices', a['totalUsers']),
                        _kv('Journaux actifs', a['activeJournals']),
                        _kv('Durée moyenne du cycle', a['averageCycleLength']),
                        _kv('Durée moyenne des règles', a['averagePeriodLength']),
                        const Divider(),
                        for (final e in sub('ageBands').entries) _kv('Âge ${e.key}', e.value),
                        const Divider(),
                        for (final e in sub('lifeModes').entries) _kv('Mode ${e.key}', e.value),
                        const Divider(),
                        for (final e in sub('symptomsReported').entries) _kv('Symptôme ${e.key}', e.value),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(a)));
                            if (context.mounted) showToast(context, 'Statistiques copiées (JSON).');
                          },
                          icon: const Icon(Icons.copy),
                          label: const T('Copier pour un rapport'),
                        ),
                      ],
                    ]),
                  ),
                ],
              ),
      ),
    );
  }
}
