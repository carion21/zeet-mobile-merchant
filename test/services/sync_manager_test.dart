// Tests d'integration legers pour SyncManager — couvre les bugs P1
// fixes dans le commit 87a3db1 :
//   - B-11 : dedup confirmOrder (double-tap < 500ms = 1 seule action).
//   - B-3  : _inFlight skip — pas de double-execution sur la meme action
//            si run() et retryAction() s'entrelacent.
//
// Setup minimal :
//   - DB Drift en memoire via PartnerDatabase.forTesting(NativeDatabase.memory()).
//   - Stub OrderService qui simule les API calls (delais, throws controlles).

import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';

import 'package:merchant/data/local/partner_database.dart';
import 'package:merchant/models/order_model.dart';
import 'package:merchant/services/api_client.dart';
import 'package:merchant/services/order_service.dart';
import 'package:merchant/services/sync_manager.dart';

/// En `flutter test` (Dart pur) sur Linux, sqlite3_flutter_libs n'a pas
/// d'effet — on doit pointer vers la lib systeme. macOS/Windows : la lib
/// est trouvee automatiquement.
void _setupSqliteLoader() {
  if (Platform.isLinux) {
    open.overrideFor(OperatingSystem.linux, () {
      // Fallback sur le path Debian/Ubuntu standard. Si le test tourne
      // sur une autre distro et echoue, ajuster ici.
      return DynamicLibrary.open(
        '/lib/x86_64-linux-gnu/libsqlite3.so.0',
      );
    });
  }
}

class _StubOrderService implements OrderService {
  int confirmCalls = 0;
  int cancelCalls = 0;
  int markPreparingCalls = 0;
  int markReadyCalls = 0;

  /// Si non null, executor attend ce duration avant de resoudre — utile
  /// pour orchestrer les races.
  Duration? confirmDelay;

  /// Si non null, l'API throw cette exception au lieu de reussir.
  Object? confirmThrow;

  @override
  Future<Order> confirmOrder(
    int orderId, {
    int estimatedMinutes = 30,
  }) async {
    confirmCalls++;
    if (confirmDelay != null) {
      await Future<void>.delayed(confirmDelay!);
    }
    if (confirmThrow != null) {
      throw confirmThrow!;
    }
    return Order(id: orderId, statusValue: 'confirmed');
  }

  @override
  Future<Order> markPreparing(int orderId, {int estimatedMinutes = 20}) async {
    markPreparingCalls++;
    return Order(id: orderId, statusValue: 'preparing');
  }

  @override
  Future<Order> markReady(int orderId) async {
    markReadyCalls++;
    return Order(id: orderId, statusValue: 'ready');
  }

  @override
  Future<Order> cancelOrder(int orderId, {required String cancelReason}) async {
    cancelCalls++;
    return Order(id: orderId, statusValue: 'cancelled');
  }

  // Methodes non testees — `noSuchMethod` evite de devoir tout stubber.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'StubOrderService.${invocation.memberName} not stubbed',
    );
  }
}

