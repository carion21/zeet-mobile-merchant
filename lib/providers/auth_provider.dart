import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/models/partner_model.dart';
import 'package:merchant/providers/sync_provider.dart';
import 'package:merchant/providers/dashboard_provider.dart';
import 'package:merchant/providers/notifications_provider.dart';
import 'package:merchant/providers/orders_provider.dart';
import 'package:merchant/providers/payout_provider.dart';
import 'package:merchant/providers/profile_provider.dart';
import 'package:merchant/providers/ticket_provider.dart';
import 'package:merchant/providers/wallet_provider.dart';
import 'package:merchant/services/auth_service.dart';
import 'package:merchant/services/api_client.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final PartnerModel? partner;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.partner,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    PartnerModel? partner,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      partner: partner ?? this.partner,
      errorMessage: errorMessage,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final Ref? _ref;

  AuthNotifier({AuthService? authService, Ref? ref})
      : _authService = authService ?? AuthService(),
        _ref = ref,
        super(const AuthState());

  /// Verifie l'etat d'authentification au demarrage de l'app.
  ///
  /// Strategie OPTIMISTE : si des tokens locaux existent → `authenticated`
  /// immediat, l'hydratation du `PartnerModel` via `/me` tourne en tache
  /// de fond. Evite de figer la splash sur un backend lent.
  Future<void> checkAuthStatus() async {
    state = state.copyWith(status: AuthStatus.loading);

    final bool isAuth = await _authService.isAuthenticated();
    if (!isAuth) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    // Tokens presents → authenticated immediatement, partner=null temporaire.
    state = const AuthState(status: AuthStatus.authenticated);

    // Hydrate le partner en arriere-plan, ne bloque pas la navigation.
    unawaited(_refreshMeInBackground());
  }

  Future<void> _refreshMeInBackground() async {
    try {
      final partner = await _authService.getMe();
      state = AuthState(
        status: AuthStatus.authenticated,
        partner: partner,
      );
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        // Tokens invalides cote serveur → downgrade vers login.
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
      debugPrint('[AuthProvider] refresh /me failed: $e');
    } catch (e) {
      // Reseau / timeout : silencieux, on reste authenticated (offline-tolerant).
      debugPrint('[AuthProvider] refresh /me error: $e');
    }
  }

  /// Connecte le partner avec telephone + mot de passe.
  /// Retourne un message d'erreur en cas d'echec, null en cas de succes.
  Future<String?> login({
    required String phone,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      await _authService.login(phone: phone, password: password);

      // Recuperer le profil partner enrichi
      final partner = await _authService.getMe();

      state = AuthState(
        status: AuthStatus.authenticated,
        partner: partner,
      );

      return null; // succes
    } on ApiException catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: e.message,
      );
      return e.message;
    } catch (e) {
      const message = 'Une erreur est survenue lors de la connexion';
      state = const AuthState(
        status: AuthStatus.error,
        errorMessage: message,
      );
      return message;
    }
  }

  /// Deconnecte le partner et reinitialise l'etat.
  ///
  /// Ordre des operations (important) :
  ///   1. Purge la DB Drift locale (orders cache + queued actions). Sans
  ///      ca la queue d'un user A se rejouait avec les tokens du user B
  ///      apres un changement de compte → 403 et fuite cross-user.
  ///   2. Invalide les providers metier (orders, dashboard, wallet,
  ///      payouts, profile, tickets, notifs). Sans ca l'user voyait
  ///      brievement les commandes / le solde du compte precedent au
  ///      cold-start de la session suivante.
  ///   3. Demande au backend de revoquer les tokens + clear local tokens.
  ///   4. Reset le state authProvider.
  ///
  /// FCM listeners ne sont PAS disposes ici : ils sont des singletons
  /// `_initialized` une seule fois dans `_MyAppState.initState`. Le
  /// re-routage vers le bon compte se fait via
  /// `DeviceTokenManager.registerCurrentDevice()` au login suivant.
  ///
  /// Chaque etape est try/catch independante : on veut absolument que
  /// le logout aboutisse meme si une purge echoue (sinon l'user est
  /// bloque sur un compte qu'il refuse).
  Future<void> logout() async {
    state = state.copyWith(status: AuthStatus.loading);

    // 1. Purge DB locale — empeche la queue d'agir sur un compte tiers.
    final ref = _ref;
    if (ref != null) {
      try {
        await ref.read(partnerDatabaseProvider).clearAll();
      } catch (e) {
        debugPrint('[AuthProvider] clearAll DB failed: $e');
      }

      // 2. Invalide les providers metier — Riverpod recreera les notifiers
      //    a la prochaine watch/read, garantissant que rien du compte
      //    precedent ne reste affiche.
      for (final invalidate in <void Function()>[
        () => ref.invalidate(ordersListProvider),
        () => ref.invalidate(dashboardProvider),
        () => ref.invalidate(walletProvider),
        () => ref.invalidate(payoutsListProvider),
        () => ref.invalidate(profileProvider),
        () => ref.invalidate(ticketsListProvider),
        () => ref.invalidate(unreadCountProvider),
      ]) {
        try {
          invalidate();
        } catch (e) {
          debugPrint('[AuthProvider] invalidate provider failed: $e');
        }
      }
    }

    // 3. Backend logout + clear tokens.
    try {
      await _authService.logout();
    } catch (e) {
      debugPrint('[AuthProvider] logout error: $e');
    }

    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref: ref);
});
