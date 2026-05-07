// lib/screens/permissions/widgets/permission_rationale_sheet.dart
//
// Bottom sheet "rationale" affichee avant le prompt OS natif. Pattern
// just-in-time (skill `zeet-notification-strategy` §8) :
//
//   tap card  →  rationale sheet  →  user comprend "pourquoi"
//                                    →  tap "Autoriser"
//                                    →  prompt OS natif
//                                    →  status update card
//
// Vs. l'ancien flux (tap → prompt OS direct) qui generait des refus
// reflexes parce que l'utilisateur ne comprenait pas l'enjeu.
//
// Pour `permanentlyDenied`, on bascule en mode "comment ouvrir les
// reglages" avec un breadcrumb manuel (la deeplink ne suffit pas
// toujours sur certains OEM Android).

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/services/permissions_service.dart';
import 'package:zeet_ui/zeet_ui.dart';

/// Affiche la sheet rationale et renvoie `true` si l'utilisateur a confirme
/// (= il faut declencher la suite : `request()` ou `openSettings()`).
Future<bool> showPermissionRationaleSheet(
  BuildContext context, {
  required ZeetPermission permission,
  required ZeetPermissionStatus status,
  required bool critical,
}) async {
  final bool? confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext ctx) => _RationaleBody(
      permission: permission,
      status: status,
      critical: critical,
    ),
  );
  return confirmed ?? false;
}

class _RationaleBody extends StatelessWidget {
  const _RationaleBody({
    required this.permission,
    required this.status,
    required this.critical,
  });

  final ZeetPermission permission;
  final ZeetPermissionStatus status;
  final bool critical;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final PermissionsService svc = PermissionsService.instance;
    final String title = svc.labelFor(permission);
    final IconData icon = _iconFor(permission);
    final List<String> bullets = _bulletsFor(permission);
    final String impact = _impactFor(permission, critical: critical);
    final bool isLocked = status == ZeetPermissionStatus.permanentlyDenied;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20.w,
        8.h,
        20.w,
        MediaQuery.of(context).viewInsets.bottom + 24.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 48.w,
                height: 48.h,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(icon, color: AppColors.primary, size: 26.r),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (critical) ...<Widget>[
                      SizedBox(height: 4.h),
                      Text(
                        'Permission requise pour bien recevoir vos commandes.',
                        style: tt.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Text(
            'Pourquoi nous le demandons',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8.h),
          ...bullets.map((String b) => _Bullet(text: b)),
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: critical
                  ? ZeetColors.dangerBg
                  : scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(ZeetRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.info_outline_rounded,
                  size: 20.r,
                  color: critical ? ZeetColors.danger : scheme.onSurfaceVariant,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    impact,
                    style: tt.bodyMedium?.copyWith(
                      color: critical
                          ? ZeetColors.dangerText
                          : scheme.onSurface,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isLocked) ...<Widget>[
            SizedBox(height: 16.h),
            _SettingsBreadcrumb(),
          ],
          SizedBox(height: 24.h),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                  child: const Text('Plus tard'),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: Icon(
                    isLocked
                        ? Icons.settings_rounded
                        : Icons.check_rounded,
                  ),
                  label: Text(
                    isLocked ? 'Ouvrir les réglages' : 'Autoriser',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconFor(ZeetPermission p) {
    switch (p) {
      case ZeetPermission.notifications:
        return Icons.notifications_active_rounded;
      case ZeetPermission.overlay:
        return Icons.bubble_chart_rounded;
      case ZeetPermission.batteryOptimization:
        return Icons.battery_charging_full_rounded;
      case ZeetPermission.exactAlarm:
        return Icons.alarm_on_rounded;
    }
  }

  List<String> _bulletsFor(ZeetPermission p) {
    switch (p) {
      case ZeetPermission.notifications:
        return const <String>[
          'Vous recevez un signal sonore + visuel à chaque nouvelle commande.',
          'Sans notification, vous risquez de rater une commande pendant un coup de feu.',
          'Notre canal "incoming" est haute priorité (full-screen) — il sonne même en mode silencieux.',
        ];
      case ZeetPermission.overlay:
        return const <String>[
          'L\'écran de commande entrante s\'affiche par-dessus toute autre app.',
          'Indispensable si vous étiez en train d\'utiliser WhatsApp ou un compteur cuisine.',
          'Aucun usage en arrière-plan : la fenêtre apparaît uniquement à la réception d\'une commande.',
        ];
      case ZeetPermission.batteryOptimization:
        return const <String>[
          'Garde l\'app ZEET active même si l\'écran est verrouillé.',
          'Sans ça, Android peut tuer l\'app après 30 min d\'inactivité — vous rateriez les commandes.',
          'Aucun impact mesurable sur la batterie : l\'app reste en veille tant qu\'aucune commande n\'arrive.',
        ];
      case ZeetPermission.exactAlarm:
        return const <String>[
          'Permet de programmer des rappels précis (ex. fin de préparation, heure de fermeture).',
          'Sans ça, les alertes peuvent se déclencher avec plusieurs minutes de retard.',
        ];
    }
  }

  String _impactFor(ZeetPermission p, {required bool critical}) {
    if (!critical) {
      return 'Optionnel — l\'app fonctionne sans, mais avec moins de confort.';
    }
    switch (p) {
      case ZeetPermission.notifications:
        return 'Sans cette permission, vous ne recevez aucun signal sur les nouvelles commandes : vous les manquerez.';
      case ZeetPermission.overlay:
        return 'Sans cette permission, l\'app ne peut pas afficher l\'écran de commande entrante quand vous utilisez une autre app.';
      case ZeetPermission.batteryOptimization:
        return 'Sans cette permission, Android va éteindre ZEET en arrière-plan : vous manquerez des commandes pendant les heures creuses.';
      case ZeetPermission.exactAlarm:
        return 'Les rappels seront imprécis. Pas critique, mais recommandé.';
    }
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(top: 7.h),
            child: Container(
              width: 5.w,
              height: 5.w,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14.sp,
                color: scheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsBreadcrumb extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<String> steps = const <String>[
      'Réglages',
      'Notifications',
      'ZEET Partenaire',
      'Activer',
    ];

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(ZeetRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Chemin dans les réglages',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              for (int i = 0; i < steps.length; i++) ...<Widget>[
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Text(
                    steps[i],
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                if (i < steps.length - 1)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16.r,
                    color: scheme.onSurfaceVariant,
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
