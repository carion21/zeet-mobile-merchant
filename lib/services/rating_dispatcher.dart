// RatingDispatcher — handler push pour `rating.received`.
//
// Backend emet (preset silent, data-only) quand un client note une commande.
// L'app refresh le dashboard pour mettre a jour la note moyenne affichee.
//
// Cf. BACKEND_WORK_ORDER_FCM_PARTNER_LIVE.md §4.10.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:merchant/providers/dashboard_provider.dart';

abstract class RatingDispatcher {
  static const Set<String> _knownTypes = <String>{
    'rating.received',
    'rating.created',
    'review.received',
  };

  static bool handleRaw(WidgetRef ref, Map<String, dynamic> raw) {
    final String type = _readType(raw);
    if (type.isEmpty) return false;
    if (!_knownTypes.contains(type) &&
        !type.startsWith('rating.') &&
        !type.startsWith('review.')) {
      return false;
    }

    debugPrint('[RatingDispatcher] type=$type');

    // Refresh dashboard — la note moyenne et le compteur d'avis
    // bougent a chaque nouveau rating.
    try {
      ref.read(dashboardProvider.notifier).refresh();
    } catch (e) {
      debugPrint('[RatingDispatcher] dashboard failed: $e');
    }

    return true;
  }

  static String _readType(Map<String, dynamic> raw) {
    final dynamic typeValue = raw['type_value'];
    if (typeValue != null && typeValue.toString().isNotEmpty) {
      return typeValue.toString().toLowerCase();
    }
    return (raw['type']?.toString() ?? '').toLowerCase();
  }
}