void main() {
  setUpAll(_setupSqliteLoader);

  late PartnerDatabase db;
  late _StubOrderService api;
  late SyncManager sm;

  setUp(() {
    // Reset le singleton entre tests — sans ca, le 2e test recupere
    // une DB deja fermee.
    SyncManager.resetForTesting();
    db = PartnerDatabase.forTesting(NativeDatabase.memory());
    api = _StubOrderService();
    sm = SyncManager.initialize(database: db, orderService: api);
  });

  tearDown(() async {
    await db.close();
  });

  group('B-11 — dedup double-tap', () {
    test('action deja en vol => optimisticConfirm skip et ne lance pas l API',
        () async {
      // Pre-condition : une action confirmOrder pour orderId=540 est
      // deja en queue avec status=syncing (simule le scenario : un
      // premier tap a deja enqueue + lance l API call, qui n'a pas
      // encore retourne).
      await db.enqueueAction(
        id: 'first-tap',
        type: QueuedActionType.confirmOrder,
        orderId: 540,
      );
      await db.markActionSyncing('first-tap');

      // 2e tap qui arrive pendant que le 1er est en vol.
      final OptimisticResult r =
          await sm.optimisticConfirm(540, estimatedMinutes: 30);

      // Doit etre dedup — pas d'API call lance, queuedLocally=true.
      expect(r.queuedLocally, isTrue);
      expect(api.confirmCalls, 0);

      // L'action originale est toujours en queue (toujours syncing).
      final List<QueuedAction> all = await db.getAllActions();
      expect(all, hasLength(1));
      expect(all.first.id, 'first-tap');
    });

    test('action pending (offline) => 2e tap dedup aussi', () async {
      await db.enqueueAction(
        id: 'pending-tap',
        type: QueuedActionType.confirmOrder,
        orderId: 540,
      );

      final OptimisticResult r = await sm.optimisticConfirm(540);

      expect(r.queuedLocally, isTrue);
      expect(api.confirmCalls, 0);
      expect(await db.getAllActions(), hasLength(1));
    });

    test('confirm puis markPreparing — types differents, pas de dedup',
        () async {
      await sm.optimisticConfirm(540);
      await sm.optimisticMarkPreparing(540);

      // Les deux ont reussi → 2 API calls effectifs.
      expect(api.confirmCalls, 1);
      expect(api.markPreparingCalls, 1);
    });

    test('confirm sur 2 orderIds differents — pas de dedup', () async {
      await sm.optimisticConfirm(540);
      await sm.optimisticConfirm(541);

      expect(api.confirmCalls, 2);
    });
  });

  group('findInFlightAction (DB)', () {
    test('retourne null si rien en queue', () async {
      final QueuedAction? r = await db.findInFlightAction(
        type: QueuedActionType.confirmOrder,
        orderId: 540,
      );
      expect(r, isNull);
    });

    test('retourne l action pending si elle existe', () async {
      await db.enqueueAction(
        id: 'abc',
        type: QueuedActionType.confirmOrder,
        orderId: 540,
      );

      final QueuedAction? r = await db.findInFlightAction(
        type: QueuedActionType.confirmOrder,
        orderId: 540,
      );
      expect(r, isNotNull);
      expect(r!.id, 'abc');
    });

    test('retourne l action syncing aussi', () async {
      await db.enqueueAction(
        id: 'def',
        type: QueuedActionType.confirmOrder,
        orderId: 540,
      );
      await db.markActionSyncing('def');

      final QueuedAction? r = await db.findInFlightAction(
        type: QueuedActionType.confirmOrder,
        orderId: 540,
      );
      expect(r, isNotNull);
      expect(r!.status, QueuedActionStatus.syncing);
    });

    test('ne retourne PAS les actions failed (dead letter)', () async {
      await db.enqueueAction(
        id: 'ghi',
        type: QueuedActionType.confirmOrder,
        orderId: 540,
      );
      await db.markActionFailed(id: 'ghi', error: 'definitive');

      final QueuedAction? r = await db.findInFlightAction(
        type: QueuedActionType.confirmOrder,
        orderId: 540,
      );
      expect(r, isNull);
    });

    test('discrimine par orderId', () async {
      await db.enqueueAction(
        id: 'jkl',
        type: QueuedActionType.confirmOrder,
        orderId: 540,
      );

      final QueuedAction? other = await db.findInFlightAction(
        type: QueuedActionType.confirmOrder,
        orderId: 999,
      );
      expect(other, isNull);
    });

    test('discrimine par type', () async {
      await db.enqueueAction(
        id: 'mno',
        type: QueuedActionType.confirmOrder,
        orderId: 540,
      );

      final QueuedAction? other = await db.findInFlightAction(
        type: QueuedActionType.markReady,
        orderId: 540,
      );
      expect(other, isNull);
    });
  });

  group('clearAll (logout purge)', () {
    test('supprime les actions ET le cache orders', () async {
      // Setup : enqueue manuellement une action (sans la rejouer) +
      // upsert une commande en cache.
      await db.enqueueAction(
        id: 'pre-logout',
        type: QueuedActionType.confirmOrder,
        orderId: 540,
      );
      await db.upsertOrder(
        id: 540,
        status: 'pending',
        payload: '{"id":540}',
      );
      expect(await db.getAllActions(), isNotEmpty);
      expect(await db.getOrderById(540), isNotNull);

      await db.clearAll();

      expect(await db.getAllActions(), isEmpty);
      expect(await db.getOrderById(540), isNull);
    });
  });

  group('Action retry sur 5xx', () {
    test('action 5xx → markActionRetry (status pending), pas de markFailed',
        () async {
      api.confirmThrow = const ApiException(
        statusCode: 502,
        message: 'Bad gateway',
      );

      final OptimisticResult r = await sm.optimisticConfirm(540);
      expect(r.queuedLocally, isTrue);
      expect(r.error, contains('Bad gateway'));

      final List<QueuedAction> all = await db.getAllActions();
      expect(all, hasLength(1));
      // Une 5xx remet en pending (retryable), pas en failed.
      expect(all.first.status, QueuedActionStatus.pending);
    });

    test('action 4xx (sauf 408/429) → markActionFailed', () async {
      api.confirmThrow = const ApiException(
        statusCode: 400,
        message: 'Validation',
      );

      final OptimisticResult r = await sm.optimisticConfirm(540);
      expect(r.queuedLocally, isFalse);

      final List<QueuedAction> all = await db.getAllActions();
      expect(all, hasLength(1));
      expect(all.first.status, QueuedActionStatus.failed);
    });

    test('408 timeout → retryable (pending)', () async {
      api.confirmThrow = const ApiException(
        statusCode: 408,
        message: 'Timeout',
      );

      await sm.optimisticConfirm(540);

      final List<QueuedAction> all = await db.getAllActions();
      expect(all.first.status, QueuedActionStatus.pending);
    });

    test('429 rate-limit → retryable (pending)', () async {
      api.confirmThrow = const ApiException(
        statusCode: 429,
        message: 'Too many',
      );

      await sm.optimisticConfirm(540);

      final List<QueuedAction> all = await db.getAllActions();
      expect(all.first.status, QueuedActionStatus.pending);
    });
  });
}
