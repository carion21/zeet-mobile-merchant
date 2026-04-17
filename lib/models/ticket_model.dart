// Modeles representant les tickets de support partner.
// Correspond aux reponses de `/v1/partner/tickets/*`.

/// Statut d'un ticket.
///
/// Mappings sur les statuts backend les plus courants :
/// - `open`, `pending` → warning (a traiter)
/// - `in_progress`, `awaiting_reply` → info (en cours)
/// - `resolved`, `closed` → success (termine)
/// - `rejected` → danger
enum TicketStatus {
  open,
  inProgress,
  awaitingReply,
  resolved,
  closed,
  rejected,
  unknown,
}

extension TicketStatusX on TicketStatus {
  String get apiValue {
    switch (this) {
      case TicketStatus.open:
        return 'open';
      case TicketStatus.inProgress:
        return 'in_progress';
      case TicketStatus.awaitingReply:
        return 'awaiting_reply';
      case TicketStatus.resolved:
        return 'resolved';
      case TicketStatus.closed:
        return 'closed';
      case TicketStatus.rejected:
        return 'rejected';
      case TicketStatus.unknown:
        return 'unknown';
    }
  }

  String get displayLabel {
    switch (this) {
      case TicketStatus.open:
        return 'Ouvert';
      case TicketStatus.inProgress:
        return 'En cours';
      case TicketStatus.awaitingReply:
        return 'En attente';
      case TicketStatus.resolved:
        return 'Resolu';
      case TicketStatus.closed:
        return 'Ferme';
      case TicketStatus.rejected:
        return 'Rejete';
      case TicketStatus.unknown:
        return 'Inconnu';
    }
  }

  static TicketStatus fromString(String? raw) {
    switch (raw) {
      case 'open':
        return TicketStatus.open;
      case 'in_progress':
        return TicketStatus.inProgress;
      case 'awaiting_reply':
        return TicketStatus.awaitingReply;
      case 'resolved':
        return TicketStatus.resolved;
      case 'closed':
        return TicketStatus.closed;
      case 'rejected':
        return TicketStatus.rejected;
      default:
        return TicketStatus.unknown;
    }
  }
}

/// Priorite d'un ticket.
enum TicketPriority { low, normal, high, urgent, unknown }

extension TicketPriorityX on TicketPriority {
  String get apiValue {
    switch (this) {
      case TicketPriority.low:
        return 'low';
      case TicketPriority.normal:
        return 'normal';
      case TicketPriority.high:
        return 'high';
      case TicketPriority.urgent:
        return 'urgent';
      case TicketPriority.unknown:
        return 'normal';
    }
  }

  String get displayLabel {
    switch (this) {
      case TicketPriority.low:
        return 'Basse';
      case TicketPriority.normal:
        return 'Normale';
      case TicketPriority.high:
        return 'Haute';
      case TicketPriority.urgent:
        return 'Urgente';
      case TicketPriority.unknown:
        return 'Normale';
    }
  }

  static TicketPriority fromString(String? raw) {
    switch (raw) {
      case 'low':
        return TicketPriority.low;
      case 'normal':
        return TicketPriority.normal;
      case 'high':
        return TicketPriority.high;
      case 'urgent':
        return TicketPriority.urgent;
      default:
        return TicketPriority.unknown;
    }
  }
}

/// Ticket de support.
class Ticket {
  final int id;
  final String? code;
  final String title;
  final String? description;
  final TicketStatus status;
  final TicketPriority priority;
  final int? orderId;
  final String? orderCode;
  final int unreadCount;
  final int messagesCount;
  final String? createdAt;
  final String? updatedAt;
  final String? lastMessageAt;

  const Ticket({
    required this.id,
    this.code,
    required this.title,
    this.description,
    this.status = TicketStatus.unknown,
    this.priority = TicketPriority.normal,
    this.orderId,
    this.orderCode,
    this.unreadCount = 0,
    this.messagesCount = 0,
    this.createdAt,
    this.updatedAt,
    this.lastMessageAt,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    final dynamic rawOrder = json['order'];
    int? orderId;
    String? orderCode;
    if (rawOrder is Map<String, dynamic>) {
      orderId = rawOrder['id'] as int?;
      orderCode = rawOrder['code'] as String?;
    } else if (rawOrder is int) {
      orderId = rawOrder;
    }

    return Ticket(
      id: json['id'] as int? ?? 0,
      code: json['code'] as String?,
      title: (json['title'] as String?) ?? 'Sans titre',
      description: json['description'] as String?,
      status: TicketStatusX.fromString(json['status'] as String?),
      priority: TicketPriorityX.fromString(json['priority'] as String?),
      orderId: orderId ?? json['order_id'] as int?,
      orderCode: orderCode,
      unreadCount: json['unread_count'] as int? ??
          json['unread_messages_count'] as int? ??
          0,
      messagesCount: json['messages_count'] as int? ?? 0,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      lastMessageAt: json['last_message_at'] as String?,
    );
  }

  Ticket copyWith({
    int? unreadCount,
    int? messagesCount,
    TicketStatus? status,
  }) {
    return Ticket(
      id: id,
      code: code,
      title: title,
      description: description,
      status: status ?? this.status,
      priority: priority,
      orderId: orderId,
      orderCode: orderCode,
      unreadCount: unreadCount ?? this.unreadCount,
      messagesCount: messagesCount ?? this.messagesCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastMessageAt: lastMessageAt,
    );
  }
}

/// Message dans un ticket.
class TicketMessage {
  final int id;
  final String? body;
  final int? authorId;
  final String? authorName;
  final String? authorType; // 'partner' | 'admin' | 'system' | 'client'
  final bool isRead;
  final String? createdAt;

