import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/core/constants/icons.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

/// Enum pour différencier les types de messages dans le toast
enum ToastType {
  /// Message d'information (bleu)
  info,

  /// Message de succès (vert)
  success,

  /// Message d'avertissement (orange)
  warning,

  /// Message d'erreur (rouge)
  error
}

/// Classe pour gérer l'affichage de toasts personnalisés
class AppToast {
  /// Affiche un toast personnalisé
  static void show({
    required BuildContext context,
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onClose,
    String? actionLabel,
    VoidCallback? onAction,
    bool dismissible = true,
  }) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Couleurs selon le type
    Color primaryColor;
    IconData iconData;

    switch (type) {
      case ToastType.info:
        primaryColor = const Color(0xFF2196F3);
        iconData = IconManager.getIconData('info');
        break;
      case ToastType.success:
        primaryColor = const Color(0xFF4CD964);
        iconData = IconManager.getIconData('success');
        break;
      case ToastType.warning:
        primaryColor = AppColors.primary;
        iconData = IconManager.getIconData('warning');
        break;
      case ToastType.error:
        primaryColor = AppColors.error;
        iconData = IconManager.getIconData('error');
        break;
    }

    // Toujours fond blanc (ou surface pour dark mode)
    final backgroundColor = isDarkMode ? AppColors.darkSurface : Colors.white;
    final textColor = isDarkMode ? AppColors.darkText : AppColors.text;

    toastification.show(
      context: context,
      type: ToastificationType.info, // Type par défaut, on custom tout
      style: ToastificationStyle.minimal,
      alignment: Alignment.topCenter,
      autoCloseDuration: duration,
      animationDuration: const Duration(milliseconds: 400),
      animationBuilder: (context, animation, alignment, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
      title: Row(
        children: [
          // Icône
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              iconData,
              color: primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Message
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
      primaryColor: primaryColor,
      backgroundColor: backgroundColor,
      foregroundColor: textColor,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDarkMode ? 0.4 : 0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ],
      showProgressBar: false,
      showIcon: false, // On gère l'icône manuellement
      closeOnClick: dismissible,
      pauseOnHover: true,
      dragToClose: true,
      applyBlurEffect: false,
      callbacks: ToastificationCallbacks(
        onTap: (toastItem) => actionLabel != null && onAction != null ? onAction() : null,
        onCloseButtonTap: (toastItem) => onClose?.call(),
      ),
    );
  }

  /// Affiche un toast d'info (bleu)
  static void showInfo({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onClose,
  }) {
    show(
      context: context,
      message: message,
      type: ToastType.info,
      duration: duration,
      onClose: onClose,
    );
  }

  /// Affiche un toast de succès (vert)
  static void showSuccess({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onClose,
  }) {
    show(
      context: context,
      message: message,
      type: ToastType.success,
      duration: duration,
      onClose: onClose,
    );
  }

  /// Affiche un toast d'avertissement (orange)
  static void showWarning({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onClose,
  }) {
    show(
      context: context,
      message: message,
      type: ToastType.warning,
      duration: duration,
      onClose: onClose,
    );
  }

  /// Affiche un toast d'erreur (rouge)
  static void showError({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onClose,
  }) {
    show(
      context: context,
      message: message,
      type: ToastType.error,
      duration: duration,
      onClose: onClose,
    );
  }
}
