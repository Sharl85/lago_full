import 'dart:io';

import 'package:flutter/material.dart';

import '../core/avatar.dart';

import '../core/calculator.dart';
import '../theme.dart';
import '../l10n/l10n.dart';

bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

Color mutedColor(BuildContext context) => isDark(context) ? const Color(0xFFC9B4C3) : LagoColors.textMuted;

/// Carte « verre dépoli » de la version web.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final Color? borderColor;
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.gradient, this.borderColor});

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (dark ? LagoColors.cardDark.withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.88)) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor ?? LagoColors.pinkSoft.withValues(alpha: dark ? 0.2 : 0.3)),
        boxShadow: [
          BoxShadow(
            color: dark ? Colors.black.withValues(alpha: 0.3) : LagoColors.pink.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Titre de section avec icône.
class SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;
  final Color? iconColor;
  final Widget? trailing;
  const SectionTitle(this.title, {super.key, required this.icon, this.subtitle, this.iconColor, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(icon, color: iconColor ?? LagoColors.pink, size: 22),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                T(title, style: Theme.of(context).textTheme.titleLarge),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: T(subtitle!, style: TextStyle(fontSize: 13, color: mutedColor(context))),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Pastille de phase colorée.
class PhaseBadge extends StatelessWidget {
  final Phase phase;
  final double fontSize;
  const PhaseBadge(this.phase, {super.key, this.fontSize = 13});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: phase.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: phase.color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_florist, size: fontSize + 2, color: phase.color),
          const SizedBox(width: 6),
          T(phase.name,
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: Color.lerp(phase.color, Colors.black, 0.35))),
        ],
      ),
    );
  }
}

/// Séparateur fleuri.
class LotusDivider extends StatelessWidget {
  const LotusDivider({super.key});
  @override
  Widget build(BuildContext context) {
    final line = Expanded(child: Divider(color: LagoColors.pinkSoft.withValues(alpha: 0.35)));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(children: [line, const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Icon(Icons.local_florist, color: LagoColors.pink, size: 18)), line]),
    );
  }
}

/// Avatar rond : photo de profil, ou emoji sur fond coloré (👧 / 👑 par défaut).
class UserAvatar extends StatelessWidget {
  final bool admin;
  final double size;
  final AvatarPref? avatar;
  const UserAvatar({super.key, required this.admin, this.size = 36, this.avatar});
  @override
  Widget build(BuildContext context) {
    final a = avatar;
    if (a != null && a.hasPhoto) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: admin ? LagoColors.goldDeep : LagoColors.pinkSoft, width: 2),
          image: DecorationImage(image: FileImage(File(a.photoPath!)), fit: BoxFit.cover),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: a != null ? Color(a.color) : null,
        gradient: a != null ? null : (admin ? LagoColors.adminGradient : LagoColors.lotusGradient),
      ),
      child: Text(a?.emoji ?? (admin ? '👑' : '👧'), style: TextStyle(fontSize: size * 0.5)),
    );
  }
}

// ------------------------------------------------------------------ Retours visuels
enum ToastType { success, error, info }

void showToast(BuildContext context, String message, {ToastType type = ToastType.success}) {
  final icon = switch (type) { ToastType.success => '🌸', ToastType.error => '⚠️', ToastType.info => 'ℹ️' };
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [T(icon), const SizedBox(width: 10), Expanded(child: T(message))]),
      duration: const Duration(milliseconds: 3200),
    ));
}

Future<bool> confirmDialog(BuildContext context, String message, {bool danger = false, String okLabel = 'Confirmer'}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      content: T(message, style: const TextStyle(fontSize: 16)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const T('Annuler')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: LagoColors.danger) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: T(okLabel),
        ),
      ],
    ),
  );
  return res ?? false;
}

/// Fond dégradé de l'application.
class LagoBackground extends StatelessWidget {
  final Widget child;
  const LagoBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: LagoColors.background(isDark(context))),
      child: child,
    );
  }
}
