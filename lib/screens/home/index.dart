import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zeet_ui/zeet_ui.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/core/constants/icons.dart';
import 'package:merchant/core/constants/assets.dart';
import 'package:merchant/core/utils/order_status_utils.dart';
import 'package:merchant/core/widgets/cancel_reason_sheet.dart';
import 'package:merchant/core/widgets/preparation_timer.dart';
import 'package:merchant/models/order_model.dart';
import 'package:merchant/providers/auth_provider.dart';
import 'package:merchant/providers/orders_provider.dart';
import 'package:merchant/providers/connectivity_provider.dart';
import 'package:merchant/providers/dashboard_provider.dart';
import 'package:merchant/providers/profile_provider.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/core/utils/phone_launcher.dart';
import 'package:merchant/services/incoming_order_dispatcher.dart';
import 'package:merchant/services/navigation_service.dart';
import 'package:merchant/screens/root/index.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      // Rebuild le sliver de commandes à chaque changement de tab
      // (le contenu de la liste dépend de `_tabController.index`).
      ..addListener(() {
        if (mounted) setState(() {});
      });

    Future.microtask(() {
      ref.read(authProvider.notifier).checkAuthStatus();
      ref.read(dashboardProvider.notifier).loadSummary();
      ref.read(profileProvider.notifier).loadProfile();
      ref.read(ordersListProvider.notifier).load();
    });

    // Si le /me en arrière-plan découvre des tokens invalides → login.
    ref.listenManual(authProvider, (prev, next) {
      if (prev?.status == AuthStatus.authenticated &&
          next.status == AuthStatus.unauthenticated) {
        Routes.navigateAndRemoveAll(Routes.login);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color backgroundColor = scheme.surface;
    final Color surfaceColor = scheme.surface;
    final Color textColor = scheme.onSurface;
    final Color textLightColor = scheme.onSurfaceVariant;

    final pendingCount = ref.watch(pendingOrdersCountProvider);
    final dashboardSummary = ref.watch(dashboardProvider).summary;
    final double todayEarnings = dashboardSummary?.revenueToday ?? 0;

    final isOnline = ref.watch(connectivityStatusProvider).maybeWhen(
      data: (v) => v,
      orElse: () => true,
    );

    // Refactor M-11 : plus de `SizedBox(height: 400.h)` qui limite la
    // TabBarView à un viewport fixe dans un SingleChildScrollView.
    // Top : header + bandeaux. Bas : Expanded(TabBarView) qui prend
    // tout l'espace → plus de double scroll, plus de contenu tronqué.
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            ConnectivityBanner(isOnline: isOnline),
            _buildModernHeader(textColor, textLightColor, pendingCount),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  HapticFeedback.lightImpact();
                  await Future.wait(<Future<void>>[
                    ref.read(dashboardProvider.notifier).loadSummary(),
                    ref.read(ordersListProvider.notifier).refresh(),
                  ]);
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: <Widget>[
                    SliverToBoxAdapter(
                      child: _buildEarningsCard(isDark, todayEarnings),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 16.h)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: _buildCompactStats(
                          textColor,
                          textLightColor,
                          surfaceColor,
                          isDark,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 20.h)),
                    SliverToBoxAdapter(
                      child: _buildOrdersSectionHeader(
                        textColor,
                        textLightColor,
                        pendingCount,
                      ),
                    ),
                    _buildOrdersSliver(
                      textColor,
                      textLightColor,
                      surfaceColor,
                      isOnline,
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 24.h)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeader(Color textColor, Color textLightColor, int newOrdersCount) {
    final partnerProfile = ref.watch(partnerDataProvider);
    final restaurantName = partnerProfile?.name ?? 'Mon Restaurant';
    final isOpen = partnerProfile?.openNow ?? false;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Stack(
        children: [
          // Row pour les elements gauche et droite
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icone profil a gauche (avec logo si disponible)
              Semantics(
                label: 'Profil restaurant — $restaurantName',
                button: true,
                child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  // Switch vers le tab Profil du RootScaffold (1 tap).
                  ref.read(rootTabProvider.notifier).state = RootTab.profile;
                },
                // Avatar 48×48pt — hit target POS partner (M-E10).
                child: Container(
                  width: 48.w,
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: partnerProfile?.picture != null
                      ? ClipOval(
                          child: ZeetImage(
                            url: partnerProfile!.picture,
                            width: 48.w,
                            height: 48.h,
                            fit: BoxFit.cover,
                            errorWidget: Center(
                              child: IconManager.getIcon('person_outline', size: 24.r, color: AppColors.primary),
                            ),
                          ),
                        )
                      : Center(
                          child: IconManager.getIcon('person_outline', size: 24.r, color: AppColors.primary),
                        ),
                ),
              ),
              ),

              // Actions a droite : (dev) test incoming order + cloche
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dev-only : declenche l'ecran "nouvelle commande" avec un
                  // payload bidon. Masque en release.
                  if (kDebugMode)
                    IconButton(
                      tooltip: 'Tester nouvelle commande (dev)',
                      onPressed: () =>
                          IncomingOrderDispatcher.triggerDev(ref),
                      icon: Icon(
                        Icons.flash_on_rounded,
                        color: AppColors.primary,
                        size: 24.r,
                      ),
                    ),
                  IconButton(
                    tooltip: 'Mon menu',
                    onPressed: () => Routes.navigateTo(Routes.menu),
                    icon: IconManager.getIcon('restaurant', color: textColor, size: 26.r),
                  ),
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: () {
                      // TODO: Navigate to notifications
                    },
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconManager.getIcon('notifications', color: textColor, size: 26.r),
                        if (newOrdersCount > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: EdgeInsets.all(4.r),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              constraints: BoxConstraints(minWidth: 18.w, minHeight: 18.h),
                              child: Center(
                                child: Text(
                                  '$newOrdersCount',
                                  // 12sp minimum (DS §3). 10sp illisible sur tablette.
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.bold,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Nom du restaurant centre
          Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  restaurantName,
                  style: TextStyle(
                    color: textColor.withValues(alpha: textColor.a * 0.7),
                    fontSize: 12.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Pastille 10×10pt (anti-daltonisme : taille + icône pleine/vide).
                    Icon(
                      isOpen ? Icons.circle : Icons.circle_outlined,
                      size: 10.r,
                      color: isOpen
                          ? ZeetColors.success
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      semanticLabel: isOpen ? 'Ouvert' : 'Fermé',
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      isOpen ? 'Ouvert' : 'Fermé',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsCard(bool isDark, double earnings) {
    final walletBackground = isDark ? AppAssets.darkWallet : AppAssets.lightWallet;

    // Raccourci 3-clicks-rule partner : tap sur la card "Gains du jour"
    // bascule vers le tab Portefeuille du RootScaffold (1 tap, zéro push).
    return GestureDetector(
      onTap: () async {
        await HapticFeedback.lightImpact();
        ref.read(rootTabProvider.notifier).state = RootTab.wallet;
      },
      child: Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        image: DecorationImage(
          image: AssetImage(walletBackground),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gains du jour',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  ZeetMoney(
                    amount: earnings,
                    currency: ZeetCurrency.fcfa,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: IconManager.getIcon('wallet', color: Colors.white, size: 28.r),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildCompactStats(Color textColor, Color textLightColor, Color surfaceColor, bool isDark) {
    final ordersToday = ref.watch(ordersTodayProvider);
    final rating = ref.watch(ratingProvider);
    final activeCarts = ref.watch(activeCartsProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: scheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          // Commandes du jour — micro-copy contextualisée (neuro-UX).
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Traitées aujourd\'hui',
                  style: TextStyle(
                    color: textLightColor,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    IconManager.getIcon('shopping_bag', color: ZeetColors.warning, size: 18.r),
                    SizedBox(width: 6.w),
                    Text(
                      '$ordersToday',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Divider vertical
          _buildVerticalDivider(isDark),

          // Note moyenne
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Note',
                  style: TextStyle(
                    color: textLightColor,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    // Intentionnel : couleur dorée standard pour les étoiles de notation
                    IconManager.getIcon('star', color: Colors.amber, size: 18.r),
                    SizedBox(width: 6.w),
                    Text(
                      rating > 0 ? rating.toStringAsFixed(1) : '--',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Divider vertical
          _buildVerticalDivider(isDark),

          // Paniers actifs
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paniers',
                  style: TextStyle(
                    color: textLightColor,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    IconManager.getIcon('shopping_cart', color: AppColors.primary, size: 18.r),
                    SizedBox(width: 6.w),
                    Text(
                      '$activeCarts',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider(bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: Container(
        width: 1.w,
        height: 40.h,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }

  /// Header de la section "Mes commandes" — titre + shortcut tab orders
  /// + TabBar "Nouvelles / En cours".
  Widget _buildOrdersSectionHeader(
    Color textColor,
    Color textLightColor,
    int newOrdersCount,
  ) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
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
                  HapticFeedback.selectionClick();
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
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: textLightColor,
            labelStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
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

  /// Sliver listant les commandes du tab actif — évite le double-scroll
  /// de l'ancien `TabBarView` dans `SizedBox(height: 400)` (issue M-11).
  Widget _buildOrdersSliver(
    Color textColor,
    Color textLightColor,
    Color surfaceColor,
    bool isOnline,
  ) {
    final OrdersListState ordersState = ref.watch(ordersListProvider);
    // Listen au TabController pour rebuild au swipe / tap de tab.
    final int tabIndex = _tabController.index;
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
        return _buildOrderCard(
          order,
          surfaceColor,
          textColor,
          textLightColor,
        );
      },
    );
  }

  Widget _buildOrderCard(Order order, Color surfaceColor, Color textColor, Color textLightColor) {
    final timeAgo = _getTimeAgo(order.createdAt);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    // Actions inline disponibles selon le statut — atteint le POS "1-tap"
    // pour les transitions critiques (issue C-04).
    final Widget? inlineActions = _buildInlineActionsForStatus(order);
    final String semantics =
        'Commande ${order.code ?? order.id} — ${order.orderStatus?.displayLabel ?? ""} — ${order.customerName}';

    return Semantics(
      container: true,
      button: true,
      label: semantics,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          Routes.pushOrderDetails(order.id);
        },
        child: Container(
        margin: EdgeInsets.only(bottom: 12.h, left: 16.w, right: 16.w),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12.r),
          // DS §2 : pas de BoxShadow sur cards (issue M-07). Border seule.
          border: Border.all(
            color: scheme.outlineVariant,
            width: 1,
          ),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header — code, timer (pression neuro-UX §2), statut.
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          Text(
                            '#${order.code ?? order.id}',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          if (order.status == 'confirmed' ||
                              order.status == 'preparing')
                            PreparationTimer(
                              createdAtIso: order.createdAt,
                              dense: true,
                            )
                          else
                            Text(
                              timeAgo,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: textLightColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(order.orderStatus, textLightColor),
                  ],
                ),
                SizedBox(height: 12.h),

                // Client info
                Row(
                  children: [
                    IconManager.getIcon('person_outline', size: 16.r, color: textLightColor),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        order.customerName,
                        style: TextStyle(fontSize: 14.sp, color: textColor),
                      ),
                    ),
                    if (order.customerPhone.isNotEmpty)
                      // Hit target minimum 48x48pt (règle POS partner §1).
                      // L'ancien IconButton avait `constraints: BoxConstraints()`
                      // qui supprimait la taille minimale → cible ~20pt,
                      // inatteignable en cuisine (audit partner 2026-04-15 §2).
                      IconButton(
                        icon: IconManager.getIcon('phone', size: 22.r, color: AppColors.primary),
                        tooltip: 'Appeler ${order.customerPhone}',
                        onPressed: () async {
                          HapticFeedback.selectionClick();
                          await launchPhoneCall(
                            order.customerPhone,
                            context: context,
                          );
                        },
                      ),
                  ],
                ),
                SizedBox(height: 8.h),

                // Total et nombre d'articles
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconManager.getIcon('shopping_bag', size: 16.r, color: textLightColor),
                        SizedBox(width: 8.w),
                        Text(
                          order.items.isNotEmpty
                              ? '${order.items.length} article${order.items.length > 1 ? 's' : ''}'
                              : 'Commande',
                          style: TextStyle(fontSize: 14.sp, color: textLightColor),
                        ),
                      ],
                    ),
                    ZeetMoney(
                      amount: order.totalAmount ?? 0,
                      currency: ZeetCurrency.fcfa,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Actions inline ZeetButton (taille md = 48pt, haptic intégré,
          // radius DS). La variante `ghost` sur le refus casse la parité
          // visuelle accept/refus pour éviter les faux refus en coup de feu.
          if (inlineActions != null)
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              child: inlineActions,
            ),
        ],
        ),
        ),
      ),
    );
  }

  Future<void> _confirmOrder(Order order) async {
    HapticFeedback.mediumImpact();
    final notifier = ref.read(orderDetailProvider.notifier);
    final success = await notifier.confirm(order.id);
    if (!mounted) return;
    if (success) {
      HapticFeedback.heavyImpact();
      AppToast.showSuccess(context: context, message: 'Commande confirmée');
      ref.read(ordersListProvider.notifier).refresh();
    } else {
      final error = ref.read(orderDetailProvider).actionError;
      AppToast.showError(context: context, message: error ?? 'Erreur lors de la confirmation');
    }
  }

  Future<void> _cancelOrder(Order order) async {
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    // Bottom sheet chips presets — zéro saisie clavier en cuisine
    // (issue C-02 / M-14, règle `zeet-pos-ergonomics` §3).
    final reason = await showCancelReasonSheet(context);
    if (reason == null || !mounted) return;

    final notifier = ref.read(orderDetailProvider.notifier);
    final success = await notifier.cancel(order.id, cancelReason: reason);
    if (success && mounted) {
      AppToast.showWarning(context: context, message: 'Commande refusée');
      ref.read(ordersListProvider.notifier).refresh();
    } else if (mounted) {
      final error = ref.read(orderDetailProvider).actionError;
      AppToast.showError(context: context, message: error ?? 'Erreur lors de l\'annulation');
    }
  }

  Future<void> _markPreparing(Order order) async {
    HapticFeedback.mediumImpact();
    final success = await ref
        .read(orderDetailProvider.notifier)
        .markPreparing(order.id);
    if (!mounted) return;
    if (success) {
      HapticFeedback.heavyImpact();
      AppToast.showSuccess(
        context: context,
        message: 'Préparation lancée',
      );
      ref.read(ordersListProvider.notifier).refresh();
    } else {
      final error = ref.read(orderDetailProvider).actionError;
      AppToast.showError(context: context, message: error ?? 'Erreur');
    }
  }

  Future<void> _markReady(Order order) async {
    HapticFeedback.mediumImpact();
    final success =
        await ref.read(orderDetailProvider.notifier).markReady(order.id);
    if (!mounted) return;
    if (success) {
      HapticFeedback.heavyImpact();
      AppToast.showSuccess(
        context: context,
        message: 'Commande prête pour collecte',
      );
      ref.read(ordersListProvider.notifier).refresh();
    } else {
      final error = ref.read(orderDetailProvider).actionError;
      AppToast.showError(context: context, message: error ?? 'Erreur');
    }
  }

  /// Retourne les actions inline appropriées pour le statut — null si
  /// aucune action merchant n'est disponible (livraison en cours etc.).
  ///
  /// Règle POS §4 : toute transition de statut critique doit être
  /// accessible en 1 tap depuis la liste (issue C-04).
  Widget? _buildInlineActionsForStatus(Order order) {
    switch (order.status) {
      case 'pending':
        return Row(
          children: <Widget>[
            Expanded(
              flex: 3,
              child: ZeetButton.primary(
                label: 'Accepter',
                onPressed: () => _confirmOrder(order),
                size: ZeetButtonSize.md,
                fullWidth: true,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              flex: 2,
              child: ZeetButton.ghost(
                label: 'Refuser',
                onPressed: () => _cancelOrder(order),
                size: ZeetButtonSize.md,
              ),
            ),
          ],
        );
      case 'confirmed':
        return ZeetButton.primary(
          label: 'Préparer',
          onPressed: () => _markPreparing(order),
          size: ZeetButtonSize.md,
          fullWidth: true,
          icon: Icons.restaurant_rounded,
        );
      case 'preparing':
        return ZeetButton(
          label: 'Prête',
          onPressed: () => _markReady(order),
          variant: ZeetButtonVariant.success,
          size: ZeetButtonSize.md,
          fullWidth: true,
          icon: Icons.check_circle_rounded,
        );
      default:
        return null;
    }
  }

  Widget _buildStatusBadge(OrderStatus? status, Color textLightColor) {
    if (status == null) return const SizedBox.shrink();
    // ZeetStatusChip force couleur + icône + label (règle a11y POS partner,
    // contraste WCAG AA garanti). Source de vérité : `partnerStatusFor`
    // centralisée dans `core/utils/order_status_utils.dart`.
    return ZeetStatusChip(
      status: partnerStatusFor(status.value),
      label: status.displayLabel,
      dense: true,
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

  String _getTimeAgo(String? dateTimeStr) {
    if (dateTimeStr == null) return '';

    try {
      final dateTime = DateTime.parse(dateTimeStr);
      final diff = DateTime.now().difference(dateTime);

      if (diff.inMinutes < 1) {
        return 'À l\'instant';
      } else if (diff.inMinutes < 60) {
        return 'Il y a ${diff.inMinutes} min';
      } else if (diff.inHours < 24) {
        return 'Il y a ${diff.inHours}h';
      } else {
        return 'Il y a ${diff.inDays}j';
      }
    } catch (_) {
      return '';
    }
  }
}
