// Actions rapides "Gestion" — raccourcis POS depuis la home vers les
// surfaces de gestion de catalogue et disponibilite.
//
// Avant : Produits / Menus / Horaires etaient accessibles uniquement
// via le tab Profil → options (3 taps depuis home). Pour un partenaire
// qui gere ses ruptures ou ses horaires plusieurs fois par service,
// c'est un frein quotidien (skill zeet-3-clicks-rule §5).
//
// Ce widget expose 3 shortcuts en 1 tap depuis l'ecran d'accueil,
// sans surcharger la bottom bar (4 tabs officiels conserves — ADN POS).

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:zeet_ui/zeet_ui.dart';

import 'package:merchant/core/constants/icons.dart';
import 'package:merchant/services/navigation_service.dart';

class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _QuickAction(
              icon: 'shopping_bag_outlined',
              label: 'Produits',
              onTap: () => Routes.navigateTo(Routes.products),
            ),
          ),
          Expanded(
            child: _QuickAction(
              icon: 'restaurant_outlined',
              label: 'Menus',
              onTap: () => Routes.navigateTo(Routes.menu),
            ),
          ),
          Expanded(
            child: _QuickAction(
              icon: 'schedule',
              label: 'Horaires',
              onTap: () => Routes.navigateTo(Routes.openingHours),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatefulWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool reduceMotion = MediaQuery.of(context).disableAnimations;

    return Semantics(
      button: true,
      label: widget.label,
      child: ExcludeSemantics(
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: reduceMotion ? Duration.zero : ZeetMotion.xs,
          curve: ZeetCurves.standard,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12.r),
            child: InkWell(
              onTapDown: (_) => _setPressed(true),
              onTapUp: (_) => _setPressed(false),
              onTapCancel: () => _setPressed(false),
              onTap: () {
                ZeetHaptics.tap();
                widget.onTap();
              },
              borderRadius: BorderRadius.circular(12.r),
              splashColor: ZeetColors.primary.withValues(alpha: 0.10),
              highlightColor: ZeetColors.primary.withValues(alpha: 0.06),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Icon slot circulaire primary subtle (glanceability POS).
                    Container(
                      width: 44.w,
                      height: 44.w,
                      decoration: BoxDecoration(
                        color: ZeetColors.primary.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: IconManager.getIcon(
                        widget.icon,
                        color: ZeetColors.primary,
                        size: 22.r,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
