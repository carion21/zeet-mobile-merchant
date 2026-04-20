import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zeet_ui/zeet_ui.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/models/order_model.dart';
import 'package:merchant/providers/orders_provider.dart';
import 'package:merchant/screens/home/widgets/home_order_card.dart';
import 'package:merchant/screens/root/index.dart';

/// Section "Mes commandes" du home : titre + shortcut tab orders + TabBar
/// "Nouvelles / En cours" + sliver de la liste des commandes filtree par tab.
///
/// Encapsulee dans un `SliverMainAxisGroup` pour rester dans un seul
/// `CustomScrollView` (evite le double scroll de l'ancien TabBarView dans
/// `SizedBox(height: 400)` — issue M-11).
///
/// Extrait de `_buildOrdersSectionHeader` + `_buildOrdersSliver` du
/// monolithe home.
class HomeOrdersSection extends ConsumerWidget {
  const HomeOrdersSection({
    super.key,
    required this.tabController,
    required this.isOnline,
  });

  final TabController tabController;
  final bool isOnline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverMainAxisGroup(
      slivers: <Widget>[
        SliverToBoxAdapter(child: _SectionHeader(tabController: tabController)),
        _OrdersSliver(
          tabController: tabController,
          isOnline: isOnline,
        ),
      ],
    );
  }
}

class _SectionHeader extends ConsumerWidget {
  const _SectionHeader({required this.tabController});

  final TabController tabController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color textColor = scheme.onSurface;
    final Color textLightColor = scheme.onSurfaceVariant;
    final int newOrdersCount = ref.watch(pendingOrdersCountProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Titre + shortcut vers le tab Commandes (1 tap — switch tab).
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Mes commandes',
                style: TextStyle(
                  color: textColor,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () {
                  ZeetHaptics.tap();
                  ref.read(rootTabProvider.notifier).state = RootTab.orders;
                },
                child: Text(
                  'Voir plus',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),

        // TabBar "Nouvelles / En cours".
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: scheme.outlineVariant,
              width: 1,
            ),
          ),
          child: TabBar(
            controller: tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: textLightColor,
            labelStyle:
                TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
            unselectedLabelStyle:
                TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
            indicatorColor: AppColors.primary,
            indicatorWeight: 2.5,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            tabs: <Widget>[
              Tab(text: 'Nouvelles ($newOrdersCount)'),
              const Tab(text: 'En cours'),
            ],
          ),
        ),
        SizedBox(height: 16.h),
      ],
    );
  }
}

/// Sliver listant les commandes du tab actif — évite le double-scroll
/// de l'ancien `TabBarView` dans `SizedBox(height: 400)` (issue M-11).
class _OrdersSliver extends ConsumerWidget {
  const _OrdersSliver({
    required this.tabController,
    required this.isOnline,
  });

  final TabController tabController;
  final bool isOnline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OrdersListState ordersState = ref.watch(ordersListProvider);
    // Listen au TabController pour rebuild au swipe / tap de tab.
    final int tabIndex = tabController.index;
    final List<Order> orders = tabIndex == 0
        ? ordersState.pendingOrders
        : ordersState.activeOrders;
    final ZeetScreenState state =
        _resolveHomeOrderState(ordersState, orders, isOnline);

    if (state == ZeetScreenState.loading) {
      return const SliverToBoxAdapter(
        child: ZeetSkeletonList(itemCount: 3, itemHeight: 140),
      );
    }
    if (state == ZeetScreenState.empty ||
        state == ZeetScreenState.error ||
        state == ZeetScreenState.offline) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
          child: ZeetEmptyState(
            icon: state == ZeetScreenState.offline
                ? Icons.wifi_off_rounded
                : state == ZeetScreenState.error
                    ? Icons.error_outline_rounded
                    : Icons.shopping_bag_outlined,
            title: state == ZeetScreenState.offline
                ? 'Hors ligne'
                : state == ZeetScreenState.error
                    ? 'Chargement impossible'
                    : tabIndex == 0
                        ? 'Aucune nouvelle commande'
                        : 'Aucune commande en cours',
            description: state == ZeetScreenState.error
                ? (ordersState.errorMessage ?? 'Une erreur est survenue.')
                : tabIndex == 0
                    ? 'Les nouvelles commandes apparaîtront ici.'
                    : 'Les commandes actives apparaîtront ici.',
            actionLabel: state == ZeetScreenState.error ? 'Réessayer' : null,
            onAction: state == ZeetScreenState.error
                ? () => ref.read(ordersListProvider.notifier).load()
                : null,
          ),
        ),
      );
    }

    return SliverList.builder(
      itemCount: orders.length,
      itemBuilder: (BuildContext context, int index) {
        final Order order = orders[index];
        final Widget card = HomeOrderCard(order: order);
        // Pulse rouge tant que la commande est "pending" — skill
        // zeet-pos-ergonomics §2bis : evenement critique qui doit etre
        // capte immediatement, impossible de rater.
        //
        // Le wrapper ZeetPulse ne doit PAS modifier la largeur effective
        // de la card : on garde le meme `Padding` horizontal que pour
        // les cards non-pulse, sans `EdgeInsets.all(2)` additionnel
        // (qui creait un decalage visible de ~4-10px cote a cote avec
        // les cards actives).
        // Pulse rouge sur les statuts "attente d'acceptation merchant" :
        // backend canonique `payment-accepted` + alias legacy `pending`.
        final bool isPendingAccept = order.status == 'pending' ||
            order.status == 'payment-accepted';
        return Padding(
          padding: EdgeInsets.only(bottom: 12.h, left: 16.w, right: 16.w),
          child: isPendingAccept
              ? ZeetPulse(
                  active: true,
                  color: ZeetColors.danger,
                  borderRadius: BorderRadius.circular(12.r),
                  minWidth: 1.5,
                  maxWidth: 3,
                  child: card,
                )
              : card,
        );
      },
    );
  }

  /// Resout l'etat ELOE pour une tab de commandes du home.
  ZeetScreenState _resolveHomeOrderState(
    OrdersListState state,
    List<Order> filteredOrders,
    bool isOnline,
  ) {
    switch (state.status) {
      case OrdersListStatus.initial:
      case OrdersListStatus.loading:
        return ZeetScreenState.loading;
      case OrdersListStatus.error:
        if (!isOnline) return ZeetScreenState.offline;
        return ZeetScreenState.error;
      case OrdersListStatus.loaded:
      case OrdersListStatus.loadingMore:
        if (filteredOrders.isEmpty) return ZeetScreenState.empty;
        return ZeetScreenState.content;
    }
  }
}

