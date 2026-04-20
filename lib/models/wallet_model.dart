// Modeles representant le portefeuille (wallet) cote partner.
// Correspond aux reponses de `GET /v1/partner/wallet` et
// `GET /v1/partner/wallet/entries`.

/// Solde du portefeuille partner.
class Wallet {
  final int? id;
  final double balance;
  final String? currency;
  final String? createdAt;
  final String? updatedAt;

  const Wallet({
    this.id,
    required this.balance,
    this.currency,
    this.createdAt,
    this.updatedAt,
  });

  /// Portefeuille vide par defaut.
  static const Wallet empty = Wallet(balance: 0);

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] as int?,
      balance: _asDouble(json['balance']),
      currency: json['currency'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'balance': balance,
      'currency': currency,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

/// Entree du portefeuille (transaction).
class WalletEntry {
  final int id;
  final String? direction; // "credit" | "debit"
  final double amount;
  final double? balanceBefore;
  final double? balanceAfter;
  final String? description;
  final String? reference;
  final String? type;
  final String? status;
  final String? createdAt;

  const WalletEntry({
    required this.id,
    this.direction,
    required this.amount,
    this.balanceBefore,
    this.balanceAfter,
    this.description,
    this.reference,
    this.type,
    this.status,
    this.createdAt,
  });

  /// Verifie si l'entree est un credit.
  bool get isCredit => direction == 'credit';

  /// Verifie si l'entree est un debit.
  bool get isDebit => direction == 'debit';

  factory WalletEntry.fromJson(Map<String, dynamic> json) {
    return WalletEntry(
      id: json['id'] as int? ?? 0,
      direction: json['direction'] as String?,
      amount: _asDouble(json['amount']),
      balanceBefore: _asNullableDouble(json['balance_before']),
      balanceAfter: _asNullableDouble(json['balance_after']),
      description:
          json['label'] as String? ?? json['description'] as String?,
      reference: json['code'] as String? ?? json['reference'] as String?,
      type: json['actor_type'] as String? ?? json['type'] as String?,
      status: json['status'] as String?,
      createdAt:
          json['date_created'] as String? ?? json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'direction': direction,
      'amount': amount,
      'balance_before': balanceBefore,
      'balance_after': balanceAfter,
      'description': description,
      'reference': reference,
      'type': type,
      'status': status,
      'created_at': createdAt,
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

double? _asNullableDouble(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw);
  return null;
}
