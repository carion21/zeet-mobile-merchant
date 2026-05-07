// lib/core/tokens/durations.dart
//
// Durees centralisees pour les animations / transitions / feedbacks de
// l'app merchant. Aligne sur le skill `zeet-motion-system` :
//   - fast (120ms)     : transitions inter-tabs, feedback tap
//   - std (200ms)      : transitions ecrans, overlays
//   - notice (400ms)   : apparitions sheets, cards, banners
//   - celebrate (800ms): rolling counters earnings/wallet, confetti
//   - peakStagger (25ms): interval entre cards stagger (service-closed)
//
// `prefers-reduced-motion` (a11y) : voir `ZeetEasing.reducedMotion()`
// helper pour diviser par 2 + fade simple a la place de slide.
import 'package:flutter/widgets.dart';

class ZeetDuration {
  const ZeetDuration._();

  /// Tap feedback / transitions inter-tabs / scale-on-tap.
  static const Duration fast = Duration(milliseconds: 120);

  /// Transitions ecrans / overlays / dialog enter/exit.
  static const Duration std = Duration(milliseconds: 200);

  /// Apparitions de cards, banners, bottom sheets.
  static const Duration notice = Duration(milliseconds: 400);

  /// Rolling counters (earnings, wallet), pulse subtil.
  static const Duration celebrate = Duration(milliseconds: 800);

  /// Interval entre cards en stagger (peak moment service closed).
  static const Duration peakStagger = Duration(milliseconds: 25);

  /// Pulse "attente" (banner offline qui respire).
  static const Duration pulse = Duration(milliseconds: 2000);

  /// Long press / swipe-to-confirm threshold.
  static const Duration longPress = Duration(milliseconds: 500);

  /// Auto-dismiss toasts (success/info).
  static const Duration toastShort = Duration(milliseconds: 2000);

  /// Auto-dismiss toasts (error/warning).
  static const Duration toastLong = Duration(milliseconds: 4000);

  /// Renvoie la duree adaptee a `prefers-reduced-motion`. Divise par 2
  /// (snappy mais visible) avec un plancher de 80ms pour eviter le
  /// "vide" (transition trop courte = perception jank).
  static Duration adapted(BuildContext context, Duration source) {
    final disable = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!disable) return source;
    final halved = source.inMilliseconds ~/ 2;
    return Duration(milliseconds: halved < 80 ? 80 : halved);
  }
}
