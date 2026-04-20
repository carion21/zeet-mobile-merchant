// Ecran "Incoming Order" — declenche quand une nouvelle commande arrive
// (via push FCM a terme, ou via dev trigger en Phase 2).
//
// Principes :
//  - Plein ecran orange ZEET (priming couleur, focus total)
//  - Hierarchie Z-pattern : code commande → total geant → client/articles → slide
//  - Sonnerie systeme en boucle (flutter_ringtone_player) — FORT, continu,
//    ne s'arrete que sur accept/reject/dismiss
//  - PAS DE MINUTEUR : le partner peut ne pas etre a cote du telephone
//  - Pulse visuel (icone cloche qui grossit) pour renforcer l'alerte
//  - Slide-to-accept (anti faux positif POS) + bouton refuser secondaire
//  - Retour systeme bloque tant que le ringing est actif
//
// Wiring : ecoute [incomingOrderProvider]. Toute la logique metier est dans le
// notifier — ici c'est uniquement du rendu + delegation + control audio/haptic.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:merchant/core/widgets/cancel_reason_sheet.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/models/incoming_order_payload.dart';
import 'package:merchant/providers/incoming_order_provider.dart';
import 'package:merchant/providers/orders_provider.dart';
import 'package:merchant/screens/incoming_order/widgets/slide_to_accept.dart';
import 'package:merchant/services/incoming_ring_bridge.dart';
import 'package:merchant/services/navigation_service.dart';
import 'package:zeet_ui/zeet_ui.dart';

class IncomingOrderScreen extends ConsumerStatefulWidget {
  const IncomingOrderScreen({super.key});

  @override
  ConsumerState<IncomingOrderScreen> createState() =>
      _IncomingOrderScreenState();
}

