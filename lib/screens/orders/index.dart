import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/core/constants/icons.dart';
import 'package:merchant/models/order_model.dart';
import 'package:merchant/providers/orders_provider.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/services/navigation_service.dart';
import 'package:intl/intl.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  OrderStatus? _selectedFilter;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkBackground : Colors.white;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.white;
    final textColor = isDark ? AppColors.darkText : AppColors.text;
    final textLightColor = isDark ? AppColors.darkTextLight : AppColors.textLight;

    // Récupérer toutes les commandes
    final allOrders = [
      ...ref.watch(newOrdersProvider),
      ...ref.watch(activeOrdersProvider),
      ...ref.watch(ordersProvider.notifier).todayDeliveredOrders,
    ];

    // Filtrer les commandes selon le filtre sélectionné
    final filteredOrders = _selectedFilter == null
        ? allOrders
        : allOrders.where((order) => order.status == _selectedFilter).toList();

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(textColor),

            // Filtres horizontaux
            _buildFilters(textColor, textLightColor, isDark),

            // Liste des commandes filtrées
            Expanded(
              child: filteredOrders.isEmpty
                  ? _buildEmptyState(textColor, textLightColor)
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      itemCount: filteredOrders.length,
                      itemBuilder: (context, index) {
                        final order = filteredOrders[index];
                        final showActions = order.status == OrderStatus.pending;
                        return _buildOrderCard(order, surfaceColor, textColor, textLightColor, isDark, showActions);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          IconButton(
            icon: IconManager.getIcon('arrow_back', color: textColor),
            onPressed: () => Routes.goBack(),
          ),
          SizedBox(width: 8.w),
          Text(
            'Mes commandes',
            style: TextStyle(
              color: textColor,
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(Color textColor, Color textLightColor, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Row(
          children: [
            _buildFilterChip('Toutes', null, textColor, textLightColor, isDark),
            SizedBox(width: 8.w),
            _buildFilterChip('En attente', OrderStatus.pending, textColor, textLightColor, isDark),
            SizedBox(width: 8.w),
            _buildFilterChip('En préparation', OrderStatus.preparing, textColor, textLightColor, isDark),
            SizedBox(width: 8.w),
            _buildFilterChip('Prêtes', OrderStatus.ready, textColor, textLightColor, isDark),
            SizedBox(width: 8.w),
            _buildFilterChip('En livraison', OrderStatus.pickedUp, textColor, textLightColor, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, OrderStatus? status, Color textColor, Color textLightColor, bool isDark) {
    final isSelected = _selectedFilter == status;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = status;
        });
      },
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : (isDark ? AppColors.darkSurface : Colors.grey[100]),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : textColor,
            fontSize: 13.sp,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(
    Order order,
    Color surfaceColor,
    Color textColor,
    Color textLightColor,
    bool isDark,
    bool showActions,
  ) {
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);
    final timeAgo = _getTimeAgo(order.createdAt);

    return GestureDetector(
      onTap: () {
        Routes.pushOrderDetails(order.id);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // En-tête
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '#${order.id}',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      _buildStatusBadge(order.status),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      IconManager.getIcon('person_outline', size: 16.r, color: textLightColor),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          order.customerName,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
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
                  Row(
                    children: [
                      Text(
                        '${order.items.length} article${order.items.length > 1 ? 's' : ''}',
                        style: TextStyle(fontSize: 13.sp, color: textLightColor),
                      ),
                      SizedBox(width: 8.w),
                      Text('•', style: TextStyle(color: textLightColor)),
                      SizedBox(width: 8.w),
                      Text(timeAgo, style: TextStyle(fontSize: 13.sp, color: textLightColor)),
                    ],
                  ),
                ],
              ),
            ),

            // Divider
            Divider(
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
              height: 1,
            ),

            // Pied
            Padding(
              padding: EdgeInsets.all(16.w),
              child: showActions
                  ? Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: textLightColor)),
                            Text(
                              currencyFormat.format(order.totalAmount),
                              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: textColor),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  ref.read(ordersProvider.notifier).acceptOrder(order.id);
                                  AppToast.showSuccess(context: context, message: 'Commande acceptée');
                                },
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
                                onPressed: () {
                                  ref.read(ordersProvider.notifier).rejectOrder(order.id);
                                  AppToast.showWarning(context: context, message: 'Commande refusée');
                                },
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
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: textLightColor)),
                        Text(
                          currencyFormat.format(order.totalAmount),
                          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: textColor),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    Color bgColor;
    switch (status) {
      case OrderStatus.pending:
        bgColor = const Color(0xFFFFA500);
        break;
      case OrderStatus.preparing:
        bgColor = const Color(0xFF2196F3);
        break;
      case OrderStatus.ready:
        bgColor = const Color(0xFF4CD964);
        break;
      case OrderStatus.pickedUp:
        bgColor = const Color(0xFF9C27B0);
        break;
      case OrderStatus.delivered:
        bgColor = const Color(0xFF4CAF50);
        break;
      case OrderStatus.cancelled:
        bgColor = AppColors.error;
        break;
      default:
        bgColor = Colors.grey;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: bgColor,
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textColor, Color textLightColor) {
    String title = 'Aucune commande';
    String subtitle = 'Les commandes apparaîtront ici';

    if (_selectedFilter != null) {
      switch (_selectedFilter!) {
        case OrderStatus.pending:
          title = 'Aucune commande en attente';
          subtitle = 'Les nouvelles commandes\napparaîtront ici';
          break;
        case OrderStatus.accepted:
          title = 'Aucune commande acceptée';
          subtitle = 'Les commandes acceptées\napparaîtront ici';
          break;
        case OrderStatus.preparing:
          title = 'Aucune commande en préparation';
          subtitle = 'Les commandes en cours de préparation\napparaîtront ici';
          break;
        case OrderStatus.ready:
          title = 'Aucune commande prête';
          subtitle = 'Les commandes prêtes\napparaîtront ici';
          break;
        case OrderStatus.pickedUp:
          title = 'Aucune commande en livraison';
          subtitle = 'Les commandes en cours de livraison\napparaîtront ici';
          break;
        case OrderStatus.delivered:
          title = 'Aucune commande livrée';
          subtitle = 'Les commandes livrées\napparaîtront ici';
          break;
        case OrderStatus.cancelled:
          title = 'Aucune commande annulée';
          subtitle = 'Les commandes annulées\napparaîtront ici';
          break;
      }
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconManager.getIcon('shopping_bag', size: 64.r, color: Colors.grey.shade300),
          SizedBox(height: 16.h),
          Text(
            title,
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: textColor),
          ),
          SizedBox(height: 8.h),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14.sp, color: textLightColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
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
  }
}
