import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/models/order_model.dart' show PaginationMeta;
import 'package:merchant/models/ticket_model.dart';
import 'package:merchant/services/api_client.dart';
import 'package:merchant/services/ticket_service.dart';

// ---------------------------------------------------------------------------
// List state
// ---------------------------------------------------------------------------

enum TicketsStatus { initial, loading, loaded, error }

/// Filtre de statut applique a la liste de tickets (client-side).
enum TicketsFilter { all, open, closed }

extension TicketsFilterX on TicketsFilter {
  String get label {
    switch (this) {
      case TicketsFilter.all:
        return 'Tous';
      case TicketsFilter.open:
        return 'Ouverts';
      case TicketsFilter.closed:
        return 'Fermes';
    }
  }

  bool matches(TicketStatus status) {
    switch (this) {
      case TicketsFilter.all:
        return true;
      case TicketsFilter.open:
        return status == TicketStatus.open ||
            status == TicketStatus.inProgress ||
            status == TicketStatus.awaitingReply;
      case TicketsFilter.closed:
        return status == TicketStatus.resolved ||
            status == TicketStatus.closed ||
            status == TicketStatus.rejected;
    }
  }
}

class TicketsListState {
  final TicketsStatus status;
  final List<Ticket> tickets;
  final PaginationMeta? meta;
  final TicketsFilter filter;
  final bool isLoadingMore;
  final String? errorMessage;

