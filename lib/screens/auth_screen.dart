import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/auth_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/profile_widgets.dart';
import 'register_screen.dart';
import '../l10n/l10n.dart';

/// Connexion / Inscription / Accès démo 1-clic.
/// [standalone] = écran d'accueil (sinon ouvert depuis le menu « Changer de compte »).
class AuthScreen extends StatefulWidget {
  final bool standalone;
  const AuthScreen({super.key, this.standalone = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final state = AppState.instance;
  bool _busy = false;
  String? _error;

  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();

  @override
  void dispose() {
    for (final c in [_loginEmail, _loginPassword]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<AuthResult> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!res.success) {
      setState(() => _error = res.message);
      return;
    }
    final user = res.user!;
    showToast(
      context,
      res.offline
          ? 'Bienvenue ${user.name} — serveur injoignable, mode local sur ce téléphone.'
          : (user.isAdmin ? '👑 Bienvenue Super Admin (${user.name}) !' : '🌸 Bienvenue sur LaGo, ${user.name} !'),
      type: res.offline ? ToastType.info : ToastType.success,
    );
    final navigator = Navigator.of(context);
    final shouldPop = !widget.standalone && navigator.canPop();
    await state.afterLogin();
    if (shouldPop) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final muted = mutedColor(context);
    return Scaffold(
      appBar: widget.standalone ? null : AppBar(title: const T('Mon compte')),
      body: LagoBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.asset('assets/icon/logo.png', width: 84))),
                    const SizedBox(height: 12),
                    T('Bienvenue sur LaGo', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
                    T('Votre espace de suivi intime & bienveillant', textAlign: TextAlign.center, style: TextStyle(color: muted)),
                    const Center(child: LanguageSelector(compact: true)),
                    const SizedBox(height: 8),
                    GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const T('Connexion', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          T('Connectez-vous pour accéder à votre suivi.', style: TextStyle(fontSize: 13, color: muted)),
                          const SizedBox(height: 16),
                          if (_error != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: LagoColors.danger.withValues(alpha: 0.3)),
                              ),
                              child: T(_error!, style: const TextStyle(color: Color(0xFFB71C1C), fontWeight: FontWeight.w600)),
                            ),
                          ..._loginForm(),
                          const SizedBox(height: 18),
                          Row(children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: T('Pas encore de compte ?', style: TextStyle(fontSize: 12.5, color: muted)),
                            ),
                            const Expanded(child: Divider()),
                          ]),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                            icon: const Icon(Icons.person_add_alt),
                            label: const T('Créer mon compte LaGo'),
                          ),
                        ],
                      ),
                    ),
                    if (AuthService.demoMode) ...[
                      const SizedBox(height: 16),
                      _demoBox(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _loginForm() => [
        TextField(
          controller: _loginEmail,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(labelText: tr('Adresse email'), prefixIcon: Icon(Icons.mail_outline)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _loginPassword,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(labelText: tr('Mot de passe'), prefixIcon: Icon(Icons.lock_outline)),
          onSubmitted: (_) => _submitLogin(),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _busy ? null : _submitLogin,
          icon: _busy ? const _Spinner() : const Icon(Icons.login),
          label: const T('Se connecter'),
        ),
      ];

  void _submitLogin() => _run(() => state.auth.login(_loginEmail.text, _loginPassword.text));

  Widget _demoBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: LagoColors.pinkLight.withValues(alpha: isDark(context) ? 0.12 : 0.8),
        border: Border.all(color: LagoColors.pink, style: BorderStyle.solid, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(children: [
            Icon(Icons.bolt, color: LagoColors.pink, size: 16),
            SizedBox(width: 4),
            T('Accès rapide démo (1 clic)', style: TextStyle(color: LagoColors.pink, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          _demoButton('👧', 'Utilisatrice (Sarah)', 'sarah@lago.app', 'user123'),
          const SizedBox(height: 8),
          _demoButton('👑', 'Super Admin', 'admin@lago.app', 'admin123'),
        ],
      ),
    );
  }

  Widget _demoButton(String emoji, String label, String email, String password) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      onPressed: _busy ? null : () => _run(() => state.auth.login(email, password)),
      child: Row(children: [
        T(emoji),
        const SizedBox(width: 8),
        Expanded(child: T('Compte $label', style: const TextStyle(fontWeight: FontWeight.w600))),
        T(email, style: TextStyle(fontSize: 11, color: mutedColor(context))),
      ]),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));
}
