// Délégation vers le design system partagé `zeet_ui`.
//
// L'API publique `AppTheme.lightTheme(context)` / `.darkTheme(context)` est
// préservée pour la compatibilité avec `main.dart` et les écrans existants.
// Toute la construction du thème est maintenant centralisée dans ZeetTheme,
// avec l'intention `partner` (POS service, dense, neutre).
import 'package:flutter/material.dart';
import 'package:merchant/core/constants/sizes.dart';
import 'package:zeet_ui/zeet_ui.dart';

class AppTheme {
  static const ZeetIntent _intent = ZeetIntent.partner;

  static ThemeData lightTheme(BuildContext context) {
    AppSizes().initialize(context);
    return ZeetTheme.light(intent: _intent);
  }

  static ThemeData darkTheme(BuildContext context) {
    AppSizes().initialize(context);
    return ZeetTheme.dark(intent: _intent);
  }
}
