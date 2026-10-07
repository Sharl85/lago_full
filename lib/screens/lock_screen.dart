import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../l10n/l10n.dart';

/// Écran de verrouillage par code PIN (stocké uniquement sur le téléphone).
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  String? _error;

  void _press(String k) {
    HapticFeedback.selectionClick();
    setState(() {
      _error = null;
      if (k == 'del') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else if (_pin.length < 6) {
        _pin += k;
      }
    });
    if (_pin.length >= 4 && k != 'del') _try(silent: _pin.length < 6);
  }

  void _try({bool silent = false}) {
    if (AppState.instance.unlock(_pin)) return;
    if (!silent) {
      HapticFeedback.heavyImpact();
      setState(() {
        _pin = '';
        _error = 'Code incorrect, réessayez.';
      });
    }
  }

  Future<void> _forgot() async {
    final ok = await confirmDialog(context,
        'Le code PIN sera supprimé et vous devrez vous reconnecter avec le mot de passe de votre compte.',
        okLabel: 'Continuer');
    if (ok) await AppState.instance.forgotPin();
  }

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'ok', '0', 'del'];
    return Scaffold(
      body: LagoBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LagoColors.lotusGradient),
                    child: const T('🌸', style: TextStyle(fontSize: 36)),
                  ),
                  const SizedBox(height: 14),
                  T('LaGo est verrouillée', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  T('Entrez votre code PIN pour accéder à votre journal.',
                      textAlign: TextAlign.center, style: TextStyle(color: mutedColor(context))),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(6, (i) {
                      final filled = i < _pin.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled ? LagoColors.pink : Colors.transparent,
                          border: Border.all(color: LagoColors.pink, width: 1.5),
                        ),
                      );
                    }),
                  ),
                  SizedBox(
                    height: 30,
                    child: Center(
                      child: T(_error ?? '', style: const TextStyle(color: LagoColors.danger, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      children: keys.map((k) {
                        final label = k == 'del' ? '⌫' : (k == 'ok' ? 'OK' : k);
                        return Material(
                          color: isDark(context) ? LagoColors.cardDark : Colors.white,
                          shape: CircleBorder(side: BorderSide(color: LagoColors.pinkSoft.withValues(alpha: 0.35))),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => k == 'ok' ? _try() : _press(k),
                            child: Center(
                              child: T(label,
                                  style: TextStyle(
                                    fontSize: k == 'ok' ? 16 : 24,
                                    fontWeight: FontWeight.w600,
                                    color: k == 'ok' ? LagoColors.pink : null,
                                  )),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(onPressed: _forgot, child: const T('Code oublié ? Se reconnecter avec mon mot de passe')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
