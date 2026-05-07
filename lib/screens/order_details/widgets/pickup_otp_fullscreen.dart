// PickupOtpFullscreen — affichage plein ecran du code OTP de collecte
// pour la cuisine.
//
// Phase 2 gap #2 : le code OTP a 4 chiffres doit etre lisible **a 1 metre
// de distance** (cuisine bruyante, partner qui dicte sans regarder l'ecran).
// L'ancienne implementation affichait le code en `fontSize: 32sp` dans une
// section parmi d'autres du detail commande — illisible en condition reelle.
//
// Specs :
//  - Code en font 96sp+ bold, letterSpacing 16, contraste max.
//  - Bouton "Lire a voix haute" (TTS) : "un, deux, trois, quatre".
//  - Bouton "Renvoyer" avec cooldown 60s en cas de 429
//    `ERR_OTP_RESEND_RATE_LIMITED` (cf. orders_provider.tickOtpCooldown).
//  - Affichage de l'expiration relative ("Expire dans 12 min").
//  - Fermeture par geste swipe-down + bouton croix en haut a droite.
//
// Skill check :
//  - zeet-pos-ergonomics : OTP lisible a 1m, hit targets 56pt+, haptics.
//  - zeet-states-elae : loading skeleton si OTP pas encore fetched, error
//    state si fetch echoue.
//  - zeet-micro-copy : ton sobre partner, vouvoiement, "Renvoyer" not
//    "Re-envoyer".
//  - zeet-design-system : tokens couleur ZEET, surface neutre fond clair,
//    primary orange pour le code.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/models/order_model.dart' show PickupOtpResponse;
import 'package:merchant/providers/orders_provider.dart';
import 'package:merchant/services/navigation_service.dart';
import 'package:merchant/services/tts_service.dart';
import 'package:zeet_ui/zeet_ui.dart';

class PickupOtpFullscreen extends ConsumerStatefulWidget {
  /// Identifiant de la commande pour fetch / resend.
  final int orderId;

  /// Code de la commande (affiche en header).
  final String? orderCode;

  const PickupOtpFullscreen({
    super.key,
    required this.orderId,
    this.orderCode,
  });

  @override
  ConsumerState<PickupOtpFullscreen> createState() =>
      _PickupOtpFullscreenState();
}

class _PickupOtpFullscreenState extends ConsumerState<PickupOtpFullscreen> {
  Timer? _cooldownTicker;

  /// Garde-fou : on ne dicte le code automatiquement qu'une seule fois par
  /// session d'ouverture de l'ecran. Reset si le code change (renvoi).
  String? _autoSpokenCode;

