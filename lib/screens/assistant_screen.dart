import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../core/content_extra.dart';
import '../core/premium.dart';
import '../l10n/l10n.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'community_screen.dart';

class _Msg {
  final bool fromUser;
  final String text;
  final bool offline;
  const _Msg(this.fromUser, this.text, {this.offline = false});
}

/// v5 — Assistant de questions-réponses.
/// Hors ligne : réponses tirées des contenus validés de LaGo.
/// En ligne (si activé sur le serveur) : réponse rédigée, encadrée par des consignes de prudence.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final state = AppState.instance;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_Msg>[
    const _Msg(false, 'Bonjour 🌸 Posez-moi vos questions sur les règles, le cycle, la contraception ou le bien-être. Je ne remplace pas un professionnel de santé.'),
  ];
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _offlineAnswer(String q) {
    final hits = ExtraContent.search(q);
    if (hits.isEmpty) {
      return 'Je n’ai pas trouvé de réponse dans les contenus de LaGo. Vous pouvez poser votre question anonymement à la Communauté, ou en parler à un professionnel de santé.';
    }
    final first = hits.first;
    final others = hits.skip(1).map((f) => '• ${tr(f.question)}').join('\n');
    return '${tr(first.question)}\n\n${tr(first.answer)}${others.isEmpty ? '' : '\n\n${tr('Voir aussi :')}\n$others'}';
  }

  Future<void> _send() async {
    final q = _input.text.trim();
    if (q.length < 3 || _busy) return;
    _input.clear();
    setState(() {
      _messages.add(_Msg(true, q));
      _busy = true;
    });
    _scrollDown();

    String? answer;
    var offline = true;
    final canOnline = ServerFeatures.assistant && (state.user?.isServer ?? false) && Premium.allows('assistant');
    if (canOnline) {
      final r = await Api.assistant(q);
      if (r.ok && r.data?['answer'] is String) {
        answer = r.data!['answer'] as String;
        offline = false;
      }
    }
    answer ??= _offlineAnswer(q);
    if (!mounted) return;
    setState(() {
      _messages.add(_Msg(false, answer!, offline: offline));
      _busy = false;
    });
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return Scaffold(
      appBar: AppBar(
        title: const T('Assistante LaGo'),
        actions: [
          IconButton(
            tooltip: tr('Communauté'),
            icon: const Icon(Icons.forum_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CommunityScreen())),
          ),
        ],
      ),
      body: LagoBackground(
        child: Column(children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              itemCount: _messages.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final f in ExtraContent.faqs.take(4))
                        ActionChip(
                          label: T(f.question, style: const TextStyle(fontSize: 12)),
                          onPressed: () {
                            _input.text = tr(f.question);
                            _send();
                          },
                        ),
                    ]),
                  );
                }
                final m = _messages[i - 1];
                return Align(
                  alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: m.fromUser ? LagoColors.pink : (dark ? LagoColors.cardDark : Colors.white),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Les réponses en ligne sont déjà dans la langue de la question : pas de traduction automatique
                      m.fromUser || !m.offline
                          ? Text(m.text, style: TextStyle(color: m.fromUser ? Colors.white : null, height: 1.35))
                          : T(m.text, style: const TextStyle(height: 1.35)),
                      if (!m.fromUser && i > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: T(m.offline ? 'Réponse tirée des contenus validés de LaGo' : 'Réponse générée — en cas de doute, consultez',
                              style: TextStyle(fontSize: 10.5, color: mutedColor(context))),
                        ),
                    ]),
                  ),
                );
              },
            ),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 800,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(hintText: tr('Votre question…'), counterText: ''),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: _busy ? null : _send, icon: const Icon(Icons.send)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
