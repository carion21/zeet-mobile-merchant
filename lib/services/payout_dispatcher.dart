// PayoutDispatcher — handler push pour les events `payout.*`.
//
// Backend emet :
//   - `payout.created_by_admin` quand un admin initie un virement.
//   - `payout.status_changed` quand le statut change (validate / reject /
//     processing → completed).
//
// Sans ce dispatcher, l'ecran Payouts reste sur l'etat ancien — l'user ne
// sait pas si son virement a ete valide → risque de demande dupliquee.
//
// Cf. BACKEND_WORK_ORDER_FCM_PARTNER_LIVE.md §4.8-4.9.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:merchant/providers/payout_provider.dart';
import 'package:merchant/providers/wallet_provider.dart';

abstract class PayoutDispatcher {
  static const Set<String> _knownTypes = <String>{
    'payout.created_by_admin',
    'payout.status_changed',
    'payout.created',
    'payout.updated',
    'payout.completed',
    'payout.rejected',
  };

  static bool handleRaw(WidgetRef ref, Map<String, dynamic> raw) {
    final String type = _readType(raw);
    if (type.isEmpty) return false;
    if (!_knownTypes.contains(type) && !type.startsWith('payout.')) {
      return false;
    }

    debugPrint('[PayoutDispatcher] type=$type');

    // Recharge la liste des virements (statut, date, montant).
    try {
      ref.read(payoutsListProvider.notifier).refresh();
    } catch (e) {
      debugPrint('[PayoutDispatcher] payoutsList failed: $e');
    }

    // Si un payout est complete/rejete, le wallet bouge aussi (debit
    // confirme, ou re-credit en cas de rejet).
    try {
      ref.read(walletProvider.notifier).loadBalance();
    } catch (e) {
      debugPrint('[PayoutDispatcher] wallet failed: $e');
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
