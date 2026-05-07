import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/core/constants/icons.dart';
import 'package:merchant/core/widgets/cancel_reason_sheet.dart';
import 'package:merchant/core/widgets/preparation_timer.dart';
import 'package:merchant/models/order_model.dart';
import 'package:merchant/providers/orders_provider.dart';
import 'package:merchant/providers/connectivity_provider.dart';
import 'package:merchant/core/widgets/order_code_text.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/core/utils/phone_launcher.dart';
import 'package:merchant/screens/order_details/widgets/dynamic_action_bar.dart';
import 'package:merchant/screens/order_details/widgets/pickup_otp_fullscreen.dart';
import 'package:merchant/services/navigation_service.dart';
import 'package:intl/intl.dart';
import 'package:zeet_ui/zeet_ui.dart';

class OrderDetailsScreen extends ConsumerStatefulWidget {
  final int orderId;

  /// Si le detail est ouvert depuis un tap sur une notification push, passer
  /// l'identifiant de la notification permet d'envoyer un ACK silent au
  /// backend pour stopper la cascade (Phase 2 gap #1, equivalent du WS ack
  /// utilise par les apps qui ont un canal realtime).
  ///
  /// Idempotent : si l'ACK a deja ete envoye (cf. IncomingOrderProvider.
  /// ackOnView), un second ACK est swallowe par le backend.
  final int? fromNotificationId;

  const OrderDetailsScreen({
    super.key,
    required this.orderId,
    this.fromNotificationId,
  });

  @override
  ConsumerState<OrderDetailsScreen> createState() =>
      _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  /// Trace quelle action est actuellement en flight pour afficher le loader
  /// uniquement sur le bouton concerne (DynamicActionBar.actingKey).
  String? _actingKey;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(orderDetailProvider(widget.orderId).notifier).load(
            widget.orderId,
            fromNotificationId: widget.fromNotificationId,
          );
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

    final detailState = ref.watch(orderDetailProvider(widget.orderId));

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: const ZeetAppBar(title: Text('Commande')),
      body: SafeArea(
        top: false,
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
    final bool isOffline =
        ref.watch(connectivityStatusProvider).maybeWhen(
              data: (bool v) => !v,
              orElse: () => false,
            );

    // Priorite sur le rendu "contenu" : tant qu'on a un order (meme en
    // re-fetch ou en acting), on affiche le detail — ELOE ne doit pas
    // faire flasher l'ecran.
    final bool hasOrder = detailState.order != null;
    final bool isLoading = !hasOrder &&
        (detailState.status == OrderDetailStatus.initial ||
            detailState.status == OrderDetailStatus.loading);
    final Object? error = !hasOrder &&
            detailState.status == OrderDetailStatus.error
        ? (detailState.errorMessage ?? 'Commande introuvable')
        : null;

    // Si on n'a pas encore l'order, on affiche un header simple avec
    // juste le bouton retour — indispensable pour pouvoir sortir de
    // l'ecran d'erreur/offline.
    return ZeetStateBuilder<Order>(
      data: detailState.order,
      isLoading: isLoading,
      error: error,
      isOffline: isOffline && !hasOrder,
      onRetry: () => ref
          .read(orderDetailProvider(widget.orderId).notifier)
          .load(widget.orderId),
      loading: const ZeetSkeletonList(itemCount: 4, itemHeight: 96),
      errorBuilder: (Object err, VoidCallback? retry) =>
          ZeetErrorState.fromError(err, onRetry: retry),
      offlineBuilder: (VoidCallback? retry) => ZeetErrorState(
        kind: ZeetErrorKind.network,
        onRetry: retry,
      ),
      builder: (Order order) => _buildOrderDetail(
        order,
        detailState,
        surfaceColor,
        textColor,
        textLightColor,
        dividerColor,
        isDark,
      ),
    );
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
        // Contenu scrollable
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 12.h),
                _buildCodeLine(order, textLightColor, dateFormat),
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

