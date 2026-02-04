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

class OrderDetailsScreen extends ConsumerWidget {
  final String orderId;

  const OrderDetailsScreen({
    super.key,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkBackground : Colors.white;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.white;
    final textColor = isDark ? AppColors.darkText : AppColors.text;
    final textLightColor = isDark ? AppColors.darkTextLight : AppColors.textLight;
    final dividerColor = isDark ? Colors.grey.shade700 : Colors.grey.shade200;

    // Trouver la commande
    final order = _findOrder(ref, orderId);

    if (order == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Text(
            'Commande introuvable',
            style: TextStyle(color: textColor, fontSize: 16.sp),
          ),
        ),
      );
    }

    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM yyyy • HH:mm', 'fr_FR');

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context, order, textColor, textLightColor, dateFormat),

            // Contenu scrollable
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16.h),

                    // Statut et Timeline
                    _buildStatusSection(order, textColor, textLightColor, surfaceColor, isDark),

                    SizedBox(height: 24.h),

                    // Client
                    _buildClientSection(order, textColor, textLightColor, surfaceColor, isDark),

                    Divider(color: dividerColor, height: 32.h),

                    // Articles
                    _buildItemsSection(order, textColor, textLightColor, currencyFormat),

                    Divider(color: dividerColor, height: 32.h),

                    // Résumé
                    _buildSummarySection(order, textColor, textLightColor, currencyFormat, isDark),

                    Divider(color: dividerColor, height: 32.h),

                    // Adresse de livraison
                    _buildAddressSection(order, textColor, textLightColor),

                    SizedBox(height: 24.h),
                  ],
                ),
              ),
            ),

            // Boutons d'action
            if (order.status == OrderStatus.pending)
              _buildActionButtons(context, ref, order, surfaceColor, isDark),
          ],
        ),
      ),
    );
  }

  Order? _findOrder(WidgetRef ref, String orderId) {
    final allOrders = [
      ...ref.watch(newOrdersProvider),
      ...ref.watch(activeOrdersProvider),
      ...ref.watch(ordersProvider.notifier).todayDeliveredOrders,
    ];

    try {
      return allOrders.firstWhere((order) => order.id == orderId);
    } catch (e) {
      return null;
    }
  }

  Widget _buildHeader(BuildContext context, Order order, Color textColor, Color textLightColor, DateFormat dateFormat) {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          IconButton(
            icon: IconManager.getIcon('arrow_back', color: textColor),
            onPressed: () => Routes.goBack(),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Commande #${order.id}',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Text(
                  dateFormat.format(order.createdAt),
                  style: TextStyle(fontSize: 13.sp, color: textLightColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(Order order, Color textColor, Color textLightColor, Color surfaceColor, bool isDark) {
    return Container(
      padding: EdgeInsets.all(20.w),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Statut de la commande',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              _buildStatusBadge(order.status),
            ],
          ),
          SizedBox(height: 16.h),
          _buildTimeline(order.status, textColor, textLightColor),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    Color bgColor;
    switch (status) {
      case OrderStatus.pending:
        bgColor = const Color(0xFFFFA500);
        break;
      case OrderStatus.accepted:
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
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: bgColor,
        ),
      ),
    );
  }

  Widget _buildTimeline(OrderStatus status, Color textColor, Color textLightColor) {
    final steps = [
      {'label': 'En attente', 'status': OrderStatus.pending},
      {'label': 'En préparation', 'status': OrderStatus.preparing},
      {'label': 'Prête', 'status': OrderStatus.ready},
      {'label': 'En livraison', 'status': OrderStatus.pickedUp},
      {'label': 'Livrée', 'status': OrderStatus.delivered},
    ];

    int currentIndex = 0;
    for (int i = 0; i < steps.length; i++) {
      if (steps[i]['status'] == status) {
        currentIndex = i;
        break;
      }
    }

    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isCompleted = index <= currentIndex;
        final isCurrent = index == currentIndex;
        final isLast = index == steps.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24.w,
                  height: 24.h,
                  decoration: BoxDecoration(
                    color: isCompleted ? AppColors.primary : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      isCompleted ? Icons.check : Icons.circle,
                      color: Colors.white,
                      size: isCompleted ? 16.sp : 8.sp,
                    ),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2.w,
                    height: 30.h,
                    color: isCompleted ? AppColors.primary : Colors.grey.shade300,
                  ),
              ],
            ),
            SizedBox(width: 12.w),
            Padding(
              padding: EdgeInsets.only(top: 2.h),
              child: Text(
                step['label'] as String,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                  color: isCurrent ? textColor : textLightColor,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildClientSection(Order order, Color textColor, Color textLightColor, Color surfaceColor, bool isDark) {
    return Container(
      padding: EdgeInsets.all(16.w),
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
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: const Color(0xFF4CD964).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: IconManager.getIcon('person_outline', color: const Color(0xFF4CD964), size: 24.r),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.customerName,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  order.customerPhone,
                  style: TextStyle(fontSize: 14.sp, color: textLightColor),
                ),
              ],
            ),
          ),
          IconButton(
            icon: IconManager.getIcon('phone', size: 24.r, color: AppColors.primary),
            onPressed: () {
              AppToast.showInfo(context: Routes.navigatorKey.currentContext!, message: 'Appel: ${order.customerPhone}');
            },
            constraints: BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(Order order, Color textColor, Color textLightColor, NumberFormat currencyFormat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Articles (${order.items.length})',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        SizedBox(height: 16.h),
        ...List.generate(order.items.length, (index) {
          final item = order.items[index];
          return Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    '${item.quantity}x',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
                Text(
                  currencyFormat.format(item.price * item.quantity),
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSummarySection(Order order, Color textColor, Color textLightColor, NumberFormat currencyFormat, bool isDark) {
    final subtotal = order.items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
    final deliveryFee = 1000.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Résumé',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        SizedBox(height: 16.h),
        _buildPriceRow('Sous-total', subtotal, textColor, textLightColor, currencyFormat),
        SizedBox(height: 8.h),
        _buildPriceRow('Frais de livraison', deliveryFee, textColor, textLightColor, currencyFormat),
        SizedBox(height: 16.h),
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Text(
                currencyFormat.format(order.totalAmount),
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(String label, double amount, Color textColor, Color textLightColor, NumberFormat currencyFormat) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 15.sp, color: textLightColor)),
        Text(
          currencyFormat.format(amount),
          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: textColor),
        ),
      ],
    );
  }

  Widget _buildAddressSection(Order order, Color textColor, Color textLightColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Adresse de livraison',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        SizedBox(height: 16.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconManager.getIcon('location', color: AppColors.primary, size: 20.r),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                order.deliveryAddress,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: textLightColor,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, Order order, Color surfaceColor, bool isDark) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                ref.read(ordersProvider.notifier).rejectOrder(order.id);
                AppToast.showWarning(context: context, message: 'Commande refusée');
                Routes.goBack();
              },
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14.h),
                side: BorderSide(color: AppColors.primary, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: Text(
                'Refuser',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                ref.read(ordersProvider.notifier).acceptOrder(order.id);
                AppToast.showSuccess(context: context, message: 'Commande acceptée');
                Routes.goBack();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                elevation: 0,
              ),
              child: Text(
                'Accepter',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
