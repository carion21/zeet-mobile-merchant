// lib/core/utils/order_status_utils.dart
//
// Utilitaire centralisé pour mapper les statuts de commande partner
// vers les sémantiques `ZeetStatus` du design system.
//
// Remplace les anciennes fonctions `_fallbackStatusColor` dupliquées
// dans `home`, `orders` et `order_details`. Source de vérité unique
// pour les couleurs de badge de statut → contraste WCAG AA garanti
// via `ZeetStatusChip`.
//
// Voir skills : `zeet-design-system` §5, `zeet-pos-ergonomics` §6.

import 'package:zeet_ui/zeet_ui.dart';

/// Retourne la sémantique [ZeetStatus] correspondant à la valeur
/// brute d'un `OrderStatus` backend.
///
/// Les statuts intermédiaires (`pending`, `confirmed`, `preparing`)
/// sont `warning` : action merchant attendue. Les statuts terminaux
/// positifs (`ready`, `delivered`) sont `success`. Les statuts en
/// transit (`picked_up`) sont `info`. Les statuts destructeurs
/// (`cancelled`, `rejected`) sont `danger`.
ZeetStatus partnerStatusFor(String? value) {
  switch (value) {
    case 'pending':
    case 'confirmed':
    case 'preparing':
      return ZeetStatus.warning;
    case 'ready':
    case 'delivered':
      return ZeetStatus.success;
    case 'picked_up':
      return ZeetStatus.info;
    case 'cancelled':
    case 'rejected':
      return ZeetStatus.danger;
    default:
      return ZeetStatus.neutral;
  }
}
