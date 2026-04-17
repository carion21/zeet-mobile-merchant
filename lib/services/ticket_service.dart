import 'package:merchant/core/constants/api.dart';
import 'package:merchant/models/order_model.dart'
    show PaginationMeta, PaginatedResult;
import 'package:merchant/models/ticket_model.dart';
import 'package:merchant/services/api_client.dart';

/// Service pour les 11 endpoints `/v1/partner/tickets/*`.
class TicketService {
  final ApiClient _apiClient;

  TicketService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  // ---------------------------------------------------------------------------
  // GET /v1/partner/tickets
  // ---------------------------------------------------------------------------
  Future<PaginatedResult<Ticket>> listTickets({
    int page = 1,
    int limit = 25,
    String? sort,
  }) async {
    final Map<String, String> queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (sort != null && sort.isNotEmpty) queryParams['sort'] = sort;

    final Map<String, dynamic> response = await _apiClient.get(
      TicketEndpoints.list,
      queryParams: queryParams,
    );

    final List<dynamic> rawList = response['data'] as List? ?? const [];
    final List<Ticket> tickets = rawList
        .whereType<Map<String, dynamic>>()
        .map(Ticket.fromJson)
        .toList();

    final dynamic rawMeta = response['meta'];
    final PaginationMeta meta = rawMeta is Map<String, dynamic>
        ? PaginationMeta.fromJson(rawMeta)
        : PaginationMeta(
            total: tickets.length,
            page: page,
            limit: limit,
            totalPages: 1,
          );
    return PaginatedResult<Ticket>(data: tickets, meta: meta);
  }

  // ---------------------------------------------------------------------------
  // POST /v1/partner/tickets
  // ---------------------------------------------------------------------------
  Future<Ticket> createTicket(CreateTicketRequest request) async {
    final Map<String, dynamic> response = await _apiClient.post(
      TicketEndpoints.create,
      body: request.toJson(),
    );
    final dynamic data = response['data'] ?? response;
    return Ticket.fromJson(data as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/tickets/:id
  // ---------------------------------------------------------------------------
  Future<Ticket> getTicket(String id) async {
    final Map<String, dynamic> response =
        await _apiClient.get(TicketEndpoints.get(id));
    final dynamic data = response['data'] ?? response;
    return Ticket.fromJson(data as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/tickets/:id/messages
  // ---------------------------------------------------------------------------
  Future<PaginatedResult<TicketMessage>> getMessages(
    String id, {
    int page = 1,
    int limit = 50,
  }) async {
    final Map<String, String> queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    final Map<String, dynamic> response = await _apiClient.get(
      TicketEndpoints.messages(id),
      queryParams: queryParams,
    );

    final List<dynamic> rawList = response['data'] as List? ?? const [];
    final List<TicketMessage> messages = rawList
        .whereType<Map<String, dynamic>>()
        .map(TicketMessage.fromJson)
        .toList();

    final dynamic rawMeta = response['meta'];
    final PaginationMeta meta = rawMeta is Map<String, dynamic>
        ? PaginationMeta.fromJson(rawMeta)
        : PaginationMeta(
            total: messages.length,
            page: page,
            limit: limit,
            totalPages: 1,
          );
    return PaginatedResult<TicketMessage>(data: messages, meta: meta);
  }

  // ---------------------------------------------------------------------------
  // POST /v1/partner/tickets/:id/messages
  // ---------------------------------------------------------------------------
  Future<TicketMessage> sendMessage(
    String id, {
    required String body,
    List<int>? mentionedUserIds,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'body': body,
      if (mentionedUserIds != null && mentionedUserIds.isNotEmpty)
        'mentioned_user_ids': mentionedUserIds,
    };
    final Map<String, dynamic> response = await _apiClient.post(
      TicketEndpoints.sendMessage(id),
      body: payload,
    );
    final dynamic data = response['data'] ?? response;
    return TicketMessage.fromJson(data as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------------------
  // PATCH /v1/partner/tickets/:id/messages/read
  // ---------------------------------------------------------------------------
  Future<void> markRead(String id, List<int> messageIds) async {
    await _apiClient.patch(
      TicketEndpoints.markRead(id),
      body: <String, dynamic>{'message_ids': messageIds},
    );
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/tickets/:id/messages/unread-count
  // ---------------------------------------------------------------------------
  Future<int> getUnreadCount(String id) async {
    final Map<String, dynamic> response =
        await _apiClient.get(TicketEndpoints.unreadCount(id));
    final dynamic data = response['data'] ?? response;
    if (data is Map<String, dynamic>) {
      return (data['count'] as int?) ??
          (data['unread_count'] as int?) ??
          (data['unread'] as int?) ??
          0;
    }
    if (data is int) return data;
    return 0;
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/tickets/:id/logs
  // ---------------------------------------------------------------------------
  Future<List<TicketLog>> getLogs(String id) async {
    final Map<String, dynamic> response =
        await _apiClient.get(TicketEndpoints.logs(id));
    final dynamic data = response['data'] ?? response;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(TicketLog.fromJson)
          .toList();
    }
    return const <TicketLog>[];
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/tickets/:id/mentionable-users
  // ---------------------------------------------------------------------------
  Future<List<MentionableUser>> getMentionableUsers(
    String id, {
    String? search,
    int? limit,
  }) async {
    final Map<String, String> queryParams = <String, String>{};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (limit != null) queryParams['limit'] = limit.toString();

    final Map<String, dynamic> response = await _apiClient.get(
      TicketEndpoints.mentionableUsers(id),
      queryParams: queryParams.isEmpty ? null : queryParams,
    );
    final dynamic data = response['data'] ?? response;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(MentionableUser.fromJson)
          .toList();
    }
    return const <MentionableUser>[];
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/tickets/actions?status=<status>
  // ---------------------------------------------------------------------------
  Future<List<TicketActionOption>> getActions({required String status}) async {
    final Map<String, dynamic> response = await _apiClient.get(
      TicketEndpoints.actions,
      queryParams: <String, String>{'status': status},
    );
    final dynamic data = response['data'] ?? response;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(TicketActionOption.fromJson)
          .toList();
    }
    return const <TicketActionOption>[];
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/tickets/select/priorities
  // ---------------------------------------------------------------------------
  Future<List<TicketPriorityOption>> getPriorities() async {
    final Map<String, dynamic> response =
        await _apiClient.get(TicketEndpoints.priorities);
    final dynamic data = response['data'] ?? response;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(TicketPriorityOption.fromJson)
          .toList();
    }
    return const <TicketPriorityOption>[];
  }
}
