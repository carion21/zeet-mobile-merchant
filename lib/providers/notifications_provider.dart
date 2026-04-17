// lib/providers/notifications_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:merchant/models/notification_model.dart';
import 'package:merchant/services/api_client.dart';
import 'package:merchant/services/notification_service.dart';

// ---------------------------------------------------------------------------
// Service Provider
// ---------------------------------------------------------------------------
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// ---------------------------------------------------------------------------
// Notifications List State
// ---------------------------------------------------------------------------
class NotificationsListState {
  final List<NotificationItem> items;
  final NotificationPaginationMeta? meta;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isOperating;
  final String? errorMessage;

  const NotificationsListState({
    this.items = const [],
    this.meta,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isOperating = false,
    this.errorMessage,
  });

  bool get hasMore => meta != null && meta!.hasNextPage;
  int get currentPage => meta?.page ?? 0;

  NotificationsListState copyWith({
    List<NotificationItem>? items,
    NotificationPaginationMeta? meta,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isOperating,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NotificationsListState(
      items: items ?? this.items,
      meta: meta ?? this.meta,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isOperating: isOperating ?? this.isOperating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifications List Notifier
// ---------------------------------------------------------------------------
class NotificationsListNotifier extends StateNotifier<NotificationsListState> {
  final NotificationService _service;
  final Ref _ref;

  NotificationsListNotifier(this._service, this._ref)
      : super(const NotificationsListState());

  Future<void> load({int limit = 25}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _service.listNotifications(page: 1, limit: limit);
      state = state.copyWith(
        items: result.data,
        meta: result.meta,
        isLoading: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      debugPrint('[NotificationsProvider] Erreur load: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erreur de connexion au serveur',
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = state.currentPage + 1;
      final result = await _service.listNotifications(
        page: nextPage,
        limit: state.meta?.limit ?? 25,
      );
      state = state.copyWith(
        items: [...state.items, ...result.data],
        meta: result.meta,
        isLoadingMore: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoadingMore: false, errorMessage: e.message);
    } catch (e) {
      debugPrint('[NotificationsProvider] Erreur loadMore: $e');
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: 'Erreur de connexion au serveur',
      );
    }
  }

  Future<void> refresh() async {
    await load(limit: state.meta?.limit ?? 25);
    _ref.read(unreadCountProvider.notifier).refresh();
  }

  Future<bool> markAsRead(int id) async {
    final previous = state.items;
    state = state.copyWith(
      items: state.items
          .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
          .toList(),
    );
    try {
      await _service.markAsRead(id);
      _ref.read(unreadCountProvider.notifier).refresh();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(items: previous, errorMessage: e.message);
      return false;
    } catch (e) {
      debugPrint('[NotificationsProvider] Erreur markAsRead: $e');
      state = state.copyWith(
        items: previous,
        errorMessage: 'Erreur de connexion au serveur',
      );
      return false;
    }
  }

  Future<bool> acknowledge(int id) async {
    final previous = state.items;
    state = state.copyWith(
      items: state.items
          .map((n) =>
              n.id == id ? n.copyWith(isAcknowledged: true, isRead: true) : n)
          .toList(),
    );
    try {
      await _service.acknowledge(id);
      _ref.read(unreadCountProvider.notifier).refresh();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(items: previous, errorMessage: e.message);
      return false;
    } catch (e) {
      debugPrint('[NotificationsProvider] Erreur acknowledge: $e');
      state = state.copyWith(
        items: previous,
        errorMessage: 'Erreur de connexion au serveur',
      );
      return false;
    }
  }

  Future<bool> markAllAsRead() async {
    final previous = state.items;
    state = state.copyWith(
      isOperating: true,
      items: state.items.map((n) => n.copyWith(isRead: true)).toList(),
    );
    try {
      await _service.markAllAsRead();
      state = state.copyWith(isOperating: false);
      _ref.read(unreadCountProvider.notifier).refresh();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        items: previous,
        isOperating: false,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('[NotificationsProvider] Erreur markAllAsRead: $e');
      state = state.copyWith(
        items: previous,
        isOperating: false,
        errorMessage: 'Erreur de connexion au serveur',
      );
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Unread Count
// ---------------------------------------------------------------------------
class UnreadCountState {
  final int count;
  final bool isLoading;
  final String? errorMessage;

  const UnreadCountState({
    this.count = 0,
    this.isLoading = false,
    this.errorMessage,
  });

  UnreadCountState copyWith({
    int? count,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UnreadCountState(
      count: count ?? this.count,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class UnreadCountNotifier extends StateNotifier<UnreadCountState> {
  final NotificationService _service;
  UnreadCountNotifier(this._service) : super(const UnreadCountState());

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final count = await _service.getUnreadCount();
      state = state.copyWith(count: count, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      debugPrint('[NotificationsProvider] Erreur unreadCount: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  void reset() {
    state = const UnreadCountState();
  }
}

// ---------------------------------------------------------------------------
// Preferences
// ---------------------------------------------------------------------------
class NotificationPreferencesState {
  final List<NotificationPreference> preferences;
  final bool isLoading;
  final bool isUpdating;
  final String? errorMessage;

  const NotificationPreferencesState({
    this.preferences = const [],
    this.isLoading = false,
    this.isUpdating = false,
    this.errorMessage,
  });

  NotificationPreferencesState copyWith({
    List<NotificationPreference>? preferences,
    bool? isLoading,
    bool? isUpdating,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NotificationPreferencesState(
      preferences: preferences ?? this.preferences,
      isLoading: isLoading ?? this.isLoading,
      isUpdating: isUpdating ?? this.isUpdating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class NotificationPreferencesNotifier
    extends StateNotifier<NotificationPreferencesState> {
  final NotificationService _service;
  NotificationPreferencesNotifier(this._service)
      : super(const NotificationPreferencesState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final prefs = await _service.getPreferences();
      state = state.copyWith(preferences: prefs, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      debugPrint('[NotificationsProvider] Erreur loadPreferences: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erreur de connexion au serveur',
      );
    }
  }

  Future<bool> updatePreference(
      int id, NotificationPreferencePatch patch) async {
    state = state.copyWith(isUpdating: true, clearError: true);
    try {
      final updated = await _service.updatePreference(id, patch);
      state = state.copyWith(
        isUpdating: false,
        preferences:
            state.preferences.map((p) => p.id == id ? updated : p).toList(),
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isUpdating: false, errorMessage: e.message);
      return false;
    } catch (e) {
      debugPrint('[NotificationsProvider] Erreur updatePreference: $e');
      state = state.copyWith(
        isUpdating: false,
        errorMessage: 'Erreur de connexion au serveur',
      );
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

final notificationsListProvider = StateNotifierProvider<
    NotificationsListNotifier, NotificationsListState>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return NotificationsListNotifier(service, ref);
});

final unreadCountProvider =
    StateNotifierProvider<UnreadCountNotifier, UnreadCountState>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return UnreadCountNotifier(service);
});

final notificationPreferencesProvider = StateNotifierProvider<
    NotificationPreferencesNotifier,
    NotificationPreferencesState>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return NotificationPreferencesNotifier(service);
});
