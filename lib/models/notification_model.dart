// lib/models/notification_model.dart
//
// Modeles lies au domaine Notifications de la surface partner/merchant.
// Mappe les payloads des endpoints /v1/partner/notifications/*.

/// Metadonnees de pagination standard de l'API ZEET.
class NotificationPaginationMeta {
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const NotificationPaginationMeta({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  bool get hasNextPage => page < totalPages;
  bool get hasPreviousPage => page > 1;

  factory NotificationPaginationMeta.fromJson(Map<String, dynamic> json) {
    return NotificationPaginationMeta(
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 25,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

class NotificationsPage {
  final List<NotificationItem> data;
  final NotificationPaginationMeta meta;

  const NotificationsPage({required this.data, required this.meta});
}

/// Un item de notification renvoye par l'API pour le partner.
class NotificationItem {
  final int id;
  final String? title;
  final String? body;
  final String? type;
  final String? category;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime? readAt;
  final bool isAcknowledged;
  final DateTime? acknowledgedAt;
  final DateTime? createdAt;

  const NotificationItem({
    required this.id,
    this.title,
    this.body,
    this.type,
    this.category,
    this.data,
    this.isRead = false,
    this.readAt,
    this.isAcknowledged = false,
    this.acknowledgedAt,
    this.createdAt,
  });

  NotificationItem copyWith({
    int? id,
    String? title,
    String? body,
    String? type,
    String? category,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? readAt,
    bool? isAcknowledged,
    DateTime? acknowledgedAt,
    DateTime? createdAt,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      category: category ?? this.category,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      isAcknowledged: isAcknowledged ?? this.isAcknowledged,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parseData(dynamic raw) {
      if (raw is Map<String, dynamic>) return raw;
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return null;
    }

    DateTime? parseDate(dynamic raw) {
      if (raw == null) return null;
      if (raw is String && raw.isNotEmpty) {
        return DateTime.tryParse(raw);
      }
      return null;
    }

    bool parseBool(dynamic raw, {bool fallback = false}) {
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      if (raw is String) {
        return raw == '1' || raw.toLowerCase() == 'true';
      }
      return fallback;
    }

    return NotificationItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String?,
      body: (json['body'] ?? json['message']) as String?,
      type: json['type'] as String?,
      category: json['category'] as String?,
      data: parseData(json['data']),
      isRead: parseBool(json['is_read'] ?? json['read']),
      readAt: parseDate(json['read_at']),
      isAcknowledged: parseBool(json['is_acknowledged'] ?? json['acknowledged']),
      acknowledgedAt: parseDate(json['acknowledged_at']),
      createdAt: parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (type != null) 'type': type,
      if (category != null) 'category': category,
      if (data != null) 'data': data,
      'is_read': isRead,
      if (readAt != null) 'read_at': readAt!.toIso8601String(),
      'is_acknowledged': isAcknowledged,
      if (acknowledgedAt != null)
        'acknowledged_at': acknowledgedAt!.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}

/// Une preference de notification pour le partner.
class NotificationPreference {
  final int id;
  final String? key;
  final String? label;
  final bool pushEnabled;
  final bool smsEnabled;
  final bool inAppEnabled;
  final bool emailEnabled;

  const NotificationPreference({
    required this.id,
    this.key,
    this.label,
    this.pushEnabled = true,
    this.smsEnabled = false,
    this.inAppEnabled = true,
    this.emailEnabled = false,
  });

  NotificationPreference copyWith({
    int? id,
    String? key,
    String? label,
    bool? pushEnabled,
    bool? smsEnabled,
    bool? inAppEnabled,
    bool? emailEnabled,
  }) {
    return NotificationPreference(
      id: id ?? this.id,
      key: key ?? this.key,
      label: label ?? this.label,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      smsEnabled: smsEnabled ?? this.smsEnabled,
      inAppEnabled: inAppEnabled ?? this.inAppEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
    );
  }

  factory NotificationPreference.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic raw, {bool fallback = false}) {
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      if (raw is String) {
        return raw == '1' || raw.toLowerCase() == 'true';
      }
      return fallback;
    }

    return NotificationPreference(
      id: (json['id'] as num?)?.toInt() ?? 0,
      key: (json['key'] ?? json['type']) as String?,
      label: (json['label'] ?? json['name']) as String?,
      pushEnabled: parseBool(json['push_enabled'], fallback: true),
      smsEnabled: parseBool(json['sms_enabled']),
      inAppEnabled: parseBool(json['in_app_enabled'], fallback: true),
      emailEnabled: parseBool(json['email_enabled']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (key != null) 'key': key,
      if (label != null) 'label': label,
      'push_enabled': pushEnabled,
      'sms_enabled': smsEnabled,
      'in_app_enabled': inAppEnabled,
      'email_enabled': emailEnabled,
    };
  }
}

/// Patch partiel envoye lors de la mise a jour d'une preference.
class NotificationPreferencePatch {
  final bool? pushEnabled;
  final bool? smsEnabled;
  final bool? inAppEnabled;
  final bool? emailEnabled;

  const NotificationPreferencePatch({
    this.pushEnabled,
    this.smsEnabled,
    this.inAppEnabled,
    this.emailEnabled,
  });

  Map<String, dynamic> toJson() {
    return {
      if (pushEnabled != null) 'push_enabled': pushEnabled,
      if (smsEnabled != null) 'sms_enabled': smsEnabled,
      if (inAppEnabled != null) 'in_app_enabled': inAppEnabled,
      if (emailEnabled != null) 'email_enabled': emailEnabled,
    };
  }
}

/// Representation d'un device token enregistre cote serveur.
class DeviceTokenRegistration {
  final int? id;
  final String token;
  final String platform;

  const DeviceTokenRegistration({
    this.id,
    required this.token,
    required this.platform,
  });

  factory DeviceTokenRegistration.fromJson(Map<String, dynamic> json) {
    return DeviceTokenRegistration(
      id: (json['id'] as num?)?.toInt(),
      token: (json['token'] as String?) ?? '',
      platform: (json['platform'] as String?) ?? 'unknown',
    );
  }
}
