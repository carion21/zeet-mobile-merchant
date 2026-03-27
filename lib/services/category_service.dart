import 'dart:convert';
import 'dart:io';
import 'package:merchant/core/constants/api.dart';
import 'package:merchant/core/utils/api_logger.dart';
import 'package:merchant/models/category_model.dart';
import 'package:merchant/models/order_model.dart';
import 'package:merchant/services/api_client.dart';
import 'package:merchant/services/token_service.dart';
import 'package:http/http.dart' as http;

/// Service pour les operations sur les categories de produits.
/// Encapsule les 8 endpoints `/v1/partner/product-categories/*`.
class CategoryService {
  final ApiClient _apiClient;
  final TokenService _tokenService;

  CategoryService({
    ApiClient? apiClient,
    TokenService? tokenService,
  })  : _apiClient = apiClient ?? ApiClient.instance,
        _tokenService = tokenService ?? TokenService.instance;

  // ---------------------------------------------------------------------------
  // GET /v1/partner/product-categories/select
  // ---------------------------------------------------------------------------
  /// Recupere la liste simplifiee des categories pour les dropdowns.
  ///
  /// Retourne une liste de [CategorySelect] (id, label, value).
  /// Cette liste n'est PAS paginee.
  Future<List<CategorySelect>> selectCategories() async {
    final response = await _apiClient.get(
      CategoryEndpoints.select,
    );

    final dataList = response['data'] as List? ?? [];
    return dataList
        .whereType<Map<String, dynamic>>()
        .map((json) => CategorySelect.fromJson(json))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/product-categories
  // ---------------------------------------------------------------------------
  /// Recupere la liste paginee des categories de produits.
  ///
  /// [page] : numero de page (defaut 1).
  /// [limit] : nombre de resultats par page (defaut 25).
  /// [search] : recherche optionnelle sur le label.
  Future<PaginatedResult<ProductCategory>> listCategories({
    int page = 1,
    int limit = 25,
    String? search,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final response = await _apiClient.get(
      CategoryEndpoints.list,
      queryParams: queryParams,
    );

    final dataList = response['data'] as List? ?? [];
    final categories = dataList
        .whereType<Map<String, dynamic>>()
        .map((json) => ProductCategory.fromJson(json))
        .toList();

    final meta = response['meta'] != null
        ? PaginationMeta.fromJson(response['meta'] as Map<String, dynamic>)
        : PaginationMeta(
            total: categories.length,
            page: page,
            limit: limit,
            totalPages: 1,
          );

    return PaginatedResult(data: categories, meta: meta);
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/product-categories/:id
  // ---------------------------------------------------------------------------
  /// Recupere le detail d'une categorie avec ses produits associes.
  Future<ProductCategory> getCategory(int categoryId) async {
    final response = await _apiClient.get(
      CategoryEndpoints.get(categoryId.toString()),
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    return ProductCategory.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // POST /v1/partner/product-categories
  // ---------------------------------------------------------------------------
  /// Cree une nouvelle categorie de produits.
  ///
  /// [label] : nom de la categorie (obligatoire).
  /// [description] : description optionnelle.
  /// [status] : active ou non (defaut true).
  Future<ProductCategory> createCategory({
    required String label,
    String? description,
    bool status = true,
  }) async {
    final body = <String, dynamic>{
      'label': label,
      'status': status,
    };
    if (description != null) body['description'] = description;

    final response = await _apiClient.post(
      CategoryEndpoints.create,
      body: body,
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    return ProductCategory.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // PATCH /v1/partner/product-categories/:id
  // ---------------------------------------------------------------------------
  /// Met a jour une categorie existante.
  ///
  /// Seuls les champs fournis (non null) sont envoyes (PATCH partiel).
  Future<ProductCategory> updateCategory(
    int categoryId, {
    String? label,
    String? description,
    bool? status,
  }) async {
    final body = <String, dynamic>{};
    if (label != null) body['label'] = label;
    if (description != null) body['description'] = description;
    if (status != null) body['status'] = status;

    final response = await _apiClient.patch(
      CategoryEndpoints.update(categoryId.toString()),
      body: body,
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    return ProductCategory.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // DELETE /v1/partner/product-categories/:id
  // ---------------------------------------------------------------------------
  /// Supprime une categorie.
  Future<void> deleteCategory(int categoryId) async {
    await _apiClient.delete(
      CategoryEndpoints.delete(categoryId.toString()),
    );
  }

  // ---------------------------------------------------------------------------
  // POST /v1/partner/product-categories/:id/picture  (multipart/form-data)
  // ---------------------------------------------------------------------------
  /// Upload l'image d'une categorie.
  ///
  /// [categoryId] : ID de la categorie.
  /// [imageFile] : fichier image (JPEG, PNG ou WebP, max 5MB).
  /// Utilise une requete multipart directe (meme pattern que ProfileService.uploadLogo).
  ///
  /// Retourne l'URL de l'image uploadee, ou null si la reponse ne contient pas d'URL.
  Future<String?> uploadPicture(int categoryId, File imageFile) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}${CategoryEndpoints.uploadPicture(categoryId.toString())}',
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

    // Headers d'authentification
    if (token != null && token.isNotEmpty) {
      request.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
    }
    request.headers[HttpHeaders.acceptHeader] = 'application/json';

    // Fichier image
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
        final data = body['data'] as Map<String, dynamic>?;
        return data?['picture'] as String?;
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
  // DELETE /v1/partner/product-categories/bulk  (DELETE avec body JSON)
  // ---------------------------------------------------------------------------
  /// Supprime plusieurs categories en masse.
  ///
  /// [ids] : liste des IDs de categories a supprimer.
  /// L'API attend `{"ids": [...], "action": "delete"}` dans le body d'un DELETE.
  ///
  /// Utilise une requete HTTP brute car le client standard ne supporte pas
  /// le body dans un DELETE.
  Future<void> bulkDelete(List<int> ids) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}${CategoryEndpoints.bulkDelete}',
    );
    final token = await _tokenService.getAccessToken();

    final headers = <String, String>{
      HttpHeaders.contentTypeHeader: 'application/json',
      HttpHeaders.acceptHeader: 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
    }

    final bodyJson = jsonEncode({
      'ids': ids,
      'action': 'delete',
    });

    ApiLogger.logRequest(
      method: 'DELETE',
      url: url.toString(),
      headers: headers,
      body: bodyJson,
    );

    final stopwatch = Stopwatch()..start();

    try {
      // Utiliser http.Request pour envoyer un body avec DELETE
      final request = http.Request('DELETE', url);
      request.headers.addAll(headers);
      request.body = bodyJson;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      stopwatch.stop();

      final body = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};

      ApiLogger.logResponse(
        method: 'DELETE',
        url: url.toString(),
        statusCode: response.statusCode,
        body: body,
        duration: stopwatch.elapsed,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }

      throw ApiException(
        statusCode: response.statusCode,
        message: body['message'] is String
            ? body['message'] as String
            : body['message'] is List
                ? (body['message'] as List).join(', ')
                : 'Erreur lors de la suppression en masse',
      );
    } catch (e, st) {
      stopwatch.stop();
      if (e is ApiException) rethrow;
      ApiLogger.logError(
        method: 'DELETE',
        url: url.toString(),
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}
