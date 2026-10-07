import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';
import '../core/tracker.dart';
import '../core/utils.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/petals.dart';
import 'admin_screen.dart';
import 'auth_screen.dart';
import 'calendar_screen.dart';
import 'dashboard_screen.dart';
import 'family_screen.dart';
import 'journal_sheet.dart';
import 'phases_screen.dart';
import 'profile_screen.dart';
import 'wellness_screen.dart';
import '../l10n/l10n.dart';

/// Structure principale : barre du haut, onglets en bas, bouton « + ».
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  final state = AppState.instance;
  // L'onglet courant est gardé dans AppState : il survit au changement de langue.
  int get _index => state.lastTab;
  set _index(int v) => state.lastTab = v;

  static HomeShellState? of(BuildContext context) => context.findAncestorStateOfType<HomeShellState>();

  void goTo(int index) => setState(() => _index = index);

  // Toucher une notification ouvre l'onglet correspondant (journal, conseils…)
  void _onRequestedTab() {
    final t = state.requestedTab.value;
    if (t != null && mounted) {
      goTo(t);
      state.requestedTab.value = null;
    }
  }

  @override
  void initState() {
    super.initState();
    state.requestedTab.addListener(_onRequestedTab);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onRequestedTab());
  }

  @override
  void dispose() {
    state.requestedTab.removeListener(_onRequestedTab);
    super.dispose();
  }

  List<_Tab> _tabs() => state.isParent
      ? [
          // Compte parent : suivi des enfants, conseils, profil
          const _Tab('Mes enfants', Icons.family_restroom_outlined, Icons.family_restroom, FamilyScreen()),
          const _Tab('Bien-être', Icons.favorite_border, Icons.favorite, WellnessScreen()),
          const _Tab('Profil', Icons.tune_outlined, Icons.tune, ProfileScreen()),
          if (state.user?.isAdmin ?? false) const _Tab('Admin', Icons.admin_panel_settings_outlined, Icons.admin_panel_settings, AdminScreen()),
        ]
      : [
        const _Tab('Accueil', Icons.dashboard_outlined, Icons.dashboard, DashboardScreen()),
        const _Tab('Journal', Icons.calendar_month_outlined, Icons.calendar_month, CalendarScreen()),
        const _Tab('Phases', Icons.donut_large_outlined, Icons.donut_large, PhasesScreen()),
        const _Tab('Bien-être', Icons.favorite_border, Icons.favorite, WellnessScreen()),
        const _Tab('Profil', Icons.tune_outlined, Icons.tune, ProfileScreen()),
        if (state.user?.isAdmin ?? false) const _Tab('Admin', Icons.admin_panel_settings_outlined, Icons.admin_panel_settings, AdminScreen()),
      ];

  void _openJournalToday() => showJournalSheet(context, Dates.toIso(DateTime.now()));

  /// Mode discret instantané : verrouille (si PIN), sinon masque l'app.
  void _quickHide() {
    if (state.tracker.hasPin) {
      state.lock();
      return;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      SystemNavigator.pop();
      return;
    }
    Navigator.of(context).push(PageRouteBuilder(
      opaque: true,
      pageBuilder: (_, __, ___) => const _CoverScreen(),
      transitionDuration: Duration.zero,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final tabs = _tabs();
        if (_index >= tabs.length) _index = 0;
        final settings = state.settings;
        return PopScope(
          canPop: _index == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && _index != 0) setState(() => _index = 0);
          },
          child: Scaffold(
            appBar: AppBar(
              titleSpacing: 12,
              title: GestureDetector(
                onTap: () => goTo(0),
                child: Row(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/icon/logo.png', width: 36)),
                  const SizedBox(width: 8),
                  const T('LaGo 🌸',
                      style: TextStyle(fontFamily: LagoTheme.serif, fontWeight: FontWeight.w700, fontSize: 26, color: LagoColors.pink)),
                ]),
              ),
              actions: [
                IconButton(
                  tooltip: tr('Pluie de pétales'),
                  isSelected: settings.petalsEnabled,
                  icon: const Icon(Icons.local_florist_outlined),
                  selectedIcon: const Icon(Icons.local_florist, color: LagoColors.pink),
                  onPressed: () {
                    final on = !settings.petalsEnabled;
                    state.updateSettings(settings.copyWith(petalsEnabled: on));
                    showToast(context, on ? '🌸 Pluie de pétales activée' : 'Pétales désactivés');
                  },
                ),
                IconButton(
                  tooltip: tr('Mode nuit'),
                  icon: Icon(settings.darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                  onPressed: () {
                    final dark = !settings.darkMode;
                    state.updateSettings(settings.copyWith(darkMode: dark));
                    showToast(context, dark ? '🌙 Mode Nuit Rosé activé' : '☀️ Mode Jour Aurore activé');
                  },
                ),
                IconButton(tooltip: tr('Masquer rapidement'), icon: const Icon(Icons.lock_outline), onPressed: _quickHide),
                _ProfileMenu(onNavigate: goTo, adminIndex: tabs.length - 1, profileIndex: state.isParent ? 2 : 4),
                const SizedBox(width: 4),
              ],
            ),
            body: Stack(fit: StackFit.expand, children: [
              const Positioned.fill(child: LagoBackground(child: SizedBox.expand())),
              IndexedStack(index: _index, children: tabs.map((t) => t.screen).toList()),
              Positioned.fill(child: PetalsOverlay(enabled: settings.petalsEnabled)),
            ]),
            floatingActionButton: _index <= 1 && !state.isParent
                ? FloatingActionButton(
                    tooltip: tr('Noter mon jour'),
                    onPressed: _openJournalToday,
                    child: const Icon(Icons.add, size: 30),
                  )
                : null,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              height: 68,
              onDestinationSelected: goTo,
              destinations: tabs
                  .map((t) => NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selectedIcon, color: LagoColors.pink), label: tr(t.label)))
                  .toList(),
            ),
          ),
        );
      },
    );
  }
}

