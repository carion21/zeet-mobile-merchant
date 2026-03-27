import 'package:merchant/core/constants/api.dart';
import 'package:merchant/models/menu_model.dart';
import 'package:merchant/models/order_model.dart';
import 'package:merchant/services/api_client.dart';

/// Service pour les operations sur les menus partner.
/// Encapsule les appels aux 6 endpoints `/v1/partner/menus/*`.
class MenuService {
  final ApiClient _apiClient;

  MenuService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  // ---------------------------------------------------------------------------
  // GET /v1/partner/menus
  // ---------------------------------------------------------------------------
  /// Recupere la liste paginee des menus du partner.
  ///
  /// [page] : numero de page (defaut 1).
  /// [limit] : nombre de resultats par page (defaut 25).
  /// [search] : recherche optionnelle (nom du menu).
  /// [parentMenu] : filtre optionnel par menu parent.
  Future<PaginatedResult<Menu>> listMenus({
    int page = 1,
    int limit = 25,
    String? search,
    String? parentMenu,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (parentMenu != null && parentMenu.isNotEmpty) {
      queryParams['parent_menu'] = parentMenu;
    }

    final response = await _apiClient.get(
      MenuEndpoints.list,
      queryParams: queryParams,
    );

    final dataList = response['data'] as List? ?? [];
    final menus = dataList
        .whereType<Map<String, dynamic>>()
        .map((json) => Menu.fromJson(json))
        .toList();

    final meta = response['meta'] != null
        ? PaginationMeta.fromJson(response['meta'] as Map<String, dynamic>)
        : PaginationMeta(
            total: menus.length,
            page: page,
            limit: limit,
            totalPages: 1,
          );

    return PaginatedResult(data: menus, meta: meta);
  }

  // ---------------------------------------------------------------------------
  // POST /v1/partner/menus
  // ---------------------------------------------------------------------------
  /// Cree un nouveau menu.
  ///
  /// [name] : nom du menu (obligatoire).
  /// [description] : description optionnelle.
  /// [isDefault] : menu par defaut ou non.
  /// [timeStart] : heure de debut (ex: "08:00").
  /// [timeEnd] : heure de fin (ex: "22:00").
  /// [daysOfWeek] : jours de la semaine actifs.
  /// [productIds] : liste des IDs produits a associer.
  Future<Menu> createMenu({
    required String name,
    String? code,
    String? description,
    bool isDefault = false,
    String? timeStart,
    String? timeEnd,
    DaysOfWeek? daysOfWeek,
    List<int>? productIds,
  }) async {
    final body = <String, dynamic>{
      'name': name,
    };
    if (code != null) body['code'] = code;
    if (description != null) body['description'] = description;
    body['is_default'] = isDefault;
    if (timeStart != null) body['time_start'] = timeStart;
    if (timeEnd != null) body['time_end'] = timeEnd;
    if (daysOfWeek != null) body['days_of_week'] = daysOfWeek.toJson();
    if (productIds != null && productIds.isNotEmpty) {
      body['product_ids'] = productIds;
    }

    final response = await _apiClient.post(
      MenuEndpoints.create,
      body: body,
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    return Menu.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/menus/:id
  // ---------------------------------------------------------------------------
  /// Recupere le detail d'un menu avec ses items/produits.
  Future<Menu> getMenu(int menuId) async {
    final response = await _apiClient.get(
      MenuEndpoints.get(menuId.toString()),
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    return Menu.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // PATCH /v1/partner/menus/:id
  // ---------------------------------------------------------------------------
  /// Met a jour un menu existant.
  ///
  /// Seuls les champs fournis seront modifies (PATCH partiel).
  Future<Menu> updateMenu(
    int menuId, {
    String? name,
    String? description,
    bool? isDefault,
    String? timeStart,
    String? timeEnd,
    DaysOfWeek? daysOfWeek,
    List<int>? productIds,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (isDefault != null) body['is_default'] = isDefault;
    if (timeStart != null) body['time_start'] = timeStart;
    if (timeEnd != null) body['time_end'] = timeEnd;
    if (daysOfWeek != null) body['days_of_week'] = daysOfWeek.toJson();
    if (productIds != null) body['product_ids'] = productIds;

    final response = await _apiClient.patch(
      MenuEndpoints.update(menuId.toString()),
      body: body,
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    return Menu.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // PATCH /v1/partner/menus/:id/publish
  // ---------------------------------------------------------------------------
  /// Publie ou active/desactive un menu (toggle du statut).
  /// Le PATCH est envoye sans body.
  Future<Menu> publishMenu(int menuId) async {
    final response = await _apiClient.patch(
      MenuEndpoints.publish(menuId.toString()),
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    return Menu.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // DELETE /v1/partner/menus/:id
  // ---------------------------------------------------------------------------
  /// Supprime un menu.
  Future<void> deleteMenu(int menuId) async {
    await _apiClient.delete(
      MenuEndpoints.delete(menuId.toString()),
    );
  }
}
