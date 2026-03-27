import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/core/constants/icons.dart';
import 'package:merchant/core/constants/assets.dart';
import 'package:merchant/models/order_model.dart';
import 'package:merchant/providers/orders_provider.dart';
import 'package:merchant/providers/dashboard_provider.dart';
import 'package:merchant/providers/profile_provider.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/services/navigation_service.dart';
import 'package:intl/intl.dart';

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
    _tabController = TabController(length: 2, vsync: this);

    // Charger le dashboard, le profil et les commandes au demarrage
    Future.microtask(() {
      ref.read(dashboardProvider.notifier).loadSummary();
      ref.read(profileProvider.notifier).loadProfile();
      ref.read(ordersListProvider.notifier).load();
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
    final backgroundColor = isDark ? AppColors.darkBackground : Colors.white;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.white;
    final textColor = isDark ? AppColors.darkText : AppColors.text;
    final textLightColor = isDark ? AppColors.darkTextLight : AppColors.textLight;

    final pendingCount = ref.watch(pendingOrdersCountProvider);
    final dashboardSummary = ref.watch(dashboardProvider).summary;
    final double todayEarnings = dashboardSummary?.revenueToday ?? 0;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header moderne
            _buildModernHeader(textColor, textLightColor, pendingCount),

            // Contenu defilable
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Carte de gains avec image de fond
                    _buildEarningsCard(isDark, todayEarnings),

                    SizedBox(height: 16.h),

                    // Statistiques compactes
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: _buildCompactStats(textColor, textLightColor, surfaceColor, isDark),
                    ),

                    SizedBox(height: 20.h),

                    // Section des commandes
                    _buildOrdersSection(textColor, textLightColor, surfaceColor, pendingCount),

                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: pendingCount > 0 ? _buildNewOrdersFAB(pendingCount) : null,
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
              GestureDetector(
                onTap: () {
                  Routes.navigateTo(Routes.profile);
                },
                child: Container(
                  width: 40.w,
                  height: 40.h,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    image: partnerProfile?.picture != null
                        ? DecorationImage(
                            image: NetworkImage(partnerProfile!.picture!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: partnerProfile?.picture == null
                      ? Center(
                          child: IconManager.getIcon('person_outline', size: 22.r, color: AppColors.primary),
                        )
                      : null,
                ),
              ),

              // Notification a droite
              IconButton(
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
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          constraints: BoxConstraints(minWidth: 16.w, minHeight: 16.h),
                          child: Center(
                            child: Text(
                              '$newOrdersCount',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
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
                SizedBox(height: 2.h),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7.w,
                      height: 7.h,
                      decoration: BoxDecoration(
                        color: isOpen ? const Color(0xFF4CD964) : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 5.w),
                    Text(
                      isOpen ? 'Ouvert' : 'Ferme',
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
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);
    final walletBackground = isDark ? AppAssets.darkWallet : AppAssets.lightWallet;

    return Container(
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
                  Text(
                    currencyFormat.format(earnings),
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
    );
  }

  Widget _buildCompactStats(Color textColor, Color textLightColor, Color surfaceColor, bool isDark) {
    final ordersToday = ref.watch(ordersTodayProvider);
    final rating = ref.watch(ratingProvider);
    final activeCarts = ref.watch(activeCartsProvider);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Commandes du jour
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Commandes',
                  style: TextStyle(
                    color: textLightColor,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    IconManager.getIcon('shopping_bag', color: const Color(0xFFFFA500), size: 18.r),
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
                    IconManager.getIcon('star', color: const Color(0xFFFFD700), size: 18.r),
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
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.15),
      ),
    );
  }

  Widget _buildOrdersSection(Color textColor, Color textLightColor, Color surfaceColor, int newOrdersCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre de la section avec "Voir plus"
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
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
                  Routes.navigateTo(Routes.orders);
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

        // TabBar
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: textLightColor,
            labelStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
            unselectedLabelStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
            indicatorColor: AppColors.primary,
            indicatorWeight: 2.5,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: 'Nouvelles ($newOrdersCount)'),
              Tab(text: 'En cours'),
            ],
          ),
        ),

        SizedBox(height: 16.h),

        // Liste des commandes
        SizedBox(
          height: 400.h, // Hauteur fixe pour la liste
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildNewOrdersList(surfaceColor, textColor, textLightColor),
              _buildActiveOrdersList(surfaceColor, textColor, textLightColor),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNewOrdersFAB(int newOrdersCount) {
    return FloatingActionButton(
      onPressed: () {
        // Passer directement a l'onglet "Nouvelles"
        _tabController.animateTo(0);
      },
      backgroundColor: AppColors.primary,
      elevation: 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconManager.getIcon('shopping_bag', color: Colors.white, size: 28.r),
          if (newOrdersCount > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: EdgeInsets.all(5.r),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                constraints: BoxConstraints(minWidth: 10.w, minHeight: 10.h),
                child: Center(
                  child: Text(
                    '$newOrdersCount',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNewOrdersList(Color surfaceColor, Color textColor, Color textLightColor) {
    final ordersState = ref.watch(ordersListProvider);
    final pendingOrders = ordersState.pendingOrders;

    if (ordersState.status == OrdersListStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (pendingOrders.isEmpty) {
      return _buildEmptyState('Aucune nouvelle commande', 'Les nouvelles commandes apparaitront ici');
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      itemCount: pendingOrders.length,
      itemBuilder: (context, index) {
        final order = pendingOrders[index];
        return _buildOrderCard(order, surfaceColor, textColor, textLightColor, showActions: true);
      },
    );
  }

  Widget _buildActiveOrdersList(Color surfaceColor, Color textColor, Color textLightColor) {
    final ordersState = ref.watch(ordersListProvider);
    final active = ordersState.activeOrders;

    if (ordersState.status == OrdersListStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (active.isEmpty) {
      return _buildEmptyState('Aucune commande en cours', 'Les commandes actives apparaitront ici');
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      itemCount: active.length,
      itemBuilder: (context, index) {
        final order = active[index];
        return _buildOrderCard(order, surfaceColor, textColor, textLightColor);
      },
    );
  }

  Widget _buildOrderCard(Order order, Color surfaceColor, Color textColor, Color textLightColor, {bool showActions = false}) {
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);
    final timeAgo = _getTimeAgo(order.createdAt);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        Routes.pushOrderDetails(order.id);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h, left: 16.w, right: 16.w),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            '#${order.code ?? order.id}',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          SizedBox(width: 8.w),
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
                      IconButton(
                        icon: IconManager.getIcon('phone', size: 20.r, color: AppColors.primary),
                        onPressed: () {
                          AppToast.showInfo(context: context, message: 'Appel: ${order.customerPhone}');
                        },
                        constraints: BoxConstraints(),
                        padding: EdgeInsets.zero,
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
                    Text(
                      currencyFormat.format(order.totalAmount ?? 0),
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

          // Actions
          if (showActions)
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: textLightColor.withValues(alpha: 0.1))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _confirmOrder(order),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                      ),
                      child: Text('Accepter', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _cancelOrder(order),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                      ),
                      child: Text('Refuser', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
        ],
        ),
      ),
    );
  }

  Future<void> _confirmOrder(Order order) async {
    final notifier = ref.read(orderDetailProvider.notifier);
    final success = await notifier.confirm(order.id);
    if (success && mounted) {
      AppToast.showSuccess(context: context, message: 'Commande confirmee');
      ref.read(ordersListProvider.notifier).refresh();
    } else if (mounted) {
      final error = ref.read(orderDetailProvider).actionError;
      AppToast.showError(context: context, message: error ?? 'Erreur lors de la confirmation');
    }
  }

  Future<void> _cancelOrder(Order order) async {
    final reason = await _showCancelDialog();
    if (reason == null || !mounted) return;

    final notifier = ref.read(orderDetailProvider.notifier);
    final success = await notifier.cancel(order.id, cancelReason: reason);
    if (success && mounted) {
      AppToast.showWarning(context: context, message: 'Commande refusee');
      ref.read(ordersListProvider.notifier).refresh();
    } else if (mounted) {
      final error = ref.read(orderDetailProvider).actionError;
      AppToast.showError(context: context, message: error ?? 'Erreur lors de l\'annulation');
    }
  }

  Future<String?> _showCancelDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Refuser la commande'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Raison du refus...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = controller.text.trim();
              if (reason.isNotEmpty) {
                Navigator.pop(context, reason);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(OrderStatus? status, Color textLightColor) {
    if (status == null) return const SizedBox.shrink();

    Color bgColor;
    final colorStr = status.color;
    if (colorStr != null && colorStr.startsWith('#')) {
      try {
        bgColor = Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
      } catch (_) {
        bgColor = _fallbackStatusColor(status.value);
      }
    } else {
      bgColor = _fallbackStatusColor(status.value);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        status.displayLabel,
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: bgColor,
        ),
      ),
    );
  }

  Color _fallbackStatusColor(String? value) {
    switch (value) {
      case 'pending':
        return const Color(0xFFFFA500);
      case 'confirmed':
        return const Color(0xFF2196F3);
      case 'preparing':
        return const Color(0xFF2196F3);
      case 'ready':
        return const Color(0xFF4CD964);
      case 'picked_up':
        return const Color(0xFF9C27B0);
      case 'delivered':
        return const Color(0xFF4CAF50);
      case 'cancelled':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  Widget _buildEmptyState(String title, String subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : AppColors.text;
    final textLightColor = isDark ? AppColors.darkTextLight : AppColors.textLight;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconManager.getIcon('shopping_bag', size: 64.r, color: textLightColor.withValues(alpha: 0.3)),
            SizedBox(height: 16.h),
            Text(
              title,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: textColor),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              subtitle,
              style: TextStyle(fontSize: 14.sp, color: textLightColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(String? dateTimeStr) {
    if (dateTimeStr == null) return '';

    try {
      final dateTime = DateTime.parse(dateTimeStr);
      final diff = DateTime.now().difference(dateTime);

      if (diff.inMinutes < 1) {
        return 'A l\'instant';
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
