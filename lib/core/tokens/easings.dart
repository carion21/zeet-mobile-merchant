// lib/core/tokens/easings.dart
//
// Courbes d'easing canoniques pour merchant. Skill `zeet-motion-system` :
//   - decelerate : entree d'element (POS = snappy, pas bouncy)
//   - standard   : transition generique enter/exit
//   - emphasized : peak-moment (service closed cards stagger)
//   - linear     : barres de progression deterministes (countdown, prep)
import 'package:flutter/animation.dart';

class ZeetEasing {
  const ZeetEasing._();

  /// Entree (apparition) — POS doit ressentir snappy, pas bouncy.
  static const Curve decelerate = Curves.fastOutSlowIn;

  /// Transition generique (enter/exit).
  static const Curve standard = Curves.easeInOutCubic;

  /// Peak moment (service closed, mission completed).
  static const Curve emphasized = Curves.easeOutCubic;

  /// Sortie (disparition).
  static const Curve exit = Curves.easeInCubic;

  /// Progress lineaire (countdown, prep timer).
  static const Curve linear = Curves.linear;
}