class _Tab {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget screen;
  const _Tab(this.label, this.icon, this.selectedIcon, this.screen);
}

/// Menu du compte (avatar en haut à droite).
class _ProfileMenu extends StatelessWidget {
  final void Function(int) onNavigate;
  final int adminIndex;
  final int profileIndex;
  const _ProfileMenu({required this.onNavigate, required this.adminIndex, required this.profileIndex});

  String _syncLabel(SyncState s) => switch (s) {
        SyncState.synced => '☁️ Données synchronisées',
        SyncState.syncing => '🔄 Synchronisation…',
        SyncState.offline => '📴 Hors-ligne — enregistré sur le téléphone',
        SyncState.error => '⚠️ Synchronisation en attente',
        SyncState.local => '📱 Mode local (sur ce téléphone)',
        SyncState.guest => '👤 Invitée — données sur ce téléphone',
      };

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final user = state.user;
    return PopupMenuButton<String>(
      tooltip: tr('Mon compte'),
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      onSelected: (v) async {
        switch (v) {
          case 'profile':
            onNavigate(profileIndex);
          case 'admin':
            onNavigate(adminIndex);
          case 'switch':
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
          case 'logout':
            await state.logout();
            if (context.mounted) showToast(context, 'Déconnexion réussie.');
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            T(user?.name ?? 'Invitée', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            T(user?.email ?? 'Non connectée', style: TextStyle(fontSize: 12, color: mutedColor(context))),
            if (user != null) T(user.isAdmin ? 'Super Admin 👑' : (user.age != null ? '${user.age} ans' : 'Membre'),
                style: const TextStyle(fontSize: 12, color: LagoColors.pink)),
            const SizedBox(height: 4),
            T(_syncLabel(state.syncState), style: TextStyle(fontSize: 11.5, color: mutedColor(context))),
          ]),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'profile', child: ListTile(leading: Icon(Icons.tune), title: T('Mon profil & sécurité'), dense: true)),
        if (user?.isAdmin ?? false)
          const PopupMenuItem(
              value: 'admin', child: ListTile(leading: Icon(Icons.admin_panel_settings, color: LagoColors.goldDeep), title: T('Espace Super Admin 👑'), dense: true)),
        PopupMenuItem(
            value: 'switch', child: ListTile(leading: const Icon(Icons.people_outline), title: T(user == null ? 'Se connecter' : 'Changer de compte'), dense: true)),
        if (user != null)
          const PopupMenuItem(
              value: 'logout', child: ListTile(leading: Icon(Icons.logout, color: LagoColors.danger), title: T('Se déconnecter', style: TextStyle(color: LagoColors.danger)), dense: true)),
      ],
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: UserAvatar(admin: user?.isAdmin ?? false, size: 34, avatar: user == null ? null : AppState.instance.avatar),
      ),
    );
  }
}

/// Écran neutre affiché par le bouton cadenas quand aucun PIN n'est défini (iOS).
class _CoverScreen extends StatelessWidget {
  const _CoverScreen();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: () => Navigator.of(context).pop(),
        child: const SafeArea(
          child: Center(child: T('Touchez deux fois pour revenir', style: TextStyle(color: Colors.black26))),
        ),
      ),
    );
  }
}
