// lib/services/cache_policies.dart
//
// TTL canonique par endpoint (Skill plan 7-D §4). Permet aux providers
// de connaitre la duree de fraicheur attendue pour decider si refetch
// ou utiliser le cache local Riverpod / Drift.
//
// Convention :
//   - Donnees temps reel (orders en cours)        → 30s
//   - Donnees agregees jour (dashboard, stats)    → 5min
//   - Donnees catalogue (produits, categories)    → 5min
//   - Donnees referentiel (status select, types)  → 1h
//   - Donnees profil (commission rate, info user) → 1h
//
// Usage :
//   final ttl = CachePolicies.ttlFor('dashboard.summary');
//   if (DateTime.now().difference(lastFetch) < ttl) return cached;

class CachePolicies {
  const CachePolicies._();

  static const Duration _short = Duration(seconds: 30);
  static const Duration _medium = Duration(minutes: 5);
  static const Duration _long = Duration(hours: 1);
  static const Duration _veryLong = Duration(hours: 24);

  static const Map<String, Duration> _ttls = <String, Duration>{
    // Dashboard / orders en cours — refetch frequent
    'dashboard.summary': _short,
    'orders.list': _short,
    'orders.counts': _short,
    'orders.detail': _short,

    // Stats / earnings — agregations jour
    'stats.rating': _medium,
    'stats.revenue': _medium,
    'product-stats.ranking': _medium,
    'wallet': _short,
    'wallet.entries': _medium,
    'transactions.list': _medium,

    // Catalogue — change rarement en service
    'products.list': _medium,
    'products.detail': _medium,
    'categories.list': _medium,
    'menus.list': _medium,

    // Profil / referentiel — quasi-statique
    'profile': _long,
    'commission-rate': _long,
    'orders.statuses': _long,
    'orders.transitions': _long,
    'orders.actions': _long,
    'tickets.priorities': _long,
    'notifications.preferences': _long,

    // Carts (paniers actifs cote partner) — temps reel
    'carts.list': _short,
    'carts.stats': _short,
  };

  /// Duree de fraicheur pour un endpoint logique. Retourne `_medium`
  /// (5min) si la cle n'est pas referencee — evite les bugs silencieux.
  static Duration ttlFor(String logicalKey) {
    return _ttls[logicalKey] ?? _medium;
  }

  /// TTL idempotency-key (cote client + serveur) — fenetre pendant
  /// laquelle un retry avec la meme cle renvoie la meme reponse.
  static Duration get idempotency => _veryLong;
}
