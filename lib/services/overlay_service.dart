// lib/services/overlay_service.dart
//
// Service singleton qui encapsule la bulle flottante chat-head
// (flutter_overlay_window). Role :
// - Gerer la preference utilisateur (activee/desactivee)
// - Demander/verifier la permission SYSTEM_ALERT_WINDOW
// - Afficher / masquer / mettre a jour la bulle sur evenement
//   (nouvelle commande FCM)
// - Router le tap : quand la bulle envoie {action: open_app},
//   ramener MainActivity au premier plan via MethodChannel "zeet/app_launcher".
//
// Android uniquement. Sur iOS, toutes les methodes sont des no-op
// (Apple n'autorise pas le System Alert Window style chat-head).

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef OverlayTapHandler = void Function();

class OverlayService {
  OverlayService._();

  static final OverlayService instance = OverlayService._();

  static const MethodChannel _appLauncher =
      MethodChannel('zeet/app_launcher');
  static const String _prefEnabledKey = 'zeet_merchant_overlay_enabled';

  StreamSubscription<dynamic>? _listenerSub;
  OverlayTapHandler? _onTap;
  int _currentCount = 0;

  /// Feature disponible uniquement sur Android.
  bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// Preference utilisateur : a-t-il choisi d'activer la bulle ?
  Future<bool> isEnabledInPrefs() async {
    if (!isSupported) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefEnabledKey) ?? false;
  }

  Future<void> setEnabledInPrefs(bool enabled) async {
    if (!isSupported) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabledKey, enabled);
    // Si desactivation alors que bulle active, la masquer immediatement.
    if (!enabled) {
      await hideBubble();
    }
  }

  /// Permission systeme (Display over other apps).
  Future<bool> hasPermission() async {
    if (!isSupported) return false;
    try {
      return await FlutterOverlayWindow.isPermissionGranted();
    } catch (_) {
      return false;
    }
  }

  /// Ouvre la page Systeme pour accorder la permission.
  /// Retourne true si accordee, false sinon.
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    try {
      final bool? result = await FlutterOverlayWindow.requestPermission();
      return result ?? false;
    } catch (e) {
      debugPrint('[OverlayService] requestPermission failed: $e');
      return false;
    }
  }

  /// Installe le listener global du tap sur la bulle. A appeler une fois
  /// au boot depuis main.dart.
  Future<void> initListener({required OverlayTapHandler onTap}) async {
    if (!isSupported) return;
    _onTap = onTap;
    await _listenerSub?.cancel();
    _listenerSub = FlutterOverlayWindow.overlayListener.listen((data) async {
      if (data is Map && data['action'] == 'open_app') {
        debugPrint('[OverlayService] bubble tapped → bringing app to front');
        try {
          await _appLauncher.invokeMethod<void>('bringToFront');
        } catch (e) {
          debugPrint('[OverlayService] bringToFront failed: $e');
        }
        _onTap?.call();
      }
    });
  }

  /// Affiche la bulle flottante (ou met a jour le count si deja visible).
  /// Respecte la preference utilisateur ET la permission systeme.
  Future<void> showBubble({int count = 1, String? title}) async {
    if (!isSupported) return;
    if (!await isEnabledInPrefs()) {
      debugPrint('[OverlayService] skip showBubble: disabled by user');
      return;
    }
    if (!await hasPermission()) {
      debugPrint('[OverlayService] skip showBubble: permission not granted');
      return;
    }

    _currentCount = count;

    try {
      final bool isActive = await FlutterOverlayWindow.isActive();
      if (isActive) {
        // Deja affichee — juste mettre a jour le count via shareData.
        await FlutterOverlayWindow.shareData(<String, Object?>{
          'count': count,
          if (title != null) 'title': title,
        });
        return;
      }

      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: title ?? 'ZEET Partner',
        overlayContent: 'Nouvelle commande en attente',
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.auto,
        height: 180,
        width: 180,
        alignment: OverlayAlignment.centerRight,
      );

      // Pousse le count initial (la bulle affiche 1 par defaut mais on force
      // pour synchroniser en cas de >1 des le demarrage).
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await FlutterOverlayWindow.shareData(<String, Object?>{
        'count': count,
        if (title != null) 'title': title,
      });
    } catch (e) {
      debugPrint('[OverlayService] showBubble failed: $e');
    }
  }

  /// Masque la bulle (et la detruit).
  Future<void> hideBubble() async {
    if (!isSupported) return;
    try {
      final bool isActive = await FlutterOverlayWindow.isActive();
      if (isActive) {
        await FlutterOverlayWindow.closeOverlay();
      }
      _currentCount = 0;
    } catch (e) {
      debugPrint('[OverlayService] hideBubble failed: $e');
    }
  }

  /// Incremente le count de la bulle (nouvelle commande quand bulle deja active).
  Future<void> incrementBubble({String? title}) async {
    await showBubble(count: _currentCount + 1, title: title);
  }

  int get currentCount => _currentCount;

  Future<void> dispose() async {
    await _listenerSub?.cancel();
    _listenerSub = null;
    _onTap = null;
  }
}
