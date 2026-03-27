import 'dart:convert';
import 'dart:io';
import 'package:merchant/core/constants/api.dart';
import 'package:merchant/core/utils/api_logger.dart';
import 'package:merchant/models/order_model.dart';
import 'package:merchant/models/product_model.dart';
import 'package:merchant/services/api_client.dart';
import 'package:merchant/services/token_service.dart';
import 'package:http/http.dart' as http;

/// Service pour les operations sur les produits, variantes, groupes d'options
/// et items d'options.
/// Encapsule les 23 endpoints `/v1/partner/products/*`.
class ProductService {
  final ApiClient _apiClient;
  final TokenService _tokenService;

  ProductService({
    ApiClient? apiClient,
    TokenService? tokenService,
  })  : _apiClient = apiClient ?? ApiClient.instance,
        _tokenService = tokenService ?? TokenService.instance;

  // ===========================================================================
  // PRODUCTS (11 endpoints)
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // GET /v1/partner/products
  // ---------------------------------------------------------------------------
  /// Recupere la liste paginee des produits, avec filtres optionnels.
  ///
  /// [page] : numero de page (defaut 1).
  /// [limit] : nombre de resultats par page (defaut 25).
  /// [search] : recherche textuelle sur le nom.
  /// [category] : filtre par ID de categorie.
  Future<PaginatedResult<Product>> listProducts({
    int page = 1,
    int limit = 25,
    String? search,
    int? category,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (category != null) {
      queryParams['category'] = category.toString();
    }

    final response = await _apiClient.get(
      ProductEndpoints.list,
      queryParams: queryParams,
    );

    final dataList = response['data'] as List? ?? [];
    final products = dataList
        .whereType<Map<String, dynamic>>()
        .map((json) => Product.fromJson(json))
        .toList();

    final meta = response['meta'] != null
        ? PaginationMeta.fromJson(response['meta'] as Map<String, dynamic>)
        : PaginationMeta(
            total: products.length,
            page: page,
            limit: limit,
            totalPages: 1,
          );

    return PaginatedResult(data: products, meta: meta);
  }

  // ---------------------------------------------------------------------------
  // POST /v1/partner/products
  // ---------------------------------------------------------------------------
  /// Cree un nouveau produit.
  ///
  /// [name] : nom du produit (obligatoire).
  /// [price] : prix en unite minimale (obligatoire).
  /// [productCategory] : ID de la categorie (obligatoire).
  /// [description] : description optionnelle.
  Future<Product> createProduct({
    required String name,
    required int price,
    required int productCategory,
    String? description,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'price': price,
      'product_category': productCategory,
    };
    if (description != null) body['description'] = description;

    final response = await _apiClient.post(
      ProductEndpoints.create,
      body: body,
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    return Product.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/products/:id
  // ---------------------------------------------------------------------------
  /// Recupere le detail d'un produit avec ses variantes, groupes d'options
  /// et images.
  Future<Product> getProduct(int productId) async {
    final response = await _apiClient.get(
      ProductEndpoints.get(productId.toString()),
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    return Product.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // PATCH /v1/partner/products/:id
  // ---------------------------------------------------------------------------
  /// Met a jour un produit existant (PATCH partiel).
  /// Seuls les champs fournis (non null) sont envoyes.
  Future<Product> updateProduct(
    int productId, {
    String? name,
    int? price,
    int? productCategory,
    String? description,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (price != null) body['price'] = price;
    if (productCategory != null) body['product_category'] = productCategory;
    if (description != null) body['description'] = description;

    final response = await _apiClient.patch(
      ProductEndpoints.update(productId.toString()),
      body: body,
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    return Product.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // PATCH /v1/partner/products/:id/availability
  // ---------------------------------------------------------------------------
  /// Active ou desactive la disponibilite d'un produit.
  Future<Product> toggleAvailability(int productId, {required bool available}) async {
    final response = await _apiClient.patch(
      ProductEndpoints.toggleAvailability(productId.toString()),
      body: {'available': available},
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    return Product.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // DELETE /v1/partner/products/:id
  // ---------------------------------------------------------------------------
  /// Supprime un produit.
  Future<void> deleteProduct(int productId) async {
    await _apiClient.delete(
      ProductEndpoints.delete(productId.toString()),
    );
  }

  // ---------------------------------------------------------------------------
  // POST /v1/partner/products/:id/pictures  (multipart/form-data)
  // ---------------------------------------------------------------------------
  /// Upload une image pour un produit.
  ///
  /// [productId] : ID du produit.
  /// [imageFile] : fichier image (JPEG, PNG ou WebP, max 5MB).
  /// Retourne le [ProductPicture] cree.
  Future<ProductPicture> uploadPicture(int productId, File imageFile) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}${ProductEndpoints.pictures(productId.toString())}',
    );
    final token = await _tokenService.getAccessToken();

    ApiLogger.logRequest(
      method: 'POST',
      url: url.toString(),
      headers: {'Authorization': 'Bearer ${token ?? ''}'},
      body: 'multipart/form-data (file: ${imageFile.path})',
    );

    final stopwatch = Stopwatch()..start();

    final request = http.MultipartRequest('POST', url);

    if (token != null && token.isNotEmpty) {
      request.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
    }
    request.headers[HttpHeaders.acceptHeader] = 'application/json';

    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      stopwatch.stop();

      final body = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};

      ApiLogger.logResponse(
        method: 'POST',
        url: url.toString(),
        statusCode: response.statusCode,
        body: body,
        duration: stopwatch.elapsed,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = body['data'] as Map<String, dynamic>? ?? body;
        return ProductPicture.fromJson(data);
      }

      throw ApiException(
        statusCode: response.statusCode,
        message: body['message'] is String
            ? body['message'] as String
            : body['message'] is List
                ? (body['message'] as List).join(', ')
                : 'Erreur lors de l\'upload de l\'image',
      );
    } catch (e, st) {
      stopwatch.stop();
      if (e is ApiException) rethrow;
      ApiLogger.logError(
        method: 'POST',
        url: url.toString(),
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/products/:id/pictures
  // ---------------------------------------------------------------------------
  /// Recupere la liste des images d'un produit (URLs MinIO presignees).
  ///
  /// Retourne un record contenant la liste de [ProductPicture] et
  /// l'URL par defaut (placeholder).
  Future<({List<ProductPicture> pictures, String? defaultImage})>
      listPictures(int productId) async {
    final response = await _apiClient.get(
      ProductEndpoints.pictures(productId.toString()),
    );

    final dataList = response['data'] as List? ?? [];
    final pictures = dataList
        .whereType<Map<String, dynamic>>()
        .map((json) => ProductPicture.fromJson(json))
        .toList();

    final defaultImage = response['default_image'] as String?;

    return (pictures: pictures, defaultImage: defaultImage);
  }

  // ---------------------------------------------------------------------------
  // DELETE /v1/partner/products/:id/pictures/:pic_id
  // ---------------------------------------------------------------------------
  /// Supprime une image d'un produit.
  Future<void> deletePicture(int productId, int pictureId) async {
    await _apiClient.delete(
      ProductEndpoints.deletePicture(
        productId.toString(),
        pictureId.toString(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PATCH /v1/partner/products/bulk
  // ---------------------------------------------------------------------------
  /// Effectue une action en masse sur des produits.
  ///
  /// [ids] : liste des IDs de produits.
  /// [action] : `"activate"`, `"deactivate"` ou `"delete"`.
  Future<void> bulkAction({
    required List<int> ids,
    required String action,
  }) async {
    await _apiClient.patch(
      ProductEndpoints.bulk,
      body: {
        'ids': ids,
        'action': action,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // POST /v1/partner/products/:id/duplicate
  // ---------------------------------------------------------------------------
  /// Duplique un produit existant.
  /// Retourne le nouveau [Product] cree.
  Future<Product> duplicateProduct(int productId) async {
    final response = await _apiClient.post(
      ProductEndpoints.duplicate(productId.toString()),
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    return Product.fromJson(data);
  }

  // ===========================================================================
  // VARIANTS (4 endpoints)
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // GET /v1/partner/products/:id/variants
  // ---------------------------------------------------------------------------
  /// Recupere la liste des variantes d'un produit.
  Future<List<ProductVariant>> listVariants(int productId) async {
    final response = await _apiClient.get(
      ProductEndpoints.variants(productId.toString()),
    );

    final dataList = response['data'] as List? ?? [];
    return dataList
        .whereType<Map<String, dynamic>>()
        .map((json) => ProductVariant.fromJson(json))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // POST /v1/partner/products/:id/variants
  // ---------------------------------------------------------------------------
  /// Cree une variante pour un produit.
  ///
  /// [name] : nom de la variante (obligatoire).
  /// [priceDelta] : delta de prix par rapport au prix de base (obligatoire).
  /// [orderIndex] : ordre d'affichage (defaut 0).
  /// [description] : description optionnelle.
  Future<ProductVariant> createVariant(
    int productId, {
    required String name,
    required int priceDelta,
    int orderIndex = 0,
    String? description,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'price_delta': priceDelta,
      'order_index': orderIndex,
    };
    if (description != null) body['description'] = description;

    final response = await _apiClient.post(
      ProductEndpoints.createVariant(productId.toString()),
      body: body,
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    return ProductVariant.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // PATCH /v1/partner/products/:id/variants/:vid
  // ---------------------------------------------------------------------------
  /// Met a jour une variante (PATCH partiel).
  Future<ProductVariant> updateVariant(
    int productId,
    int variantId, {
    String? name,
    int? priceDelta,
    int? orderIndex,
    String? description,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (priceDelta != null) body['price_delta'] = priceDelta;
    if (orderIndex != null) body['order_index'] = orderIndex;
    if (description != null) body['description'] = description;

    final response = await _apiClient.patch(
      ProductEndpoints.updateVariant(
        productId.toString(),
        variantId.toString(),
      ),
      body: body,
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    return ProductVariant.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // DELETE /v1/partner/products/:id/variants/:vid
  // ---------------------------------------------------------------------------
  /// Supprime une variante d'un produit.
  Future<void> deleteVariant(int productId, int variantId) async {
    await _apiClient.delete(
      ProductEndpoints.deleteVariant(
        productId.toString(),
        variantId.toString(),
      ),
    );
  }

  // ===========================================================================
  // OPTION GROUPS (4 endpoints)
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // GET /v1/partner/products/:id/option-groups
  // ---------------------------------------------------------------------------
  /// Recupere la liste des groupes d'options d'un produit.
  Future<List<ProductOptionGroup>> listOptionGroups(int productId) async {
    final response = await _apiClient.get(
      ProductEndpoints.optionGroups(productId.toString()),
    );

    final dataList = response['data'] as List? ?? [];
    return dataList
        .whereType<Map<String, dynamic>>()
        .map((json) => ProductOptionGroup.fromJson(json))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // POST /v1/partner/products/:id/option-groups
  // ---------------------------------------------------------------------------
  /// Cree un groupe d'options pour un produit.
  ///
  /// [name] : nom du groupe (obligatoire).
  /// [required] : le groupe est-il obligatoire ? (defaut false).
  /// [allowDuplicate] : autoriser les doublons ? (defaut false).
  /// [minSelect] : nombre minimum de selections (defaut 0).
  /// [maxSelect] : nombre maximum de selections (defaut 0 = illimite).
  /// [orderIndex] : ordre d'affichage (defaut 0).
  Future<ProductOptionGroup> createOptionGroup(
    int productId, {
    required String name,
    bool required = false,
    bool allowDuplicate = false,
    int minSelect = 0,
    int maxSelect = 0,
    int orderIndex = 0,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'required': required,
      'allow_duplicate': allowDuplicate,
      'min_select': minSelect,
      'max_select': maxSelect,
      'order_index': orderIndex,
    };

    final response = await _apiClient.post(
      ProductEndpoints.createOptionGroup(productId.toString()),
      body: body,
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    return ProductOptionGroup.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // PATCH /v1/partner/products/:id/option-groups/:gid
  // ---------------------------------------------------------------------------
  /// Met a jour un groupe d'options (PATCH partiel).
  Future<ProductOptionGroup> updateOptionGroup(
    int productId,
    int groupId, {
    String? name,
    bool? required,
    bool? allowDuplicate,
    int? minSelect,
    int? maxSelect,
    int? orderIndex,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (required != null) body['required'] = required;
    if (allowDuplicate != null) body['allow_duplicate'] = allowDuplicate;
    if (minSelect != null) body['min_select'] = minSelect;
    if (maxSelect != null) body['max_select'] = maxSelect;
    if (orderIndex != null) body['order_index'] = orderIndex;

    final response = await _apiClient.patch(
      ProductEndpoints.updateOptionGroup(
        productId.toString(),
        groupId.toString(),
      ),
      body: body,
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    return ProductOptionGroup.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // DELETE /v1/partner/products/:id/option-groups/:gid
  // ---------------------------------------------------------------------------
  /// Supprime un groupe d'options d'un produit.
  Future<void> deleteOptionGroup(int productId, int groupId) async {
    await _apiClient.delete(
      ProductEndpoints.deleteOptionGroup(
        productId.toString(),
        groupId.toString(),
      ),
    );
  }

  // ===========================================================================
  // OPTION ITEMS (4 endpoints)
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // GET /v1/partner/products/:id/option-groups/:gid/items
  // ---------------------------------------------------------------------------
  /// Recupere la liste des items d'un groupe d'options.
  Future<List<ProductOptionItem>> listOptionItems(
    int productId,
    int groupId,
  ) async {
    final response = await _apiClient.get(
      ProductEndpoints.optionItems(
        productId.toString(),
        groupId.toString(),
      ),
    );

    final dataList = response['data'] as List? ?? [];
    return dataList
        .whereType<Map<String, dynamic>>()
        .map((json) => ProductOptionItem.fromJson(json))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // POST /v1/partner/products/:id/option-groups/:gid/items
  // ---------------------------------------------------------------------------
  /// Cree un item dans un groupe d'options.
  ///
  /// [name] : nom de l'item (obligatoire).
  /// [priceDelta] : delta de prix (obligatoire).
  /// [orderIndex] : ordre d'affichage (defaut 0).
  /// [description] : description optionnelle.
  Future<ProductOptionItem> createOptionItem(
    int productId,
    int groupId, {
    required String name,
    required int priceDelta,
    int orderIndex = 0,
    String? description,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'price_delta': priceDelta,
      'order_index': orderIndex,
    };
    if (description != null) body['description'] = description;

    final response = await _apiClient.post(
      ProductEndpoints.createOptionItem(
        productId.toString(),
        groupId.toString(),
      ),
      body: body,
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    return ProductOptionItem.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // PATCH /v1/partner/products/:id/option-groups/:gid/items/:iid
  // ---------------------------------------------------------------------------
  /// Met a jour un item d'option (PATCH partiel).
  Future<ProductOptionItem> updateOptionItem(
    int productId,
    int groupId,
    int itemId, {
    String? name,
    int? priceDelta,
    int? orderIndex,
    String? description,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (priceDelta != null) body['price_delta'] = priceDelta;
    if (orderIndex != null) body['order_index'] = orderIndex;
    if (description != null) body['description'] = description;

    final response = await _apiClient.patch(
      ProductEndpoints.updateOptionItem(
        productId.toString(),
        groupId.toString(),
        itemId.toString(),
      ),
      body: body,
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    return ProductOptionItem.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // DELETE /v1/partner/products/:id/option-groups/:gid/items/:iid
  // ---------------------------------------------------------------------------
  /// Supprime un item d'un groupe d'options.
  Future<void> deleteOptionItem(
    int productId,
    int groupId,
    int itemId,
  ) async {
    await _apiClient.delete(
      ProductEndpoints.deleteOptionItem(
        productId.toString(),
        groupId.toString(),
        itemId.toString(),
      ),
    );
  }
}
