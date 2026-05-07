// PartnerDispatcher — handler push pour les events `partner.*` et
// `menu_item.*`.
//
// Backend emet :
//   - `partner.availability_forced_closed` (preset critical) — admin a
//     coupe le resto. L'app DOIT refresh le profile pour afficher le badge
//     "Ferme par ZEET" et bloquer les actions de service.
//   - `partner.availability_restored` — reouverture forcee.
//   - `menu_item.availability_changed` — admin a desactive un produit
//     (rupture forcee). La liste produits doit refresh.
//
// Cf. BACKEND_WORK_ORDER_FCM_PARTNER_LIVE.md §4.5, §4.6, §4.11.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:merchant/providers/product_provider.dart';
import 'package:merchant/providers/profile_provider.dart';

abstract class PartnerDispatcher {
  static const Set<String> _knownTypes = <String>{
    'partner.availability_forced_closed',
    'partner.availability_restored',
    'partner.availability_changed',
    'partner.profile_updated',
    'menu_item.availability_changed',
    'menu_item.updated',
    'product.availability_changed',
  };

  static bool handleRaw(WidgetRef ref, Map<String, dynamic> raw) {
    final String type = _readType(raw);
    if (type.isEmpty) return false;
    if (!_knownTypes.contains(type) &&
        !type.startsWith('partner.') &&
        !type.startsWith('menu_item.') &&
        !type.startsWith('product.')) {
      return false;
    }

    debugPrint('[PartnerDispatcher] type=$type');

    // Profil — uniquement sur events partner.*. Le statut de service
    // (open/forced_closed/restored) est porte par profileProvider.
    if (type.startsWith('partner.')) {
      try {
        ref.read(profileProvider.notifier).loadProfile();
      } catch (e) {
        debugPrint('[PartnerDispatcher] profile failed: $e');
      }
    }

    // Liste produits — uniquement sur menu_item.* / product.*.
    if (type.startsWith('menu_item.') || type.startsWith('product.')) {
      try {
        ref.read(productsListProvider.notifier).refresh();
      } catch (e) {
        debugPrint('[PartnerDispatcher] productsList failed: $e');
      }
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
