// Modeles representant les demandes de virement (payouts) cote partner.
// Correspond aux endpoints `/v1/partner/payouts/*`.
//
// Enum PayoutStatus — 6 valeurs canoniques backend (2026-04-15) :
//   requested : demande par le partner, en attente d'approbation admin
//   pending   : approuve par admin, fonds lockes
//   validated : confirme par le partner
//   completed : paye, preuve de virement uploadee (ancienne valeur `paid`)
//   rejected  : refuse par l'admin
//   cancelled : annule par l'admin (fonds liberes)

import 'package:flutter/material.dart';

import 'package:merchant/core/utils/color_utils.dart';

/// Statut canonique d'une demande de virement partner.
enum PayoutStatus {
  requested,
  pending,
  validated,
  completed,
  rejected,
  cancelled;

  /// Valeur stringifiee attendue par l'API.
  String get value {
    switch (this) {
      case PayoutStatus.requested:
        return 'requested';
      case PayoutStatus.pending:
        return 'pending';
      case PayoutStatus.validated:
        return 'validated';
      case PayoutStatus.completed:
        return 'completed';
      case PayoutStatus.rejected:
        return 'rejected';
      case PayoutStatus.cancelled:
        return 'cancelled';
    }
  }

  /// Libelle FR pour affichage UI (badges, filtres, listes).
  String get label {
    switch (this) {
      case PayoutStatus.requested:
        return 'Demande';
      case PayoutStatus.pending:
        return 'En attente';
      case PayoutStatus.validated:
        return 'Validee';
      case PayoutStatus.completed:
        return 'Payee';
      case PayoutStatus.rejected:
        return 'Refusee';
      case PayoutStatus.cancelled:
        return 'Annulee';
    }
  }

  /// Parse une valeur brute (String de l'API) vers un PayoutStatus.
  /// Gere le cas legacy `paid` -> completed et les valeurs inconnues (null).
  static PayoutStatus? fromString(dynamic raw) {
    if (raw == null) return null;
    final str = raw.toString().trim().toLowerCase();
    switch (str) {
      case 'requested':
        return PayoutStatus.requested;
      case 'pending':
        return PayoutStatus.pending;
      case 'validated':
        return PayoutStatus.validated;
      case 'completed':
      case 'paid': // compatibilite avec ancien payload backend
        return PayoutStatus.completed;
      case 'rejected':
        return PayoutStatus.rejected;
      case 'cancelled':
      case 'canceled':
        return PayoutStatus.cancelled;
      default:
        return null;
    }
  }

  /// Liste ordonnee utilisee par les filtres UI (listes / chips).
  static const List<PayoutStatus> filterOrder = <PayoutStatus>[
    PayoutStatus.requested,
    PayoutStatus.pending,
    PayoutStatus.validated,
    PayoutStatus.completed,
    PayoutStatus.rejected,
    PayoutStatus.cancelled,
  ];
}

/// Objet riche `{id,label,value,color}` envoye par le core quand `status`
/// est fourni comme objet (et non simple string). Porte la couleur
/// authoritative pour l'UI.
class PayoutStatusBadge {
  final int? id;
  final String? label;
  final String? value;
  final String? color;

  const PayoutStatusBadge({this.id, this.label, this.value, this.color});

  factory PayoutStatusBadge.fromJson(Map<String, dynamic> json) {
    return PayoutStatusBadge(
      id: json['id'] as int?,
      label: json['label'] as String?,
      value: json['value'] as String?,
      color: json['color'] as String?,
    );
  }

  Color? get colorValue => hexToColor(color);
}

/// Demande de virement effectuee par le partner.
class Payout {
  final int? id;
  final String? uuid;
  final String? code;
  final double amount;
  final String? currency;
  final PayoutStatus? status;

  /// Objet riche envoye par le core quand `status` est fourni comme
  /// `{id,label,value,color}`. Source de verite pour la couleur du badge.
  final PayoutStatusBadge? statusBadge;
  final String? note;
  final String? method;
  final Map<String, dynamic>? accountDetails;
  final String? createdAt;
  final String? updatedAt;
  final String? validatedAt;
  final String? completedAt;
  final String? rejectedAt;
  final String? cancelledAt;
  final String? rejectionReason;

