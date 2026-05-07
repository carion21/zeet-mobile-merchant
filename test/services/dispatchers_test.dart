// Tests des 5 dispatchers FCM cross-domain de l'app partner.
//
// Couverture :
//   - extractOrderId : tolerance aux alias order_id / entity_id / id,
//     parsing string -> int, null safety.
//   - handleRaw : matching de type (type_value prio sur type), prefix
//     matching (`order.*` couvre les futurs events), retour bool pour
//     permettre la cascade non-bloquante dans main.dart.
//
// On NE teste PAS ici les invalidations de providers — ca demanderait
// un mocking complet des notifiers. Le contrat "handleRaw retourne true
// => notre domaine s'occupe du payload" suffit pour blinder la cascade.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:merchant/services/order_status_dispatcher.dart';
import 'package:merchant/services/partner_dispatcher.dart';
import 'package:merchant/services/payout_dispatcher.dart';
import 'package:merchant/services/rating_dispatcher.dart';
import 'package:merchant/services/wallet_dispatcher.dart';

void main() {
  group('OrderStatusDispatcher.extractOrderId', () {
    test('lit order_id en int', () {
      expect(
        OrderStatusDispatcher.extractOrderId(<String, dynamic>{
          'order_id': 540,
        }),
        540,
      );
    });

    test('lit order_id en string', () {
      expect(
        OrderStatusDispatcher.extractOrderId(<String, dynamic>{
          'order_id': '540',
        }),
        540,
      );
    });

    test('fallback sur entity_id si order_id absent', () {
      expect(
        OrderStatusDispatcher.extractOrderId(<String, dynamic>{
          'entity_id': '777',
        }),
        777,
      );
    });

    test('fallback sur id si order_id et entity_id absents', () {
      expect(
        OrderStatusDispatcher.extractOrderId(<String, dynamic>{
          'id': 42,
        }),
        42,
      );
    });

    test('priorite : order_id > entity_id > id', () {
      expect(
        OrderStatusDispatcher.extractOrderId(<String, dynamic>{
          'order_id': 1,
          'entity_id': 2,
          'id': 3,
        }),
        1,
      );
    });

    test('null si rien d exploitable', () {
      expect(
        OrderStatusDispatcher.extractOrderId(<String, dynamic>{
          'foo': 'bar',
        }),
        isNull,
      );
    });

    test('null si la string n est pas un int', () {
      expect(
        OrderStatusDispatcher.extractOrderId(<String, dynamic>{
          'order_id': 'abc',
        }),
        isNull,
      );
    });
  });

  group('OrderStatusDispatcher.isDeliveredType', () {
    test('reconnait order.delivered', () {
      expect(OrderStatusDispatcher.isDeliveredType('order.delivered'), isTrue);
    });

    test('reconnait delivery.delivered', () {
      expect(
        OrderStatusDispatcher.isDeliveredType('delivery.delivered'),
        isTrue,
      );
    });

    test('reconnait delivered nu', () {
      expect(OrderStatusDispatcher.isDeliveredType('delivered'), isTrue);
    });

    test('insensible a la casse', () {
      expect(OrderStatusDispatcher.isDeliveredType('ORDER.DELIVERED'), isTrue);
    });

    test('refuse order.created', () {
      expect(
        OrderStatusDispatcher.isDeliveredType('order.created'),
        isFalse,
      );
    });

    test('refuse string vide', () {
      expect(OrderStatusDispatcher.isDeliveredType(''), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // handleRaw : matching par type. On monte un Consumer minimal pour
  // recuperer un WidgetRef valide. Les invalidations sur les providers
  // sont try/catch dans les dispatchers, donc on accepte qu'elles
  // echouent silencieusement (notifiers non bootes en environnement test).
  // ---------------------------------------------------------------------------

  group('Dispatchers — matching par type', () {
    Future<void> withRef(
      WidgetTester tester,
      void Function(WidgetRef ref) body,
    ) async {
      WidgetRef? captured;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (BuildContext context, WidgetRef ref, _) {
              captured = ref;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(captured, isNotNull);
      body(captured!);
    }

    group('OrderStatusDispatcher', () {
      testWidgets('matche order.created', (WidgetTester tester) async {
        await withRef(tester, (WidgetRef ref) {
          expect(
            OrderStatusDispatcher.handleRaw(ref, <String, dynamic>{
              'type': 'order.created',
              'order_id': 1,
            }),
            isTrue,
          );
        });
      });

      testWidgets('matche order.status_changed (le bug principal du rapport)',
          (WidgetTester tester) async {
        await withRef(tester, (WidgetRef ref) {
          expect(
            OrderStatusDispatcher.handleRaw(ref, <String, dynamic>{
              'type_value': 'order.status_changed',
              'order_id': 1,
            }),
            isTrue,
          );
        });
      });

      testWidgets('matche les futurs order.* via prefix',
          (WidgetTester tester) async {
        await withRef(tester, (WidgetRef ref) {
          expect(
            OrderStatusDispatcher.handleRaw(ref, <String, dynamic>{
              'type': 'order.future_event_unknown',
              'order_id': 1,
            }),
            isTrue,
          );
        });
      });

      testWidgets('priorise type_value sur type',
          (WidgetTester tester) async {
        await withRef(tester, (WidgetRef ref) {
          // type = wallet.* (refuse) MAIS type_value = order.* (accepte)
          expect(
            OrderStatusDispatcher.handleRaw(ref, <String, dynamic>{
              'type': 'wallet.credited',
              'type_value': 'order.created',
              'order_id': 1,
            }),
            isTrue,
          );
        });
      });

      testWidgets('refuse wallet.credited', (WidgetTester tester) async {
        await withRef(tester, (WidgetRef ref) {
          expect(
            OrderStatusDispatcher.handleRaw(ref, <String, dynamic>{
              'type': 'wallet.credited',
            }),
            isFalse,
          );
        });
      });

      testWidgets('refuse payload sans type', (WidgetTester tester) async {
        await withRef(tester, (WidgetRef ref) {
          expect(
            OrderStatusDispatcher.handleRaw(ref, <String, dynamic>{
              'order_id': 1,
            }),
            isFalse,
          );
        });
      });
    });

    group('WalletDispatcher', () {
      testWidgets('matche wallet.credited', (WidgetTester tester) async {
        await withRef(tester, (WidgetRef ref) {
          expect(
            WalletDispatcher.handleRaw(ref, <String, dynamic>{
              'type': 'wallet.credited',
            }),
            isTrue,
          );
        });
      });

      testWidgets('matche les futurs wallet.* via prefix',
          (WidgetTester tester) async {
        await withRef(tester, (WidgetRef ref) {
          expect(
            WalletDispatcher.handleRaw(ref, <String, dynamic>{
              'type_value': 'wallet.unknown_future',
            }),
            isTrue,
          );
        });
      });

      testWidgets('refuse order.created', (WidgetTester tester) async {
        await withRef(tester, (WidgetRef ref) {
          expect(
            WalletDispatcher.handleRaw(ref, <String, dynamic>{
              'type': 'order.created',
            }),
            isFalse,
          );
        });
      });
    });

    group('PayoutDispatcher', () {
      testWidgets('matche payout.status_changed',
          (WidgetTester tester) async {
        await withRef(tester, (WidgetRef ref) {
          expect(
            PayoutDispatcher.handleRaw(ref, <String, dynamic>{
              'type': 'payout.status_changed',
            }),
            isTrue,
          );
        });
      });

      testWidgets('matche payout.created_by_admin',
          (WidgetTester tester) async {
        await withRef(tester, (WidgetRef ref) {
          expect(
            PayoutDispatcher.handleRaw(ref, <String, dynamic>{
              'type_value': 'payout.created_by_admin',
            }),
            isTrue,
          );
        });
      });

      testWidgets('refuse partner.availability_forced_closed',
          (WidgetTester tester) async {
        await withRef(tester, (WidgetRef ref) {
          expect(
            PayoutDispatcher.handleRaw(ref, <String, dynamic>{
              'type': 'partner.availability_forced_closed',
            }),
            isFalse,
          );
        });
      });
    });

    group('PartnerDispatcher', () {
      testWidgets('matche partner.availability_forced_closed',
          (WidgetTester tester) async {
        await withRef(tester, (WidgetRef ref) {
          expect(
            PartnerDispatcher.handleRaw(ref, <String, dynamic>{
              'type': 'partner.availability_forced_closed',
            }),
            isTrue,
          );
        });
      });

      testWidgets('matche partner.availability_restored',
          (WidgetTester tester) async {
        await withRef(tester, (WidgetRef ref) {
          expect(
            PartnerDispatcher.handleRaw(ref, <String, dynamic>{
              'type_value': 'partner.availability_restored',
            }),
            isTrue,
          );
        });
      });

      testWidgets('matche menu_item.availability_changed',
          (WidgetTester tester) async {
        await withRef(tester, (WidgetRef ref) {
          expect(
            PartnerDispatcher.handleRaw(ref, <String, dynamic>{
              'type': 'menu_item.availability_changed',
            }),
            isTrue,
          );
        });
      });

      testWidgets('refuse rating.received', (WidgetTester tester) async {
        await withRef(tester, (WidgetRef ref) {
          expect(
            PartnerDispatcher.handleRaw(ref, <String, dynamic>{
              'type': 'rating.received',
            }),
            isFalse,
          );
        });
      });
    });

    group('RatingDispatcher', () {
      testWidgets('matche rating.received', (WidgetTester tester) async {
        await withRef(tester, (WidgetRef ref) {
          expect(
            RatingDispatcher.handleRaw(ref, <String, dynamic>{
              'type': 'rating.received',
            }),
            isTrue,
          );
        });
      });

      testWidgets('matche review.received (alias)',
          (WidgetTester tester) async {
        await withRef(tester, (WidgetRef ref) {
          expect(
            RatingDispatcher.handleRaw(ref, <String, dynamic>{
              'type_value': 'review.received',
            }),
            isTrue,
          );
        });
      });

      testWidgets('refuse order.created', (WidgetTester tester) async {
        await withRef(tester, (WidgetRef ref) {
          expect(
            RatingDispatcher.handleRaw(ref, <String, dynamic>{
              'type': 'order.created',
            }),
            isFalse,
          );
        });
      });
    });

    testWidgets('Cascade : un meme payload n est consomme que par un dispatcher',
        (WidgetTester tester) async {
      await withRef(tester, (WidgetRef ref) {
        // wallet.credited -> seul WalletDispatcher matche.
        const Map<String, dynamic> walletPayload = <String, dynamic>{
          'type_value': 'wallet.credited',
        };
        expect(OrderStatusDispatcher.handleRaw(ref, walletPayload), isFalse);
        expect(WalletDispatcher.handleRaw(ref, walletPayload), isTrue);
        expect(PayoutDispatcher.handleRaw(ref, walletPayload), isFalse);
        expect(PartnerDispatcher.handleRaw(ref, walletPayload), isFalse);
        expect(RatingDispatcher.handleRaw(ref, walletPayload), isFalse);
      });
    });
  });
}