class _IncomingOrderScreenState extends ConsumerState<IncomingOrderScreen>
    with SingleTickerProviderStateMixin {
  // Couleurs fixes ecran — ne suivent pas le dark mode (ecran de focus).
  static const Color _bg = Color(0xFFFF5A1F);
  static const Color _bgDark = Color(0xFFE64A0F);
  static const Color _ink = Colors.white;

  static final _currency = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'FCFA',
    decimalDigits: 0,
  );

  static const Duration _ringTimeout = Duration(seconds: 90);

  late final AnimationController _pulseController;
  Timer? _hapticTicker;
  Timer? _ringTimeoutTimer;
  bool _ringtonePlaying = false;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) => _startRinging());
  }

  /// Lance la sonnerie en boucle + la vibration continue.
  ///
  /// Phase 4 : si l'ecran est ouvert en foreground (tap sur notif, dev
  /// trigger), le service natif n'est PAS deja en cours → on le demarre via
  /// [IncomingRingBridge.startFake] + fallback Flutter sur
  /// [FlutterRingtonePlayer] en cas d'echec du channel (iOS, dev).
  ///
  /// Si l'ecran est ouvert apres un tap sur la notif FSI natif, le service
  /// tourne deja — startFake sur le canal est idempotent cote natif donc OK.
  Future<void> _startRinging() async {
    if (_ringtonePlaying) return;
    _ringtonePlaying = true;

    final payload = ref.read(incomingOrderProvider).payload;
    final title = payload?.title ?? 'Nouvelle commande';
    final body = payload?.body ?? '';

    // ACK "vu" — Phase 2 gap #1. Stoppe la cascade backend (WS → FCM
    // retries → SMS → Telegram admin) des que l'ecran est affiche, sans
    // attendre l'accept ou le reject. Idempotent + non-bloquant.
    // ignore: unawaited_futures
    ref.read(incomingOrderProvider.notifier).ackOnView();

    // Preferred path : service natif (loop + MediaPlayer custom).
    await IncomingRingBridge.startFake(title: title, body: body);

    // Fallback in-process : assure un son meme si le channel n'est pas dispo
    // (iOS, simulator, dev sans build natif). Le natif est idempotent donc
    // pas de double ring en production.
    try {
      await FlutterRingtonePlayer().play(
        android: AndroidSounds.alarm,
        ios: IosSounds.alarm,
        looping: true,
        volume: 1.0,
        asAlarm: true,
      );
    } catch (e) {
      debugPrint('[IncomingOrderScreen] ringtone fallback failed: $e');
    }

    // Vibration rythmee en continu en complement du son.
    await HapticFeedback.heavyImpact();
    _hapticTicker?.cancel();
    _hapticTicker = Timer.periodic(const Duration(milliseconds: 1100), (_) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
    });

    // Coupe la sonnerie apres _ringTimeout pour preserver la batterie.
    // L'ecran reste affiche — le partner peut toujours accepter/refuser.
    _ringTimeoutTimer?.cancel();
    _ringTimeoutTimer = Timer(_ringTimeout, () {
      if (mounted) _stopRinging();
    });
  }

  /// Coupe la sonnerie + la vibration.
  Future<void> _stopRinging() async {
    _hapticTicker?.cancel();
    _hapticTicker = null;
    if (!_ringtonePlaying) return;
    _ringtonePlaying = false;

    // Stop le service natif (source de verite Phase 4).
    await IncomingRingBridge.stop();
    // Stop le fallback in-process.
    try {
      await FlutterRingtonePlayer().stop();
    } catch (e) {
      debugPrint('[IncomingOrderScreen] ringtone fallback stop failed: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ringTimeoutTimer?.cancel();
    _stopRinging();
    super.dispose();
  }

  void _listenForAutoClose(IncomingOrderState state) {
    if (_dismissing) return;

    // Sur accept/reject, on coupe immediatement la sonnerie (feedback
    // immediat — le partner sait que l'action a ete prise en compte).
    if (state.phase != IncomingOrderPhase.ringing && _ringtonePlaying) {
      _stopRinging();
    }

    // Phases terminales → on ferme l'ecran et on reset le state.
    if (state.phase == IncomingOrderPhase.accepted ||
        state.phase == IncomingOrderPhase.rejected) {
      _dismissing = true;
      final wasAccepted = state.phase == IncomingOrderPhase.accepted;
      final code = state.payload?.orderCode ?? '';

      // Refresh la liste des commandes en arriere-plan.
      ref.read(ordersListProvider.notifier).refresh();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Routes.goBack();
        // Feedback apres fermeture.
        final ctx = Routes.navigatorKey.currentContext;
        if (ctx != null) {
          if (wasAccepted) {
            AppToast.showSuccess(
              context: ctx,
              message: code.isNotEmpty
                  ? 'Commande $code acceptée'
                  : 'Commande acceptée',
            );
          } else {
            AppToast.showWarning(
              context: ctx,
              message: code.isNotEmpty
                  ? 'Commande $code refusée'
                  : 'Commande refusée',
            );
          }
        }
        // Reset du provider apres fermeture.
        ref.read(incomingOrderProvider.notifier).dismiss();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(incomingOrderProvider);
    _listenForAutoClose(state);

    // Si aucun payload (ex: deep link direct, cold start apres bug FCM),
    // on ne ferme plus automatiquement — on affiche un ZeetErrorState
    // "Donnees incompletes" avec un CTA retour explicite, conforme ELOE.
    // Fermer silencieusement laissait l'utilisateur avec l'ecran
    // precedent sans explication.
    final payload = state.payload;
    if (payload == null) {
      return Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Theme(
            // Theme clair sur fond orange — ZeetErrorState utilise
            // onSurfaceVariant pour les icones + texte. On force un
            // ColorScheme blanc pour rester lisible.
            data: ThemeData(
              colorScheme: const ColorScheme.light(
                primary: _ink,
                onPrimary: _bg,
                surface: _bg,
                onSurface: _ink,
                onSurfaceVariant: Colors.white70,
              ),
              textTheme: Theme.of(context).textTheme.apply(
                    bodyColor: _ink,
                    displayColor: _ink,
                  ),
            ),
            child: ZeetErrorState(
              kind: ZeetErrorKind.parsing,
              title: 'Données incomplètes',
              description:
                  "On n'a pas pu afficher cette commande. Elle est peut-être "
                  'déjà dans votre liste. Revenez à l\'écran précédent.',
              retryLabel: 'Retour',
              onRetry: () => Routes.goBack(),
            ),
          ),
        ),
      );
    }

    // Bloque le retour systeme tant que le ringing est actif (pas de dodge
    // par le bouton retour).
    return PopScope(
      canPop: !state.isActive,
      child: Scaffold(
        backgroundColor: _bg,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bg, _bgDark],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(payload),
                  SizedBox(height: 24.h),
                  Expanded(
                    child: Center(child: _buildAmountBlock(payload)),
                  ),
                  _buildInfoRows(payload),
                  SizedBox(height: 20.h),
                  if (state.errorMessage != null) _buildErrorBanner(state),
                  _buildActions(state),
                  SizedBox(height: 8.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header — label "Nouvelle commande" + icone cloche pulsee
  // ---------------------------------------------------------------------------

  Widget _buildHeader(IncomingOrderPayload payload) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NOUVELLE COMMANDE',
                style: TextStyle(
                  color: _ink.withValues(alpha: 0.75),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                payload.orderCode.isNotEmpty
                    ? payload.orderCode
                    : '#${payload.orderId}',
                style: TextStyle(
                  color: _ink,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        _buildPulsingBell(),
      ],
    );
  }

  Widget _buildPulsingBell() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final scale = 1.0 + _pulseController.value * 0.18;
        final haloOpacity = (1.0 - _pulseController.value) * 0.35;
        return SizedBox(
          width: 72.w,
          height: 72.w,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Halo qui se propage
              Container(
                width: 72.w,
                height: 72.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _ink.withValues(alpha: haloOpacity),
                ),
              ),
              // Disque interieur
              Transform.scale(
                scale: scale,
                child: Container(
                  width: 52.w,
                  height: 52.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _ink,
                  ),
                  child: Icon(
                    Icons.notifications_active_rounded,
                    color: _bg,
                    size: 28.sp,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Amount block — total geant (focus principal)
  // ---------------------------------------------------------------------------

  Widget _buildAmountBlock(IncomingOrderPayload payload) {
    final formatted = _currency.format(payload.totalFcfa);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Total',
          style: TextStyle(
            color: _ink.withValues(alpha: 0.75),
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 8.h),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            formatted,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ink,
              fontSize: 64.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Info rows — nombre d'articles, body de la notif
  // ---------------------------------------------------------------------------

  Widget _buildInfoRows(IncomingOrderPayload payload) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: _ink.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: _ink.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.shopping_bag_outlined,
            label: payload.itemsCount > 0
                ? '${payload.itemsCount} article${payload.itemsCount > 1 ? 's' : ''}'
                : 'Nouvelle commande',
          ),
          if (payload.body.isNotEmpty) ...[
            SizedBox(height: 10.h),
            Divider(
              color: _ink.withValues(alpha: 0.2),
              height: 1,
            ),
            SizedBox(height: 10.h),
            _InfoRow(
              icon: Icons.info_outline_rounded,
              label: payload.body,
              multiline: true,
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Error banner
  // ---------------------------------------------------------------------------

  Widget _buildErrorBanner(IncomingOrderState state) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: _bgDark, size: 20.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              state.errorMessage ?? 'Erreur',
              style: TextStyle(
                color: _bgDark,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () =>
                ref.read(incomingOrderProvider.notifier).retryAfterError(),
            style: TextButton.styleFrom(
              foregroundColor: _bgDark,
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              minimumSize: Size(48.w, 36.h),
            ),
            child: Text(
              'Réessayer',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions — slide-to-accept + bouton refuser
  // ---------------------------------------------------------------------------

  Widget _buildActions(IncomingOrderState state) {
    final bool busy = state.isBusy;

    return Column(
      children: <Widget>[
        SlideToAcceptButton(
          key: ValueKey(state.payload?.orderId ?? 0),
          label: busy ? 'CONFIRMATION...' : 'GLISSER POUR ACCEPTER',
          enabled: !busy && state.phase == IncomingOrderPhase.ringing,
          onCompleted: () {
            ref.read(incomingOrderProvider.notifier).accept();
          },
        ),
        SizedBox(height: 14.h),
        // Refuser — ghost POS sur fond orange fixe (hors theme).
        // Hit target 56pt (skill zeet-pos-ergonomics §2.1), scale-on-press,
        // border blanc subtile pour glanceability sous stress / lumiere,
        // haptic warning (action destructive volontaire).
        _RejectGhostButton(
          enabled: !busy,
          onPressed: _showRejectDialog,
          foreground: _ink,
        ),
      ],
    );
  }

  Future<void> _showRejectDialog() async {
    // Pendant la saisie de la raison, on coupe la sonnerie pour ne pas hurler
    // au-dessus du bottom sheet. La sonnerie reprendra si le partner annule.
    await _stopRinging();
    if (!mounted) return;

    // Bottom sheet chips presets — même widget partagé que les 3 autres
    // call sites (home, orders, order_details). Zéro saisie clavier au
    // clavier pour refuser une commande entrante (issue M-14).
    final String? reason = await showCancelReasonSheet(context);

    if (!mounted) return;

    if (reason != null) {
      await ref.read(incomingOrderProvider.notifier).reject(reason: reason);
    } else {
      // Annulation → on relance la sonnerie, la commande est toujours active.
      if (ref.read(incomingOrderProvider).phase == IncomingOrderPhase.ringing) {
        await _startRinging();
      }
    }
  }
}

/// Bouton ghost custom adapte a l'ecran incoming_order (fond orange fixe,
/// hors theme). Remplace un `TextButton` underline sous-dimensionne :
/// - hit target 56pt (skill zeet-pos-ergonomics §2.1)
/// - scale-on-press + haptic warning (action destructive volontaire)
/// - border blanc subtile + fg blanc plein : glanceable sous stress/gants
/// - `Semantics(button: true)` explicite + `reduceMotion` respecte
class _RejectGhostButton extends StatefulWidget {
  const _RejectGhostButton({
    required this.enabled,
    required this.onPressed,
    required this.foreground,
  });

  final bool enabled;
  final Future<void> Function() onPressed;
  final Color foreground;

  @override
  State<_RejectGhostButton> createState() => _RejectGhostButtonState();
}

class _RejectGhostButtonState extends State<_RejectGhostButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.of(context).disableAnimations;
    final Color fg = widget.foreground;
    final bool enabled = widget.enabled;

    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Refuser la commande',
      child: ExcludeSemantics(
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: reduceMotion ? Duration.zero : ZeetMotion.xs,
          curve: ZeetCurves.standard,
          child: Material(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ZeetRadius.md),
              side: BorderSide(
                color: fg.withValues(alpha: enabled ? 0.45 : 0.2),
                width: 1.2,
              ),
            ),
            child: InkWell(
              onTapDown: enabled ? (_) => _setPressed(true) : null,
              onTapUp: enabled ? (_) => _setPressed(false) : null,
              onTapCancel: enabled ? () => _setPressed(false) : null,
              onTap: enabled
                  ? () {
                      ZeetHaptics.warning();
                      widget.onPressed();
                    }
                  : null,
              borderRadius: BorderRadius.circular(ZeetRadius.md),
              splashColor: fg.withValues(alpha: 0.10),
              highlightColor: fg.withValues(alpha: 0.06),
              child: Container(
                height: 56,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(
                  horizontal: ZeetSpacing.x5,
                ),
                child: Text(
                  'Refuser la commande',
                  style: TextStyle(
                    color: fg.withValues(alpha: enabled ? 1.0 : 0.5),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool multiline;

  const _InfoRow({
    required this.icon,
    required this.label,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 20.sp),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            label,
            maxLines: multiline ? 3 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
