// ZeetFreshnessChip — pastille de fraîcheur des données.
//
// Pattern signature ZEET pour rendre **visible** la possibilité de rafraîchir
// manuellement une vue qui dépend d'une API. Le pull-to-refresh étant
// invisible par nature (skill `zeet-gesture-grammar` §6 — discoverability),
// ce chip joue 3 rôles cumulés :
//   1. **Statut fraîcheur** (Zeigarnik / fluency heuristic — `zeet-neuro-ux`
//      §F + I) : l'utilisateur voit que la donnée vit.
//   2. **Hint visuel** (dot qui respire en stale = invitation au geste).
//   3. **Alternative tap** au geste de tirage (POS rider/partner avec gants
//      ne peuvent pas pull précisément — skill `zeet-pos-ergonomics`).
//
// 3 états :
//   - **fresh** (`updatedAt < 60s`) : dot `success` plein, pas d'anim.
//   - **stale** (`updatedAt > 60s`) : dot `warning` qui pulse 1.5s loop.
//   - **offline** (`isOnline == false`) : dot `danger` qui pulse plus vite.
//
// Tap = `ZeetHaptics.tap` + spinner inline pendant la promise + retour à dot.
//
// Tokens stricts (skill `zeet-design-system`) : surfaceAlt bg, caption 11sp,
// pill radius, échelle 4pt. Aucune valeur magique.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:zeet_ui/zeet_ui.dart';

import 'package:merchant/providers/connectivity_provider.dart';

class ZeetFreshnessChip extends StatefulWidget {
  const ZeetFreshnessChip({
    super.key,
    required this.updatedAt,
    required this.isOnline,
    required this.onRefresh,
    this.staleAfter = const Duration(minutes: 1),
  });

  /// Timestamp du dernier sync réussi. `null` = jamais synchronisé.
  final DateTime? updatedAt;

  /// Faux = bandeau offline activé en parallèle (cf. `ConnectivityBanner`),
  /// le chip passe en état `offline` et désactive le tap.
  final bool isOnline;

  /// Action déclenchée au tap. Doit retourner un `Future` qui complète quand
  /// le refresh est terminé — le spinner reste visible jusque-là.
  final Future<void> Function() onRefresh;

  /// Délai au-delà duquel l'état `fresh` bascule en `stale`. Par défaut 1 min
  /// (signal d'invitation au refresh sans être agressif).
  final Duration staleAfter;

  @override
  State<ZeetFreshnessChip> createState() => _ZeetFreshnessChipState();
}

