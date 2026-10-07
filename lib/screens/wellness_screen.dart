import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/content.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../l10n/l10n.dart';

/// Conseils naturels, seed cycling et questions fréquentes.
class WellnessScreen extends StatelessWidget {
  const WellnessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
      children: [
        const _TipOfDay(),
        const SizedBox(height: 16),
        const SectionTitle('Bien-être & santé féminine',
            icon: Icons.volunteer_activism_outlined,
            subtitle: 'Conseils naturels, tisanes et rituels pour vivre chaque phase en harmonie.'),
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _cardTitle(Icons.emoji_food_beverage_outlined, "L'herboristerie du cycle"),
            const T('Les plantes traditionnelles alliées de votre équilibre hormonal :', style: TextStyle(fontSize: 13.5)),
            const SizedBox(height: 8),
            _item(Icons.local_florist, LagoColors.pink, 'Feuilles de framboisier',
                'Tonique utérin remarquable, apaise les crampes menstruelles.'),
            _item(Icons.wb_sunny_outlined, LagoColors.gold, 'Camomille & mélisse',
                'Détendent le système nerveux et soulagent les tensions du SPM.'),
            _item(Icons.eco_outlined, LagoColors.green, 'Achillée millefeuille', 'Régulatrice du flux et antispasmodique naturel.'),
            _item(Icons.auto_awesome, LagoColors.orange, 'Gingembre doux',
                "Réduit l'inflammation et favorise une bonne circulation pelvienne."),
          ]),
        ),
        const SizedBox(height: 14),
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _cardTitle(Icons.grass, 'Le seed cycling (graines du cycle)'),
            const T('Une méthode douce pour soutenir naturellement vos hormones :', style: TextStyle(fontSize: 13.5)),
            const SizedBox(height: 8),
            _item(Icons.check_circle_outline, LagoColors.green, 'Jours 1 à 14 (phase folliculaire)',
                '1 c. à soupe de graines de lin moulues + graines de courge (soutien des œstrogènes).'),
            _item(Icons.check_circle_outline, LagoColors.gold, 'Jours 15 à 28 (phase lutéale)',
                '1 c. à soupe de graines de sésame + graines de tournesol (soutien de la progestérone).'),
          ]),
        ),
        const SizedBox(height: 20),
        const SectionTitle('Questions fréquentes & repères', icon: Icons.help_outline),
        _faq(context, "Quelle est la durée normale d'un cycle menstruel ?",
            "Un cycle régulier dure généralement entre 21 et 35 jours (moyenne : 28 jours). Une variation de quelques jours d'un mois à l'autre est naturelle et peut être influencée par le stress, les cours, les voyages ou le sommeil."),
        _faq(context, 'Comment repérer sa fenêtre de fertilité ?',
            "La fenêtre fertile s'étend sur environ 6 jours (les 5 jours précédant l'ovulation et le jour de celle-ci). Les signes corporels incluent une glaire cervicale fluide et transparente (aspect blanc d'œuf)."),
        _faq(context, 'Quand consulter un professionnel de santé ?',
            "Consultez une sage-femme, un gynécologue ou votre médecin en cas de douleurs très intenses non soulagées par les antalgiques usuels, de saignements inhabituels entre les règles, ou d'absence de règles prolongée."),
      ],
    );
  }

  Widget _cardTitle(IconData icon, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, color: const Color(0xFFC2185B)),
          const SizedBox(width: 8),
          Expanded(
            child: T(title,
                style: const TextStyle(fontFamily: LagoTheme.serif, fontSize: 21, fontWeight: FontWeight.w700, color: Color(0xFFC2185B))),
          ),
        ]),
      );

  Widget _item(IconData icon, Color color, String title, String text) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 17, color: color)),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: tr('$title : '), style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: tr(text)),
            ]), style: const TextStyle(fontSize: 13.5, height: 1.4)),
          ),
        ]),
      );

  Widget _faq(BuildContext context, String q, String a) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GlassCard(
          padding: EdgeInsets.zero,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              shape: const Border(),
              iconColor: LagoColors.pink,
              title: T(q, style: const TextStyle(fontWeight: FontWeight.w700, color: LagoColors.pink, fontSize: 14.5)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [T(a, style: const TextStyle(fontSize: 13.5, height: 1.45))],
            ),
          ),
        ),
      );
}

/// Conseil santé intime du jour + bibliothèque des conseils (adaptés à l'âge).
class _TipOfDay extends StatelessWidget {
  const _TipOfDay();

  @override
  Widget build(BuildContext context) {
    final age = AppState.instance.user?.age;
    final tip = LagoContent.tipOfDay(DateTime.now(), age);
    final cat = LagoContent.tipCategories[tip.category] ?? 'Conseil';
    return GlassCard(
      gradient: const LinearGradient(
        colors: [Color(0xFFFCE4EC), Color(0xFFF3E5F5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const T('💡', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          const Expanded(
            child: T('Conseil santé intime du jour',
                style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFC2185B), fontSize: 15)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
            child: T(cat, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: LagoColors.purple)),
          ),
        ]),
        const SizedBox(height: 10),
        T(tip.title, style: const TextStyle(fontFamily: LagoTheme.serif, fontSize: 21, fontWeight: FontWeight.w700, color: LagoColors.textDark)),
        const SizedBox(height: 6),
        T(tip.body, style: const TextStyle(fontSize: 14, height: 1.45, color: LagoColors.textDark)),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TipsLibraryScreen(age: age))),
            icon: const Icon(Icons.library_books_outlined),
            label: const T('Tous les conseils'),
          ),
        ),
      ]),
    );
  }
}

class TipsLibraryScreen extends StatelessWidget {
  final int? age;
  const TipsLibraryScreen({super.key, this.age});

  @override
  Widget build(BuildContext context) {
    final tips = LagoContent.tipsFor(age);
    final byCat = <String, List<Tip>>{};
    for (final t in tips) {
      byCat.putIfAbsent(t.category, () => []).add(t);
    }
    return Scaffold(
      appBar: AppBar(title: const T('Santé intime & relations')),
      body: LagoBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
          children: [
            T(
              (age ?? 0) >= 18
                  ? 'Des informations fiables sur la sexualité, la contraception et la santé intime.'
                  : 'Des informations adaptées à votre âge sur votre corps, le consentement et les relations.',
              style: TextStyle(color: mutedColor(context)),
            ),
            const SizedBox(height: 12),
            for (final e in byCat.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 6),
                child: T(LagoContent.tipCategories[e.key] ?? e.key, style: Theme.of(context).textTheme.titleLarge),
              ),
              for (final t in e.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    padding: EdgeInsets.zero,
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        shape: const Border(),
                        title: T(t.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        expandedAlignment: Alignment.centerLeft,
                        children: [T(t.body, style: const TextStyle(fontSize: 13.5, height: 1.45))],
                      ),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            T(
              'En cas de question ou d’inquiétude, un médecin, une sage-femme, une infirmière scolaire ou un centre de santé sexuelle peut vous répondre en toute confidentialité.',
              style: TextStyle(fontSize: 12.5, color: mutedColor(context)),
            ),
          ],
        ),
      ),
    );
  }
}
