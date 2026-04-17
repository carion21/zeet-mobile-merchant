// Provider Riverpod qui pilote l'ecran "nouvelle commande" (Incoming Order).
//
// Responsabilites :
//  - Detenir le payload courant (ou null si inactif)
//  - Declencher confirm + ack cote API sur acceptation
//  - Declencher cancel + ack cote API sur refus
//  - Exposer les etats transitoires (accepting / rejecting) pour l'UI
//
// /!\ PAS DE MINUTEUR :
// Le partner peut ne pas etre a cote du telephone quand la commande arrive
// (cuisine, caisse, autre zone). L'ecran reste affiche avec la sonnerie
// en boucle tant que le partner n'a pas explicitement accepte ou refuse.
//
// Hors-scope Phase 2 :
//  - Lecture du ringtone en boucle est gere par l'ecran (flutter_ringtone_player)
//  - File d'attente offline (Phase 5)

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:merchant/models/incoming_order_payload.dart';
import 'package:merchant/services/api_client.dart';
import 'package:merchant/services/notification_service.dart';
import 'package:merchant/services/order_service.dart';

/// Temps de preparation par defaut envoye au backend lors d'un confirm.
const int kDefaultPrepMinutes = 30;

enum IncomingOrderPhase {
  idle,
  ringing,
  accepting,
  rejecting,
  accepted,
  rejected,
  error,
}

@immutable
class IncomingOrderState {
  final IncomingOrderPhase phase;
  final IncomingOrderPayload? payload;

  /// Dernier message d'erreur utilisateur (affiche inline sur l'ecran).
  final String? errorMessage;

  const IncomingOrderState({
    this.phase = IncomingOrderPhase.idle,
    this.payload,
    this.errorMessage,
  });

  bool get isActive =>
      phase == IncomingOrderPhase.ringing ||
      phase == IncomingOrderPhase.accepting ||
      phase == IncomingOrderPhase.rejecting;

  bool get isBusy =>
      phase == IncomingOrderPhase.accepting ||
      phase == IncomingOrderPhase.rejecting;

  IncomingOrderState copyWith({
    IncomingOrderPhase? phase,
    IncomingOrderPayload? payload,
    String? errorMessage,
    bool clearError = false,
    bool clearPayload = false,
  }) {
    return IncomingOrderState(
      phase: phase ?? this.phase,
      payload: clearPayload ? null : (payload ?? this.payload),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class IncomingOrderNotifier extends StateNotifier<IncomingOrderState> {
  final OrderService _orderService;
  final NotificationService _notificationService;

  IncomingOrderNotifier({
    OrderService? orderService,
    NotificationService? notificationService,
  })  : _orderService = orderService ?? OrderService(),
        _notificationService = notificationService ?? NotificationService(),
        super(const IncomingOrderState());

  // ---------------------------------------------------------------------------
  // Entry point — called by the dispatcher / FCM handler / dev trigger
  // ---------------------------------------------------------------------------

  /// Demarre le "ringing" pour un payload. Si un ringing est deja actif pour la
  /// meme commande, ignore (evite les doubles pushes FCM).
  void show(IncomingOrderPayload payload) {
    // Idempotence : meme commande deja affichee → on ignore.
    if (state.isActive && state.payload?.orderId == payload.orderId) {
      debugPrint(
        '[IncomingOrder] duplicate push for order ${payload.orderId} — ignored',
      );
      return;
    }

    state = IncomingOrderState(
      phase: IncomingOrderPhase.ringing,
      payload: payload,
    );
  }

  // ---------------------------------------------------------------------------
  // Accept (slide-to-accept)
  // ---------------------------------------------------------------------------

  /// Appele par le slider quand le partner accepte la commande.
  ///
  /// Retourne `true` si l'acceptation a reussi cote API (screen peut se
  /// fermer), `false` sinon (screen reste pour permettre un retry).
  Future<bool> accept() async {
    final payload = state.payload;
    if (payload == null || state.isBusy) return false;

    state = state.copyWith(
      phase: IncomingOrderPhase.accepting,
      clearError: true,
    );

    try {
      await _orderService.confirmOrder(
        payload.orderId,
        estimatedMinutes: kDefaultPrepMinutes,
      );

      // Ack la notification pour couper la cascade cote backend.
      if (payload.requiresAck && payload.notificationId > 0) {
        try {
          await _notificationService.acknowledge(payload.notificationId);
        } catch (e) {
          // L'ack a echoue mais la commande est confirmee : on ne bloque pas
          // le flow utilisateur. Le backend retentera son mieux.
          debugPrint('[IncomingOrder] ack failed (non-fatal): $e');
        }
      }

      state = state.copyWith(phase: IncomingOrderPhase.accepted);
      return true;
    } on ApiException catch (e) {
      debugPrint('[IncomingOrder] accept failed: $e');
      state = state.copyWith(
        phase: IncomingOrderPhase.error,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('[IncomingOrder] accept error: $e');
      state = state.copyWith(
        phase: IncomingOrderPhase.error,
        errorMessage: 'Impossible de confirmer la commande',
      );
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Reject (bouton refuser)
  // ---------------------------------------------------------------------------

  /// Appele par le bouton "Refuser".
  /// [reason] est **obligatoire** : le backend rejette tout cancel sans raison (400).
  Future<bool> reject({required String reason}) async {
    final payload = state.payload;
    if (payload == null || state.isBusy) return false;

    final trimmed = reason.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        phase: IncomingOrderPhase.error,
        errorMessage:
            'La raison du refus est obligatoire pour annuler une commande.',
      );
      return false;
    }

    state = state.copyWith(
      phase: IncomingOrderPhase.rejecting,
      clearError: true,
    );

    try {
      await _orderService.cancelOrder(
        payload.orderId,
        cancelReason: trimmed,
      );

      if (payload.requiresAck && payload.notificationId > 0) {
        try {
          await _notificationService.acknowledge(payload.notificationId);
        } catch (e) {
          debugPrint('[IncomingOrder] ack failed (non-fatal): $e');
        }
      }

      state = state.copyWith(phase: IncomingOrderPhase.rejected);
      return true;
    } on ApiException catch (e) {
      debugPrint('[IncomingOrder] reject failed: $e');
      state = state.copyWith(
        phase: IncomingOrderPhase.error,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('[IncomingOrder] reject error: $e');
      state = state.copyWith(
        phase: IncomingOrderPhase.error,
        errorMessage: 'Impossible de refuser la commande',
      );
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Misc
  // ---------------------------------------------------------------------------

  /// Reset complet de l'etat (a appeler une fois que l'ecran a ete ferme
  /// apres un `accepted` ou `rejected`).
  void dismiss() {
    state = const IncomingOrderState();
  }

  /// Permet a l'UI de retenter apres une erreur (remet en `ringing`).
  void retryAfterError() {
    if (state.phase != IncomingOrderPhase.error) return;
    state = state.copyWith(
      phase: IncomingOrderPhase.ringing,
      clearError: true,
    );
  }
}

final incomingOrderProvider =
    StateNotifierProvider<IncomingOrderNotifier, IncomingOrderState>((ref) {
  return IncomingOrderNotifier();
});
