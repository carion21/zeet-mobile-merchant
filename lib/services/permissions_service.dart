// lib/services/permissions_service.dart
//
// Service centralise pour la gestion des permissions de l'app partner.
// Wrappe `permission_handler` + `OverlayService` pour offrir une API unifiee
// a l'ecran d'onboarding post-login :
//
//  - Notifications         (Android 13+ / iOS — critique)
//  - Ignore battery        (Android — critique POS, evite que le FGS soit killed)
//  - Bulle flottante       (Android — optionnel, recommande)
//  - Exact alarms          (Android 12+ — utile pour les notifs planifiees)
//
// Le flag `permissions_onboarded` est persiste dans SharedPreferences pour
// ne plus re-afficher l'ecran a chaque lancement. L'utilisateur peut
// revisiter depuis le profil (non implemente ici — on se contente du gate
// post-login).

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:merchant/services/overlay_service.dart';

enum ZeetPermission {
  /// POST_NOTIFICATIONS Android / UNUserNotificationCenter iOS.
  notifications,

  /// SYSTEM_ALERT_WINDOW Android (bulle flottante).
  overlay,

  /// REQUEST_IGNORE_BATTERY_OPTIMIZATIONS Android.
  batteryOptimization,

  /// SCHEDULE_EXACT_ALARM Android 12+.
  exactAlarm,
}

/// Etat d'une permission vis-a-vis du systeme.
enum ZeetPermissionStatus {
  /// Jamais demandee ou demande en attente.
  unknown,

  /// Accordee par l'utilisateur.
  granted,

  /// Refusee (peut etre re-demandee).
  denied,

  /// Refusee definitivement — l'utilisateur doit aller dans les reglages.
  permanentlyDenied,

  /// Non applicable sur cette plateforme.
  notApplicable,
}

class PermissionsService {
  PermissionsService._();

  static final PermissionsService instance = PermissionsService._();

  static const String _prefKey = 'zeet_merchant_permissions_onboarded_v1';

  /// Ensemble des permissions a proposer sur la plateforme courante,
  /// dans l'ordre d'importance operationnelle.
  List<ZeetPermission> get applicablePermissions {
    if (kIsWeb) return const <ZeetPermission>[];
    if (Platform.isAndroid) {
      return const <ZeetPermission>[
        ZeetPermission.notifications,
        ZeetPermission.batteryOptimization,
        ZeetPermission.overlay,
        ZeetPermission.exactAlarm,
      ];
    }
    if (Platform.isIOS) {
      return const <ZeetPermission>[
        ZeetPermission.notifications,
      ];
    }
    return const <ZeetPermission>[];
  }

  /// Permissions considerees comme critiques (business). L'ecran
  /// d'onboarding previent si une critique reste refusee.
  Set<ZeetPermission> get criticalPermissions => const <ZeetPermission>{
        ZeetPermission.notifications,
        ZeetPermission.batteryOptimization,
      };

  // ---------------------------------------------------------------------------
  // Status / Request
  // ---------------------------------------------------------------------------

  Future<ZeetPermissionStatus> getStatus(ZeetPermission p) async {
    if (!applicablePermissions.contains(p)) {
      return ZeetPermissionStatus.notApplicable;
    }
    switch (p) {
      case ZeetPermission.notifications:
        return _map(await Permission.notification.status);
      case ZeetPermission.overlay:
        if (!Platform.isAndroid) return ZeetPermissionStatus.notApplicable;
        final bool granted = await OverlayService.instance.hasPermission();
        return granted
            ? ZeetPermissionStatus.granted
            : ZeetPermissionStatus.denied;
      case ZeetPermission.batteryOptimization:
        return _map(await Permission.ignoreBatteryOptimizations.status);
      case ZeetPermission.exactAlarm:
        // Disponible seulement Android 12+ (ignore silencieux sinon).
        try {
          return _map(await Permission.scheduleExactAlarm.status);
        } catch (_) {
          return ZeetPermissionStatus.notApplicable;
        }
    }
  }

  Future<ZeetPermissionStatus> request(ZeetPermission p) async {
    if (!applicablePermissions.contains(p)) {
      return ZeetPermissionStatus.notApplicable;
    }
    switch (p) {
      case ZeetPermission.notifications:
        return _map(await Permission.notification.request());
      case ZeetPermission.overlay:
        if (!Platform.isAndroid) return ZeetPermissionStatus.notApplicable;
        final bool granted = await OverlayService.instance.requestPermission();
        // Si accordee par le user, on active aussi la preference app
        // pour que la bulle soit effectivement affichee a la prochaine commande.
        if (granted) {
          await OverlayService.instance.setEnabledInPrefs(true);
        }
        return granted
            ? ZeetPermissionStatus.granted
            : ZeetPermissionStatus.denied;
      case ZeetPermission.batteryOptimization:
        return _map(await Permission.ignoreBatteryOptimizations.request());
      case ZeetPermission.exactAlarm:
        try {
          return _map(await Permission.scheduleExactAlarm.request());
        } catch (_) {
          return ZeetPermissionStatus.notApplicable;
        }
    }
  }

  /// Ouvre les reglages systeme (utile quand permanentlyDenied).
  Future<void> openSettings() async {
    await openAppSettings();
  }

  // ---------------------------------------------------------------------------
  // Flag onboarded
  // ---------------------------------------------------------------------------

  Future<bool> isOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  Future<void> markOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }

  // ---------------------------------------------------------------------------
  // Copy / metadata
  // ---------------------------------------------------------------------------

  String labelFor(ZeetPermission p) {
    switch (p) {
      case ZeetPermission.notifications:
        return 'Notifications';
      case ZeetPermission.overlay:
        return 'Bulle flottante';
      case ZeetPermission.batteryOptimization:
        return 'Batterie';
      case ZeetPermission.exactAlarm:
        return 'Alarmes precises';
    }
  }

  String descriptionFor(ZeetPermission p) {
    switch (p) {
      case ZeetPermission.notifications:
        return 'Recevez les nouvelles commandes en temps reel, meme ecran eteint.';
      case ZeetPermission.overlay:
        return 'Une bulle ZEET s\'affiche par-dessus vos autres apps sur nouvelle commande.';
      case ZeetPermission.batteryOptimization:
        return 'Empechez Android de mettre ZEET en veille pour ne rater aucune commande.';
      case ZeetPermission.exactAlarm:
        return 'Permet de declencher les alertes commande a la seconde pres.';
    }
  }

  /// Convertit un PermissionStatus de `permission_handler` vers notre enum.
  ZeetPermissionStatus _map(PermissionStatus s) {
    if (s.isGranted || s.isLimited || s.isProvisional) {
      return ZeetPermissionStatus.granted;
    }
    if (s.isPermanentlyDenied || s.isRestricted) {
      return ZeetPermissionStatus.permanentlyDenied;
    }
    return ZeetPermissionStatus.denied;
  }
}