  @override
  void initState() {
    super.initState();
    // Fetch immediatement si pas encore en state. Le notifier met a jour
    // pickupOtp; on lit avec ref.watch() dans build().
    Future.microtask(() {
      final state = ref.read(orderDetailProvider(widget.orderId));
      if (state.pickupOtp == null) {
        ref
            .read(orderDetailProvider(widget.orderId).notifier)
            .getPickupOtp(widget.orderId);
      }
    });

    // Tick du cooldown 1x/sec pour mettre a jour l'UI (countdown visible).
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      ref
          .read(orderDetailProvider(widget.orderId).notifier)
          .tickOtpCooldown();
      // Force le rebuild pour rafraichir l'affichage du countdown.
      setState(() {});
    });
  }

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    // Stop la lecture TTS si l'utilisateur ferme l'ecran pendant la
    // diction. La service est singleton mais pas dispose ici (peut etre
    // reutilise sur d'autres ecrans).
    TtsService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderDetailProvider(widget.orderId));
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    final otp = state.pickupOtp;
    final code = otp?.otp;
    final hasCode = code != null && code.isNotEmpty;
    final cooldownSec = state.otpResendCooldownSeconds;
    final canResend = state.canResendOtp;

    // Auto-dictation au 1er affichage ou apres un renvoi (code change).
    // Skill `zeet-pos-ergonomics` §2.9 : cuisine bruyante, le partner ne
    // doit pas avoir a chercher le bouton "Lire" — l'app dicte d'elle-meme.
    if (hasCode && _autoSpokenCode != code) {
      _autoSpokenCode = code;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ZeetHaptics.success();
        TtsService.instance.speakOtp(code);
      });
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // ─── Header : code commande + close ────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 8.w, 8.h),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'CODE DE COLLECTE',
                          style: tt.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            fontSize: 12.sp,
                          ),
                        ),
                        if (widget.orderCode != null) ...<Widget>[
                          SizedBox(height: 2.h),
                          Text(
                            'Commande ${widget.orderCode}',
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    iconSize: 28.sp,
                    onPressed: () {
                      ZeetHaptics.tap();
                      Routes.goBack();
                    },
                    icon: Icon(
                      Icons.close_rounded,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),

            // ─── Corps : OTP geant ou etat ELOE ────────────────────────
            Expanded(
              child: hasCode
                  ? _buildOtpDisplay(context, otp!, code)
                  : _buildLoadingOrError(context, state),
            ),

            // ─── CTAs bas : TTS + Renvoyer ─────────────────────────────
            if (hasCode)
              _buildBottomActions(
                context: context,
                code: code,
                canResend: canResend,
                cooldownSec: cooldownSec,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpDisplay(
    BuildContext context,
    PickupOtpResponse otp,
    String code,
  ) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    final expiresIn = _formatExpiresIn(otp.expiresAtDateTime);

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Dictez ce code au livreur',
              textAlign: TextAlign.center,
              style: tt.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 24.h),
            // ─── OTP geant — focus principal de l'ecran ────────────────
            // Font scale a la largeur ecran, FittedBox pour rester dans
            // le viewport meme sur petits screens.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: SelectableText(
                _spaceOut(code),
                style: TextStyle(
                  fontSize: 128.sp,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: 4,
                  height: 1,
                ),
                semanticsLabel: 'Code de collecte ${_spaceOut(code)}',
              ),
            ),
            SizedBox(height: 24.h),
            if (expiresIn != null)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 6.h,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.timer_outlined,
                      size: 16.sp,
                      color: scheme.onSurfaceVariant,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      expiresIn,
                      style: tt.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            if (otp.attemptCount != null && otp.maxAttempts != null) ...<Widget>[
              SizedBox(height: 12.h),
              Text(
                '${otp.attemptCount} / ${otp.maxAttempts} tentatives',
                style: tt.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOrError(BuildContext context, OrderDetailState state) {
    if (state.actionError != null) {
      return ZeetErrorState(
        kind: ZeetErrorKind.generic,
        title: 'Code indisponible',
        description: state.actionError ?? 'Reessayez dans un instant.',
        retryLabel: 'Reessayer',
        onRetry: () {
          ref
              .read(orderDetailProvider(widget.orderId).notifier)
              .getPickupOtp(widget.orderId);
        },
      );
    }
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const CircularProgressIndicator(),
            SizedBox(height: 16.h),
            Text(
              'Generation du code...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions({
    required BuildContext context,
    required String code,
    required bool canResend,
    required int cooldownSec,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ZeetButton.primary(
            label: 'Lire a voix haute',
            icon: Icons.volume_up_rounded,
            size: ZeetButtonSize.lg,
            fullWidth: true,
            onPressed: () => _speakCode(code),
          ),
          SizedBox(height: 12.h),
          ZeetButton(
            label: canResend
                ? 'Renvoyer le code'
                : 'Reessayez dans ${cooldownSec}s',
            icon: Icons.refresh_rounded,
            variant: ZeetButtonVariant.secondary,
            size: ZeetButtonSize.lg,
            fullWidth: true,
            onPressed: canResend ? _resendCode : null,
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Actions
  // ───────────────────────────────────────────────────────────────────

  Future<void> _speakCode(String code) async {
    ZeetHaptics.tap();
    final ok = await TtsService.instance.speakOtp(code);
    if (!ok && mounted) {
      AppToast.showInfo(
        context: context,
        message: 'Lecture audio indisponible sur cet appareil.',
      );
    }
  }

  Future<void> _resendCode() async {
    ZeetHaptics.warning();
    final ok = await ref
        .read(orderDetailProvider(widget.orderId).notifier)
        .resendPickupOtp(widget.orderId);
    if (!mounted) return;
    if (ok) {
      ZeetHaptics.success();
      AppToast.showSuccess(
        context: context,
        message: 'Nouveau code envoye au livreur.',
      );
    } else {
      final err = ref.read(orderDetailProvider(widget.orderId)).actionError;
      AppToast.showWarning(
        context: context,
        message: err ?? 'Renvoi impossible. Reessayez plus tard.',
      );
    }
  }

  // ───────────────────────────────────────────────────────────────────
  // Helpers d'affichage
  // ───────────────────────────────────────────────────────────────────

  /// Formatte le code OTP avec un espace tous les 2 chiffres pour faciliter
  /// la lecture (ex: "1234" -> "12 34", "123456" -> "12 34 56").
  String _spaceOut(String code) {
    if (code.length <= 4) {
      // Pour 4 chiffres, on espace au milieu : "1234" -> "12 34"
      if (code.length == 4) {
        return '${code.substring(0, 2)} ${code.substring(2)}';
      }
      return code;
    }
    final buffer = StringBuffer();
    for (int i = 0; i < code.length; i++) {
      if (i > 0 && i % 2 == 0) buffer.write(' ');
      buffer.write(code[i]);
    }
    return buffer.toString();
  }

  /// Format relatif "Expire dans X min" / "Expire dans X s" ou null si
  /// expire ou pas de date.
  String? _formatExpiresIn(DateTime? expiresAt) {
    if (expiresAt == null) return null;
    final diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) return 'Code expire';
    if (diff.inMinutes >= 1) {
      return 'Expire dans ${diff.inMinutes} min';
    }
    final secs = diff.inSeconds;
    return 'Expire dans ${secs}s';
  }
}
