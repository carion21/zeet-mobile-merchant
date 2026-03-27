/// Configuration des URLs de l'API pour différents environnements.
/// Base URL du Core API ZEET (sans le préfixe de version).
class ApiConfig {
  static const String devBaseUrl = 'http://localhost:8000/v1';
  static const String testBaseUrl = 'http://46.202.170.228:8000/v1';
  static const String prodBaseUrl = 'https://zeet-core-system-production.up.railway.app/v1';

  static String get baseUrl {
    const environment = "test";
    switch (environment) {
      case 'prod':
        return prodBaseUrl;
      case 'test':
        return testBaseUrl;
      default:
        return devBaseUrl;
    }
  }
}

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------
abstract class AuthEndpoints {
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
}

// ---------------------------------------------------------------------------
// Profile
// ---------------------------------------------------------------------------
abstract class ProfileEndpoints {
  static const String get = '/partner/profile';
  static const String update = '/partner/profile';
  static const String commissionRate = '/partner/commission-rate';
  static const String availability = '/partner/availability';
  static const String uploadLogo = '/partner/profile/logo';
  static const String removeLogo = '/partner/profile/logo';
}

// ---------------------------------------------------------------------------
// Stats
// ---------------------------------------------------------------------------
abstract class StatsEndpoints {
  static const String revenue = '/partner/stats/revenue';
  static const String orders = '/partner/stats/orders';
  static const String rating = '/partner/stats/rating';
  static const String topProducts = '/partner/stats/top-products';
  static const String topCategories = '/partner/stats/top-categories';
  static const String topCustomers = '/partner/stats/top-customers';
}

// ---------------------------------------------------------------------------
// Dashboard
// ---------------------------------------------------------------------------
abstract class DashboardEndpoints {
  static const String summary = '/partner/dashboard/summary';
}

// ---------------------------------------------------------------------------
// Menus
// ---------------------------------------------------------------------------
abstract class MenuEndpoints {
  static const String list = '/partner/menus';
  static const String create = '/partner/menus';
  static String get(String id) => '/partner/menus/$id';
  static String update(String id) => '/partner/menus/$id';
  static String publish(String id) => '/partner/menus/$id/publish';
  static String delete(String id) => '/partner/menus/$id';
}

// ---------------------------------------------------------------------------
// Product Categories
// ---------------------------------------------------------------------------
abstract class CategoryEndpoints {
  static const String list = '/partner/product-categories';
  static const String select = '/partner/product-categories/select';
  static const String create = '/partner/product-categories';
  static const String bulkDelete = '/partner/product-categories/bulk';
  static String get(String id) => '/partner/product-categories/$id';
  static String update(String id) => '/partner/product-categories/$id';
  static String delete(String id) => '/partner/product-categories/$id';
  static String uploadPicture(String id) =>
      '/partner/product-categories/$id/picture';
}

// ---------------------------------------------------------------------------
// Products
// ---------------------------------------------------------------------------
abstract class ProductEndpoints {
  static const String list = '/partner/products';
  static const String create = '/partner/products';
  static const String bulk = '/partner/products/bulk';
  static String get(String id) => '/partner/products/$id';
  static String update(String id) => '/partner/products/$id';
  static String toggleAvailability(String id) =>
      '/partner/products/$id/availability';
  static String delete(String id) => '/partner/products/$id';
  static String duplicate(String id) => '/partner/products/$id/duplicate';
  static String pictures(String id) => '/partner/products/$id/pictures';
  static String deletePicture(String productId, String pictureId) =>
      '/partner/products/$productId/pictures/$pictureId';
  static String stats(String id) => '/partner/products/$id/stats';
  // Variants
  static String variants(String id) => '/partner/products/$id/variants';
  static String createVariant(String id) => '/partner/products/$id/variants';
  static String updateVariant(String productId, String variantId) =>
      '/partner/products/$productId/variants/$variantId';
  static String deleteVariant(String productId, String variantId) =>
      '/partner/products/$productId/variants/$variantId';
  // Option Groups
  static String optionGroups(String id) =>
      '/partner/products/$id/option-groups';
  static String createOptionGroup(String id) =>
      '/partner/products/$id/option-groups';
  static String updateOptionGroup(String productId, String groupId) =>
      '/partner/products/$productId/option-groups/$groupId';
  static String deleteOptionGroup(String productId, String groupId) =>
      '/partner/products/$productId/option-groups/$groupId';
  // Option Items
  static String optionItems(String productId, String groupId) =>
      '/partner/products/$productId/option-groups/$groupId/items';
  static String createOptionItem(String productId, String groupId) =>
      '/partner/products/$productId/option-groups/$groupId/items';
  static String updateOptionItem(
          String productId, String groupId, String itemId) =>
      '/partner/products/$productId/option-groups/$groupId/items/$itemId';
  static String deleteOptionItem(
          String productId, String groupId, String itemId) =>
      '/partner/products/$productId/option-groups/$groupId/items/$itemId';
}

// ---------------------------------------------------------------------------
// Product Stats
// ---------------------------------------------------------------------------
abstract class ProductStatsEndpoints {
  static const String ranking = '/partner/product-stats/ranking';
}

// ---------------------------------------------------------------------------
// Orders
// ---------------------------------------------------------------------------
abstract class OrderEndpoints {
  static const String list = '/partner/orders';
  static const String countsByStatus = '/partner/orders/counts-by-status';
  static const String statuses = '/partner/orders/select/statuses';
  static const String transitions = '/partner/orders/transitions';
  static const String actions = '/partner/orders/actions';
  static String get(String id) => '/partner/orders/$id';
  static String confirm(String id) => '/partner/orders/$id/confirm';
  static String preparing(String id) => '/partner/orders/$id/preparing';
  static String ready(String id) => '/partner/orders/$id/ready';
  static String cancel(String id) => '/partner/orders/$id/cancel';
  static String pickupOtp(String id) => '/partner/orders/$id/pickup-otp';
  static String resendPickupOtp(String id) =>
      '/partner/orders/$id/pickup-otp/resend';
}

// ---------------------------------------------------------------------------
// Support Tickets
// ---------------------------------------------------------------------------
abstract class TicketEndpoints {
  static const String create = '/partner/tickets';
  static const String list = '/partner/tickets';
  static const String priorities = '/partner/tickets/select/priorities';
  static String get(String id) => '/partner/tickets/$id';
  static String logs(String id) => '/partner/tickets/$id/logs';
  static String messages(String id) => '/partner/tickets/$id/messages';
  static String mentionableUsers(String id) =>
      '/partner/tickets/$id/mentionable-users';
  static String sendMessage(String id) => '/partner/tickets/$id/messages';
  static String markRead(String id) => '/partner/tickets/$id/messages/read';
  static String unreadCount(String id) =>
      '/partner/tickets/$id/messages/unread-count';
}

// ---------------------------------------------------------------------------
// Carts (paniers actifs des clients)
// ---------------------------------------------------------------------------
abstract class CartEndpoints {
  static const String list = '/partner/carts';
  static const String stats = '/partner/carts/stats';
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------
class ApiHelper {
  static String buildUrl(String endpoint) {
    return '${ApiConfig.baseUrl}$endpoint';
  }

  static String buildUrlWithId(String endpoint, String id) {
    return '${ApiConfig.baseUrl}$endpoint/$id';
  }
}
