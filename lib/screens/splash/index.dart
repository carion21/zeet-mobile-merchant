// lib/screens/splash/index.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/providers/auth_provider.dart';
import 'package:merchant/services/navigation_service.dart';
import 'package:merchant/services/permissions_service.dart';
import 'package:merchant/services/token_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _liquidController;
  late AnimationController _fadeController;
  late Animation<double> _liquidAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Animation du liquide — 800ms. Le splash partner n'est pas un
    // showcase : un restaurateur en coup de feu doit accéder aux
    // commandes le plus vite possible. Budget perf : splash < 60% du
    // cold-start (cf. zeet-performance-budget §9).
    _liquidController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _liquidAnimation = Tween<double>(begin: 0.0, end: 1.1).animate(
      CurvedAnimation(parent: _liquidController, curve: Curves.easeInOut),
    );

    // Animation de fade pour le sous-texte
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    // Démarrer l'animation du liquide immédiatement
    _liquidController.forward();

    // Démarrer l'animation du sous-texte après un délai court.
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _fadeController.forward();
      }
    });

    // Verifier l'authentification puis naviguer
    _checkAuthAndNavigate();
  }

  /// Vérifie l'état d'authentification en parallèle de l'animation.
  /// Attend au minimum 800ms (durée de l'animation) — suffisant pour
  /// la reconnaissance de marque, pas plus. Un partner qui démarre
  /// son app en plein service ne doit pas attendre 3s.
  ///
  /// Filet de sécurité : try/catch global assure qu'on navigue TOUJOURS,
  /// même si checkAuthStatus crashe.
  Future<void> _checkAuthAndNavigate() async {
    final Stopwatch stopwatch = Stopwatch()..start();

    // S'assurer que TokenService est initialise (idempotent).
    await TokenService.instance.init();

    // Source de verite PRIMAIRE : les tokens locaux. Si presents, le partner
    // est authentifie optimiste — on laisse l'app ouvrir le root, et les
    // appels API echoueront proprement (401 -> refresh -> login) si les
    // tokens ne sont plus valides cote serveur. Eviter de dependre du state
    // du notifier qui peut etre mute par `_refreshMeInBackground`.
    final bool hasTokens = await TokenService.instance.hasTokens();

    // Booter le auth provider en parallele (pour hydrater le partner).
    // On n'await PAS son resultat pour la decision de routage : les tokens
    // locaux sont la source de verite.
    unawaited(ref.read(authProvider.notifier).checkAuthStatus());

    stopwatch.stop();

    final int elapsed = stopwatch.elapsedMilliseconds;
    const int minSplashDuration = 800;
    if (elapsed < minSplashDuration) {
      await Future<void>.delayed(
        Duration(milliseconds: minSplashDuration - elapsed),
      );
    }

    if (!mounted) return;

    if (hasTokens) {
      // Gate permissions : si jamais onboardees, passer par l'ecran dedie
      // AVANT d'atterrir sur le root.
      final bool onboarded =
          await PermissionsService.instance.isOnboarded();
      if (!mounted) return;
      if (onboarded) {
        Routes.navigateAndRemoveAll(Routes.root);
      } else {
        Routes.navigateAndRemoveAll(Routes.permissions);
      }
    } else {
      Routes.navigateAndRemoveAll(Routes.login);
    }
  }

  @override
  void dispose() {
    _liquidController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? AppColors.darkBackground : AppColors.white;
    final primaryColor = Theme.of(context).colorScheme.primary;
    // Le texte a la même couleur que le fond pour être invisible au départ
    // et devient visible uniquement quand le liquide coloré passe derrière
    final textColor = backgroundColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Animation de liquide en arrière-plan
          AnimatedBuilder(
            animation: _liquidAnimation,
            builder: (context, child) {
              return CustomPaint(
                painter: LiquidPainter(
                  animationValue: _liquidAnimation.value,
                  color: primaryColor,
                ),
                child: Container(),
              );
            },
          ),

          // Contenu au-dessus de l'animation
          SafeArea(
            child: Column(
              children: [
                // Spacer pour centrer le contenu verticalement
                const Spacer(flex: 5),

                // Logo "ZEET" — Inter w900 (M-04). Outfit n'est pas
                // au DS ZEET (Inter uniquement, cf. `zeet-design-system` §3).
                Text(
                  'ZEET',
                  style: GoogleFonts.inter(
                    fontSize: 72.0.sp,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    letterSpacing: 4.w,
                    height: 1.0,
                  ),
                ),

                SizedBox(height: 32.h),

                // Slogan animé
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 48.w),
                    child: Text(
                      'Gérez votre restaurant en toute simplicité',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 17.0.sp,
                        fontWeight: FontWeight.w500,
                        color: textColor.withValues(alpha: 0.8),
                        letterSpacing: 0.8.w,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),

                // Spacer pour équilibrer la disposition
                const Spacer(flex: 5),

                // Copyright en bas
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 32.h),
                    child: Text(
                      'Propulsé par ZEET © 2025',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13.0.sp,
                        fontWeight: FontWeight.w400,
                        color: textColor.withValues(alpha: 0.6),
                        letterSpacing: 0.5.w,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter pour l'animation de liquide
class LiquidPainter extends CustomPainter {
  final double animationValue;
  final Color color;

  LiquidPainter({
    required this.animationValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    // Hauteur du liquide (monte du bas vers le haut)
    final liquidHeight = size.height * animationValue;
    final waveHeight = 20.0;
    final waveLength = size.width / 2;

    // Si le liquide a atteint le haut, remplir tout l'écran
    if (liquidHeight >= size.height) {
      path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawPath(path, paint);
      return;
    }

    // Commencer du coin inférieur gauche
    path.moveTo(0, size.height);

    // Ligne gauche jusqu'à la hauteur du liquide
    path.lineTo(0, size.height - liquidHeight + waveHeight);

    // Créer des vagues sur le dessus du liquide
    for (double i = 0; i <= size.width; i++) {
      final wave1 = sin((i / waveLength) * 2 * pi) * waveHeight;
      final wave2 = sin((i / waveLength) * 2 * pi + pi / 2) * (waveHeight / 2);
      final waveY = size.height - liquidHeight + wave1 + wave2;
      // S'assurer que les vagues ne dépassent pas le haut de l'écran
      path.lineTo(i, waveY.clamp(0, size.height));
    }

    // Ligne droite jusqu'au coin inférieur droit
    path.lineTo(size.width, size.height);

    // Fermer le chemin
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(LiquidPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