  const TicketsListState({
    this.status = TicketsStatus.initial,
    this.tickets = const <Ticket>[],
    this.meta,
    this.filter = TicketsFilter.all,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  TicketsListState copyWith({
    TicketsStatus? status,
    List<Ticket>? tickets,
    PaginationMeta? meta,
    TicketsFilter? filter,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TicketsListState(
      status: status ?? this.status,
      tickets: tickets ?? this.tickets,
      meta: meta ?? this.meta,
      filter: filter ?? this.filter,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  List<Ticket> get filteredTickets =>
      tickets.where((Ticket t) => filter.matches(t.status)).toList();

  bool get hasNextPage => meta?.hasNextPage ?? false;
}

// ---------------------------------------------------------------------------
// List notifier
// ---------------------------------------------------------------------------

class TicketsListNotifier extends StateNotifier<TicketsListState> {
  final TicketService _service;

  TicketsListNotifier({TicketService? service})
      : _service = service ?? TicketService(),
        super(const TicketsListState());

  Future<void> load() async {
    state = state.copyWith(status: TicketsStatus.loading, clearError: true);
    try {
      final result = await _service.listTickets(page: 1, limit: 25);
      state = state.copyWith(
        status: TicketsStatus.loaded,
        tickets: result.data,
        meta: result.meta,
      );
    } on ApiException catch (e) {
      debugPrint('[TicketsProvider] load failed: $e');
      state = state.copyWith(
        status: TicketsStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[TicketsProvider] load error: $e');
      state = state.copyWith(
        status: TicketsStatus.error,
        errorMessage: 'Impossible de charger les tickets',
      );
    }
  }

  Future<void> refresh() => load();

  Future<void> loadMore() async {
    final PaginationMeta? meta = state.meta;
    if (meta == null || !meta.hasNextPage || state.isLoadingMore) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _service.listTickets(
        page: meta.page + 1,
        limit: meta.limit,
      );
      state = state.copyWith(
        tickets: <Ticket>[...state.tickets, ...result.data],
        meta: result.meta,
        isLoadingMore: false,
      );
    } catch (e) {
      debugPrint('[TicketsProvider] loadMore error: $e');
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void setFilter(TicketsFilter filter) {
    if (filter == state.filter) return;
    state = state.copyWith(filter: filter);
  }

  /// Creer un ticket et l'ajouter en tete de liste.
  Future<Ticket?> createTicket(CreateTicketRequest request) async {
    try {
      final Ticket created = await _service.createTicket(request);
      state = state.copyWith(
        tickets: <Ticket>[created, ...state.tickets],
      );
      return created;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Impossible de creer le ticket',
      );
      return null;
    }
  }
}

final ticketsListProvider =
    StateNotifierProvider<TicketsListNotifier, TicketsListState>((ref) {
  return TicketsListNotifier();
});

// ---------------------------------------------------------------------------
// Detail state
// ---------------------------------------------------------------------------

class TicketDetailState {
  final TicketsStatus status;
  final Ticket? ticket;
  final List<TicketMessage> messages;
  final List<TicketLog> logs;
  final bool isSending;
  final String? errorMessage;

  const TicketDetailState({
    this.status = TicketsStatus.initial,
    this.ticket,
    this.messages = const <TicketMessage>[],
    this.logs = const <TicketLog>[],
    this.isSending = false,
    this.errorMessage,
  });

  TicketDetailState copyWith({
    TicketsStatus? status,
    Ticket? ticket,
    List<TicketMessage>? messages,
    List<TicketLog>? logs,
    bool? isSending,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TicketDetailState(
      status: status ?? this.status,
      ticket: ticket ?? this.ticket,
      messages: messages ?? this.messages,
      logs: logs ?? this.logs,
      isSending: isSending ?? this.isSending,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class TicketDetailNotifier extends StateNotifier<TicketDetailState> {
  final TicketService _service;
  final String ticketId;

  TicketDetailNotifier({required this.ticketId, TicketService? service})
      : _service = service ?? TicketService(),
        super(const TicketDetailState());

  Future<void> load() async {
    state = state.copyWith(status: TicketsStatus.loading, clearError: true);
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _service.getTicket(ticketId),
        _service.getMessages(ticketId, page: 1, limit: 100),
        _service.getLogs(ticketId),
      ]);
      final Ticket ticket = results[0] as Ticket;
      final messagesResult = results[1] as dynamic; // PaginatedResult
      final List<TicketLog> logs = results[2] as List<TicketLog>;

      state = state.copyWith(
        status: TicketsStatus.loaded,
        ticket: ticket,
        messages: messagesResult.data as List<TicketMessage>,
        logs: logs,
      );

      // Auto mark-read des messages non lus qui ne sont pas les miens.
      final List<int> unreadIds = (messagesResult.data as List<TicketMessage>)
          .where((TicketMessage m) => !m.isRead && !m.isMine)
          .map((TicketMessage m) => m.id)
          .toList();
      if (unreadIds.isNotEmpty) {
        unawaited(_service.markRead(ticketId, unreadIds));
      }
    } on ApiException catch (e) {
      debugPrint('[TicketDetail] load failed: $e');
      state = state.copyWith(
        status: TicketsStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[TicketDetail] load error: $e');
      state = state.copyWith(
        status: TicketsStatus.error,
        errorMessage: 'Impossible de charger le ticket',
      );
    }
  }

  Future<void> refresh() => load();

  /// Envoie un message et l'ajoute optimistiquement.
  Future<bool> sendMessage(String body) async {
    if (body.trim().isEmpty) return false;
    state = state.copyWith(isSending: true, clearError: true);
    try {
      final TicketMessage msg =
          await _service.sendMessage(ticketId, body: body.trim());
      state = state.copyWith(
        messages: <TicketMessage>[...state.messages, msg],
        isSending: false,
      );
      return true;
    } on ApiException catch (e) {
      debugPrint('[TicketDetail] sendMessage failed: $e');
      state = state.copyWith(isSending: false, errorMessage: e.message);
      return false;
    } catch (e) {
      debugPrint('[TicketDetail] sendMessage error: $e');
      state = state.copyWith(
        isSending: false,
        errorMessage: 'Envoi impossible',
      );
      return false;
    }
  }
}

/// Provider familial indexe par ticketId.
final ticketDetailProvider = StateNotifierProvider.family<TicketDetailNotifier,
    TicketDetailState, String>((ref, ticketId) {
  return TicketDetailNotifier(ticketId: ticketId);
});

// ---------------------------------------------------------------------------
// Priorities provider
// ---------------------------------------------------------------------------

/// FutureProvider pour charger les priorites disponibles a la volee.
final ticketPrioritiesProvider =
    FutureProvider<List<TicketPriorityOption>>((ref) async {
  try {
    return await TicketService().getPriorities();
  } catch (_) {
    return const <TicketPriorityOption>[];
  }
});

/// Charge la liste d'actions disponibles pour un ticket selon son statut
/// (etat machine). Utilise par l'ecran detail pour griser/montrer les
/// boutons d'action contextuels.
final ticketActionsProvider = FutureProvider.family<List<TicketActionOption>,
    String>((ref, status) async {
  try {
    return await TicketService().getActions(status: status);
  } catch (_) {
    return const <TicketActionOption>[];
  }
});

/// Charge la liste des utilisateurs mentionables dans un ticket
/// (autocomplete @mention). Rafraichit a chaque recherche.
final ticketMentionableUsersProvider =
    FutureProvider.family<List<MentionableUser>, String>((ref, ticketId) async {
  try {
    return await TicketService()
        .getMentionableUsers(ticketId, limit: 20);
  } catch (_) {
    return const <MentionableUser>[];
  }
});

/// Compteur de messages non lus pour un ticket donne (badge temps reel).
final ticketUnreadCountProvider =
    FutureProvider.family<int, String>((ref, ticketId) async {
  try {
    return await TicketService().getUnreadCount(ticketId);
  } catch (_) {
    return 0;
  }
});

