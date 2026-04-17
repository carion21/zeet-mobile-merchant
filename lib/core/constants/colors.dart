// Re-export vers le design system partagé `zeet_ui`.
//
// Tous les symboles historiques `AppColors.*` pointent maintenant sur
// [ZeetColors] pour éviter toute divergence DA inter-app. Préférer
// `ZeetColors.*` directement dans le nouveau code.
import 'package:flutter/material.dart';
import 'package:zeet_ui/zeet_ui.dart';

abstract class AppColors {
  // ---------- Brand ----------
  static const Color primary = ZeetColors.primary;
  static const Color primaryDark = ZeetColors.primaryDark;
  static const Color primaryLight = ZeetColors.primaryLight;

  // ---------- Neutres ----------
  static const Color text = ZeetColors.ink;
  static const Color textLight = ZeetColors.inkMuted;
  static const Color line = ZeetColors.line;
  static const Color white = ZeetColors.surface;
  static const Color background = ZeetColors.surfaceAlt;

  // ---------- Sémantique ----------
  static const Color success = ZeetColors.success;
  static const Color warning = ZeetColors.warning;
  static const Color danger = ZeetColors.danger;
  static const Color info = ZeetColors.info;

  /// @deprecated Utiliser [danger]
  static const Color error = ZeetColors.danger;

  // ---------- Dark ----------
  static const Color darkBackground = ZeetColors.surfaceDark;
  static const Color darkSurface = ZeetColors.surfaceAltDark;
  static const Color darkText = ZeetColors.inkDark;
  static const Color darkTextLight = ZeetColors.inkMutedDark;
}
