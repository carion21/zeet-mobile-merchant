// lib/core/tokens/spacing.dart
//
// Echelle d'espacement 4pt strict. Skills `zeet-design-system` +
// `zeet-tokens-audit`. Remplace progressivement les magic numbers
// (3px, 7px, 13px) et les `AppSizes().paddingX` (legacy %).
//
// Convention :
//   xxs = 2,  xs = 4,  sm = 8,  md = 12,  lg = 16,  xl = 24,  xxl = 32, huge = 48
//
// Usage :
//   Padding(padding: EdgeInsets.all(ZeetSpacing.lg))
//   SizedBox(height: ZeetSpacing.md)

class ZeetSpacing {
  const ZeetSpacing._();

  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double huge = 48.0;

  /// Hit target minimum POS (Skill `zeet-pos-ergonomics` §1).
  /// Mains sales/mouillees + cuisine = pression imprecise → 56pt mini.
  static const double hitTarget = 56.0;

  /// Hit target etendu (CTA primary slide-to-confirm).
  static const double hitTargetWide = 64.0;
}
