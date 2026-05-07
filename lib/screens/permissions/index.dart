// lib/screens/permissions/index.dart
//
// Ecran d'onboarding des permissions post-login. Design "hero" avec un header
// visuel + une liste de cards (une par permission) + un CTA sticky bottom.
//
// Reflexions UX :
// - zeet-notification-strategy §8 : ask-in-context. Dans le cas partner,
//   le "contexte" est "je viens de me connecter et je veux configurer mon
//   POS" — c'est donc legitime de batcher toutes les demandes post-login.
// - zeet-pos-ergonomics §2 : CTA bottom sticky, hit target 56pt+, haptic,
//   color+icon+label sur chaque permission.
// - zeet-motion-system (partner) : durees courtes 120-200ms, fonctionnel
//   uniquement. Check icon qui se dessine sur grant (crossfade 150ms).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/screens/permissions/widgets/permission_rationale_sheet.dart';
import 'package:merchant/services/navigation_service.dart';
import 'package:merchant/services/permissions_service.dart';
import 'package:zeet_ui/zeet_ui.dart';

class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen>
    with WidgetsBindingObserver {
  final Map<ZeetPermission, ZeetPermissionStatus> _statuses =
      <ZeetPermission, ZeetPermissionStatus>{};
  bool _loading = true;
  bool _requestingAny = false;
  // Signalé par didChangeAppLifecycleState(resumed) : une fois que l'app
  // revient au premier plan apres un settings screen, on annule la boucle
  // "Tout autoriser" pour que l'utilisateur pilote la suite une permission
  // a la fois (evite les buttons greyed out + chaine de 4 ecrans settings).
  bool _batchCancelled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Au retour d'une settings page (SYSTEM_ALERT_WINDOW, batterie…),
    // refresher l'etat pour que les chips se mettent a jour toutes seules,
    // et annuler toute boucle "Tout autoriser" en cours : sur certains OEM
    // Android, l'await `Permission.xxx.request()` ne resout jamais apres
    // retour de settings, bloquant `_requestingAny` a true (= boutons grises).
    if (state == AppLifecycleState.resumed) {
      _batchCancelled = true;
      if (_requestingAny && mounted) {
        setState(() => _requestingAny = false);
      }
      _refreshAll();
    }
  }

  Future<void> _refreshAll() async {
    final svc = PermissionsService.instance;
    final perms = svc.applicablePermissions;
    final Map<ZeetPermission, ZeetPermissionStatus> next = {};
    for (final p in perms) {
      next[p] = await svc.getStatus(p);
    }
    if (!mounted) return;
    setState(() {
      _statuses
        ..clear()
        ..addAll(next);
      _loading = false;
    });
  }

  Future<void> _requestOne(ZeetPermission p) async {
    await ZeetHaptics.tap();
    final ZeetPermissionStatus current =
        _statuses[p] ?? ZeetPermissionStatus.unknown;
    final bool isCritical = PermissionsService.instance.criticalPermissions
        .contains(p);

    // Just-in-time rationale (skill `zeet-notification-strategy` §8) :
    // un sheet intermediaire explique pourquoi avant d'appeler le prompt OS.
    // Sur permanentlyDenied, le sheet bascule en mode "ouvrir reglages"
    // avec breadcrumb manuel.
    if (!mounted) return;
    final bool confirmed = await showPermissionRationaleSheet(
      context,
      permission: p,
      status: current,
      critical: isCritical,
    );
    if (!confirmed || !mounted) return;

    setState(() => _requestingAny = true);
    try {
      if (current == ZeetPermissionStatus.permanentlyDenied) {
        await PermissionsService.instance.openSettings();
      } else {
        final next = await PermissionsService.instance.request(p);
        if (!mounted) return;
        setState(() => _statuses[p] = next);
        if (next == ZeetPermissionStatus.granted) {
          await ZeetHaptics.success();
        }
      }
    } finally {
      if (mounted) setState(() => _requestingAny = false);
    }
  }

  Future<void> _requestAllMissing() async {
    final svc = PermissionsService.instance;
    final perms = svc.applicablePermissions;
    _batchCancelled = false;
    setState(() => _requestingAny = true);
    try {
      for (final p in perms) {
        if (_batchCancelled || !mounted) return;
        final current = _statuses[p];
        if (current == ZeetPermissionStatus.granted ||
            current == ZeetPermissionStatus.notApplicable) {
          continue;
        }
        if (current == ZeetPermissionStatus.permanentlyDenied) {
          continue; // skip — require manual settings
        }
        // Timeout defensif : sur certains devices, l'await `request()`
        // ne resout pas apres retour de settings. On cap a 2 min.
        ZeetPermissionStatus next;
        try {
          next = await svc.request(p).timeout(
                const Duration(minutes: 2),
                onTimeout: () => current ?? ZeetPermissionStatus.unknown,
              );
        } catch (_) {
          next = current ?? ZeetPermissionStatus.unknown;
        }
        if (_batchCancelled || !mounted) return;
        setState(() => _statuses[p] = next);
        // Petit delay entre deux prompts pour eviter le stack natif.
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    } finally {
      if (mounted) setState(() => _requestingAny = false);
    }
  }

  Future<void> _finish() async {
    await PermissionsService.instance.markOnboarded();
    if (!mounted) return;

    // Si une permission critique reste refusee, prevenir l'utilisateur.
    final criticals = PermissionsService.instance.criticalPermissions;
    final missingCritical = criticals
        .where((ZeetPermission p) =>
            _statuses[p] != ZeetPermissionStatus.granted &&
            _statuses[p] != ZeetPermissionStatus.notApplicable)
        .toList();

    if (missingCritical.isNotEmpty) {
      AppToast.showWarning(
        context: context,
        message:
            'Certaines permissions critiques ne sont pas accordees. Vous pourriez rater des commandes.',
      );
    } else {
      AppToast.showSuccess(
        context: context,
        message: 'ZEET est pret. Bon service !',
      );
    }

    Routes.navigateAndRemoveAll(Routes.root);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    final perms = PermissionsService.instance.applicablePermissions;

    final int grantedCount = perms
        .where((p) => _statuses[p] == ZeetPermissionStatus.granted)
        .length;
    final int totalCount = perms.length;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _refreshAll,
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
                        children: <Widget>[
                          _Header(
                            grantedCount: grantedCount,
                            totalCount: totalCount,
                          ),
                          SizedBox(height: 24.h),
                          Text(
                            'Dernieres etapes',
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Ces acces nous permettent d\'etre alertes instantanement sur chaque commande.',
                            style: tt.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          ...perms.map((ZeetPermission p) {
                            final status =
                                _statuses[p] ?? ZeetPermissionStatus.unknown;
                            return _PermissionCard(
                              permission: p,
                              status: status,
                              critical: PermissionsService.instance
                                  .criticalPermissions
                                  .contains(p),
                              onTap: _requestingAny
                                  ? null
                                  : () => _requestOne(p),
                            );
                          }),
                          SizedBox(height: 8.h),
                          if (perms.any((p) =>
                              _statuses[p] ==
                              ZeetPermissionStatus.permanentlyDenied))
                            _SettingsHint(
                              onOpen: PermissionsService.instance.openSettings,
                            ),
                        ],
                      ),
                    ),
            ),
            _BottomBar(
              grantedCount: grantedCount,
              totalCount: totalCount,
              requesting: _requestingAny,
              onRequestAll: _requestAllMissing,
              onFinish: _finish,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Header hero
// =============================================================================

class _Header extends StatelessWidget {
  const _Header({required this.grantedCount, required this.totalCount});

  final int grantedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;

    final double progress = totalCount == 0 ? 0 : grantedCount / totalCount;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(ZeetRadius.md),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 48.w,
                height: 48.h,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(
                  Icons.restaurant_rounded,
                  color: Colors.white,
                  size: 26.r,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Bienvenue sur ZEET Partner',
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Configurons votre POS en 30 secondes.',
                      style: tt.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // Progress bar visuelle (fonctionnel : montre l'avancement).
          ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8.h,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            totalCount == 0
                ? 'Aucune permission requise sur votre appareil.'
                : '$grantedCount sur $totalCount permission${totalCount > 1 ? 's' : ''} accordee${grantedCount > 1 ? 's' : ''}',
            style: tt.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Card permission
// =============================================================================

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.permission,
    required this.status,
    required this.critical,
    required this.onTap,
  });

  final ZeetPermission permission;
  final ZeetPermissionStatus status;
  final bool critical;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    final svc = PermissionsService.instance;

    final IconData icon = _iconFor(permission);
    final String title = svc.labelFor(permission);
    final String desc = svc.descriptionFor(permission);

    final bool granted = status == ZeetPermissionStatus.granted;
    final bool locked = status == ZeetPermissionStatus.permanentlyDenied;
    final bool actionable = !granted && status != ZeetPermissionStatus.notApplicable;

    final Color accent = granted
        ? ZeetColors.success
        : (critical ? AppColors.primary : scheme.onSurfaceVariant);

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: granted
              ? ZeetColors.success.withValues(alpha: 0.35)
              : scheme.outlineVariant,
          width: granted ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: actionable ? onTap : null,
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: granted
                      ? Container(
                          key: const ValueKey<String>('granted'),
                          width: 48.w,
                          height: 48.h,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color:
                                ZeetColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            color: ZeetColors.success,
                            size: 26.r,
                          ),
                        )
                      : Container(
                          key: const ValueKey<String>('icon'),
                          width: 48.w,
                          height: 48.h,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          child: Icon(icon, color: accent, size: 24.r),
                        ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              title,
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (critical) ...<Widget>[
                            SizedBox(width: 6.w),
                            _CriticalPill(),
                          ],
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        desc,
                        style: tt.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      _StatusPill(status: status, locked: locked),
                    ],
                  ),
                ),
                if (actionable)
                  Padding(
                    padding: EdgeInsets.only(left: 8.w, top: 4.h),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14.r,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
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
}

