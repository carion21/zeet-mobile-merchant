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
/// Deux conventions coexistent et sont toutes les deux mappees :
/// - **Backend canonique** (NestJS — cf. ORDERS_PARTNER_FLOW.md §2) :
///   `payment-accepted`, `ready-for-delivery`, `on-the-way`, `canceled`,
///   `failed`.
/// - **Legacy/alias frontend** : `pending`, `ready`, `picked_up`,
///   `cancelled`, `rejected` — garde par compatibilite avec l'historique
///   de l'app.
///
/// `warning` = action merchant attendue ; `success` = etat positif stable ;
/// `info` = transit ; `danger` = etat destructeur/echec.
ZeetStatus partnerStatusFor(String? value) {
  switch (value) {
    case 'pending':
    case 'payment-accepted':
    case 'confirmed':
    case 'preparing':
      return ZeetStatus.warning;
    case 'ready':
    case 'ready-for-delivery':
    case 'delivered':
      return ZeetStatus.success;
    case 'picked_up':
    case 'on-the-way':
      return ZeetStatus.info;
    case 'cancelled':
    case 'canceled':
    case 'rejected':
    case 'failed':
      return ZeetStatus.danger;
    default:
      return ZeetStatus.neutral;
  }
}
