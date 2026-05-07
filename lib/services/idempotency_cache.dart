// lib/services/idempotency_cache.dart
//
// Cache d'idempotency-key generique. Garantit qu'une mutation critique
// (POST/PATCH/DELETE) re-emise apres timeout ou reseau coupe ne provoque
// pas de doublon serveur. Chaque mutation marquee `idempotent` recoit un
// UUID v4 stable lors du premier essai, persiste dans SharedPreferences,
// et est rejoue avec le meme UUID jusqu'a confirmation 2xx ou 4xx
// definitif (rejet metier non-retryable).
//
// Mutations couvertes (Skill plan 7-D §1) :
//   - POST /v1/partner/orders/{id}/confirm
//   - POST /v1/partner/orders/{id}/preparing
//   - POST /v1/partner/orders/{id}/ready
//   - POST /v1/partner/orders/{id}/cancel
//   - POST /v1/partner/payouts
//   - POST /v1/partner/payouts/{uuid}/validate
//
// TTL : 24h. Apres expiration, la cle est purgee (le serveur doit purger
// la sienne au meme rythme cf. RFC Idempotency-Key draft-ietf-httpapi).

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class IdempotencyCache {
  IdempotencyCache._();
  static final IdempotencyCache instance = IdempotencyCache._();

  static const String _prefix = 'zeet_merchant_idem_';
  static const Duration _ttl = Duration(hours: 24);
  static const _uuid = Uuid();

  /// Recupere la cle d'idempotency pour une logical key (ex: "order:42:confirm").
  /// Si la cle n'existe pas ou a expire, en genere une nouvelle et la
  /// persiste. Retourne toujours un UUID v4 stable.
  ///
  /// Usage typique cote ApiClient :
  ///   final key = await IdempotencyCache.instance.keyFor('order:$id:confirm');
  ///   headers['Idempotency-Key'] = key;
  Future<String> keyFor(String logicalKey) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = '$_prefix$logicalKey';
    final raw = prefs.getString(storageKey);

    if (raw != null) {
      final parts = raw.split('|');
      if (parts.length == 2) {
        final key = parts[0];
        final ts = int.tryParse(parts[1]) ?? 0;
        final age = DateTime.now().millisecondsSinceEpoch - ts;
        if (age < _ttl.inMilliseconds && key.isNotEmpty) {
          return key;
        }
      }
    }

    final fresh = _uuid.v4();
    await prefs.setString(
      storageKey,
      '$fresh|${DateTime.now().millisecondsSinceEpoch}',
    );
    return fresh;
  }

  /// Purge explicitement une cle apres confirmation 2xx finale ou rejet
  /// metier 4xx definitif. Empêche un re-emploi accidentel ulterieur.
  Future<void> purge(String logicalKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$logicalKey');
  }

  /// Nettoie toutes les cles expirees (TTL 24h). A appeler periodiquement
  /// (ex: au boot app, depuis main.dart) pour limiter la taille SP.
  Future<void> sweep() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final k in keys) {
      if (!k.startsWith(_prefix)) continue;
      final raw = prefs.getString(k);
      if (raw == null) continue;
      final parts = raw.split('|');
      if (parts.length != 2) {
        await prefs.remove(k);
        continue;
      }
      final ts = int.tryParse(parts[1]) ?? 0;
      if (now - ts >= _ttl.inMilliseconds) {
        await prefs.remove(k);
      }
    }
  }
}
