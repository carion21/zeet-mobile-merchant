// Modeles representant les transactions financieres cote partner.
// Correspond a la reponse de `GET /v1/partner/transactions`.

/// Transaction financiere du partner (paiement, recharge, remboursement, etc.).
class Transaction {
  final int? id;
  final String? uuid;
  final String? code;
  final String? externalReference;
  final double amount;
  final String? currency;
  final String? type; // recharge | purchase | refund
  final String? status; // pending | completed | failed
  final String? description;
  final String? createdAt;
  final String? updatedAt;

  const Transaction({
    this.id,
    this.uuid,
    this.code,
    this.externalReference,
    required this.amount,
    this.currency,
    this.type,
    this.status,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as int?,
      uuid: json['uuid'] as String? ?? json['id']?.toString(),
      code: json['code'] as String? ?? json['reference'] as String?,
      externalReference: json['external_reference'] as String? ??
          json['externalReference'] as String?,
      amount: _asDouble(json['amount'] ?? json['value']),
      currency: json['currency'] as String?,
      type: json['type'] as String?,
      status: json['status'] as String?,
      description:
          json['description'] as String? ?? json['reason'] as String?,
      createdAt:
          json['created_at'] as String? ?? json['date_created'] as String?,
      updatedAt:
          json['updated_at'] as String? ?? json['date_updated'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'code': code,
      'external_reference': externalReference,
      'amount': amount,
      'currency': currency,
      'type': type,
      'status': status,
      'description': description,
      'created_at': createdAt,
      'updated_at': updatedAt,
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