class _CriticalPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(ZeetRadius.pill),
      ),
      child: Text(
        'Requis',
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.locked});

  final ZeetPermissionStatus status;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    late final String label;
    late final IconData icon;

    switch (status) {
      case ZeetPermissionStatus.granted:
        bg = ZeetColors.success.withValues(alpha: 0.15);
        fg = ZeetColors.success;
        label = 'Accordee';
        icon = Icons.check_circle_rounded;
      case ZeetPermissionStatus.denied:
      case ZeetPermissionStatus.unknown:
        bg = AppColors.primary.withValues(alpha: 0.12);
        fg = AppColors.primary;
        label = 'Appuyez pour autoriser';
        icon = Icons.touch_app_rounded;
      case ZeetPermissionStatus.permanentlyDenied:
        bg = ZeetColors.dangerBg;
        fg = ZeetColors.danger;
        label = 'Ouvrir les reglages';
        icon = Icons.settings_rounded;
      case ZeetPermissionStatus.notApplicable:
        bg = ZeetColors.line;
        fg = ZeetColors.inkMuted;
        label = 'Non necessaire';
        icon = Icons.remove_circle_outline_rounded;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ZeetRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: fg, size: 14.r),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsHint extends StatelessWidget {
  const _SettingsHint({required this.onOpen});

  final Future<void> Function() onOpen;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    return Container(
      margin: EdgeInsets.only(top: 4.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.info_outline_rounded, color: scheme.onSurfaceVariant),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'Certaines permissions necessitent un passage par les reglages systeme.',
              style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: onOpen,
            child: const Text('Ouvrir'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Bottom bar sticky
// =============================================================================

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.grantedCount,
    required this.totalCount,
    required this.requesting,
    required this.onRequestAll,
    required this.onFinish,
  });

  final int grantedCount;
  final int totalCount;
  final bool requesting;
  final VoidCallback onRequestAll;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool allGranted =
        totalCount == 0 || grantedCount >= totalCount;

    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: <Widget>[
          if (!allGranted)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: requesting ? null : onRequestAll,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                ),
                icon: const Icon(Icons.flash_on_rounded, size: 18),
                label: const Text('Tout autoriser'),
              ),
            ),
          if (!allGranted) SizedBox(width: 12.w),
          Expanded(
            flex: allGranted ? 1 : 1,
            child: FilledButton(
              onPressed: requesting ? null : onFinish,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(vertical: 14.h),
              ),
              child: Text(
                allGranted ? 'Commencer' : 'Plus tard',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