                // OTP pickup — section compacte qui invite a ouvrir le
                // plein ecran. Le code geant est affiche dans
                // `PickupOtpFullscreen` (Phase 2 gap #2 : 1m readability).
                if (order.status == 'ready' || order.status == 'picked_up') ...[
                  Divider(color: dividerColor, height: 32.h),
                  _buildPickupOtpTeaser(
                    order,
                    detailState,
                    textColor,
                    textLightColor,
                    surfaceColor,
                  ),
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

  /// Ligne code (copiable 1 tap) + date, compacte, sous l'AppBar.
  Widget _buildCodeLine(
      Order order, Color textLightColor, DateFormat dateFormat) {
    String formattedDate = '';
    if (order.createdAt != null) {
      try {
        formattedDate = dateFormat.format(DateTime.parse(order.createdAt!));
      } catch (_) {
        formattedDate = order.createdAt ?? '';
      }
    }
    final String code = order.code ?? '#${order.id}';

    return Row(
      children: <Widget>[
        Flexible(child: _HeaderCodeButton(code: code)),
        if (formattedDate.isNotEmpty) ...<Widget>[
          SizedBox(width: 12.w),
          Text(
            formattedDate,
            style: TextStyle(fontSize: 12.sp, color: textLightColor),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusSection(Order order, Color textColor, Color textLightColor,
      Color surfaceColor, bool isDark) {
    // Status strip pleine largeur, cohérent avec la card de liste.
    // Glance-first (POS §6) : le statut est la première info scannable.
    // La flex sur label + timer évite tout overflow quand le statut a un
    // label long ("En préparation") combiné à un timer (>20 min).
    //
    // Couleur authoritative depuis `last_order_status.color` backend.
    final Color stripColor =
        order.orderStatus?.colorValue ?? ZeetColors.inkMuted;
    final bool isOngoing =
        order.status == 'confirmed' || order.status == 'preparing';
    final String? rawLabel = order.orderStatus?.displayLabel;
    final String statusLabel = (rawLabel != null && rawLabel.trim().isNotEmpty)
        ? rawLabel
        : _fallbackStatusLabel(order.status);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: stripColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border(
          left: BorderSide(color: stripColor, width: 3),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      child: Row(
        children: <Widget>[
          Container(
            width: 8.w,
            height: 8.w,
            decoration: BoxDecoration(
              color: stripColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 10.w),
          Flexible(
            child: Text(
              statusLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: stripColor,
                letterSpacing: 0.2,
              ),
            ),
          ),
          if (isOngoing) ...<Widget>[
            SizedBox(width: 12.w),
            PreparationTimer(createdAtIso: order.createdAt, dense: true),
          ],
        ],
      ),
    );
  }

  String _fallbackStatusLabel(String? value) {
    // Normalise aussi la chaine vide en "inconnu" — le backend peut
    // renvoyer un `status: ""` ou un `last_order_status` null pour des
    // commandes freshly created : sans cette garde, la chip affichait
    // juste le dot + aucun label (issue visuelle sur detail partner).
    if (value == null || value.trim().isEmpty) return 'Statut inconnu';
    switch (value) {
      case 'pending':
        return 'En attente';
      case 'confirmed':
      case 'payment-accepted':
        return 'Confirmée';
      case 'preparing':
        return 'En préparation';
      case 'ready':
        return 'Prête';
      case 'picked_up':
      case 'on-the-way':
        return 'En livraison';
      case 'delivered':
        return 'Livrée';
      case 'cancelled':
        return 'Annulée';
      case 'rejected':
        return 'Refusée';
      default:
        return value;
    }
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
                ZeetHaptics.tap();
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

  /// Résumé financier **orienté partenaire** : ce qui compte pour le
  /// restaurateur, c'est ce qu'il touche, pas les frais de livraison que
  /// ZEET facture au client. On masque donc `deliveryFee`, `totalAmount`
  /// (payé par le client) et `paymentMethod` (transparent côté partenaire,
  /// payé par ZEET via wallet).
  ///
  /// Net partenaire = `netAmount` si fourni par l'API, sinon calculé
  /// localement : `subtotal - discount - commission`.
  Widget _buildSummarySection(Order order, Color textColor,
      Color textLightColor, NumberFormat currencyFormat, bool isDark) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    // Net touché par le partenaire. Source de vérité : `net_amount` backend
    // si disponible, sinon fallback calculé.
    final double? netToPartner = order.netAmount ??
        _computeNetAmount(
          subtotal: order.subtotal,
          discount: order.discount,
          commission: order.commission,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Rémunération',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        SizedBox(height: 16.h),
        if (order.subtotal != null) ...<Widget>[
          _buildPriceRow('Sous-total articles', order.subtotal!, textColor,
              textLightColor, currencyFormat),
          SizedBox(height: 8.h),
        ],
        if (order.discount != null && order.discount! > 0) ...<Widget>[
          _buildPriceRow('Réduction', -order.discount!, textColor,
              textLightColor, currencyFormat),
          SizedBox(height: 8.h),
        ],
        if (order.commission != null && order.commission! > 0) ...<Widget>[
          _buildPriceRow('Commission ZEET', -order.commission!, textColor,
              textLightColor, currencyFormat),
          SizedBox(height: 8.h),
        ],
        SizedBox(height: 8.h),
        // Card "Net partenaire" — la seule ligne qui importe côté POS.
        // Mise en avant couleur primary pour hiérarchie visuelle forte.
        if (netToPartner != null)
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Vous touchez',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Crédité sur votre portefeuille',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: textLightColor,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: ZeetMoney(
                      amount: netToPartner,
                      currency: ZeetCurrency.fcfa,
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          // Fallback rare : si on n'a ni netAmount ni subtotal/commission,
          // on affiche le total payé par le client comme référence.
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Total commande',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                SizedBox(width: 8.w),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: ZeetMoney(
                      amount: order.totalAmount ?? 0,
                      currency: ZeetCurrency.fcfa,
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Calcule le montant net du partenaire si le backend ne le fournit pas.
  /// Retourne `null` si on n'a pas assez d'infos pour être fiable (on
  /// préfère masquer plutôt qu'afficher une valeur fausse).
  double? _computeNetAmount({
    required double? subtotal,
    required double? discount,
    required double? commission,
  }) {
    if (subtotal == null) return null;
    double net = subtotal;
    if (discount != null && discount > 0) net -= discount;
    if (commission != null && commission > 0) net -= commission;
    return net < 0 ? 0 : net;
  }

  Widget _buildPriceRow(String label, double amount, Color textColor,
      Color textLightColor, NumberFormat currencyFormat) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15.sp, color: textLightColor),
          ),
        ),
        SizedBox(width: 8.w),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: ZeetMoney(
              amount: amount,
              currency: ZeetCurrency.fcfa,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
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

  /// Teaser compact : invite a ouvrir l'ecran plein ecran ou affiche un
  /// preview discret du code si deja recupere. Le focus est sur le CTA
  /// "Afficher en grand" — la lisibilite a 1m est dans
  /// `PickupOtpFullscreen` (Phase 2 gap #2).
  Widget _buildPickupOtpTeaser(
    Order order,
    OrderDetailState detailState,
    Color textColor,
    Color textLightColor,
    Color surfaceColor,
  ) {
    final otp = detailState.pickupOtp?.otp;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Code de collecte',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        SizedBox(height: 12.h),
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: <Widget>[
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  Icons.vpn_key_outlined,
                  color: AppColors.primary,
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      otp != null
                          ? 'Code disponible — tapez pour l\'afficher en grand'
                          : 'Le code est genere automatiquement.',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: textLightColor,
                        height: 1.3,
                      ),
                    ),
                    if (otp != null) ...<Widget>[
                      SizedBox(height: 4.h),
                      Text(
                        otp,
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: 4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        ZeetButton.primary(
          label: 'Afficher le code en grand',
          icon: Icons.fullscreen_rounded,
          size: ZeetButtonSize.lg,
          fullWidth: true,
          onPressed: () => _showPickupOtpFullscreen(order),
        ),
      ],
    );
  }

  /// Section "Historique" d'une commande :
  ///
  /// 1. Card "Vos performances" — UNIQUEMENT les durees que le partner
  ///    controle (acceptation + preparation). On omet volontairement
  ///    `pickup_wait`, `transit` et `total` — ce sont des metriques rider,
  ///    pas des performances partner, les afficher ici brouillerait la
  ///    lecture.
  /// 2. Timeline verticale : dot colore depuis `order_status.color`
  ///    backend (jamais de mapping cote Flutter, cf. feedback
  ///    `status_colors_from_core`), label + heure a droite, observation
  ///    en ligne secondaire si presente (hors strings techniques
  ///    "Synced from delivery → ...").
  ///
  /// Motion : volontairement statique — budget POS partner ≤ 200ms,
  /// zero animation decorative sur un ecran de flux operationnel.
  Widget _buildLogsSection(
      Order order, Color textColor, Color textLightColor) {
    final List<OrderLog> logs = List<OrderLog>.from(order.logs)
      ..sort((OrderLog a, OrderLog b) {
        final DateTime? da = _parseLogDate(a.createdAt);
        final DateTime? db = _parseLogDate(b.createdAt);
        if (da != null && db != null) return da.compareTo(db);
        return (a.id ?? 0).compareTo(b.id ?? 0);
      });
    final OrderTimings? timings = order.timings;
    final bool showPerf = timings != null &&
        (timings.acceptanceSeconds != null ||
            timings.preparationSeconds != null);
    if (logs.isEmpty && !showPerf) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showPerf) ...<Widget>[
          Text(
            'Vos performances',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          SizedBox(height: 12.h),
          _buildPartnerPerformance(timings, textColor, textLightColor),
          SizedBox(height: 24.h),
        ],
        if (logs.isNotEmpty) ...<Widget>[
          Text(
            'Historique',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          SizedBox(height: 12.h),
          ...List<Widget>.generate(logs.length, (int i) {
            return _buildLogEntry(
              logs[i],
              textColor,
              textLightColor,
              isLast: i == logs.length - 1,
              showConnector: i < logs.length - 1,
            );
          }),
        ],
      ],
    );
  }

  /// Une entree de timeline : dot colore + label + heure + observation
  /// optionnelle. Quand `showConnector` est vrai, une ligne verticale
  /// prolonge le dot vers l'entree suivante (rail continu).
  Widget _buildLogEntry(
    OrderLog log,
    Color textColor,
    Color textLightColor, {
    required bool isLast,
    required bool showConnector,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color statusColor = log.orderStatus?.colorValue ?? scheme.outline;
    final String rawLabel = log.orderStatus?.displayLabel ?? '';
    final String label = rawLabel.trim().isNotEmpty
        ? rawLabel
        : _fallbackStatusLabel(log.orderStatus?.value);
    final String? observation = _cleanLogObservation(log.observation);
    final String timeLabel = _formatLogTime(log.createdAt);
    final double dotSize = isLast ? 14.w : 10.w;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 18.w,
            child: Column(
              children: <Widget>[
                SizedBox(height: 4.h),
                Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: isLast
                        ? Border.all(
                            color: statusColor.withValues(alpha: 0.22),
                            width: 3,
                          )
                        : null,
                  ),
                ),
                if (showConnector)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: EdgeInsets.symmetric(vertical: 2.h),
                      color: scheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: 2.h,
                bottom: showConnector ? 14.h : 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight:
                                isLast ? FontWeight.w700 : FontWeight.w600,
                            color: isLast ? statusColor : textColor,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                      if (timeLabel.isNotEmpty) ...<Widget>[
                        SizedBox(width: 8.w),
                        Text(
                          timeLabel,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: textLightColor,
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (observation != null) ...<Widget>[
                    SizedBox(height: 3.h),
                    Text(
                      observation,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: textLightColor,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Card "Vos performances" — 2 tuiles cote a cote :
  /// - **Acceptation** (`pending → confirmed`) : votre reactivite a
  ///   prendre la commande.
  /// - **Preparation** (`confirmed → ready-for-delivery`) : votre
  ///   efficacite en cuisine.
  ///
  /// Uniquement ces deux metriques car ce sont les SEULES que le partner
  /// maitrise reellement. Attente livreur + trajet dependent du rider,
  /// total est pollue par ces deux phases — les afficher ici ferait
  /// porter au partner une responsabilite qui n'est pas la sienne.
  ///
  /// Si une seule des deux metriques est dispo (commande en cours), la
  /// tuile unique prend toute la largeur.
  Widget _buildPartnerPerformance(
    OrderTimings t,
    Color textColor,
    Color textLightColor,
  ) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<_PerfTile> tiles = <_PerfTile>[
      if (t.acceptanceSeconds != null)
        _PerfTile(
          label: 'Acceptation',
          value: _formatDuration(t.acceptanceSeconds!),
          caption: 'Délai avant confirmation',
        ),
      if (t.preparationSeconds != null)
        _PerfTile(
          label: 'Préparation',
          value: _formatDuration(t.preparationSeconds!),
          caption: 'Temps en cuisine',
        ),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < tiles.length; i++) ...<Widget>[
              Expanded(
                child: _buildPerfTile(tiles[i], textColor, textLightColor),
              ),
              if (i < tiles.length - 1)
                Container(
                  width: 1,
                  color: scheme.outlineVariant,
                  margin: EdgeInsets.symmetric(horizontal: 12.w),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPerfTile(
    _PerfTile tile,
    Color textColor,
    Color textLightColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          tile.label,
          style: TextStyle(
            fontSize: 12.sp,
            color: textLightColor,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: 6.h),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            tile.value,
            style: TextStyle(
              fontSize: 24.sp,
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              height: 1.0,
              letterSpacing: -0.3,
              fontFeatures: const <FontFeature>[
                FontFeature.tabularFigures(),
              ],
            ),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          tile.caption,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.sp,
            color: textLightColor,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  /// Filtre les observations de plumbing backend (ex.
  /// `"Synced from delivery → on-the-way"`) qui n'ont aucune valeur
  /// cote partner et polluent l'historique. Les autres observations
  /// libres sont affichees telles quelles.
  String? _cleanLogObservation(String? raw) {
    if (raw == null) return null;
    final String t = raw.trim();
    if (t.isEmpty) return null;
    if (t.toLowerCase().startsWith('synced from')) return null;
    return t;
  }

  DateTime? _parseLogDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return null;
    }
  }

  /// Heure locale dans un format compact :
  /// - meme jour : `HH:mm`
  /// - sinon meme annee : `dd/MM · HH:mm`
  /// - sinon : `dd/MM/yyyy · HH:mm`
  String _formatLogTime(String? raw) {
    final DateTime? dt = _parseLogDate(raw);
    if (dt == null) return '';
    final DateTime now = DateTime.now();
    final bool sameDay =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (sameDay) {
      return DateFormat('HH:mm', 'fr_FR').format(dt);
    }
    final String pattern =
        dt.year == now.year ? 'dd/MM · HH:mm' : 'dd/MM/yyyy · HH:mm';
    return DateFormat(pattern, 'fr_FR').format(dt);
  }

  /// Formate une duree en secondes en copy partner (sobre, FR) :
  /// - `< 60 s` : `"12 s"`
  /// - `< 1 h`  : `"13 min"` ou `"13 min 46 s"` (omet `0 s`)
  /// - `≥ 1 h`  : `"1 h"` ou `"1 h 15 min"` (omet `0 min`)
  ///
  /// Valeurs negatives → absolues (tolerance aux horloges desync).
  String _formatDuration(int seconds) {
    final int s = seconds < 0 ? -seconds : seconds;
    if (s < 60) return '$s s';
    final int minutes = s ~/ 60;
    final int remSec = s % 60;
    if (minutes < 60) {
      if (remSec == 0) return '$minutes min';
      return '$minutes min $remSec s';
    }
    final int hours = minutes ~/ 60;
    final int remMin = minutes % 60;
    if (remMin == 0) return '$hours h';
    return '$hours h $remMin min';
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
    final actions = detailState.actions;
    final actionsStatus = detailState.actionsStatus;

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
        stateKey: '${order.status}|${isActing ? "acting" : "idle"}|${actions.length}',
        alignment: Alignment.topCenter,
        // Phase 2 gap #4 : action bar generee depuis `/orders/actions`,
        // plus de mapping hardcode statut → boutons.
        child: _buildDynamicActionsOrFallback(
          order,
          actions,
          actionsStatus,
          isActing,
        ),
      ),
    );
  }

  /// Si le backend a renvoye des actions, on les utilise via
  /// [DynamicActionBar]. Sinon, fallback informationnel pour les statuts
  /// terminaux ou sans action.
  Widget _buildDynamicActionsOrFallback(
    Order order,
    List<OrderActionItem> actions,
    OrderActionsStatus actionsStatus,
    bool isActing,
  ) {
    // Etats sans CTA cote partner : on affiche une ligne d'info plutot
    // qu'un bouton mort (anti-pattern POS).
    final status = order.status;
    if ((status == 'ready' ||
            status == 'picked_up' ||
            status == 'on-the-way') &&
        actions.where((a) => !_isInfoOnly(a.key)).isEmpty) {
      return _buildPassiveInfo(order);
    }

    // Si le fetch a echoue (actionsStatus = error) et qu'on n'a aucune
    // action, on affiche aussi l'info passive plutot qu'un blanc.
    if (actions.isEmpty && actionsStatus == OrderActionsStatus.error) {
      return _buildPassiveInfo(order);
    }

    return DynamicActionBar(
      actions: actions,
      actionsStatus: actionsStatus,
      isActing: isActing,
      actingKey: _actingKey,
      onAction: (action) => _dispatchAction(order, action),
    );
  }

  bool _isInfoOnly(String key) {
    // view-pickup-otp et resend-pickup-otp sont presents sur ready/on-the-way
    // mais on les expose deja via le teaser OTP — ici on n'affiche pas
    // l'action bar pour les eviter dupliquer.
    return key == 'view-pickup-otp' || key == 'resend-pickup-otp';
  }

  Widget _buildPassiveInfo(Order order) {
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
  }

  /// Dispatch d'une action generee dynamiquement vers le bon handler local.
  /// Source de verite : `OrderActionItem.key` (cf. orders.helpers.ts).
  Future<void> _dispatchAction(Order order, OrderActionItem action) async {
    setState(() => _actingKey = action.key);
    try {
      switch (action.key) {
        case 'confirm':
          await _confirmOrder(order);
          break;
        case 'preparing':
          await _markPreparing(order);
          break;
        case 'ready':
          await _markReady(order);
          break;
        case 'cancel':
          await _cancelOrder(order);
          break;
        case 'view-pickup-otp':
          _showPickupOtpFullscreen(order);
          break;
        case 'resend-pickup-otp':
          await _resendOtp();
          break;
        default:
          debugPrint('[OrderDetails] unknown action key: ${action.key}');
      }
    } finally {
      if (mounted) setState(() => _actingKey = null);
    }
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  Future<void> _confirmOrder(Order order) async {
    // Haptics propagés (quickwin vague 2 §QW5) : confirmation sur tap,
    // succès lourd sur validation backend.
    ZeetHaptics.warning();
    final notifier = ref.read(orderDetailProvider(order.id).notifier);
    final success = await notifier.confirm(order.id);
    if (success && mounted) {
      ZeetHaptics.heavy();
      AppToast.showSuccess(context: context, message: 'Commande confirmée');
      ref.read(ordersListProvider.notifier).refresh();
    } else if (mounted) {
      final error = ref.read(orderDetailProvider(order.id)).actionError;
      AppToast.showError(
          context: context, message: error ?? 'Erreur lors de la confirmation');
    }
  }

  Future<void> _markPreparing(Order order) async {
    ZeetHaptics.warning();
    final notifier = ref.read(orderDetailProvider(order.id).notifier);
    final success = await notifier.markPreparing(order.id);
    if (success && mounted) {
      ZeetHaptics.heavy();
      AppToast.showSuccess(
          context: context, message: 'Préparation lancée — un livreur a été assigné');
      ref.read(ordersListProvider.notifier).refresh();
    } else if (mounted) {
      final error = ref.read(orderDetailProvider(order.id)).actionError;
      AppToast.showError(context: context, message: error ?? 'Erreur');
    }
  }

  Future<void> _markReady(Order order) async {
    ZeetHaptics.warning();
    final notifier = ref.read(orderDetailProvider(order.id).notifier);
    final success = await notifier.markReady(order.id);
    if (success && mounted) {
      ZeetHaptics.heavy();
      AppToast.showSuccess(
          context: context, message: 'Commande prête pour collecte');
      ref.read(ordersListProvider.notifier).refresh();
    } else if (mounted) {
      final error = ref.read(orderDetailProvider(order.id)).actionError;
      AppToast.showError(context: context, message: error ?? 'Erreur');
    }
  }

  Future<void> _cancelOrder(Order order) async {
    ZeetHaptics.warning();
    // Bottom sheet chips presets — évite la saisie clavier en cuisine
    // (issue C-02 de l'audit, règle zeet-pos-ergonomics §3).
    final reason = await showCancelReasonSheet(context);
    if (reason == null || !mounted) return;

    final notifier = ref.read(orderDetailProvider(order.id).notifier);
    final success = await notifier.cancel(order.id, cancelReason: reason);
    if (success && mounted) {
      ZeetHaptics.heavy();
      AppToast.showWarning(context: context, message: 'Commande annulée');
      ref.read(ordersListProvider.notifier).refresh();
      Routes.goBack();
    } else if (mounted) {
      final error = ref.read(orderDetailProvider(order.id)).actionError;
      AppToast.showError(
          context: context, message: error ?? 'Erreur lors de l\'annulation');
    }
  }

  Future<void> _resendOtp() async {
    ZeetHaptics.warning();
    final notifier = ref.read(orderDetailProvider(widget.orderId).notifier);
    final success = await notifier.resendPickupOtp(widget.orderId);
    if (success && mounted) {
      ZeetHaptics.success();
      AppToast.showSuccess(
        context: context,
        message: 'Nouveau code envoye au livreur.',
      );
    } else if (mounted) {
      final error = ref.read(orderDetailProvider(widget.orderId)).actionError;
      AppToast.showWarning(
        context: context,
        message: error ?? 'Renvoi impossible. Reessayez plus tard.',
      );
    }
  }

  /// Pousse l'ecran plein ecran d'affichage du code OTP. Le widget se charge
  /// du fetch initial si pas encore en state, du TTS et du cooldown.
  /// Phase 2 gap #2 : OTP lisible a 1m de distance.
  void _showPickupOtpFullscreen(Order order) {
    ZeetHaptics.tap();
    Routes.push(
      PickupOtpFullscreen(
        orderId: widget.orderId,
        orderCode: order.code,
      ),
    );
  }
}

/// Bouton code commande dans le header — prominent, monospace, tap pour
/// copier dans le presse-papier. Version "détails" : plus grande et plus
/// visible que la chip de la liste, avec icône de copie explicite.
///
/// Le code commande est la référence universelle que le partenaire utilise
/// pour communiquer (support, WhatsApp, téléphone). Le rendre copiable en
/// 1 tap depuis le header est un gain de plusieurs secondes par incident.
class _HeaderCodeButton extends StatelessWidget {
  const _HeaderCodeButton({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    // Header détail : le bouton partage sa ligne avec la date formatée
    // ("21 avr. 2026 · 14h32"). `OrderCodeText` affiche le code complet
    // tant que ça rentre, sinon `#…<9 derniers>`. Le tap copie le code
    // COMPLET pour le support, quelle que soit la forme affichée.
    return Semantics(
      button: true,
      label: 'Code commande $code, toucher pour copier',
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(8.r),
          onTap: () async {
            ZeetHaptics.success();
            await Clipboard.setData(ClipboardData(text: code));
            if (!context.mounted) return;
            AppToast.showSuccess(
              context: context,
              message: 'Code $code copié',
            );
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: OrderCodeText(
                    code: code,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                      letterSpacing: 0.3,
                      fontFamily: 'monospace',
                      fontFamilyFallback: const <String>['Menlo', 'Consolas'],
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(
                  Icons.content_copy_rounded,
                  size: 14.r,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Donnees d'une tuile de la card "Vos performances" (`_buildPerfTile`).
class _PerfTile {
  const _PerfTile({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;
}
