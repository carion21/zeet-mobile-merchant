import 'dart:io';
import 'package:merchant/core/constants/colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';


class AppPopup {
  /// Vérifie si l'application tourne sur iOS
  static bool _isIOS() {
    return Platform.isIOS;
  }

  /// Détermine si le thème est sombre
  static bool _isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  /// Popup d'information adaptatif
  static Future<void> showInfo({
    required BuildContext context,
    required String title,
    required String message,
    String buttonLabel = 'OK',
    Widget? icon,
    Color? titleColor,
    TextStyle? messageStyle,
    TextStyle? buttonTextStyle,
    bool barrierDismissible = true,
  }) async {
    if (_isIOS()) {
      // Style iOS (Cupertino)
      await showCupertinoDialog(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: (context) => CupertinoAlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                icon,
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: titleColor ?? (_isDarkMode(context) ? AppColors.darkText : AppColors.text),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              message,
              style: messageStyle ?? TextStyle(
                color: _isDarkMode(context) ? AppColors.darkTextLight : AppColors.textLight,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: Text(
                buttonLabel,
                style: buttonTextStyle ?? TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    } else {
      // Style Android (Material)
      await showDialog(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: (context) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              if (icon != null) ...[
                icon,
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: titleColor ?? (_isDarkMode(context) ? AppColors.darkText : AppColors.text),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: _isDarkMode(context) ? AppColors.darkSurface : AppColors.white,
          content: Text(
            message,
            style: messageStyle ?? TextStyle(
              color: _isDarkMode(context) ? AppColors.darkTextLight : AppColors.textLight,
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                buttonLabel,
                style: buttonTextStyle ?? TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
  }

  /// Popup de confirmation adaptatif
  static Future<bool> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirmer',
    String cancelLabel = 'Annuler',
    bool isDestructive = true,
    Widget? icon,
    Color? titleColor,
    TextStyle? messageStyle,
    TextStyle? confirmTextStyle,
    TextStyle? cancelTextStyle,
    bool barrierDismissible = false,
    bool reverseActionOrder = false,
  }) async {
    if (_isIOS()) {
      // Style iOS (Cupertino)
      final List<Widget> actions = [
        CupertinoDialogAction(
          child: Text(
            cancelLabel,
            style: cancelTextStyle ?? TextStyle(
              color: _isDarkMode(context) ? AppColors.darkTextLight : AppColors.textLight,
            ),
          ),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        CupertinoDialogAction(
          isDestructiveAction: isDestructive,
          child: Text(
            confirmLabel,
            style: confirmTextStyle ?? TextStyle(
              color: isDestructive ? AppColors.error : AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ];

      final result = await showCupertinoDialog<bool>(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: (context) => CupertinoAlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                icon,
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              message,
              style: messageStyle,
              textAlign: TextAlign.center,
            ),
          ),
          actions: reverseActionOrder ? actions.reversed.toList() : actions,
        ),
      );
      return result ?? false;
    } else {
      // Style Android (Material)
      final List<Widget> actions = [
        TextButton(
          child: Text(
            cancelLabel,
            style: cancelTextStyle ?? TextStyle(
              color: _isDarkMode(context) ? AppColors.darkTextLight : AppColors.textLight,
            ),
          ),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        TextButton(
          child: Text(
            confirmLabel,
            style: confirmTextStyle?.copyWith(
              color: isDestructive ? AppColors.error : AppColors.primary,
            ) ?? TextStyle(
              color: isDestructive ? AppColors.error : AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ];

      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: (context) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              if (icon != null) ...[
                icon,
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: messageStyle,
          ),
          actions: reverseActionOrder ? actions.reversed.toList() : actions,
        ),
      );
      return result ?? false;
    }
  }

  /// Popup avec champ de saisie adaptatif
  static Future<String?> showInputDialog({
    required BuildContext context,
    required String title,
    String? message,
    String hintText = '',
    String initialValue = '',
    String confirmLabel = 'Valider',
    String cancelLabel = 'Annuler',
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    Widget? icon,
    Color? titleColor,
    TextStyle? messageStyle,
    BoxDecoration? inputDecoration,
  }) async {
    final controller = TextEditingController(text: initialValue);

    if (_isIOS()) {
      // Style iOS (Cupertino)
      final result = await showCupertinoDialog<String>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                icon,
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                  child: Text(
                    message,
                    style: messageStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
              Container(
                decoration: inputDecoration ??
                    BoxDecoration(
                      color: _isDarkMode(context)
                          ? AppColors.darkSurface.withOpacity(0.7)
                          : CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                child: CupertinoTextField(
                  controller: controller,
                  placeholder: hintText,
                  obscureText: obscureText,
                  keyboardType: keyboardType,
                  maxLength: maxLength,
                  padding: const EdgeInsets.all(12.0),
                ),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              child: Text(cancelLabel),
              onPressed: () => Navigator.of(context).pop(null),
            ),
            CupertinoDialogAction(
              child: Text(confirmLabel),
              onPressed: () => Navigator.of(context).pop(controller.text),
            ),
          ],
        ),
      );
      return result;
    } else {
      // Style Android (Material)
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              if (icon != null) ...[
                icon,
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    message,
                    style: messageStyle,
                  ),
                ),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hintText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(color: AppColors.primary, width: 2.0),
                  ),
                  filled: _isDarkMode(context),
                  fillColor: _isDarkMode(context) ? AppColors.darkSurface : null,
                  hintStyle: TextStyle(
                    color: _isDarkMode(context)
                        ? AppColors.darkTextLight.withOpacity(0.6)
                        : AppColors.textLight.withOpacity(0.6),
                  ),
                ),
                style: TextStyle(
                  color: _isDarkMode(context) ? AppColors.darkText : AppColors.text,
                ),
                obscureText: obscureText,
                keyboardType: keyboardType,
                maxLength: maxLength,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text(cancelLabel),
              onPressed: () => Navigator.of(context).pop(null),
            ),
            TextButton(
              child: Text(confirmLabel),
              onPressed: () => Navigator.of(context).pop(controller.text),
            ),
          ],
        ),
      );
      return result;
    }
  }

  /// Popup avec options adaptatif
  static Future<T?> showOptions<T>({
    required BuildContext context,
    required String title,
    String? message,
    required List<AppPopupOption<T>> options,
    Widget? icon,
    Color? titleColor,
    TextStyle? messageStyle,
    String cancelLabel = 'Annuler',
    bool showCancel = true,
  }) async {
    if (_isIOS()) {
      // Style iOS (CupertinoActionSheet)
      return await showCupertinoModalPopup<T>(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                icon,
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          message: message != null
              ? Text(
            message,
            style: messageStyle,
            textAlign: TextAlign.center,
          )
              : null,
          actions: options.map((option) {
            return CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(option.value),
              isDefaultAction: option.isDefault,
              isDestructiveAction: option.isDestructive,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (option.icon != null) ...[
                    option.icon!,
                    const SizedBox(width: 8),
                  ],
                  Text(option.label, style: option.textStyle),
                ],
              ),
            );
          }).toList(),
          cancelButton: showCancel
              ? CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(cancelLabel),
          )
              : null,
        ),
      );
    } else {
      // Style Android (BottomSheet)
      return await showModalBottomSheet<T>(
        context: context,
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        icon,
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: titleColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        message,
                        style: messageStyle,
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ...options.map((option) {
                    final textColor = option.isDestructive
                        ? AppColors.error
                        : (option.isDefault ? AppColors.primary : (_isDarkMode(context) ? AppColors.darkText : AppColors.text));

                    return ListTile(
                      leading: option.icon,
                      title: Text(
                        option.label,
                        style: option.textStyle?.copyWith(color: textColor) ?? TextStyle(color: textColor),
                      ),
                      onTap: () => Navigator.of(context).pop(option.value),
                    );
                  }).toList(),
                  if (showCancel)
                    ListTile(
                      title: Text(cancelLabel, textAlign: TextAlign.center),
                      onTap: () => Navigator.of(context).pop(null),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  /// Popup de chargement avec animation adaptatif
  static Future<T?> showLoading<T>({
    required BuildContext context,
    required String message,
    bool dismissible = false,
    Future<T>? future,
  }) async {
    Future<dynamic> dialog;

    if (_isIOS()) {
      // Style iOS (Cupertino)
      dialog = showCupertinoDialog(
        context: context,
        barrierDismissible: dismissible,
        builder: (context) => CupertinoAlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(radius: 16),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    } else {
      // Style Android (Material)
      dialog = showDialog(
        context: context,
        barrierDismissible: dismissible,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    if (future != null) {
      future.then((value) {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        return value;
      }).catchError((error) {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        throw error;
      });
    }

    return await dialog;
  }
}

/// Classe pour gérer les options dans showOptions
class AppPopupOption<T> {
  final String label;
  final T value;
  final Widget? icon;
  final bool isDefault;
  final bool isDestructive;
  final TextStyle? textStyle;

  AppPopupOption({
    required this.label,
    required this.value,
    this.icon,
    this.isDefault = false,
    this.isDestructive = false,
    this.textStyle,
  });
}
