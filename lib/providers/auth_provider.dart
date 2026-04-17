import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/models/partner_model.dart';
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

  AuthNotifier({AuthService? authService})
      : _authService = authService ?? AuthService(),
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
  Future<void> logout() async {
    state = state.copyWith(status: AuthStatus.loading);

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
  return AuthNotifier();
});
