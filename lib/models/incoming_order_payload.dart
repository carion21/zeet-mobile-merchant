// Modele de payload "nouvelle commande" recue via push (FCM a terme).
//
// Contrat d'interface fourni par le backend :
//
//   {
//     "type": "order.created",
//     "notification_id": "1843",
//     "title": "Nouvelle commande ZT-2026-00421",
//     "body": "Total : 12500 FCFA — preparer immediatement",
//     "entity": "order",
//     "entity_id": "421",
//     "metadata": "{\"type\":\"order.created\",\"order_id\":421,\"order_code\":\"ZT-2026-00421\",\"partner_id\":17,\"total_fcfa\":12500,\"items_count\":3,\"requires_ack\":true}"
//   }
//
// Le champ `metadata` arrive en JSON encode sous forme de String (c'est le format
// standard FCM : les valeurs dans `data` sont toujours des strings). Le parser
// est defensif pour absorber les variantes possibles (types laxes, cles absentes).

import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Payload typee d'une notification "nouvelle commande".
///
/// Toutes les donnees sont derivees du couple `(top-level, metadata JSON string)`
/// recu via FCM ou injecte manuellement en mode dev.
@immutable
class IncomingOrderPayload {
  /// Type de l'evenement (ex: "order.created").
  final String type;

  /// Identifiant de la notification cote backend (pour l'ack).
  final int notificationId;

  /// Identifiant de la commande cote backend (pour le confirm).
  final int orderId;

  /// Code lisible de la commande (ex: "ZT-2026-00421").
  final String orderCode;

  /// Titre pre-formate par le backend.
  final String title;

  /// Corps pre-formate par le backend.
  final String body;

  /// Montant total en FCFA (entier, pas de decimales pour XOF).
  final int totalFcfa;

  /// Nombre d'articles dans la commande.
  final int itemsCount;

  /// Id du partner cible (verification cote client).
  final int? partnerId;

  /// Si true, l'app DOIT appeler /notifications/:id/ack apres l'acceptation
  /// pour couper la cascade backend.
  final bool requiresAck;

  const IncomingOrderPayload({
    required this.type,
    required this.notificationId,
    required this.orderId,
    required this.orderCode,
    required this.title,
    required this.body,
    required this.totalFcfa,
    required this.itemsCount,
    this.partnerId,
    this.requiresAck = true,
  });

  /// Parse un payload FCM brut (map reconstruite depuis RemoteMessage.data).
  ///
  /// Accepte :
  /// - `metadata` en String JSON ou en Map directement
  /// - `notification_id`, `entity_id`, `order_id` en String ou en num
  /// - cles manquantes (fallback defensifs)
  ///
  /// Retourne `null` si le payload n'est pas exploitable (pas d'`order_id`
  /// trouvable).
  static IncomingOrderPayload? tryParse(Map<String, dynamic> raw) {
    final metadata = _extractMetadata(raw);

    final orderId = _asInt(
      metadata['order_id'] ?? raw['entity_id'] ?? raw['order_id'],
    );
    if (orderId == null) return null;

    final notificationId =
        _asInt(raw['notification_id'] ?? metadata['notification_id']) ?? 0;

    final orderCode = _asString(metadata['order_code']) ??
        _asString(raw['order_code']) ??
        _extractCodeFromTitle(raw['title']) ??
        '';

    final totalFcfa = _asInt(
          metadata['total_fcfa'] ??
              metadata['total'] ??
              raw['total_fcfa'] ??
              raw['total'],
        ) ??
        0;

    final itemsCount = _asInt(
          metadata['items_count'] ?? raw['items_count'],
        ) ??
        0;

    final partnerId = _asInt(metadata['partner_id'] ?? raw['partner_id']);

    final requiresAck = _asBool(
      metadata['requires_ack'] ?? raw['requires_ack'],
      fallback: true,
    );

    return IncomingOrderPayload(
      type: _asString(raw['type']) ?? _asString(metadata['type']) ?? 'order.created',
      notificationId: notificationId,
      orderId: orderId,
      orderCode: orderCode,
      title: _asString(raw['title']) ?? 'Nouvelle commande',
      body: _asString(raw['body']) ?? '',
      totalFcfa: totalFcfa,
      itemsCount: itemsCount,
      partnerId: partnerId,
      requiresAck: requiresAck,
    );
  }

  // ---------------------------------------------------------------------------
  // Internals — parsing defensif
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _extractMetadata(Map<String, dynamic> raw) {
    final meta = raw['metadata'];
    if (meta is Map<String, dynamic>) return meta;
    if (meta is Map) return Map<String, dynamic>.from(meta);
    if (meta is String && meta.isNotEmpty) {
      try {
        final decoded = jsonDecode(meta);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        // metadata malforme — on retombe sur les champs top-level
      }
    }
    return const {};
  }

  static int? _asInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  static String? _asString(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return raw.isEmpty ? null : raw;
    return raw.toString();
  }

  static bool _asBool(dynamic raw, {bool fallback = false}) {
    if (raw == null) return fallback;
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final v = raw.toLowerCase();
      return v == 'true' || v == '1' || v == 'yes';
    }
    return fallback;
  }

  /// Fallback : extrait le code depuis le titre si le backend a oublie de le
  /// mettre dans metadata. Ex: "Nouvelle commande ZT-2026-00421" → "ZT-2026-00421".
  static String? _extractCodeFromTitle(dynamic title) {
    if (title is! String) return null;
    final match = RegExp(r'([A-Z]{2,3}-\d{4}-\d+)').firstMatch(title);
    return match?.group(1);
  }

  /// Utilitaire pour creer un payload de test (dev trigger, tests unitaires).
  factory IncomingOrderPayload.fake({
    int orderId = 421,
    String orderCode = 'ZT-2026-00421',
    int totalFcfa = 12500,
    int itemsCount = 3,
    int notificationId = 1843,
  }) {
    return IncomingOrderPayload(
      type: 'order.created',
      notificationId: notificationId,
      orderId: orderId,
      orderCode: orderCode,
      title: 'Nouvelle commande $orderCode',
      body: 'Total : $totalFcfa FCFA — preparer immediatement',
      totalFcfa: totalFcfa,
      itemsCount: itemsCount,
      partnerId: 17,
      requiresAck: true,
    );
  }

  @override
  String toString() =>
      'IncomingOrderPayload(order=$orderCode #$orderId, total=$totalFcfa FCFA, '
      'items=$itemsCount, notif=$notificationId, ack=$requiresAck)';
}
