import 'package:merchant/core/constants/api.dart';
import 'package:merchant/models/notification_model.dart';
import 'package:merchant/services/api_client.dart';

/// Service pour le domaine Notifications de la surface partner/merchant.
/// Encapsule les appels aux endpoints `/v1/partner/notifications/*`.
class NotificationService {
  final ApiClient _apiClient;

  NotificationService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  // ---------------------------------------------------------------------------
  // GET /v1/partner/notifications
  // ---------------------------------------------------------------------------
  /// Recupere la liste paginee des notifications du partner.
  Future<NotificationsPage> listNotifications({
    int page = 1,
    int limit = 25,
  }) async {
    final response = await _apiClient.get(
      NotificationEndpoints.list,
      queryParams: {
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );

    final rawList = (response['data'] as List?) ?? const [];
    final items = rawList
        .whereType<Map>()
        .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final meta = response['meta'] is Map<String, dynamic>
        ? NotificationPaginationMeta.fromJson(
            response['meta'] as Map<String, dynamic>)
        : NotificationPaginationMeta(
            total: items.length,
            page: page,
            limit: limit,
            totalPages: 1,
          );

    return NotificationsPage(data: items, meta: meta);
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/notifications/unread-count
  // ---------------------------------------------------------------------------
  Future<int> getUnreadCount() async {
    final response = await _apiClient.get(NotificationEndpoints.unreadCount);

    final data = response['data'];
    if (data is Map<String, dynamic>) {
      final count = data['count'] ?? data['unread_count'] ?? data['total'];
      if (count is num) return count.toInt();
    }
    if (data is num) return data.toInt();

    final topLevel = response['count'] ?? response['unread_count'];
    if (topLevel is num) return topLevel.toInt();

    return 0;
  }

  // ---------------------------------------------------------------------------
  // PATCH /v1/partner/notifications/:id/read
  // ---------------------------------------------------------------------------
  Future<void> markAsRead(int id) async {
    await _apiClient.patch(NotificationEndpoints.markAsRead(id.toString()));
  }

  // ---------------------------------------------------------------------------
  // POST /v1/partner/notifications/:id/ack
  // ---------------------------------------------------------------------------
  /// Accuse reception (stoppe la cascade cote backend — critique notamment
  /// pour les notifications de nouvelles commandes cote partner).
  Future<void> acknowledge(int id) async {
    await _apiClient.post(NotificationEndpoints.acknowledge(id.toString()));
  }

  // ---------------------------------------------------------------------------
  // POST /v1/partner/notifications/read-all
  // ---------------------------------------------------------------------------
  Future<void> markAllAsRead() async {
    await _apiClient.post(NotificationEndpoints.readAll);
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/notifications/preferences
  // ---------------------------------------------------------------------------
  Future<List<NotificationPreference>> getPreferences() async {
    final response = await _apiClient.get(NotificationEndpoints.preferences);

    final data = response['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) =>
              NotificationPreference.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  // ---------------------------------------------------------------------------
  // PATCH /v1/partner/notifications/preferences/:id
  // ---------------------------------------------------------------------------
  Future<NotificationPreference> updatePreference(
    int id,
    NotificationPreferencePatch patch,
  ) async {
    final response = await _apiClient.patch(
      NotificationEndpoints.updatePreference(id.toString()),
      body: patch.toJson(),
    );

    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return NotificationPreference.fromJson(data);
    }
    return NotificationPreference(
      id: id,
      pushEnabled: patch.pushEnabled ?? true,
      smsEnabled: patch.smsEnabled ?? false,
      inAppEnabled: patch.inAppEnabled ?? true,
      emailEnabled: patch.emailEnabled ?? false,
    );
  }

  // ---------------------------------------------------------------------------
  // POST /v1/partner/notifications/device-token
  // ---------------------------------------------------------------------------
  Future<DeviceTokenRegistration> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    final response = await _apiClient.post(
      NotificationEndpoints.deviceToken,
      body: {
        'token': token,
        'platform': platform,
      },
    );

    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return DeviceTokenRegistration.fromJson(data);
    }
    return DeviceTokenRegistration(token: token, platform: platform);
  }

  // ---------------------------------------------------------------------------
  // DELETE /v1/partner/notifications/device-token/:id
  // ---------------------------------------------------------------------------
  Future<void> removeDeviceToken(int id) async {
    await _apiClient.delete(
      NotificationEndpoints.removeDeviceToken(id.toString()),
    );
  }
}
