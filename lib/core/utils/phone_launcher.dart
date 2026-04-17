// lib/core/utils/phone_launcher.dart
//
// Helper minimal pour lancer un appel téléphonique natif depuis un
// numéro arbitraire. Utilise `url_launcher` avec le scheme `tel:`.
//
// Usage :
//   await launchPhoneCall('+225 07 07 12 34 56', context: context);

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:merchant/core/widgets/toastification.dart';

/// Sanitize un numéro en supprimant espaces, tirets, parenthèses,
/// tout en gardant le `+` initial si présent.
String _sanitizePhoneNumber(String raw) {
  final trimmed = raw.trim();
  final hasPlus = trimmed.startsWith('+');
  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  return hasPlus ? '+$digits' : digits;
}

/// Lance un appel téléphonique natif.
///
/// Retourne `true` si l'OS a accepté de lancer l'intent, `false` sinon.
/// En cas d'échec et si un [BuildContext] est fourni, affiche un toast
/// d'erreur via [AppToast].
Future<bool> launchPhoneCall(
  String phoneNumber, {
  BuildContext? context,
}) async {
  final sanitized = _sanitizePhoneNumber(phoneNumber);
  if (sanitized.isEmpty) {
    if (context != null && context.mounted) {
      AppToast.showError(
        context: context,
        message: 'Numéro de téléphone invalide',
      );
    }
    return false;
  }

  final uri = Uri.parse('tel:$sanitized');
  try {
    final launched = await launchUrl(uri);
    if (!launched && context != null && context.mounted) {
      AppToast.showError(
        context: context,
        message: 'Impossible de lancer l\'appel',
      );
    }
    return launched;
  } catch (_) {
    if (context != null && context.mounted) {
      AppToast.showError(
        context: context,
        message: 'Impossible de lancer l\'appel',
      );
    }
    return false;
  }
}
