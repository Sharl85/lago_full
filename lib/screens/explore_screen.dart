import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_state.dart';
import '../core/content_extra.dart';
import '../core/life_mode.dart';
import '../core/models.dart';
import '../core/premium.dart';
import '../core/utils.dart';
import '../l10n/l10n.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'assistant_screen.dart';
import 'community_screen.dart';
import 'life_mode_screen.dart';
import 'messaging_screen.dart';
import 'monthly_report_screen.dart';
import 'partners_screen.dart';
import 'premium_screen.dart';
import 'privacy_screen.dart';

/// v5 — « Plus de LaGo » : toutes les nouvelles fonctions au même endroit.
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  /// Résumé à partager (partenaire, mère, sœur…) — ne contient jamais les notes du journal.
  static String shareSummary(AppState s) {
    final c = s.cycle;
    final b = StringBuffer('🌸 ${tr('Mes prochaines dates (LaGo)')}\n');
    if (s.effective.isPregnant) {
      final p = PregnancyInfo.fromIso(s.effective.pregnancyStartDate);
      if (p != null) b.writeln(tr('Grossesse : ${p.weeks} SA, terme prévu le ${Dates.long(p.dueDate)}'));
      return b.toString();
    }
    final w = s.periodWindow;
    b.writeln(tr('Prochaines règles : ${w == null ? Dates.long(c.nextPeriodStart) : w.label}'));
    if (!Contraception.isHormonal(s.effective.contraception)) {
      b.writeln(tr('Fenêtre fertile estimée : ${Dates.short(c.fertileStart)} – ${Dates.short(c.fertileEnd)}'));
    }
    b.writeln(tr('Phase actuelle : ${c.phase.name}'));
    b.writeln(tr('(Estimations indicatives — LaGo n’est pas une méthode de contraception.)'));
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    void go(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    Widget tile(IconData icon, Color color, String title, String sub, VoidCallback onTap) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color),
          ),
          title: T(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: T(sub, style: const TextStyle(fontSize: 12.5)),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        );

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final s = state.settings;
        return Scaffold(
          appBar: AppBar(title: const T('Plus de LaGo')),
          body: LagoBackground(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
              children: [
                GlassCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const SectionTitle('Mon suivi', icon: Icons.favorite_outline),
                    tile(Icons.swap_horiz, LagoColors.pink, 'Mode de vie & contraception',
                        '${LifeMode.of(s.lifeMode).emoji} ${tr(LifeMode.of(s.lifeMode).label)} · ${tr(Contraception.of(s.contraception).label)}',
                        () => go(const LifeModeScreen())),
                    tile(Icons.calendar_view_month, LagoColors.purple, 'Bilan du mois', 'Règles, symptômes et humeurs du mois',
                        () => go(const MonthlyReportScreen())),
                    tile(Icons.share_outlined, LagoColors.teal, 'Partager mes dates', 'Avec un partenaire ou une proche, sans vos notes',
                        () => Share.share(shareSummary(state), subject: tr('Mes prochaines dates (LaGo)'))),
                  ]),
                ),
                const SizedBox(height: 14),
                GlassCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const SectionTitle('Questions & aide', icon: Icons.help_outline),
                    tile(Icons.chat_bubble_outline, LagoColors.pink, 'Assistante LaGo',
                        ServerFeatures.assistant ? 'Posez vos questions, réponse immédiate' : 'Réponses tirées des contenus validés (hors ligne)',
                        () => go(const AssistantScreen())),
                    tile(Icons.forum_outlined, LagoColors.purple, 'Communauté', 'Questions anonymes, réponses validées',
                        () => go(const CommunityScreen())),
                    tile(Icons.local_pharmacy_outlined, LagoColors.green, 'Partenaires santé', 'Pharmacies, centres de santé, téléconsultation',
                        () => go(const PartnersScreen())),
                  ]),
                ),
                const SizedBox(height: 14),
                GlassCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const SectionTitle('Guides', icon: Icons.menu_book_outlined),
                    for (final g in ExtraContent.guides)
                      tile(Icons.article_outlined, LagoColors.gold, '${g.emoji} ${g.title}', g.intro.length > 70 ? '${g.intro.substring(0, 70)}…' : g.intro,
                          () => go(GuideScreen(guide: g))),
                  ]),
                ),
                const SizedBox(height: 14),
                GlassCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const SectionTitle('Services', icon: Icons.miscellaneous_services_outlined),
                    tile(Icons.sms_outlined, LagoColors.teal, 'Rappels SMS & WhatsApp', 'Pour être prévenue même sans ouvrir l’app',
                        () => go(const MessagingScreen())),
                    tile(Icons.workspace_premium_outlined, LagoColors.goldDeep, 'LaGo Premium',
                        Premium.active ? 'Actif — merci de votre soutien 💛' : 'Soutenir LaGo par Mobile Money', () => go(const PremiumScreen())),
                    tile(Icons.verified_user_outlined, LagoColors.green, 'Vos données', 'Aucune pub, aucune revente : nos engagements',
                        () => go(const PrivacyScreen())),
                  ]),
                ),
                if (state.user?.isAdmin ?? false) ...[
                  const SizedBox(height: 14),
                  GlassCard(
                    child: tile(Icons.admin_panel_settings_outlined, LagoColors.goldDeep, 'Outils Super Admin',
                        'Modération, partenaires, statistiques ONG', () => go(const AdminToolsScreen())),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Affiche un guide (Ramadan, hygiène, mythes, contraception).
class GuideScreen extends StatelessWidget {
  final Guide guide;
  const GuideScreen({super.key, required this.guide});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: T(guide.title)),
      body: LagoBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
          children: [
            GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(guide.emoji, textAlign: TextAlign.center, style: const TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                T(guide.intro, style: const TextStyle(fontSize: 14.5, height: 1.4)),
                const SizedBox(height: 12),
                for (final p in guide.points)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Padding(padding: EdgeInsets.only(top: 3), child: Icon(Icons.check_circle_outline, size: 16, color: LagoColors.green)),
                      const SizedBox(width: 8),
                      Expanded(child: T(p, style: const TextStyle(fontSize: 13.5, height: 1.4))),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: 14),
            GlassCard(
              borderColor: LagoColors.gold.withValues(alpha: 0.4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.medical_services_outlined, color: LagoColors.gold),
                const SizedBox(width: 10),
                Expanded(child: T(guide.consult, style: const TextStyle(fontSize: 13.5, height: 1.4))),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
