import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_state.dart';
import 'core/storage.dart';
import 'l10n/l10n.dart';
import 'screens/auth_screen.dart';
import 'screens/cycle_setup_screen.dart';
import 'screens/home_shell.dart';
import 'screens/lock_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.init();
  L.init(); // langue choisie, ou langue du téléphone
  runApp(const LagoApp());
  AppState.instance.init();
}

class LagoApp extends StatefulWidget {
  const LagoApp({super.key});

  @override
  State<LagoApp> createState() => _LagoAppState();
}

class _LagoAppState extends State<LagoApp> with WidgetsBindingObserver {
  final state = AppState.instance;
  DateTime? _backgroundAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Verrouillage PIN au retour dans l'app après 30 s + synchronisation.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.paused || lifecycle == AppLifecycleState.hidden) {
      _backgroundAt ??= DateTime.now();
    } else if (lifecycle == AppLifecycleState.resumed) {
      final away = _backgroundAt;
      _backgroundAt = null;
      if (away != null && DateTime.now().difference(away).inSeconds > 30) state.lock();
      state.syncNow(pull: true);
    }
  }

  /// Le téléphone change de langue pendant que l'app est ouverte.
  @override
  void didChangeLocales(List<Locale>? locales) => state.onSystemLocaleChanged();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final dark = state.settings.darkMode;
        SystemChrome.setSystemUIOverlayStyle(dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark);
        return MaterialApp(
          // Nouvelle clé à chaque changement de langue : toute l'interface est reconstruite dans la bonne langue
          key: ValueKey('app_${L.lang}'),
          title: 'LaGo',
          debugShowCheckedModeBanner: false,
          theme: LagoTheme.build(Brightness.light),
          darkTheme: LagoTheme.build(Brightness.dark),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          locale: L.locale,
          supportedLocales: const [Locale('fr'), Locale('en'), Locale('es'), Locale('pt'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: _gate(),
        );
      },
    );
  }

  Widget _gate() {
    if (!state.ready) return const _Splash();
    if (state.locked) return const LockScreen();
    if (state.user == null) return const AuthScreen(standalone: true);
    if (state.loadingAccount) return const _Splash();
    if (state.needsCycleSetup) return const CycleSetupScreen();
    return const HomeShell();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(borderRadius: BorderRadius.circular(28), child: Image.asset('assets/icon/logo.png', width: 110)),
          const SizedBox(height: 18),
          const CircularProgressIndicator(color: LagoColors.pink),
        ]),
      ),
    );
  }
}
