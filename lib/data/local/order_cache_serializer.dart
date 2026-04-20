// lib/data/local/order_cache_serializer.dart
//
// Serialisation minimale d'une commande pour le cache Drift offline-first.
//
// On ne cherche PAS a recreer l'integralite du modele API depuis le cache :
// l'objectif est de pouvoir afficher la liste et les actions principales
// meme sans reseau. Les champs rares (position detaillee, logs) sont
// recharges depuis l'API au retour online.
//
// Le JSON stocke est compatible avec [Order.fromJson] — on re-utilise le
// parsing existant, ce qui garantit zero divergence de modele.

import 'dart:convert';

import 'package:merchant/models/order_model.dart';

class OrderCacheSerializer {
  const OrderCacheSerializer._();

  /// Encode un [Order] en JSON string prêt a stocker.
  static String encode(Order order) => jsonEncode(_toJson(order));

  /// Decode une chaine JSON en [Order]. Retourne null si la chaine est vide.
  static Order? decode(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final Map<String, dynamic> map =
          jsonDecode(payload) as Map<String, dynamic>;
      return Order.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Mute le JSON stocke pour reflether un changement de statut optimistic.
  /// Utile pour projeter instantanement "pending → confirmed" dans l'UI
  /// avant que l'API ne confirme.
  static String applyOptimisticStatus(String payload, String newStatus) {
    try {
      final Map<String, dynamic> map =
          jsonDecode(payload) as Map<String, dynamic>;
      // Supprime les formes objet/int pour forcer le parseur a prendre la
      // nouvelle string.
      map['status'] = newStatus;
      map['last_order_status'] = <String, dynamic>{
        if (map['last_order_status'] is Map<String, dynamic>)
          ...map['last_order_status'] as Map<String, dynamic>,
        'value': newStatus,
        'label': _humanLabel(newStatus),
      };
      return jsonEncode(map);
    } catch (_) {
      return payload;
    }
  }

  static Map<String, dynamic> _toJson(Order o) {
    return <String, dynamic>{
      'id': o.id,
      'code': o.code,
      'uuid': o.uuid,
      'status': o.status,
      'last_order_status': <String, dynamic>{
        if (o.orderStatus?.id != null) 'id': o.orderStatus?.id,
        'value': o.status,
        'label': o.statusLabel,
        if (o.orderStatus?.color != null) 'color': o.orderStatus?.color,
      },
      if (o.customerId != null) 'customer_id': o.customerId,
      if (o.customer != null)
        'customer': <String, dynamic>{
          'id': o.customer!.id,
          if (o.customer!.firstName != null) 'firstname': o.customer!.firstName,
          if (o.customer!.lastName != null) 'lastname': o.customer!.lastName,
          if (o.customer!.phone != null) 'phone': o.customer!.phone,
          if (o.customer!.picture != null) 'picture': o.customer!.picture,
        },
      if (o.partnerId != null) 'partner_id': o.partnerId,
      if (o.partner != null)
        'partner': <String, dynamic>{
          'id': o.partner!.id,
          if (o.partner!.name != null) 'name': o.partner!.name,
          if (o.partner!.phone != null) 'phone': o.partner!.phone,
          if (o.partner!.address != null) 'address': o.partner!.address,
          if (o.partner!.picture != null) 'picture': o.partner!.picture,
        },
      if (o.rider != null)
        'rider': <String, dynamic>{
          'id': o.rider!.id,
        },
      'items': o.items
          .map((OrderItem i) => <String, dynamic>{
                'id': i.id,
                'product_id': i.productId,
                if (i.productName != null) 'product_name': i.productName,
                if (i.variantId != null) 'variant_id': i.variantId,
                if (i.variantName != null) 'variant_name': i.variantName,
                'quantity': i.quantity,
                if (i.unitPrice != null) 'unit_price': i.unitPrice,
                if (i.totalPrice != null) 'total_price': i.totalPrice,
                if (i.note != null) 'note': i.note,
              })
          .toList(),
      if (o.subtotal != null) 'subtotal': o.subtotal,
      if (o.deliveryFee != null) 'delivery_fee': o.deliveryFee,
      if (o.netAmount != null) 'net_amount': o.netAmount,
      if (o.commission != null) 'commission': o.commission,
      if (o.discount != null) 'discount': o.discount,
      if (o.totalAmount != null) 'total_amount': o.totalAmount,
      if (o.paymentMethod != null)
        'payment_method': <String, dynamic>{
          if (o.paymentMethod!.id != null) 'id': o.paymentMethod!.id,
          if (o.paymentMethod!.value != null) 'value': o.paymentMethod!.value,
          if (o.paymentMethod!.label != null) 'label': o.paymentMethod!.label,
        },
      if (o.deliveryAddress != null) 'delivery_address': o.deliveryAddress,
      if (o.etaMinutes != null) 'eta_minutes': o.etaMinutes,
      if (o.estimatedMinutes != null) 'estimated_minutes': o.estimatedMinutes,
      if (o.noteCustomer != null) 'note_customer': o.noteCustomer,
      if (o.notePartner != null) 'note_partner': o.notePartner,
      if (o.cancelReason != null) 'cancel_reason': o.cancelReason,
      if (o.cancelledAt != null) 'cancelled_at': o.cancelledAt,
      if (o.pickupOtp != null) 'pickup_otp': o.pickupOtp,
      if (o.createdAt != null) 'created_at': o.createdAt,
      if (o.updatedAt != null) 'updated_at': o.updatedAt,
    };
  }

  /// Converti un status metier en libelle FR lisible, pour la relance
  /// optimistic quand on n'a pas encore la version enrichie cote serveur.
  static String _humanLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Nouvelle';
      case 'confirmed':
        return 'Confirmee';
      case 'preparing':
        return 'En preparation';
      case 'ready':
        return 'Prete';
      case 'picked_up':
        return 'Recuperee';
      case 'delivered':
        return 'Livree';
      case 'cancelled':
        return 'Annulee';
      case 'refused':
        return 'Refusee';
      default:
        return status;
    }
  }
}
