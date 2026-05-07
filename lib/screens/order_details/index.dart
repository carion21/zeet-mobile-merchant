// lib/screens/order_details/index.dart
//
// Orchestrateur du detail commande. Selon `order.status`, route vers le
// step layout correspondant (`pending` / `preparing` / `ready` / `terminal`)
// — chaque layout reordonne les sections pour mettre en avant l'info
// critique a l'instant T (skill `zeet-pos-ergonomics` §11).
//
// Sections extraites dans `widgets/` (orderCodeHeader, statusStrip,
// client, items, summary, address, otpTeaser, logs, passiveInfoBar).

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/core/widgets/cancel_reason_sheet.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/models/order_model.dart';
import 'package:merchant/providers/connectivity_provider.dart';
import 'package:merchant/providers/orders_provider.dart';
import 'package:merchant/screens/order_details/steps/pending_layout.dart';
import 'package:merchant/screens/order_details/steps/preparing_layout.dart';
import 'package:merchant/screens/order_details/steps/ready_layout.dart';
import 'package:merchant/screens/order_details/steps/terminal_layout.dart';
import 'package:merchant/screens/order_details/widgets/dynamic_action_bar.dart';
import 'package:merchant/screens/order_details/widgets/passive_info_bar.dart';
import 'package:merchant/screens/order_details/widgets/pickup_otp_fullscreen.dart';
import 'package:merchant/services/navigation_service.dart';
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final OrderDetailState detailState =
        ref.watch(orderDetailProvider(widget.orderId));

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: const ZeetAppBar(title: Text('Commande')),
      body: SafeArea(
        top: false,
        child: _buildBody(detailState, scheme.surface, isDark),
      ),
    );
  }

  Widget _buildBody(
    OrderDetailState detailState,
    Color surfaceColor,
    bool isDark,
  ) {
    final bool isOffline = ref.watch(connectivityStatusProvider).maybeWhen(
          data: (bool v) => !v,
          orElse: () => false,
        );

    final bool hasOrder = detailState.order != null;
    final bool isLoading = !hasOrder &&
        (detailState.status == OrderDetailStatus.initial ||
            detailState.status == OrderDetailStatus.loading);
    final Object? error = !hasOrder &&
            detailState.status == OrderDetailStatus.error
        ? (detailState.errorMessage ?? 'Commande introuvable')
        : null;

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
      builder: (Order order) =>
          _buildOrderDetail(order, detailState, surfaceColor, isDark),
    );
  }

  Widget _buildOrderDetail(
    Order order,
    OrderDetailState detailState,
    Color surfaceColor,
    bool isDark,
  ) {
    return Column(
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            child: _selectStepLayout(order, detailState),
          ),
        ),
        _buildActionBar(order, detailState, surfaceColor, isDark),
      ],
    );
  }

  /// Selection du layout step en fonction du statut courant. Chaque layout
  /// reordonne les sections pour mettre l'info critique en haut.
  Widget _selectStepLayout(Order order, OrderDetailState detailState) {
    switch (order.status) {
      case 'pending':
        return PendingLayout(order: order);
      case 'confirmed':
      case 'payment-accepted':
      case 'preparing':
        return PreparingLayout(order: order);
      case 'ready':
      case 'picked_up':
      case 'on-the-way':
        return ReadyLayout(
          order: order,
          detailState: detailState,
          onTapOtpFullscreen: () => _showPickupOtpFullscreen(order),
        );
      case 'delivered':
      case 'cancelled':
      case 'rejected':
        return TerminalLayout(order: order);
      default:
        return TerminalLayout(order: order);
    }
  }

  Widget _buildActionBar(
    Order order,
    OrderDetailState detailState,
    Color surfaceColor,
    bool isDark,
  ) {
    final bool isActing = detailState.status == OrderDetailStatus.acting;
    final String status = order.status;

    if (status == 'delivered' ||
        status == 'cancelled' ||
        status == 'rejected') {
      return const SizedBox.shrink();
    }

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<OrderActionItem> actions = detailState.actions;
    final OrderActionsStatus actionsStatus = detailState.actionsStatus;

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
      child: ZeetStateSwitcher(
        stateKey:
            '${order.status}|${isActing ? "acting" : "idle"}|${actions.length}',
        alignment: Alignment.topCenter,
        child: _buildDynamicActionsOrFallback(
          order,
          actions,
          actionsStatus,
          isActing,
        ),
      ),
    );
  }

  Widget _buildDynamicActionsOrFallback(
    Order order,
    List<OrderActionItem> actions,
    OrderActionsStatus actionsStatus,
    bool isActing,
  ) {
    final String status = order.status;
    if ((status == 'ready' ||
            status == 'picked_up' ||
            status == 'on-the-way') &&
        actions.where((a) => !_isInfoOnly(a.key)).isEmpty) {
      return PassiveInfoBar(order: order);
    }

    if (actions.isEmpty && actionsStatus == OrderActionsStatus.error) {
      return PassiveInfoBar(order: order);
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
    return key == 'view-pickup-otp' || key == 'resend-pickup-otp';
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

  Future<void> _confirmOrder(Order order) async {
    ZeetHaptics.warning();
    final notifier = ref.read(orderDetailProvider(order.id).notifier);
    final bool success = await notifier.confirm(order.id);
    if (success && mounted) {
      ZeetHaptics.heavy();
      AppToast.showSuccess(context: context, message: 'Commande confirmée');
      ref.read(ordersListProvider.notifier).refresh();
    } else if (mounted) {
      final String? error =
          ref.read(orderDetailProvider(order.id)).actionError;
      AppToast.showError(
        context: context,
        message: error ?? 'Erreur lors de la confirmation',
      );
    }
  }

  Future<void> _markPreparing(Order order) async {
    ZeetHaptics.warning();
    final notifier = ref.read(orderDetailProvider(order.id).notifier);
    final bool success = await notifier.markPreparing(order.id);
    if (success && mounted) {
      ZeetHaptics.heavy();
      AppToast.showSuccess(
        context: context,
        message: 'Préparation lancée — un livreur a été assigné',
      );
      ref.read(ordersListProvider.notifier).refresh();
    } else if (mounted) {
      final String? error =
          ref.read(orderDetailProvider(order.id)).actionError;
      AppToast.showError(context: context, message: error ?? 'Erreur');
    }
  }

  Future<void> _markReady(Order order) async {
    ZeetHaptics.warning();
    final notifier = ref.read(orderDetailProvider(order.id).notifier);
    final bool success = await notifier.markReady(order.id);
    if (success && mounted) {
      ZeetHaptics.heavy();
      AppToast.showSuccess(
        context: context,
        message: 'Commande prête pour collecte',
      );
      ref.read(ordersListProvider.notifier).refresh();
    } else if (mounted) {
      final String? error =
          ref.read(orderDetailProvider(order.id)).actionError;
      AppToast.showError(context: context, message: error ?? 'Erreur');
    }
  }

  Future<void> _cancelOrder(Order order) async {
    ZeetHaptics.warning();
    final String? reason = await showCancelReasonSheet(context);
    if (reason == null || !mounted) return;

    final notifier = ref.read(orderDetailProvider(order.id).notifier);
    final bool success = await notifier.cancel(order.id, cancelReason: reason);
    if (success && mounted) {
      ZeetHaptics.heavy();
      AppToast.showWarning(context: context, message: 'Commande annulée');
      ref.read(ordersListProvider.notifier).refresh();
      Routes.goBack();
    } else if (mounted) {
      final String? error =
          ref.read(orderDetailProvider(order.id)).actionError;
      AppToast.showError(
        context: context,
        message: error ?? 'Erreur lors de l\'annulation',
      );
    }
  }

  Future<void> _resendOtp() async {
    ZeetHaptics.warning();
    final notifier = ref.read(orderDetailProvider(widget.orderId).notifier);
    final bool success = await notifier.resendPickupOtp(widget.orderId);
    if (success && mounted) {
      ZeetHaptics.success();
      AppToast.showSuccess(
        context: context,
        message: 'Nouveau code envoye au livreur.',
      );
    } else if (mounted) {
      final String? error =
          ref.read(orderDetailProvider(widget.orderId)).actionError;
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
