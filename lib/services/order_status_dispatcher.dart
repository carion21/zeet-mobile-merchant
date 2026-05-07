// OrderStatusDispatcher — point d'entree unique pour les events push
// "order.*" sur la surface partner.
//
// Appele depuis :
//   - FcmService.onDataMessage (foreground)
//   - DeepLinkHandler (cold-start, tap-from-background)
//
// Role :
//   1. Filtrer les payloads qui ne concernent pas une commande.
//   2. Rafraichir la liste + le dashboard.
//   3. Si l'ecran detail est ouvert sur la commande ciblee, le recharger.
//   4. Sur "order.delivered", recharger aussi le wallet (credit immediat).
//
// Le dispatcher ne navigue jamais : la navigation reste assuree par
// DeepLinkHandler / IncomingOrderDispatcher.
//
// Types d'events officiels (cf. FCM_PARTNER_CONTRACT.md §4 et
// BACKEND_WORK_ORDER_FCM_PARTNER_LIVE.md §4.1-4.4) :
//   order.created · order.status_changed · order.delivered ·
//   order.cancelled_by_customer · order.cancelled_by_admin
//
// Pour rester resilient aux alias backend ou aux vieux clients, on accepte
// aussi `order.cancelled` / `order.canceled` / `order.updated` (ancien nom
// generique de status_changed).

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:merchant/providers/dashboard_provider.dart';
import 'package:merchant/providers/orders_provider.dart';
import 'package:merchant/providers/wallet_provider.dart';

abstract class OrderStatusDispatcher {
  /// Types qu'on consomme. Match aussi par prefix `order.` pour absorber
  /// les futurs events sans modifier le code (silent refresh).
  static const Set<String> _knownTypes = <String>{
    'order.created',
    'order.status_changed',
    'order.delivered',
    'order.cancelled',
    'order.canceled',
    'order.cancelled_by_customer',
    'order.cancelled_by_admin',
    'order.updated', // alias historique
    'new_order',     // alias legacy
    'orders.group',  // event de regroupement (Phase 4)
  };

  /// Types qui denotent une livraison terminee → wallet a recharger.
  static const Set<String> _deliveredTypes = <String>{
    'order.delivered',
    'delivery.delivered',
    'delivered',
  };

  /// Traite un payload brut (RemoteMessage.data ou launchPayload).
  /// Retourne `false` si le payload n'est pas un event commande exploitable
  /// — l'appelant peut alors essayer un autre dispatcher.
  static bool handleRaw(WidgetRef ref, Map<String, dynamic> raw) {
    final String type = _readType(raw);
    if (type.isEmpty) return false;
    if (!_knownTypes.contains(type) && !type.startsWith('order.')) {
      return false;
    }

    final int? orderId = extractOrderId(raw);
    debugPrint(
      '[OrderStatusDispatcher] type=$type order_id=$orderId',
    );

    // 1. Liste — toujours utile (l'user peut etre sur Accueil ou Commandes).
    _safeCall(
      'ordersList',
      () => ref.read(ordersListProvider.notifier).refresh(),
    );

    // 2. Dashboard — compteurs/revenus du jour bougent a chaque transition.
    _safeCall(
      'dashboard',
      () => ref.read(dashboardProvider.notifier).refresh(),
    );

    // 3. Detail — uniquement si on a un order_id. Le provider est .family,
    //    le notifier ne sera materialise que s'il est deja watche par un
    //    ecran ouvert ; sinon ce read est inoffensif.
    if (orderId != null) {
      _safeCall(
        'orderDetail($orderId)',
        () => ref.read(orderDetailProvider(orderId).notifier).load(orderId),
      );
    }

    // 4. Wallet — sur livraison, le solde est credite immediatement cote
    //    backend. WalletDispatcher gere `wallet.credited` independamment,
    //    mais on declenche aussi ici pour fermer la boucle si l'event
    //    silent wallet.credited n'arrive pas (degraded mode reseau).
    if (_isDeliveredType(type)) {
      _safeCall(
        'wallet',
        () => ref.read(walletProvider.notifier).loadBalance(),
      );
    }

    return true;
  }

  /// Vrai si [type] denote une livraison terminee.
  static bool isDeliveredType(String type) =>
      _isDeliveredType(type.toLowerCase());

  static bool _isDeliveredType(String t) {
    if (_deliveredTypes.contains(t)) return true;
    return t.endsWith('.delivered') || t == 'delivered';
  }

  /// Extrait l'order_id (tolerant aux alias `order_id`, `entity_id`, `id`).
  static int? extractOrderId(Map<String, dynamic> raw) {
    final candidates = <dynamic>[
      raw['order_id'],
      raw['entity_id'],
      raw['id'],
    ];
    for (final c in candidates) {
      if (c == null) continue;
      if (c is int) return c;
      if (c is String) {
        final parsed = int.tryParse(c);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static String _readType(Map<String, dynamic> raw) {
    final dynamic typeValue = raw['type_value'];
    if (typeValue != null && typeValue.toString().isNotEmpty) {
      return typeValue.toString().toLowerCase();
    }
    return (raw['type']?.toString() ?? '').toLowerCase();
  }

  static void _safeCall(String label, void Function() fn) {
    try {
      fn();
    } catch (e) {
      debugPrint('[OrderStatusDispatcher] $label failed: $e');
    }
  }
}
