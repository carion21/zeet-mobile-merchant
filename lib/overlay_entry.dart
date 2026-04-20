// lib/overlay_entry.dart
//
// Point d'entree Dart separe pour la bulle flottante chat-head
// (flutter_overlay_window). Tourne dans un engine Flutter isole, ne partage
// ni providers ni state avec le main isolate.
//
// Communication avec le main isolate via FlutterOverlayWindow.shareData :
// - Le main envoie {"count": 3, "title": "..."} pour mettre a jour la bulle.
// - La bulle envoie {"action": "open_app"} au tap pour demander l'ouverture.
//
// POS ergo (§1-2) : hit target 64pt, couleur + icone + badge chiffre.
// Motion partner (§3) : pulse rouge pour nouvelle commande (fonctionnel).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _OverlayApp());
}

class _OverlayApp extends StatelessWidget {
  const _OverlayApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: _OrderBubble(),
      ),
    );
  }
}

class _OrderBubble extends StatefulWidget {
  const _OrderBubble();

  @override
  State<_OrderBubble> createState() => _OrderBubbleState();
}

class _OrderBubbleState extends State<_OrderBubble>
    with SingleTickerProviderStateMixin {
  int _count = 1;
  String _title = 'Nouvelle commande';

  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    FlutterOverlayWindow.overlayListener.listen((data) {
      if (!mounted) return;
      if (data is Map) {
        setState(() {
          if (data['count'] is int) _count = data['count'] as int;
          if (data['title'] is String) _title = data['title'] as String;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await HapticFeedback.mediumImpact();
    // Demande au main isolate d'ouvrir l'app (ramene MainActivity au front).
    await FlutterOverlayWindow.shareData(<String, Object?>{
      'action': 'open_app',
    });
    // Laisser une fraction de seconde au main isolate pour consommer le signal.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await FlutterOverlayWindow.closeOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (BuildContext context, Widget? child) {
            // Pulse ring exterieur (fonctionnel : signale nouvelle commande).
            final double scale = 1.0 + (_pulseCtrl.value * 0.25);
            final double opacity = 0.6 - (_pulseCtrl.value * 0.6);
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: <Widget>[
                // Halo rouge pulsant.
                Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF3B30).withValues(
                        alpha: opacity.clamp(0.0, 1.0),
                      ),
                    ),
                  ),
                ),
                child!,
              ],
            );
          },
          child: _BubbleChild(count: _count, title: _title),
        ),
      ),
    );
  }
}

class _BubbleChild extends StatelessWidget {
  const _BubbleChild({required this.count, required this.title});

  final int count;
  final String title;

  @override
  Widget build(BuildContext context) {
    const Color primary = Color(0xFFFB6A2B); // ZEET primary (partner).
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: <Widget>[
        // Cercle principal 64pt (hit target POS).
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primary,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(
            Icons.restaurant_rounded,
            color: Colors.white,
            size: 30,
            semanticLabel: 'Nouvelle commande ZEET',
          ),
        ),
        // Badge count rouge (top-right).
        if (count > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              constraints: const BoxConstraints(
                minWidth: 22,
                minHeight: 22,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                shape: count > 9 ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: count > 9
                    ? BorderRadius.circular(12)
                    : null,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
