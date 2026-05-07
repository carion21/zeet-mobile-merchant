// WalletDispatcher — handler push pour les events `wallet.*`.
//
// Backend emet `wallet.credited` (preset silent, data-only) apres chaque
// livraison confirmee. Sans ce dispatcher, le solde affiche reste stale tant
// que l'user ne fait pas un pull-to-refresh sur l'ecran Wallet.
//
// Cf. BACKEND_WORK_ORDER_FCM_PARTNER_LIVE.md §4.7.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:merchant/providers/wallet_provider.dart';

abstract class WalletDispatcher {
  static const Set<String> _knownTypes = <String>{
    'wallet.credited',
    'wallet.debited',
    'wallet.updated',
  };

  /// Retourne `true` si le payload a ete consomme par ce dispatcher.
  static bool handleRaw(WidgetRef ref, Map<String, dynamic> raw) {
    final String type = _readType(raw);
    if (type.isEmpty) return false;
    if (!_knownTypes.contains(type) && !type.startsWith('wallet.')) {
      return false;
    }

    debugPrint('[WalletDispatcher] type=$type');

    // Recharge le solde immediatement pour que l'user voit le montant
    // a jour des qu'il ouvre l'ecran wallet (ou si le badge est visible).
    try {
      ref.read(walletProvider.notifier).loadBalance();
    } catch (e) {
      debugPrint('[WalletDispatcher] loadBalance failed: $e');
    }

    // Recharge aussi la liste des entries — l'utilisateur peut etre
    // sur l'ecran historique en train de regarder.
    try {
      ref.read(walletProvider.notifier).loadEntries(reset: true);
    } catch (e) {
      debugPrint('[WalletDispatcher] loadEntries failed: $e');
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
