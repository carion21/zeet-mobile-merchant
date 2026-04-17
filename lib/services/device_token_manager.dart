import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:merchant/services/api_client.dart';
import 'package:merchant/services/notification_service.dart';
import 'package:merchant/services/token_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gestionnaire du token push (FCM/APNs) pour la surface partner.
///
/// Cette classe est volontairement decouplee du plugin `firebase_messaging`
/// afin que la couche API + le wiring auth soient operationnels AVANT la mise
/// en place de la configuration native Firebase (GoogleService-Info.plist,
/// google-services.json, APS entitlements, etc.).
///
/// CRITICITE PARTICULIERE COTE PARTNER :
/// le push est la facon de reveiller le restaurateur sur une nouvelle commande
/// entrante. Sans FCM, l'app partner risque de rater des commandes en production.
///
/// USAGE:
/// - Sur login succes : appeler `registerCurrentDevice()`
/// - Sur logout : appeler `unregisterCurrentDevice()` AVANT de purger les tokens
/// - Quand FCM sera wired : appeler `setPushToken(fcmToken)` dans le callback
///   `FirebaseMessaging.onTokenRefresh` puis `registerCurrentDevice()`.
///
/// TODO(fcm): Brancher `firebase_messaging` :
///   1. Ajouter `firebase_core` + `firebase_messaging` dans pubspec.yaml
///   2. Configurer les fichiers natifs (google-services.json / APNs)
///   3. Appeler `FirebaseMessaging.instance.getToken()` au boot post-auth
///   4. Ecouter `FirebaseMessaging.instance.onTokenRefresh`
///   5. Injecter le token recu via `DeviceTokenManager.instance.setPushToken(token)`
///      puis `registerCurrentDevice()`.
class DeviceTokenManager {
  static const String _prefsTokenKey = 'zeet_merchant_push_token';
  static const String _prefsRegistrationIdKey =
      'zeet_merchant_push_registration_id';

  static DeviceTokenManager? _instance;
  final NotificationService _notificationService;

  DeviceTokenManager._({NotificationService? notificationService})
      : _notificationService = notificationService ?? NotificationService();

  static DeviceTokenManager get instance {
    _instance ??= DeviceTokenManager._();
    return _instance!;
  }

  String? _cachedToken;

  String get _platform {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
    } catch (_) {}
    return 'unknown';
  }

  void setPushToken(String? token) {
    _cachedToken = (token != null && token.isNotEmpty) ? token : null;
  }

  String? get currentToken => _cachedToken;

  /// Enregistre le device courant aupres du backend.
  ///
  /// Gardes-fous :
  ///   1. Skip si aucun token FCM en cache (FCM pas encore pret)
  ///   2. Skip si aucun token d'auth local (user pas logge) — sinon le POST
  ///      part sans Bearer et le backend renvoie 401. Le register sera
  ///      automatiquement rejoue par `AuthService.login` apres succes.
  Future<bool> registerCurrentDevice() async {
    final token = _cachedToken;
    if (token == null || token.isEmpty) {
      debugPrint('[DeviceTokenManager] Aucun token push en cache — skip register');
      return false;
    }

    final bool hasAuth = await TokenService.instance.hasTokens();
    if (!hasAuth) {
      debugPrint('[DeviceTokenManager] Aucune session auth — skip register (retente apres login)');
      return false;
    }

    try {
      final result = await _notificationService.registerDeviceToken(
        token: token,
        platform: _platform,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsTokenKey, token);
      if (result.id != null) {
        await prefs.setInt(_prefsRegistrationIdKey, result.id!);
      }
      debugPrint('[DeviceTokenManager] 🏪 Device token enregistre (id=${result.id})');
      return true;
    } on ApiException catch (e) {
      debugPrint('[DeviceTokenManager] Echec enregistrement: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[DeviceTokenManager] Erreur enregistrement: $e');
      return false;
    }
  }

  /// Desenregistre le device courant aupres du backend.
  /// A appeler AVANT de purger les tokens d'auth pour que l'appel reste authentifie.
  Future<bool> unregisterCurrentDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getInt(_prefsRegistrationIdKey);
      if (id == null) {
        debugPrint(
            '[DeviceTokenManager] Aucun id de registration en cache — skip unregister');
        await prefs.remove(_prefsTokenKey);
        return false;
      }

      await _notificationService.removeDeviceToken(id);
      await prefs.remove(_prefsTokenKey);
      await prefs.remove(_prefsRegistrationIdKey);
      debugPrint('[DeviceTokenManager] 🏪 Device token supprime (id=$id)');
      return true;
    } on ApiException catch (e) {
      debugPrint('[DeviceTokenManager] Echec suppression: ${e.message}');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsTokenKey);
      await prefs.remove(_prefsRegistrationIdKey);
      return false;
    } catch (e) {
      debugPrint('[DeviceTokenManager] Erreur suppression: $e');
      return false;
    }
  }
}