  const Payout({
    this.id,
    this.uuid,
    this.code,
    required this.amount,
    this.currency,
    this.status,
    this.statusBadge,
    this.note,
    this.method,
    this.accountDetails,
    this.createdAt,
    this.updatedAt,
    this.validatedAt,
    this.completedAt,
    this.rejectedAt,
    this.cancelledAt,
    this.rejectionReason,
  });

  bool get isRequested => status == PayoutStatus.requested;
  bool get isPending => status == PayoutStatus.pending;
  bool get isValidated => status == PayoutStatus.validated;
  bool get isCompleted => status == PayoutStatus.completed;
  bool get isRejected => status == PayoutStatus.rejected;
  bool get isCancelled => status == PayoutStatus.cancelled;

  /// Couleur authoritative du statut, provenant du backend si fournie.
  /// `null` → l'UI doit fallback sur un neutre (`ZeetColors.inkMuted`).
  Color? get statusColor => statusBadge?.colorValue;

  /// true si la demande est terminee (succes ou echec) — utile pour figer l'UI.
  bool get isTerminal => isCompleted || isRejected || isCancelled;

  factory Payout.fromJson(Map<String, dynamic> json) {
    // `status` peut etre une String legacy ou un objet riche
    // `{id,label,value,color}` depuis l'evolution core. On parse les deux
    // formes : l'enum (state-machine) ET le badge (couleur).
    dynamic rawStatus = json['status'];
    PayoutStatusBadge? statusBadge;
    if (rawStatus is Map<String, dynamic>) {
      statusBadge = PayoutStatusBadge.fromJson(rawStatus);
      rawStatus = statusBadge.value;
    }

    return Payout(
      id: json['id'] as int?,
      uuid: json['uuid'] as String? ?? json['id']?.toString(),
      code: json['code'] as String? ?? json['reference'] as String?,
      amount: _asDouble(json['amount'] ?? json['value']),
      currency: json['currency'] as String?,
      status: PayoutStatus.fromString(rawStatus),
      statusBadge: statusBadge,
      note: json['note'] as String? ?? json['description'] as String?,
      method: json['method'] as String?,
      accountDetails: json['account_details'] is Map<String, dynamic>
          ? json['account_details'] as Map<String, dynamic>
          : json['accountDetails'] is Map<String, dynamic>
              ? json['accountDetails'] as Map<String, dynamic>
              : null,
      createdAt:
          json['created_at'] as String? ?? json['date_created'] as String?,
      updatedAt:
          json['updated_at'] as String? ?? json['date_updated'] as String?,
      validatedAt: json['validated_at'] as String?,
      completedAt:
          json['completed_at'] as String? ?? json['paid_at'] as String?,
      rejectedAt: json['rejected_at'] as String?,
      cancelledAt: json['cancelled_at'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'code': code,
      'amount': amount,
      'currency': currency,
      'status': status?.value,
      'note': note,
      'method': method,
      'account_details': accountDetails,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'validated_at': validatedAt,
      'completed_at': completedAt,
      'rejected_at': rejectedAt,
      'cancelled_at': cancelledAt,
      'rejection_reason': rejectionReason,
    };
  }

  Payout copyWith({
    int? id,
    String? uuid,
    String? code,
    double? amount,
    String? currency,
    PayoutStatus? status,
    PayoutStatusBadge? statusBadge,
    String? note,
    String? method,
    Map<String, dynamic>? accountDetails,
    String? createdAt,
    String? updatedAt,
    String? validatedAt,
    String? completedAt,
    String? rejectedAt,
    String? cancelledAt,
    String? rejectionReason,
  }) {
    return Payout(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      code: code ?? this.code,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      statusBadge: statusBadge ?? this.statusBadge,
      note: note ?? this.note,
      method: method ?? this.method,
      accountDetails: accountDetails ?? this.accountDetails,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      validatedAt: validatedAt ?? this.validatedAt,
      completedAt: completedAt ?? this.completedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}

/// Body envoye pour creer une demande de payout.
/// `POST /v1/partner/payouts`
class CreatePayoutRequest {
  final double amount;
  final String? note;

  const CreatePayoutRequest({
    required this.amount,
    this.note,
  });

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      if (note != null && note!.isNotEmpty) 'note': note,
    };
  }
}

// Helpers de parsing monetaire (certains champs viennent en String, certains en num).
double _asDouble(dynamic raw) {
  if (raw == null) return 0;
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw) ?? 0;
  return 0;
}
