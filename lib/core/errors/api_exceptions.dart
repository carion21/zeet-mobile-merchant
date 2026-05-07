// lib/core/errors/api_exceptions.dart
//
// Hierarchie d'exceptions API typees pour merchant. Permet aux providers
// et screens de reagir differemment selon la classe d'erreur :
//   - AuthException        (401)   : forcer re-login
//   - ForbiddenException   (403)   : toast "action interdite"
//   - NotFoundException    (404)   : etat vide / ressource supprimee
//   - ValidationException  (422)   : afficher errors[] dans le formulaire
//   - ConflictException    (409)   : reload data, prevenir l'utilisateur
//   - ServerException      (5xx)   : retry silencieux puis toast
//   - NetworkException     (timeout, dns, no-internet) : enqueue offline
//
// Tous heritent de `ApiException` historique (statusCode + message + code +
// errors) pour ne pas casser le code existant. Les call-sites peuvent
// progressivement matcher la classe specifique avec `on AuthException`.

/// Base : conserve la signature historique pour compatibilite.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;
  final Map<String, dynamic>? errors;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.code,
    this.errors,
  });

  @override
  String toString() =>
      'ApiException($statusCode${code != null ? " $code" : ""}): $message';

  /// Verifie si l'erreur est une 401 Unauthorized.
  bool get isUnauthorized => statusCode == 401;

  /// Verifie si l'erreur est une 422 Validation.
  bool get isValidation => statusCode == 422;

  /// Construit la sous-classe adaptee au status code. Utilise par
  /// `ApiClient._handleResponse` pour typer automatiquement les erreurs.
  factory ApiException.fromStatus({
    required int statusCode,
    required String message,
    String? code,
    Map<String, dynamic>? errors,
  }) {
    if (statusCode == 401) {
      return AuthException(message: message, code: code, errors: errors);
    }
    if (statusCode == 403) {
      return ForbiddenException(message: message, code: code, errors: errors);
    }
    if (statusCode == 404) {
      return NotFoundException(message: message, code: code, errors: errors);
    }
    if (statusCode == 409) {
      return ConflictException(message: message, code: code, errors: errors);
    }
    if (statusCode == 422) {
      return ValidationException(message: message, code: code, errors: errors);
    }
    if (statusCode >= 500 && statusCode < 600) {
      return ServerException(
        statusCode: statusCode,
        message: message,
        code: code,
        errors: errors,
      );
    }
    return ApiException(
      statusCode: statusCode,
      message: message,
      code: code,
      errors: errors,
    );
  }
}

/// 401 Unauthorized — token rejete ou refresh KO. UX : forcer re-login.
class AuthException extends ApiException {
  const AuthException({
    required super.message,
    super.code,
    super.errors,
  }) : super(statusCode: 401);
}

/// 403 Forbidden — action permise mais ressource interdite a ce role.
/// UX : toast clair "Action non autorisee", pas de logout.
class ForbiddenException extends ApiException {
  const ForbiddenException({
    required super.message,
    super.code,
    super.errors,
  }) : super(statusCode: 403);
}

/// 404 Not Found — ressource supprimee ou jamais existee.
/// UX : etat vide, pas un toast d'erreur.
class NotFoundException extends ApiException {
  const NotFoundException({
    required super.message,
    super.code,
    super.errors,
  }) : super(statusCode: 404);
}

/// 409 Conflict — etat serveur a evolue (ex: order deja confirmee par un
/// autre user). UX : reload + prevenir.
class ConflictException extends ApiException {
  const ConflictException({
    required super.message,
    super.code,
    super.errors,
  }) : super(statusCode: 409);
}

/// 422 Validation — payload invalide cote serveur. `errors` contient le
/// detail par champ. UX : surligner les champs en erreur.
class ValidationException extends ApiException {
  const ValidationException({
    required super.message,
    super.code,
    super.errors,
  }) : super(statusCode: 422);
}

/// 5xx Server Error — backend en panne ou bug. UX : retry silencieux puis
/// toast "Probleme cote serveur, on retente plus tard".
class ServerException extends ApiException {
  const ServerException({
    required super.statusCode,
    required super.message,
    super.code,
    super.errors,
  });
}

/// Erreur reseau / timeout / DNS / pas d'internet. PAS un statusCode HTTP.
/// UX : enqueue offline si l'action est critique (orders, payouts) sinon
/// banner "Hors ligne, on retente au retour reseau".
class NetworkException extends ApiException {
  final Object? cause;
  NetworkException({String? message, this.cause})
      : super(
          statusCode: 0,
          message: message ??
              'Pas de connexion reseau. L\'action sera envoyee plus tard.',
        );
}