class _ZeetFreshnessChipState extends State<ZeetFreshnessChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  Timer? _relativeTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    // Tick toutes les 30s pour que "il y a X min" reste à jour sans rebuild
    // externe (le state du parent ne change pas si la donnée ne bouge pas,
    // mais le label relatif évolue).
    _relativeTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _relativeTimer?.cancel();
    super.dispose();
  }

  _Freshness _resolveState() {
    if (!widget.isOnline) return _Freshness.offline;
    final DateTime? at = widget.updatedAt;
    if (at == null) return _Freshness.stale;
    final Duration age = DateTime.now().difference(at);
    return age < widget.staleAfter ? _Freshness.fresh : _Freshness.stale;
  }

  String _label(_Freshness s) {
    if (s == _Freshness.offline) return 'Hors ligne';
    final DateTime? at = widget.updatedAt;
    if (at == null) return 'Pas encore sync.';
    final Duration age = DateTime.now().difference(at);
    if (age.inSeconds < 30) return 'À l\'instant';
    if (age.inMinutes < 1) return 'À l\'instant';
    if (age.inMinutes < 60) return 'il y a ${age.inMinutes} min';
    if (age.inHours < 24) return 'il y a ${age.inHours} h';
    return 'il y a ${age.inDays} j';
  }

  Future<void> _onTap() async {
    if (_refreshing || !widget.isOnline) return;
    setState(() => _refreshing = true);
    ZeetHaptics.tap();
    try {
      await widget.onRefresh();
      if (mounted) ZeetHaptics.success();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final _Freshness s = _resolveState();
    final Color dotColor = switch (s) {
      _Freshness.fresh => ZeetColors.success,
      _Freshness.stale => ZeetColors.warning,
      _Freshness.offline => ZeetColors.danger,
    };
    final bool shouldPulse = s != _Freshness.fresh && !reduceMotion;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? ZeetColors.inkMutedDark : ZeetColors.inkMuted;
    final Color bgColor = isDark
        ? ZeetColors.surfaceAltDark
        : ZeetColors.surfaceAlt;

    return Semantics(
      button: true,
      label: 'Rafraîchir — ${_label(s)}',
      child: InkWell(
        onTap: widget.isOnline ? _onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          margin: EdgeInsets.only(right: 8.w),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: dotColor.withValues(alpha: 0.20),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 8.w,
                height: 8.w,
                child: _refreshing
                    ? CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation(dotColor),
                      )
                    : _PulseDot(
                        color: dotColor,
                        controller: _pulseCtrl,
                        animate: shouldPulse,
                      ),
              ),
              SizedBox(width: 6.w),
              Text(
                _label(s),
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Freshness { fresh, stale, offline }

/// Variante self-managed du `ZeetFreshnessChip` — 1 ligne par écran.
///
/// Maintient son propre `lastSyncedAt` (initialisé à `DateTime.now()` au
/// mount = présomption de fraîcheur à l'arrivée sur l'écran), lit `isOnline`
/// depuis `isOnlineProvider`, et met à jour le timestamp à chaque refresh
/// réussi. Idéal pour propager le pattern sur 10+ écrans sans toucher à
/// chaque state Riverpod.
///
/// Trade-off : ne capte pas les `silentRefresh` déclenchés par push FCM ou
/// background sync. Pour ces cas (ex: my_orders avec push live), préférer
/// le constructor `ZeetFreshnessChip` standard avec un `lastSyncedAt`
/// exposé par le state.
class ZeetFreshnessChipLocal extends ConsumerStatefulWidget {
  const ZeetFreshnessChipLocal({
    super.key,
    required this.onRefresh,
    this.staleAfter = const Duration(minutes: 1),
  });

  final Future<void> Function() onRefresh;
  final Duration staleAfter;

  @override
  ConsumerState<ZeetFreshnessChipLocal> createState() =>
      ZeetFreshnessChipLocalState();
}

/// State public pour permettre aux parents de notifier le chip d'un refresh
/// externe (pull-to-refresh, retry, post-action) via un
/// `GlobalKey<ZeetFreshnessChipLocalState>` + `bump()`. Le tap direct sur la
/// chip continue de fonctionner indépendamment.
class ZeetFreshnessChipLocalState
    extends ConsumerState<ZeetFreshnessChipLocal> {
  // Présomption de fraîcheur au mount : l'utilisateur vient d'arriver,
  // l'écran affiche déjà des données chargées (initState a déjà déclenché
  // un load). Le chip passe en stale après `staleAfter` sans interaction.
  DateTime _lastSyncedAt = DateTime.now();

  /// Notifie le chip qu'un refresh a eu lieu en dehors de son propre tap
  /// (pull-to-refresh, retry empty-state, post-action, FCM push…). Remet la
  /// pastille en état `fresh` et met à jour le label « il y a X min ».
  void bump() {
    if (mounted) setState(() => _lastSyncedAt = DateTime.now());
  }

  Future<void> _refresh() async {
    await widget.onRefresh();
    if (mounted) setState(() => _lastSyncedAt = DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final bool isOnline = ref.watch(isOnlineProvider);
    return ZeetFreshnessChip(
      updatedAt: _lastSyncedAt,
      isOnline: isOnline,
      onRefresh: _refresh,
      staleAfter: widget.staleAfter,
    );
  }
}

class _PulseDot extends StatelessWidget {
  const _PulseDot({
    required this.color,
    required this.controller,
    required this.animate,
  });

  final Color color;
  final AnimationController controller;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    if (!animate) {
      return Container(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          // Alpha 0.4 → 1.0 en easing doux (springGentle équivalent ease).
          final double t = Curves.easeInOut.transform(controller.value);
          final double alpha = 0.4 + 0.6 * t;
          return Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: alpha),
              shape: BoxShape.circle,
            ),
          );
        },
      ),
    );
  }
}
