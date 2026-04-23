// Ecran "Incoming Order" — redesign full-power (skills ZEET charges).
//
// Principes appliques :
//  - Plein ecran orange ZEET avec dark gradient bas (priming couleur, focus)
//  - Z-pattern POS : badge pulse top-left, cloche pulse top-right, total
//    geant center, details cards middle, slide + refuser bottom
//  - Sonnerie systeme en boucle (service natif + fallback FlutterRingtonePlayer)
//  - Timer countdown visible (lineaire horizontal) : urgence veridique,
//    loss aversion — neuro-UX §5 et §12bis.D. Couleur degrade vert→rouge.
//  - `ZeetPulse` sur le badge "NOUVELLE COMMANDE" (pos-ergonomics §2bis)
//  - `ZeetRollingCounter` sur le total (motion §6 + neuro §12bis.A dopamine)
//  - Progressive disclosure : detail commande (client, items, adresse) fetche
//    en parallele via `orderDetailProvider.family`. Skeleton si loading,
//    fallback sur payload basic si erreur — states-elae §6.
//  - reduceMotion respecte partout (motion §14)
//  - RepaintBoundary sur chaque widget anime (perf-budget §3)
//  - Haptics semantiques via ZeetHaptics (gesture-grammar §4)
//  - Micro-copy partner pro / sobre (micro-copy §2)
//  - Hit targets POS ≥ 56pt (pos-ergonomics §2.1)
//  - Tokens : ZeetMotion, ZeetRadius, ZeetSpacing — zero magic number
//
// Wiring : ecoute [incomingOrderProvider] (state metier) +
// [orderDetailProvider] (enrichissement). Logique API / accept / reject
// reste dans le notifier.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:merchant/core/widgets/cancel_reason_sheet.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/models/incoming_order_payload.dart';
import 'package:merchant/models/order_model.dart';
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
    with TickerProviderStateMixin {
  // Couleurs fixes ecran — ne suivent pas le dark mode (ecran de focus POS
  // critique, doit etre reconnaissable instantanement, identite orange ZEET).
  static const Color _bg = Color(0xFFFF5A1F);
  static const Color _bgDark = Color(0xFFE64A0F);
  static const Color _ink = Colors.white;

  /// Sonnerie max avant arret auto (batterie). L'ecran reste — le partner
  /// peut toujours accepter/refuser apres.
  static const Duration _ringTimeout = Duration(seconds: 90);

  /// Compte-a-rebours de decision visible par l'utilisateur (differe du
  /// [_ringTimeout] qui est purement cote sonnerie). Meme duree par defaut
  /// pour simplicite mentale, mais l'ecran reste affiche apres 0s.
  static const int _decisionTimerSeconds = 90;

  late final AnimationController _bellPulseController;
  Timer? _hapticTicker;
  Timer? _ringTimeoutTimer;
  Timer? _decisionTicker;
  int _decisionRemaining = _decisionTimerSeconds;
  bool _ringtonePlaying = false;
  bool _dismissing = false;

  /// Derniere cle rolling counter — on part de 0 -> total une seule fois
  /// a l'apparition du payload (pas a chaque rebuild sinon on re-anime
  /// depuis 0 en boucle et le chiffre clignote).
  int? _rollingAnimatedForOrderId;

  @override
  void initState() {
    super.initState();
    _bellPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRinging();
      _startDecisionTimer();
      _prefetchOrderDetail();
    });
  }

  /// Prefetch du detail de commande en arriere-plan pour enrichir l'ecran
  /// (client, items, adresse) des qu'il est disponible. Non bloquant :
  /// l'UI fonctionne sans (fallback payload basic). Skill states-elae §6
  /// "progressive disclosure".
  void _prefetchOrderDetail() {
    final payload = ref.read(incomingOrderProvider).payload;
    if (payload == null) return;
    try {
      ref.read(orderDetailProvider(payload.orderId).notifier).load(
            payload.orderId,
            fromNotificationId: payload.notificationId > 0
                ? payload.notificationId
                : null,
          );
    } catch (e) {
      debugPrint('[IncomingOrderScreen] orderDetail prefetch failed: $e');
    }
  }

  /// Lance la sonnerie en boucle + la vibration continue.
  ///
  /// Phase 4 : l'ecran est typiquement ouvert apres un tap sur notif FSI
  /// natif (service natif deja en cours) OU un trigger Flutter foreground
  /// (FcmService.onMessage). Les deux branches sont idempotentes.
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

    // Vibration rythmee en continu en complement du son. Obligatoire pos
    // ergonomics §2bis (haptic = feedback primaire sous bruit cuisine).
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

  /// Lance le compte-a-rebours visible utilisateur. Ne ferme pas l'ecran
  /// a 0 — continue d'afficher un badge "Decision en attente". L'urgence
  /// visible (neuro §5) pousse a decider, sans etre bloquante.
  void _startDecisionTimer() {
    _decisionTicker?.cancel();
    setState(() => _decisionRemaining = _decisionTimerSeconds);
    _decisionTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_decisionRemaining <= 0) {
        _decisionTicker?.cancel();
        return;
      }
      setState(() => _decisionRemaining -= 1);
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
    _bellPulseController.dispose();
    _ringTimeoutTimer?.cancel();
    _decisionTicker?.cancel();
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
    // on affiche un ZeetErrorState "Donnees incompletes" avec un CTA
    // retour explicite, conforme states-elae. Fermer silencieusement
    // laissait l'utilisateur avec l'ecran precedent sans explication.
    final payload = state.payload;
    if (payload == null) return _buildNoPayloadFallback(context);

    // Fetch enrichissement — AsyncValue-like State via StateNotifier.
    final OrderDetailState detailState =
        ref.watch(orderDetailProvider(payload.orderId));

    // Bloque le retour systeme tant que le ringing est actif (pas de dodge
    // par le bouton retour / swipe back iOS).
    return PopScope(
      canPop: !state.isActive,
      child: Scaffold(
        backgroundColor: _bg,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[_bg, _bgDark],
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildHeader(payload),
                _buildDecisionTimer(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 8.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _buildAmountBlock(payload),
                        SizedBox(height: 16.h),
                        _buildSummaryCard(payload, detailState),
                        SizedBox(height: 12.h),
                        _buildDetailSection(detailState),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 8.h,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (state.errorMessage != null) _buildErrorBanner(state),
                      _buildActions(state),
                      SizedBox(height: 8.h),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoPayloadFallback(BuildContext context) {
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

  // ---------------------------------------------------------------------------
  // Header — badge pulse "NOUVELLE COMMANDE" + code + cloche pulsee
  // ---------------------------------------------------------------------------

  Widget _buildHeader(IncomingOrderPayload payload) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // ZeetPulse : border blanc qui respire en boucle autour du
                // badge — capte l'oeil immediatement meme en vision peripherique
                // (pos-ergonomics §2bis pulse d'attention).
                ZeetPulse(
                  active: true,
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ZeetRadius.pill),
                  minWidth: 1.0,
                  maxWidth: 2.5,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(ZeetRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 8.w,
                          height: 8.w,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'NOUVELLE COMMANDE',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  payload.orderCode.isNotEmpty
                      ? payload.orderCode
                      : '#${payload.orderId}',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          RepaintBoundary(child: _buildPulsingBell()),
        ],
      ),
    );
  }

  Widget _buildPulsingBell() {
    final bool reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      // Statique mais bien visible — feedback non-anime (a11y §14).
      return Container(
        width: 56.w,
        height: 56.w,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: _ink,
        ),
        child: Icon(
          Icons.notifications_active_rounded,
          color: _bg,
          size: 28.sp,
        ),
      );
    }
    return AnimatedBuilder(
      animation: _bellPulseController,
      builder: (BuildContext context, _) {
        final double scale = 1.0 + _bellPulseController.value * 0.16;
        final double haloOpacity = (1.0 - _bellPulseController.value) * 0.35;
        return SizedBox(
          width: 72.w,
          height: 72.w,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                width: 72.w,
                height: 72.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _ink.withValues(alpha: haloOpacity),
                ),
              ),
              Transform.scale(
                scale: scale,
                child: Container(
                  width: 52.w,
                  height: 52.w,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _ink,
                  ),
                  child: Icon(
                    Icons.notifications_active_rounded,
                    color: _bg,
                    size: 26.sp,
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
  // Timer countdown — progress ring horizontal + temps restant
  // ---------------------------------------------------------------------------
  //
  // Urgence veridique (neuro §5) : affiche un decompte qui informe le
  // partner qu'une decision est attendue dans X. Ne ferme PAS l'ecran a 0,
  // change juste le label en "Décision en attente" — on ne bloque jamais
  // une commande qui attend encore cote backend.
  //
  // Couleur degrade vert (>= 60s) → orange (>= 20s) → rouge (< 20s), skill
  // pos-ergonomics §2bis "timer rings" (loss aversion sans etre punitif).

  Widget _buildDecisionTimer() {
    final bool expired = _decisionRemaining <= 0;
    final double progress = (_decisionRemaining / _decisionTimerSeconds)
        .clamp(0.0, 1.0);
    final Color tint = _timerTint(_decisionRemaining);
    final String label = expired
        ? 'Décision en attente'
        : 'Décidez dans ${_formatMMSS(_decisionRemaining)}';

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                expired ? Icons.hourglass_bottom_rounded : Icons.timer_rounded,
                color: _ink.withValues(alpha: 0.85),
                size: 16.sp,
                semanticLabel: expired ? 'En attente' : 'Chronometre',
              ),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(
                  color: _ink,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          RepaintBoundary(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ZeetRadius.pill),
              child: Stack(
                children: <Widget>[
                  Container(
                    height: 6.h,
                    color: _ink.withValues(alpha: 0.18),
                  ),
                  AnimatedFractionallySizedBox(
                    // Tween doux sur la valeur — la valeur descend par
                    // paliers d'1s mais l'animation lisse le changement
                    // (evite l'effet "saccade").
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.linear,
                    alignment: Alignment.centerLeft,
                    widthFactor: expired ? 0 : progress,
                    child: Container(
                      height: 6.h,
                      decoration: BoxDecoration(
                        color: tint,
                        borderRadius: BorderRadius.circular(ZeetRadius.pill),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _timerTint(int remaining) {
    if (remaining <= 0) return Colors.white.withValues(alpha: 0.5);
    if (remaining <= 20) return const Color(0xFFFFB4B4); // rouge clair
    if (remaining <= 60) return const Color(0xFFFFD87A); // orange clair
    return const Color(0xFFB7F5C9); // vert clair (sur fond orange = lisible)
  }

  String _formatMMSS(int s) {
    final int m = s ~/ 60;
    final int r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // Amount block — total geant (focus principal, peak visuel)
  // ---------------------------------------------------------------------------
  //
  // ZeetRollingCounter : anime de 0 vers le total a l'apparition
  // (neuro §12bis.A dopamine d'anticipation + motion §6 rolling numbers).
  // Une seule fois par orderId pour eviter le clignotement sur rebuild.

  Widget _buildAmountBlock(IncomingOrderPayload payload) {
    final bool reduceMotion = MediaQuery.of(context).disableAnimations;
    final bool firstTimeForThisOrder =
        _rollingAnimatedForOrderId != payload.orderId;
    if (firstTimeForThisOrder) {
      // Marque fait — evite d'animer a chaque build (sinon le chiffre
      // re-roule a partir de 0 apres chaque setState du timer).
      _rollingAnimatedForOrderId = payload.orderId;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'Total',
          style: TextStyle(
            color: _ink.withValues(alpha: 0.75),
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        SizedBox(height: 6.h),
        RepaintBoundary(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: (reduceMotion || !firstTimeForThisOrder)
                ? Text(
                    _formatFcfa(payload.totalFcfa),
                    style: _amountStyle(),
                    textAlign: TextAlign.center,
                  )
                : ZeetRollingCounter(
                    value: payload.totalFcfa,
                    suffix: ' FCFA',
                    style: _amountStyle(),
                    color: _ink,
                  ),
          ),
        ),
      ],
    );
  }

  TextStyle _amountStyle() => TextStyle(
        color: _ink,
        fontSize: 64.sp,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.5,
        height: 1,
      );

  String _formatFcfa(int v) {
    // Separation milliers par espace insecable (micro-copy §10).
    final String s = v.toString();
    final StringBuffer b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final int posFromEnd = s.length - i;
      b.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) {
        b.write('\u00A0');
      }
    }
    return '${b.toString()} FCFA';
  }

  // ---------------------------------------------------------------------------
  // Summary card — ligne de chips (articles, paiement, mode livraison)
  // ---------------------------------------------------------------------------

  Widget _buildSummaryCard(
    IncomingOrderPayload payload,
    OrderDetailState detailState,
  ) {
    final Order? order = detailState.order;
    final int itemsCount = order?.items.length ?? payload.itemsCount;
    final String articleLabel = itemsCount > 0
        ? '$itemsCount article${itemsCount > 1 ? 's' : ''}'
        : 'Commande reçue';
    final String? paymentLabel = order?.paymentMethod?.displayLabel;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: _ink.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(ZeetRadius.md),
        border: Border.all(
          color: _ink.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Wrap(
        spacing: 10.w,
        runSpacing: 8.h,
        children: <Widget>[
          _summaryChip(Icons.shopping_bag_outlined, articleLabel),
          if (paymentLabel != null && paymentLabel.isNotEmpty)
            _summaryChip(Icons.payments_outlined, paymentLabel),
          if (payload.body.isNotEmpty && order == null)
            _summaryChip(Icons.info_outline_rounded, payload.body,
                maxLines: 2),
        ],
      ),
    );
  }

  Widget _summaryChip(IconData icon, String label, {int maxLines = 1}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: _ink.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(ZeetRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: _ink.withValues(alpha: 0.9), size: 16.sp),
          SizedBox(width: 6.w),
          Flexible(
            child: Text(
              label,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _ink,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Detail section — progressive disclosure (client, items preview, adresse)
  // ---------------------------------------------------------------------------
  //
  // Patterns states-elae §6 : loading = skeleton inline, error silencieuse
  // (fallback payload basic deja affiche au-dessus), data = enrichissement.
  // Pas d'encombrement de l'ecran sous stress — on affiche uniquement ce
  // qui accelere la decision (qui commande, quoi, ou).

  Widget _buildDetailSection(OrderDetailState state) {
    if (state.status == OrderDetailStatus.loading && state.order == null) {
      return _buildDetailSkeleton();
    }
    final Order? order = state.order;
    if (order == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ZeetRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (order.customer?.fullName.isNotEmpty == true)
            _detailLine(
              icon: Icons.person_rounded,
              label: order.customer!.fullName,
              bold: true,
            ),
          if (order.position?.dropoffAddress?.isNotEmpty == true) ...<Widget>[
            SizedBox(height: 6.h),
            _detailLine(
              icon: Icons.place_outlined,
              label: order.position!.dropoffAddress!,
              multiline: true,
            ),
          ],
          if (order.items.isNotEmpty) ...<Widget>[
            SizedBox(height: 10.h),
            Divider(color: _bgDark.withValues(alpha: 0.12), height: 1),
            SizedBox(height: 10.h),
            ..._buildItemsPreview(order.items),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildItemsPreview(List<OrderItem> items) {
    // Preview max 3 items — au-dela l'info est perdue sous stress. Le reste
    // est resume par "+N autres". Charge cognitive 7±2 (neuro §1).
    final int visibleCount = items.length > 3 ? 3 : items.length;
    final List<Widget> lines = <Widget>[];
    for (int i = 0; i < visibleCount; i++) {
      final OrderItem item = items[i];
      lines.add(_itemLine(item));
      if (i < visibleCount - 1) lines.add(SizedBox(height: 6.h));
    }
    if (items.length > visibleCount) {
      lines.add(SizedBox(height: 6.h));
      lines.add(
        Text(
          '+ ${items.length - visibleCount} autre${items.length - visibleCount > 1 ? 's' : ''}',
          style: TextStyle(
            color: _bgDark.withValues(alpha: 0.72),
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    return lines;
  }

  Widget _itemLine(OrderItem item) {
    final String name = item.productName ?? 'Article';
    final int qty = item.quantity;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 24.w,
          height: 24.w,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _bg.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(ZeetRadius.sm),
          ),
          child: Text(
            '×$qty',
            style: TextStyle(
              color: _bgDark,
              fontSize: 12.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _bgDark,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailLine({
    required IconData icon,
    required String label,
    bool bold = false,
    bool multiline = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: _bgDark.withValues(alpha: 0.75), size: 18.sp),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            label,
            maxLines: multiline ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _bgDark,
              fontSize: 14.sp,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailSkeleton() {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(ZeetRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ZeetSkeleton(width: 160.w, height: 14.h),
          SizedBox(height: 8.h),
          ZeetSkeleton(width: 220.w, height: 12.h),
          SizedBox(height: 12.h),
          ZeetSkeleton(width: 140.w, height: 12.h),
          SizedBox(height: 6.h),
          ZeetSkeleton(width: 180.w, height: 12.h),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Error banner (inline, inchanged from legacy — polish tokens)
  // ---------------------------------------------------------------------------

  Widget _buildErrorBanner(IncomingOrderState state) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ZeetRadius.md),
      ),
      child: Row(
        children: <Widget>[
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
              minimumSize: Size(48.w, 40.h),
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
  // Actions — slide-to-accept + refuser ghost
  // ---------------------------------------------------------------------------

  Widget _buildActions(IncomingOrderState state) {
    final bool busy = state.isBusy;

    return Column(
      children: <Widget>[
        SlideToAcceptButton(
          key: ValueKey<int>(state.payload?.orderId ?? 0),
          label: busy ? 'CONFIRMATION...' : 'GLISSER POUR ACCEPTER',
          enabled: !busy && state.phase == IncomingOrderPhase.ringing,
          onCompleted: () {
            ref.read(incomingOrderProvider.notifier).accept();
          },
        ),
        SizedBox(height: 12.h),
        // Refuser — ghost POS sur fond orange fixe (hors theme).
        // Hit target 56pt (pos-ergonomics §2.1), scale-on-press,
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
