import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/core/constants/icons.dart';
import 'package:merchant/core/utils/order_status_utils.dart';
import 'package:merchant/core/widgets/cancel_reason_sheet.dart';
import 'package:merchant/core/widgets/preparation_timer.dart';
import 'package:merchant/models/order_model.dart';
import 'package:merchant/providers/orders_provider.dart';
import 'package:merchant/providers/connectivity_provider.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/core/utils/phone_launcher.dart';
import 'package:merchant/services/navigation_service.dart';
import 'package:intl/intl.dart';
import 'package:zeet_ui/zeet_ui.dart';

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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color backgroundColor = scheme.surface;
    final Color surfaceColor = scheme.surface;
    final Color textColor = scheme.onSurface;
    final Color textLightColor = scheme.onSurfaceVariant;
    final Color dividerColor = scheme.outlineVariant;

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
    final isOnline = ref.watch(connectivityStatusProvider).maybeWhen(
      data: (v) => v,
      orElse: () => true,
    );

    switch (detailState.status) {
      case OrderDetailStatus.initial:
      case OrderDetailStatus.loading:
        return Column(
          children: [
            _buildSimpleHeader(textColor),
            const Expanded(
              child: ZeetSkeletonList(itemCount: 4, itemHeight: 96),
            ),
          ],
        );

      case OrderDetailStatus.error:
        // Si offline sans donnees en cache, afficher l'etat offline.
        if (!isOnline) {
          return Column(
            children: [
              _buildSimpleHeader(textColor),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_outlined, size: 48,
                          color: textLightColor),
                      SizedBox(height: 16.h),
                      Text(
                        'Hors ligne',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Verifie ta connexion internet',
                        style: TextStyle(color: textLightColor, fontSize: 14.sp),
                      ),
                      SizedBox(height: 16.h),
                      TextButton.icon(
                        onPressed: () => ref
                            .read(orderDetailProvider.notifier)
                            .load(widget.orderId),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            _buildSimpleHeader(textColor),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48,
                        color: textLightColor),
                    SizedBox(height: 16.h),
                    Text(
                      detailState.errorMessage ?? 'Commande introuvable',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textColor, fontSize: 16.sp),
                    ),
                    SizedBox(height: 16.h),
                    TextButton.icon(
                      onPressed: () => ref
                          .read(orderDetailProvider.notifier)
                          .load(widget.orderId),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Réessayer'),
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
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
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
          // Timer de préparation pour confirmed/preparing — pression
          // positive neuro-UX §2 (issue m-09).
          if (order.status == 'confirmed' || order.status == 'preparing') ...<Widget>[
            SizedBox(height: 12.h),
            Row(
              children: <Widget>[
                Text(
                  'Temps de préparation : ',
                  style: TextStyle(fontSize: 13.sp, color: textLightColor),
                ),
                PreparationTimer(createdAtIso: order.createdAt),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(OrderStatus? status) {
    if (status == null) return const SizedBox.shrink();
    // ZeetStatusChip force couleur + icône + label sémantique. Contraste
    // WCAG AA garanti — lisible en cuisine fluorescente comme en plein soleil.
    // Remplace l'ancien badge texte-seul (ratio 2.3:1) signalé C-01.
    return ZeetStatusChip(
      status: partnerStatusFor(status.value),
      label: status.displayLabel,
      dense: true,
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
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              // Aligné sur le token sémantique ZEET (#10B981), pas la couleur
              // Material iOS #4CD964 historique (issue C-05).
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: IconManager.getIcon('person_outline',
                color: AppColors.success, size: 24.r),
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
                ZeetMoney(
                  amount: itemTotal,
                  currency: ZeetCurrency.fcfa,
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
            color: Theme.of(context).colorScheme.surfaceContainerLow,
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
              ZeetMoney(
                amount: order.totalAmount ?? 0,
                currency: ZeetCurrency.fcfa,
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
        ZeetMoney(
          amount: amount,
          currency: ZeetCurrency.fcfa,
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
              color: Theme.of(context).colorScheme.outlineVariant,
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
                      'Code non encore généré',
                      style: TextStyle(fontSize: 14.sp, color: textLightColor),
                    ),
                    SizedBox(height: 12.h),
                    ZeetButton.primary(
                      label: 'Voir le code OTP',
                      onPressed: () => _getOtp(),
                      icon: Icons.visibility_rounded,
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

    // Action bar overlay bottom — ombre légère tolérée (DS §2 exception
    // "overlay"). Seule ombre résiduelle du projet, volontaire.
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      // Transition fluide entre les CTA (pending → confirmed → preparing →
      // ready) et l'état loading. La clé inclut isActing pour que le swap
      // vers le spinner soit aussi animé.
      child: ZeetStateSwitcher(
        stateKey: '${order.status}|${isActing ? "acting" : "idle"}',
        alignment: Alignment.topCenter,
        child: _buildActionsForStatus(order, isActing),
      ),
    );
  }

  Widget _buildActionsForStatus(Order order, bool isActing) {
    // CTAs `ZeetButton` (size `lg` = 56pt) — règle `zeet-pos-ergonomics` §1 :
    // hit target ≥ 56pt pour actions primaires en cuisine. Remplace les
    // anciens `ElevatedButton`/`OutlinedButton` à ~44pt (issue M-03).
    switch (order.status) {
      case 'pending':
        return Row(
          children: <Widget>[
            Expanded(
              child: ZeetButton(
                label: 'Refuser',
                onPressed: isActing ? null : () => _cancelOrder(order),
                variant: ZeetButtonVariant.secondary,
                size: ZeetButtonSize.lg,
                fullWidth: true,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: ZeetButton.primary(
                label: 'Accepter',
                onPressed: isActing ? null : () => _confirmOrder(order),
                size: ZeetButtonSize.lg,
                fullWidth: true,
                loading: isActing,
              ),
            ),
          ],
        );

      case 'confirmed':
        return ZeetButton.primary(
          label: 'Commencer la préparation',
          onPressed: isActing ? null : () => _markPreparing(order),
          size: ZeetButtonSize.lg,
          fullWidth: true,
          loading: isActing,
          icon: Icons.restaurant_rounded,
        );

      case 'preparing':
        return ZeetButton(
          label: 'Commande prête',
          onPressed: isActing ? null : () => _markReady(order),
          variant: ZeetButtonVariant.success,
          size: ZeetButtonSize.lg,
          fullWidth: true,
          loading: isActing,
          icon: Icons.check_circle_rounded,
        );

      case 'ready':
      case 'picked_up':
        // Pas d'action directe, le rider gère la suite. Info claire
        // plutôt qu'un CTA qui ne ferait rien (anti-pattern POS).
        return Row(
          children: <Widget>[
            IconManager.getIcon('info', size: 20.r, color: AppColors.textLight),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                order.status == 'ready'
                    ? 'En attente du livreur'
                    : 'Le livreur est en route',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppColors.textLight,
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
    // Haptics propagés (quickwin vague 2 §QW5) : confirmation sur tap,
    // succès lourd sur validation backend.
    HapticFeedback.mediumImpact();
    final notifier = ref.read(orderDetailProvider.notifier);
    final success = await notifier.confirm(order.id);
    if (success && mounted) {
      HapticFeedback.heavyImpact();
      AppToast.showSuccess(context: context, message: 'Commande confirmée');
      ref.read(ordersListProvider.notifier).refresh();
    } else if (mounted) {
      final error = ref.read(orderDetailProvider).actionError;
      AppToast.showError(
          context: context, message: error ?? 'Erreur lors de la confirmation');
    }
  }

  Future<void> _markPreparing(Order order) async {
    HapticFeedback.mediumImpact();
    final notifier = ref.read(orderDetailProvider.notifier);
    final success = await notifier.markPreparing(order.id);
    if (success && mounted) {
      HapticFeedback.heavyImpact();
      AppToast.showSuccess(
          context: context, message: 'Préparation lancée — un livreur a été assigné');
      ref.read(ordersListProvider.notifier).refresh();
    } else if (mounted) {
      final error = ref.read(orderDetailProvider).actionError;
      AppToast.showError(context: context, message: error ?? 'Erreur');
    }
  }

  Future<void> _markReady(Order order) async {
    HapticFeedback.mediumImpact();
    final notifier = ref.read(orderDetailProvider.notifier);
    final success = await notifier.markReady(order.id);
    if (success && mounted) {
      HapticFeedback.heavyImpact();
      AppToast.showSuccess(
          context: context, message: 'Commande prête pour collecte');
      ref.read(ordersListProvider.notifier).refresh();
    } else if (mounted) {
      final error = ref.read(orderDetailProvider).actionError;
      AppToast.showError(context: context, message: error ?? 'Erreur');
    }
  }

  Future<void> _cancelOrder(Order order) async {
    HapticFeedback.mediumImpact();
    // Bottom sheet chips presets — évite la saisie clavier en cuisine
    // (issue C-02 de l'audit, règle zeet-pos-ergonomics §3).
    final reason = await showCancelReasonSheet(context);
    if (reason == null || !mounted) return;

    final notifier = ref.read(orderDetailProvider.notifier);
    final success = await notifier.cancel(order.id, cancelReason: reason);
    if (success && mounted) {
      HapticFeedback.heavyImpact();
      AppToast.showWarning(context: context, message: 'Commande annulée');
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

}
