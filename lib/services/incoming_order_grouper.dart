// IncomingOrderGrouper — Phase 4.3 skill zeet-notification-strategy §4.
//
// Role : grouper intelligemment les notifications "nouvelle commande" quand
// elles arrivent en rafale (coup de feu midi/soir).
//
// Regle :
//   - Window : glissante 2 minutes.
//   - Threshold : 3 commandes dans la window → passe en mode "groupe".
//   - En mode "groupe" : une notif summary Android inbox + threadIdentifier
//     iOS est affichee ("X nouvelles commandes · Y FCFA au total").
//   - Chaque notif individuelle continue d'etre affichee, mais avec un
//     `groupKey` + `threadIdentifier` pour etre stackee sous la summary.
//   - Tap sur summary → ouvre la liste orders filtree sur `payment-accepted`
//     (cf. FcmService._dispatch qui parse le payload `type='orders.group'`).
//
// Ce grouper est stateless cote persistance (tout en memoire) — un redemarrage
// de l'app reset la window, ce qui est acceptable : la summary ne peut
// exister que si l'app a recu plusieurs pushs a peu d'intervalle, ce qui
// implique que l'isolate tourne.
//
// Thread-safety : accede depuis le main isolate ET le background handler
// FCM. Les deux isolates ayant leur propre memoire Dart, chacun a sa propre
// instance (singleton local a l'isolate) — c'est acceptable : la summary
// n'a de sens que dans l'isolate qui recoit la rafale, et une fois l'app
// ramenee au premier plan, le main isolate reprend la main.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:merchant/models/incoming_order_payload.dart';
import 'package:merchant/services/local_notification_service.dart';

/// Entree dans la window de grouping. Minimaliste : on ne garde que ce qui
/// sert a afficher la summary (code + montant) et l'horodatage pour
/// l'expiration.
class _GroupEntry {
  final DateTime at;
  final int orderId;
  final String orderCode;
  final int totalFcfa;

  const _GroupEntry({
    required this.at,
    required this.orderId,
    required this.orderCode,
    required this.totalFcfa,
  });
}

class IncomingOrderGrouper {
  IncomingOrderGrouper._();
  static final IncomingOrderGrouper instance = IncomingOrderGrouper._();

  /// Window de grouping (skill §4 : "< 2 min").
  static const Duration _window = Duration(minutes: 2);

  /// Seuil de declenchement du groupe (skill §4 : "> 3 nouvelles commandes").
  static const int _threshold = 3;

  /// Queue en memoire des commandes recues dans la window. On purge a chaque
  /// arrivee pour garantir que `length` reflete toujours la window courante.
  final List<_GroupEntry> _recent = <_GroupEntry>[];

  /// Flag : la summary est-elle actuellement affichee ? Evite de la re-push
  /// a chaque nouvelle notif (Android replace par id, mais on economise le
  /// travail et on coupe le son si jamais la summary etait sonore).
  bool _summaryVisible = false;

  /// Handler principal : appele a chaque nouvelle commande dispatchee via
  /// FCM. Decide si on passe en mode "groupe" et met a jour la summary.
  ///
  /// Retourne `true` si le grouping est actif (la notif individuelle doit
  /// etre poussee avec `groupKey`), `false` sinon.
  Future<bool> onIncomingOrder(IncomingOrderPayload payload) async {
    final DateTime now = DateTime.now();
    _purgeExpired(now);

    _recent.add(_GroupEntry(
      at: now,
      orderId: payload.orderId,
      orderCode: payload.orderCode.isNotEmpty
          ? payload.orderCode
          : '#${payload.orderId}',
      totalFcfa: payload.totalFcfa,
    ));

    // Sous le seuil : pas de groupe, on laisse la notif individuelle sans
    // groupKey (= affichage standard).
    if (_recent.length < _threshold) {
      if (kDebugMode) {
        debugPrint(
          '[IncomingOrderGrouper] ${_recent.length}/$_threshold dans window — pas de group',
        );
      }
      return false;
    }

    // Seuil atteint : pousser/refresher la summary.
    final int count = _recent.length;
    final int total = _recent.fold<int>(0, (sum, e) => sum + e.totalFcfa);
    // Lignes inbox — max 5 les plus recentes (limite visuelle Android).
    final List<String> lines = _recent
        .reversed
        .take(5)
        .map<String>((e) => '${e.orderCode} · ${_formatFcfa(e.totalFcfa)}')
        .toList();

    try {
      await LocalNotificationService.showIncomingOrderSummary(
        count: count,
        totalFcfa: total,
        lines: lines,
      );
      _summaryVisible = true;
      if (kDebugMode) {
        debugPrint(
          '[IncomingOrderGrouper] summary affichee: count=$count total=$total',
        );
      }
    } catch (e) {
      debugPrint('[IncomingOrderGrouper] showSummary failed: $e');
    }
    return true;
  }

  /// Reset : appele quand l'utilisateur a consulte la liste (tap summary,
  /// ou ouverture de l'app), ou apres traitement d'une commande individuelle.
  /// Purge la window et annule la summary si visible.
  Future<void> reset() async {
    _recent.clear();
    if (_summaryVisible) {
      await LocalNotificationService.cancelIncomingOrderSummary();
      _summaryVisible = false;
    }
  }

  /// Retire les entrees expirees de la window (> [_window] dans le passe).
  void _purgeExpired(DateTime now) {
    _recent.removeWhere((e) => now.difference(e.at) > _window);
  }

  /// Format FCFA avec espace insecable (doit matcher LocalNotifService).
  static String _formatFcfa(int total) {
    final String str = total.toString();
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        out.write('\u00A0');
      }
      out.write(str[i]);
    }
    out.write('\u00A0FCFA');
    return out.toString();
  }
}
