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

class OrderDetailsScreen extends ConsumerStatefulWidget {
  final int orderId;

  const OrderDetailsScreen({
    super.key,
    required this.orderId,
  });

  @override
  ConsumerState<OrderDetailsScreen> createState() =>
      _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(orderDetailProvider.notifier).load(widget.orderId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkBackground : Colors.white;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.white;
    final textColor = isDark ? AppColors.darkText : AppColors.text;
    final textLightColor = isDark ? AppColors.darkTextLight : AppColors.textLight;
    final dividerColor = isDark ? Colors.grey.shade700 : Colors.grey.shade200;

    final detailState = ref.watch(orderDetailProvider);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: _buildBody(
          detailState,
          backgroundColor,
          surfaceColor,
          textColor,
          textLightColor,
          dividerColor,
          isDark,
        ),
      ),
    );
  }

  Widget _buildBody(
    OrderDetailState detailState,
    Color backgroundColor,
    Color surfaceColor,
    Color textColor,
    Color textLightColor,
    Color dividerColor,
    bool isDark,
  ) {
    switch (detailState.status) {
      case OrderDetailStatus.initial:
      case OrderDetailStatus.loading:
        return Column(
          children: [
            _buildSimpleHeader(textColor),
            const Expanded(child: Center(child: CircularProgressIndicator())),
          ],
        );

      case OrderDetailStatus.error:
        return Column(
          children: [
            _buildSimpleHeader(textColor),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      detailState.errorMessage ?? 'Commande introuvable',
                      style: TextStyle(color: textColor, fontSize: 16.sp),
                    ),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: () => ref
                          .read(orderDetailProvider.notifier)
                          .load(widget.orderId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Reessayer'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

      case OrderDetailStatus.loaded:
      case OrderDetailStatus.acting:
        final order = detailState.order!;
        return _buildOrderDetail(
          order,
          detailState,
          surfaceColor,
          textColor,
          textLightColor,
          dividerColor,
          isDark,
        );
    }
  }

  Widget _buildOrderDetail(
    Order order,
    OrderDetailState detailState,
    Color surfaceColor,
    Color textColor,
    Color textLightColor,
    Color dividerColor,
    bool isDark,
  ) {
    final currencyFormat =
        NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM yyyy - HH:mm', 'fr_FR');

    return Column(
      children: [
        // Header
        _buildHeader(order, textColor, textLightColor, dateFormat),

        // Contenu scrollable
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16.h),

                // Statut
                _buildStatusSection(
                    order, textColor, textLightColor, surfaceColor, isDark),

                SizedBox(height: 24.h),

                // Client
                _buildClientSection(
                    order, textColor, textLightColor, surfaceColor, isDark),

                Divider(color: dividerColor, height: 32.h),

                // Articles
                if (order.items.isNotEmpty)
                  _buildItemsSection(
                      order, textColor, textLightColor, currencyFormat),

                if (order.items.isNotEmpty)
                  Divider(color: dividerColor, height: 32.h),

                // Resume financier
                _buildSummarySection(
                    order, textColor, textLightColor, currencyFormat, isDark),

                Divider(color: dividerColor, height: 32.h),

                // Adresse de livraison
                _buildAddressSection(order, textColor, textLightColor),

                // OTP pickup (si commande prete)
                if (order.status == 'ready' || order.status == 'picked_up') ...[
                  Divider(color: dividerColor, height: 32.h),
                  _buildPickupOtpSection(
                      detailState, textColor, textLightColor, surfaceColor, isDark),
                ],

                // Logs (historique)
                if (order.logs.isNotEmpty) ...[
                  Divider(color: dividerColor, height: 32.h),
                  _buildLogsSection(order, textColor, textLightColor),
                ],

                SizedBox(height: 24.h),
              ],
            ),
          ),
        ),

        // Boutons d'action selon le statut
        _buildActionBar(order, detailState, surfaceColor, isDark),
      ],
    );
  }

  Widget _buildSimpleHeader(Color textColor) {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          IconButton(
            icon: IconManager.getIcon('arrow_back', color: textColor),
            onPressed: () => Routes.goBack(),
          ),
          SizedBox(width: 12.w),
          Text(
            'Detail commande',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
      Order order, Color textColor, Color textLightColor, DateFormat dateFormat) {
    String formattedDate = '';
    if (order.createdAt != null) {
      try {
        formattedDate = dateFormat.format(DateTime.parse(order.createdAt!));
      } catch (_) {
        formattedDate = order.createdAt ?? '';
      }
    }

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
                  'Commande #${order.code ?? order.id}',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                if (formattedDate.isNotEmpty)
                  Text(
                    formattedDate,
                    style: TextStyle(fontSize: 13.sp, color: textLightColor),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(Order order, Color textColor, Color textLightColor,
      Color surfaceColor, bool isDark) {
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
      child: Row(
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
          _buildStatusBadge(order.orderStatus),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(OrderStatus? status) {
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
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        status.displayLabel,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: bgColor,
        ),
      ),
    );
  }

  Widget _buildClientSection(Order order, Color textColor, Color textLightColor,
      Color surfaceColor, bool isDark) {
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
            child: IconManager.getIcon('person_outline',
                color: const Color(0xFF4CD964), size: 24.r),
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
                if (order.customerPhone.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Text(
                    order.customerPhone,
                    style: TextStyle(fontSize: 14.sp, color: textLightColor),
                  ),
                ],
              ],
            ),
          ),
          if (order.customerPhone.isNotEmpty)
            IconButton(
              icon: IconManager.getIcon('phone',
                  size: 24.r, color: AppColors.primary),
              onPressed: () {
                AppToast.showInfo(
                    context: context,
                    message: 'Appel: ${order.customerPhone}');
              },
              constraints: BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(
      Order order, Color textColor, Color textLightColor, NumberFormat currencyFormat) {
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
          final itemTotal = item.totalPrice ??
              ((item.unitPrice ?? 0) * item.quantity);
          return Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName ?? 'Produit #${item.productId}',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      if (item.variantName != null)
                        Text(
                          item.variantName!,
                          style: TextStyle(
                              fontSize: 13.sp, color: textLightColor),
                        ),
                      if (item.options.isNotEmpty)
                        ...item.options.map((opt) => Text(
                              '+ ${opt.name ?? 'Option'}',
                              style: TextStyle(
                                  fontSize: 12.sp, color: textLightColor),
                            )),
                    ],
                  ),
                ),
                Text(
                  currencyFormat.format(itemTotal),
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

  Widget _buildSummarySection(Order order, Color textColor,
      Color textLightColor, NumberFormat currencyFormat, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resume',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        SizedBox(height: 16.h),
        if (order.subtotal != null)
          _buildPriceRow(
              'Sous-total', order.subtotal!, textColor, textLightColor, currencyFormat),
        if (order.subtotal != null) SizedBox(height: 8.h),
        if (order.deliveryFee != null)
          _buildPriceRow('Frais de livraison', order.deliveryFee!, textColor,
              textLightColor, currencyFormat),
        if (order.deliveryFee != null) SizedBox(height: 8.h),
        if (order.discount != null && order.discount! > 0) ...[
          _buildPriceRow('Reduction', -order.discount!, textColor,
              textLightColor, currencyFormat),
          SizedBox(height: 8.h),
        ],
        if (order.commission != null) ...[
          _buildPriceRow('Commission', order.commission!, textColor,
              textLightColor, currencyFormat),
          SizedBox(height: 8.h),
        ],
        SizedBox(height: 8.h),
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
                currencyFormat.format(order.totalAmount ?? 0),
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        // Methode de paiement
        if (order.paymentMethod != null) ...[
          SizedBox(height: 12.h),
          Row(
            children: [
              IconManager.getIcon('payment', size: 18.r, color: textLightColor),
              SizedBox(width: 8.w),
              Text(
                order.paymentMethod!.displayLabel,
                style: TextStyle(fontSize: 14.sp, color: textLightColor),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPriceRow(String label, double amount, Color textColor,
      Color textLightColor, NumberFormat currencyFormat) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontSize: 15.sp, color: textLightColor)),
        Text(
          currencyFormat.format(amount),
          style: TextStyle(
              fontSize: 15.sp, fontWeight: FontWeight.w600, color: textColor),
        ),
      ],
    );
  }

  Widget _buildAddressSection(
      Order order, Color textColor, Color textLightColor) {
    final address = order.position?.dropoffAddress ??
        order.deliveryAddress ??
        'Adresse non renseignee';

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
            IconManager.getIcon('location',
                color: AppColors.primary, size: 20.r),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                address,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: textLightColor,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        // Note du client
        if (order.noteCustomer != null &&
            order.noteCustomer!.isNotEmpty) ...[
          SizedBox(height: 12.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconManager.getIcon('note',
                  color: textLightColor, size: 20.r),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  order.noteCustomer!,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: textLightColor,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPickupOtpSection(
    OrderDetailState detailState,
    Color textColor,
    Color textLightColor,
    Color surfaceColor,
    bool isDark,
  ) {
    final otp = detailState.pickupOtp?.otp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Code de collecte (OTP)',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        SizedBox(height: 16.h),
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.15),
            ),
          ),
          child: otp != null
              ? Column(
                  children: [
                    Text(
                      otp,
                      style: TextStyle(
                        fontSize: 32.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        letterSpacing: 8,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    TextButton(
                      onPressed: () => _resendOtp(),
                      child: Text(
                        'Renvoyer le code',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Text(
                      'Code non encore genere',
                      style: TextStyle(fontSize: 14.sp, color: textLightColor),
                    ),
                    SizedBox(height: 12.h),
                    ElevatedButton(
                      onPressed: () => _getOtp(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Voir le code OTP'),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildLogsSection(
      Order order, Color textColor, Color textLightColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Historique',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        SizedBox(height: 16.h),
        ...order.logs.map((log) {
          String logDate = '';
          if (log.createdAt != null) {
            try {
              final dt = DateTime.parse(log.createdAt!);
              logDate = DateFormat('dd/MM HH:mm', 'fr_FR').format(dt);
            } catch (_) {}
          }

          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 8.w,
                  height: 8.h,
                  margin: EdgeInsets.only(top: 6.h),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.description ?? log.action ?? '',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: textColor,
                        ),
                      ),
                      if (logDate.isNotEmpty)
                        Text(
                          logDate,
                          style: TextStyle(
                              fontSize: 12.sp, color: textLightColor),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActionBar(
    Order order,
    OrderDetailState detailState,
    Color surfaceColor,
    bool isDark,
  ) {
    final isActing = detailState.status == OrderDetailStatus.acting;
    final status = order.status;

    // Pas d'actions pour les commandes terminees
    if (status == 'delivered' || status == 'cancelled') {
      return const SizedBox.shrink();
    }

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
      child: _buildActionsForStatus(order, isActing),
    );
  }

  Widget _buildActionsForStatus(Order order, bool isActing) {
    switch (order.status) {
      case 'pending':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: isActing ? null : () => _cancelOrder(order),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  side: BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r)),
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
                onPressed: isActing ? null : () => _confirmOrder(order),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r)),
                  elevation: 0,
                ),
                child: isActing
                    ? SizedBox(
                        width: 20.w,
                        height: 20.h,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
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
        );

      case 'confirmed':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isActing ? null : () => _markPreparing(order),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r)),
              elevation: 0,
            ),
            child: isActing
                ? SizedBox(
                    width: 20.w,
                    height: 20.h,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Commencer la preparation',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        );

      case 'preparing':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isActing ? null : () => _markReady(order),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CD964),
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r)),
              elevation: 0,
            ),
            child: isActing
                ? SizedBox(
                    width: 20.w,
                    height: 20.h,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Commande prete',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        );

      case 'ready':
      case 'picked_up':
        // Pas d'action directe, le rider gere la suite
        return Row(
          children: [
            IconManager.getIcon('info', size: 20.r, color: Colors.grey),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                order.status == 'ready'
                    ? 'En attente du livreur'
                    : 'Le livreur est en route',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  Future<void> _confirmOrder(Order order) async {
    final notifier = ref.read(orderDetailProvider.notifier);
    final success = await notifier.confirm(order.id);
    if (success && mounted) {
      AppToast.showSuccess(context: context, message: 'Commande confirmee');
      ref.read(ordersListProvider.notifier).refresh();
    } else if (mounted) {
      final error = ref.read(orderDetailProvider).actionError;
      AppToast.showError(
          context: context, message: error ?? 'Erreur lors de la confirmation');
    }
  }

  Future<void> _markPreparing(Order order) async {
    final notifier = ref.read(orderDetailProvider.notifier);
    final success = await notifier.markPreparing(order.id);
    if (success && mounted) {
      AppToast.showSuccess(
          context: context, message: 'Preparation lancee - livreur dispatche');
      ref.read(ordersListProvider.notifier).refresh();
    } else if (mounted) {
      final error = ref.read(orderDetailProvider).actionError;
      AppToast.showError(context: context, message: error ?? 'Erreur');
    }
  }

  Future<void> _markReady(Order order) async {
    final notifier = ref.read(orderDetailProvider.notifier);
    final success = await notifier.markReady(order.id);
    if (success && mounted) {
      AppToast.showSuccess(
          context: context, message: 'Commande prete pour collecte');
      ref.read(ordersListProvider.notifier).refresh();
    } else if (mounted) {
      final error = ref.read(orderDetailProvider).actionError;
      AppToast.showError(context: context, message: error ?? 'Erreur');
    }
  }

  Future<void> _cancelOrder(Order order) async {
    final reason = await _showCancelDialog();
    if (reason == null || !mounted) return;

    final notifier = ref.read(orderDetailProvider.notifier);
    final success = await notifier.cancel(order.id, cancelReason: reason);
    if (success && mounted) {
      AppToast.showWarning(context: context, message: 'Commande annulee');
      ref.read(ordersListProvider.notifier).refresh();
      Routes.goBack();
    } else if (mounted) {
      final error = ref.read(orderDetailProvider).actionError;
      AppToast.showError(
          context: context, message: error ?? 'Erreur lors de l\'annulation');
    }
  }

  Future<void> _getOtp() async {
    final notifier = ref.read(orderDetailProvider.notifier);
    final success = await notifier.getPickupOtp(widget.orderId);
    if (!success && mounted) {
      final error = ref.read(orderDetailProvider).actionError;
      AppToast.showError(
          context: context, message: error ?? 'Impossible de recuperer l\'OTP');
    }
  }

  Future<void> _resendOtp() async {
    final notifier = ref.read(orderDetailProvider.notifier);
    final success = await notifier.resendPickupOtp(widget.orderId);
    if (success && mounted) {
      AppToast.showSuccess(context: context, message: 'Code OTP renvoye');
    } else if (mounted) {
      final error = ref.read(orderDetailProvider).actionError;
      AppToast.showError(
          context: context, message: error ?? 'Impossible de renvoyer l\'OTP');
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
}