  const TicketMessage({
    required this.id,
    this.body,
    this.authorId,
    this.authorName,
    this.authorType,
    this.isRead = false,
    this.createdAt,
  });

  /// Un message envoye par le partner courant.
  bool get isMine => authorType == 'partner';

  factory TicketMessage.fromJson(Map<String, dynamic> json) {
    final dynamic rawAuthor = json['author'];
    int? authorId;
    String? authorName;
    String? authorType;
    if (rawAuthor is Map<String, dynamic>) {
      authorId = rawAuthor['id'] as int?;
      final String? first = rawAuthor['firstname'] as String?;
      final String? last = rawAuthor['lastname'] as String?;
      authorName = <String?>[first, last]
          .whereType<String>()
          .where((String s) => s.isNotEmpty)
          .join(' ');
      authorType = rawAuthor['type'] as String? ??
          rawAuthor['surface'] as String? ??
          rawAuthor['role'] as String?;
    }

    return TicketMessage(
      id: json['id'] as int? ?? 0,
      body: json['body'] as String? ?? json['content'] as String?,
      authorId: authorId ?? json['author_id'] as int?,
      authorName: authorName,
      authorType: authorType ?? json['author_type'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] as String?,
    );
  }
}

/// Entree de log / audit d'un ticket.
class TicketLog {
  final int id;
  final String? action;
  final String? note;
  final String? actorName;
  final String? createdAt;

  const TicketLog({
    required this.id,
    this.action,
    this.note,
    this.actorName,
    this.createdAt,
  });

  factory TicketLog.fromJson(Map<String, dynamic> json) {
    String? actorName;
    final dynamic actor = json['actor'];
    if (actor is Map<String, dynamic>) {
      final String? first = actor['firstname'] as String?;
      final String? last = actor['lastname'] as String?;
      actorName = <String?>[first, last]
          .whereType<String>()
          .where((String s) => s.isNotEmpty)
          .join(' ');
    }
    return TicketLog(
      id: json['id'] as int? ?? 0,
      action: json['action'] as String?,
      note: json['note'] as String? ?? json['description'] as String?,
      actorName: actorName ?? json['actor_name'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}

/// Utilisateur mentionable (@mention).
class MentionableUser {
  final int id;
  final String? firstname;
  final String? lastname;
  final String? type;

  const MentionableUser({
    required this.id,
    this.firstname,
    this.lastname,
    this.type,
  });

  String get fullName {
    final List<String> parts = <String>[];
    if (firstname != null && firstname!.isNotEmpty) parts.add(firstname!);
    if (lastname != null && lastname!.isNotEmpty) parts.add(lastname!);
    return parts.isNotEmpty ? parts.join(' ') : 'Utilisateur $id';
  }

  factory MentionableUser.fromJson(Map<String, dynamic> json) {
    return MentionableUser(
      id: json['id'] as int? ?? 0,
      firstname: json['firstname'] as String?,
      lastname: json['lastname'] as String?,
      type: json['type'] as String? ?? json['role'] as String?,
    );
  }
}

/// Option renvoyee par GET /v1/partner/tickets/select/priorities.
class TicketPriorityOption {
  final String value;
  final String label;

  const TicketPriorityOption({required this.value, required this.label});

  factory TicketPriorityOption.fromJson(Map<String, dynamic> json) {
    return TicketPriorityOption(
      value: json['value'] as String? ?? '',
      label: json['label'] as String? ?? json['value'] as String? ?? '',
    );
  }
}

/// Action disponible selon l'etat machine, renvoyee par
/// `GET /v1/partner/tickets/actions?status=:status`.
class TicketActionOption {
  final String action;
  final String label;

  const TicketActionOption({required this.action, required this.label});

  factory TicketActionOption.fromJson(Map<String, dynamic> json) {
    return TicketActionOption(
      action: json['action'] as String? ?? json['value'] as String? ?? '',
      label: json['label'] as String? ?? json['action'] as String? ?? '',
    );
  }
}

/// Creation d'un ticket (body POST).
class CreateTicketRequest {
  final String title;
  final String? description;
  final TicketPriority priority;
  final int? orderId;

  const CreateTicketRequest({
    required this.title,
    this.description,
    this.priority = TicketPriority.normal,
    this.orderId,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      if (description != null && description!.isNotEmpty)
        'description': description,
      'priority': priority.apiValue,
      if (orderId != null) 'order': orderId,
    };
  }
}
