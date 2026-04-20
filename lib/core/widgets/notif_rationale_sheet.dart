// lib/core/widgets/notif_rationale_sheet.dart
//
// Pré-prompt notifications merchant — bottom sheet expliquant POURQUOI les
// notifs sont critiques pour un restaurateur, AVANT d'appeler
// `requestPermission()` du système.
//
// Pourquoi ?
//   iOS ne demande qu'UNE SEULE FOIS la permission. Un refus = permission
//   perdue à vie (obligation d'aller dans Réglages iOS). Le pré-prompt
//   custom permet au restaurateur de dire "Plus tard" sans brûler sa chance.
//   Pour un partenaire, sans notif = commandes ratées pendant le service.
//
//   Benchmark UX : opt-in ~30 % sans pré-prompt vs ~60-70 % avec.
//   Cf. zeet-notification-strategy §8.
//
// Tone of voice (cf. zeet-micro-copy §2) : professionnel, sobre, vouvoiement,
// vocabulaire métier (commande, service, CA).
//
// Usage :
//   final accepted = await NotifRationaleSheet.show(context);
//   if (accepted == true) { /* appeler requestPermission */ }

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeet_ui/zeet_ui.dart';

class NotifRationaleSheet {
  /// Clé SharedPreferences : marque qu'on a déjà affiché le pré-prompt
  /// et que le restaurateur a accepté.
  static const String _kRationaleShownKey = 'notif.rationale.shown';

  /// Retourne `true` si le restaurateur a déjà vu le pré-prompt et accepté.
  static Future<bool> hasBeenShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kRationaleShownKey) ?? false;
  }

  /// Marque que le pré-prompt a été vu et accepté.
  static Future<void> markAsShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRationaleShownKey, true);
  }

  /// Affiche le bottom sheet. Retourne :
  /// - `true` : tap "Activer" → déclencher requestPermission
  /// - `false` ou `null` : refus / dismiss → ne pas demander la permission
  static Future<bool?> show(BuildContext context) async {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _RationaleSheetContent(),
    );
  }
}

class _RationaleSheetContent extends StatelessWidget {
  const _RationaleSheetContent();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? ZeetColors.surfaceDark : ZeetColors.surface;
    final ink = isDark ? ZeetColors.inkDark : ZeetColors.ink;
    final inkMuted = isDark ? ZeetColors.inkMutedDark : ZeetColors.inkMuted;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: ZeetColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Icône
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: ZeetColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_active_outlined,
                color: ZeetColors.primary,
                size: 32,
              ),
            ),
          ),
          SizedBox(height: 20),

          // Titre — tone partner (pro, sobre, vouvoiement)
          Text(
            'Ne manquez aucune commande',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20.0.sp,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
          SizedBox(height: 12),

          // Description — opérationnelle, factuelle
          Text(
            'Activez les notifications pour être alerté dès qu\'une nouvelle commande arrive — '
            'même écran verrouillé, même en plein coup de feu.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.0.sp,
              color: inkMuted,
              height: 1.4,
            ),
          ),
          SizedBox(height: 20),

          // Bénéfices — focalisés POS
          _BenefitRow(
            icon: Icons.receipt_long_outlined,
            text: 'Alerte prioritaire sur chaque nouvelle commande',
            ink: ink,
          ),
          SizedBox(height: 10),
          _BenefitRow(
            icon: Icons.delivery_dining_outlined,
            text: 'Statut livreur arrivé et OTP de remise',
            ink: ink,
          ),
          SizedBox(height: 10),
          _BenefitRow(
            icon: Icons.trending_up_outlined,
            text: 'Récap de votre CA en fin de service',
            ink: ink,
          ),

          SizedBox(height: 24),

          // CTA primaire
          ZeetButton.primary(
            label: 'Activer les notifications',
            onPressed: () => Navigator.of(context).pop(true),
            fullWidth: true,
            size: ZeetButtonSize.lg,
          ),
          SizedBox(height: 8),

          // CTA secondaire
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Plus tard',
              style: TextStyle(
                color: inkMuted,
                fontSize: 14.0.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.text,
    required this.ink,
  });

  final IconData icon;
  final String text;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: ZeetColors.primary),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14.0.sp,
              color: ink,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
