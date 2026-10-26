import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../core/storage.dart';
import '../core/utils.dart';
import '../l10n/l10n.dart';
import '../theme.dart';
import '../widgets/common.dart';

const _topics = {
  'cycle': 'Cycle & règles',
  'sexualite': 'Sexualité',
  'contraception': 'Contraception',
  'grossesse': 'Grossesse',
  'bienetre': 'Bien-être',
  'autre': 'Autre',
};

/// v5 — Communauté : questions anonymes, publiées après relecture par l'équipe LaGo.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  static const _cacheKey = 'lago_community_cache';
  final state = AppState.instance;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _offline = false;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _items = Store.readList(_cacheKey).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    _load();
  }

  Future<void> _load() async {
    final r = await Api.communityList();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _offline = !r.ok;
      if (r.ok && r.data?['questions'] is List) {
        _items = (r.data!['questions'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        Store.writeJson(_cacheKey, _items);
      }
    });
  }

  Future<void> _ask() async {
    final ctrl = TextEditingController();
    var topic = 'cycle';
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            T('Poser une question anonyme', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 6),
            T('Votre nom n’apparaît jamais. La question est relue avant publication, et une réponse validée est ajoutée.',
                style: TextStyle(fontSize: 12.5, color: mutedColor(ctx))),
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in _topics.entries)
                ChoiceChip(label: T(e.value), selected: topic == e.key, onSelected: (_) => setSheet(() => topic = e.key)),
            ]),
            const SizedBox(height: 10),
            TextField(controller: ctrl, maxLines: 4, maxLength: 600, decoration: InputDecoration(hintText: tr('Votre question…'))),
            FilledButton.icon(
              onPressed: () async {
                final r = await Api.communityAsk(ctrl.text.trim(), topic);
                if (!ctx.mounted) return;
                if (r.ok) {
                  Navigator.pop(ctx, true);
                } else {
                  showToast(ctx, r.offline ? 'Connexion impossible.' : r.message('Envoi impossible.'), type: ToastType.error);
                }
              },
              icon: const Icon(Icons.send),
              label: const T('Envoyer anonymement'),
            ),
          ]),
        ),
      ),
    );
    // (le contrôleur n'est pas libéré ici : la feuille termine encore son animation de fermeture)
    if (sent == true && mounted) showToast(context, 'Merci ! Votre question sera publiée anonymement après relecture.');
  }

  @override
  Widget build(BuildContext context) {
    final serverUser = state.user?.isServer ?? false;
    final items = _filter.isEmpty ? _items : _items.where((q) => q['topic'] == _filter).toList();
    return Scaffold(
      appBar: AppBar(title: const T('Communauté')),
      floatingActionButton: serverUser
          ? FloatingActionButton.extended(onPressed: _ask, icon: const Icon(Icons.edit), label: const T('Poser une question'))
          : null,
      body: LagoBackground(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
            children: [
              if (!serverUser)
                GlassCard(
                    child: T('La communauté nécessite un compte synchronisé avec le serveur LaGo.',
                        style: TextStyle(color: mutedColor(context))))
              else ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(label: const T('Tout'), selected: _filter.isEmpty, onSelected: (_) => setState(() => _filter = '')),
                    ),
                    for (final e in _topics.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(label: T(e.value), selected: _filter == e.key, onSelected: (_) => setState(() => _filter = e.key)),
                      ),
                  ]),
                ),
                const SizedBox(height: 10),
                if (_loading && _items.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
                if (_offline)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: T('📴 Hors ligne : affichage des dernières questions enregistrées.', style: TextStyle(fontSize: 12, color: mutedColor(context))),
                  ),
                if (!_loading && items.isEmpty)
                  GlassCard(child: T('Aucune question publiée pour l’instant. Soyez la première !', style: TextStyle(color: mutedColor(context)))),
                for (final q in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        T(_topics[q['topic']] ?? 'Autre', style: const TextStyle(fontSize: 11.5, color: LagoColors.pink, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('❓ ${q['question'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        if ('${q['answer'] ?? ''}'.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('💬 ${q['answer']}', style: const TextStyle(fontSize: 13.5, height: 1.35)),
                          const SizedBox(height: 4),
                          T('Réponse validée par l’équipe LaGo', style: TextStyle(fontSize: 10.5, color: mutedColor(context))),
                        ],
                      ]),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// v5 — Modération des questions (Super Admin).
class CommunityModerationScreen extends StatefulWidget {
  const CommunityModerationScreen({super.key});

  @override
  State<CommunityModerationScreen> createState() => _CommunityModerationScreenState();
}

class _CommunityModerationScreenState extends State<CommunityModerationScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await Api.adminCommunity();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok && r.data?['questions'] is List) {
        _items = (r.data!['questions'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    });
  }

  Future<void> _moderate(Map<String, dynamic> q, String action) async {
    String? answer;
    if (action == 'approve') {
      final ctrl = TextEditingController(text: '${q['answer'] ?? ''}');
      answer = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const T('Publier avec une réponse'),
          content: TextField(controller: ctrl, maxLines: 6, maxLength: 2000, decoration: InputDecoration(hintText: tr('Réponse validée (recommandé)'))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const T('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const T('Publier')),
          ],
        ),
      );
      if (answer == null) return;
    }
    final r = await Api.adminModerate('${q['id']}', action, answer: answer);
    if (!mounted) return;
    showToast(context, r.ok ? 'Enregistré.' : r.message('Action impossible.'), type: r.ok ? ToastType.success : ToastType.error);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const T('Modération de la communauté')),
      body: LagoBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
                  children: [
                    if (_items.isEmpty) const GlassCard(child: T('Aucune question.')),
                    for (final q in _items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GlassCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            T('${_topics[q['topic']] ?? 'Autre'} · ${q['status']} · ${Dates.dateTime(DateTime.tryParse('${q['createdAt']}')?.toLocal() ?? DateTime.now())}',
                                style: TextStyle(fontSize: 11.5, color: mutedColor(context))),
                            const SizedBox(height: 4),
                            Text('${q['question']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            if ('${q['answer'] ?? ''}'.isNotEmpty) Text('💬 ${q['answer']}', style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 6),
                            Wrap(spacing: 8, children: [
                              FilledButton.tonal(onPressed: () => _moderate(q, 'approve'), child: const T('Publier')),
                              OutlinedButton(onPressed: () => _moderate(q, 'reject'), child: const T('Refuser')),
                              TextButton(
                                style: TextButton.styleFrom(foregroundColor: LagoColors.danger),
                                onPressed: () => _moderate(q, 'delete'),
                                child: const T('Supprimer'),
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
