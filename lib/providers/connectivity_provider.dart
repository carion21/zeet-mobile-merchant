// lib/providers/connectivity_provider.dart
//
// Provider Riverpod de connectivite — wrap le service mutualise
// `ZeetConnectivity` expose par le package `zeet_ui`. Alimente le
// `ConnectivityBanner` et les etats offline des ecrans merchant.
//
// Usage :
// ```dart
// final status = ref.watch(connectivityStatusProvider);
// final online = status.maybeWhen(data: (v) => v, orElse: () => true);
// ConnectivityBanner(isOnline: online);
// ```

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zeet_ui/zeet_ui.dart';

/// `Stream<bool>` — `true` si au moins une interface reseau est active.
///
/// Emet l'etat initial des l'abonnement, puis un nouvel event a chaque
/// changement detecte par `connectivity_plus` (wifi, mobile, ethernet,
/// vpn, none).
final connectivityStatusProvider = StreamProvider<bool>((ref) {
  final zc = ZeetConnectivity();
  ref.onDispose(zc.dispose);
  return zc.stream;
});

/// Raccourci synchrone : retourne `true` si online, ou `true` par defaut
/// tant que le stream n'a pas encore emis (fail-open — on ne bloque jamais
/// l'utilisateur sur un faux positif au boot).
final isOnlineProvider = Provider<bool>((ref) {
  final async = ref.watch(connectivityStatusProvider);
  return async.valueOrNull ?? true;
});
