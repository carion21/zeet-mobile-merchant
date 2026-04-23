import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/services/overlay_service.dart';
import 'package:zeet_ui/zeet_ui.dart';

/// Toggle de la bulle flottante (overlay chat-head Android).
///
/// Gere localement :
/// - l'etat "active dans les prefs" + "permission accordee" ;
/// - le pre-prompt explicatif (Google Play friendly) avant la
///   system prompt de permission overlay.
class ProfileOverlayToggle extends ConsumerStatefulWidget {
  const ProfileOverlayToggle({
    required this.textColor,
    required this.textLightColor,
    super.key,
  });

  final Color textColor;
  final Color textLightColor;

  @override
  ConsumerState<ProfileOverlayToggle> createState() =>
      _ProfileOverlayToggleState();
}

class _ProfileOverlayToggleState extends ConsumerState<ProfileOverlayToggle> {
  bool _overlayEnabled = false;
  bool _overlayHasPermission = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_refreshOverlayState);
  }

  Future<void> _refreshOverlayState() async {
    if (!OverlayService.instance.isSupported) return;
    final enabled = await OverlayService.instance.isEnabledInPrefs();
    final granted = await OverlayService.instance.hasPermission();
    if (!mounted) return;
    setState(() {
      _overlayEnabled = enabled && granted;
      _overlayHasPermission = granted;
    });
  }

  Future<void> _toggleOverlay(bool value) async {
    await HapticFeedback.selectionClick();
    final svc = OverlayService.instance;

    if (!value) {
      await svc.setEnabledInPrefs(false);
      if (!mounted) return;
      setState(() => _overlayEnabled = false);
      AppToast.showInfo(
        context: context,
        message: 'Bulle desactivee',
      );
      return;
    }

    // Activation : pre-prompt explicatif avant la system prompt
    // (respect zeet-notification-strategy §8 — ask in context).
    final bool wantsEnable = await _showOverlayPrePrompt();
    if (!wantsEnable || !mounted) return;

    bool granted = await svc.hasPermission();
    if (!granted) {
      granted = await svc.requestPermission();
    }

    if (!mounted) return;
    if (!granted) {
      setState(() {
        _overlayEnabled = false;
        _overlayHasPermission = false;
      });
      AppToast.showWarning(
        context: context,
        message:
            'Permission refusee. Vous pouvez l\'activer plus tard dans les reglages systeme.',
      );
      return;
    }

    await svc.setEnabledInPrefs(true);
    if (!mounted) return;
    setState(() {
      _overlayEnabled = true;
      _overlayHasPermission = true;
    });
    AppToast.showSuccess(
      context: context,
      message:
          'Bulle activee. Une nouvelle commande affichera l\'alerte par-dessus vos autres apps.',
    );
  }

  /// Pre-prompt avant la demande de permission systeme (Google Play friendly).
  Future<bool> _showOverlayPrePrompt() async {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;

    final bool? result = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  width: 64.w,
                  height: 64.h,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ZeetColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bubble_chart_rounded,
                    color: ZeetColors.primary,
                    size: 32.r,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'Ne ratez plus aucune commande',
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12.h),
                Text(
                  'Une bulle flottante apparaitra par-dessus vos autres apps '
                  'des qu\'une nouvelle commande arrive. Tapez dessus pour '
                  'revenir directement dans ZEET.',
                  style: tt.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.h),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.info_outline_rounded,
                        color: scheme.onSurfaceVariant,
                        size: 18.r,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'A l\'etape suivante, Android ouvre ses parametres. '
                          'Activez le toggle pour ZEET Partner puis revenez.',
                          style: tt.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                        ),
                        child: const Text('Plus tard'),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: ZeetColors.primary,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                        ),
                        child: const Text(
                          'Activer',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // Aligne sur la densite POS du reste des tiles profil (36x36 icon,
    // padding h=14 v=8, font 15sp, min-height 56pt).
    return Column(
      children: <Widget>[
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
          value: _overlayEnabled,
          activeThumbColor: ZeetColors.primary,
          onChanged: (bool v) => _toggleOverlay(v),
          secondary: Container(
            width: 36.w,
            height: 36.h,
            decoration: BoxDecoration(
              color: ZeetColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(ZeetRadius.sm),
            ),
            child: Icon(
              Icons.bubble_chart_rounded,
              color: ZeetColors.primary,
              size: 18.r,
            ),
          ),
          title: Text(
            'Bulle nouvelle commande',
            style: TextStyle(
              color: widget.textColor,
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            _overlayEnabled
                ? 'Bulle activée'
                : _overlayHasPermission
                    ? 'Bulle flottante par-dessus les autres apps'
                    : 'Permission nécessaire',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: widget.textLightColor,
              fontSize: 11.sp,
            ),
          ),
        ),
        Divider(
          height: 1.h,
          thickness: 1,
          indent: 62.w,
          endIndent: 14.w,
          color: widget.textLightColor.withValues(alpha: 0.1),
        ),
      ],
    );
  }
}
