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
import 'package:zeet_ui/zeet_ui.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Charger les commandes au demarrage
    Future.microtask(() {
      ref.read(ordersListProvider.notifier).load();
    });

    // Pagination infinie
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(ordersListProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color backgroundColor = scheme.surface;
    final Color surfaceColor = scheme.surface;
    final Color textColor = scheme.onSurface;
    final Color textLightColor = scheme.onSurfaceVariant;

    final ordersState = ref.watch(ordersListProvider);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: const ZeetAppBar(title: Text('Mes commandes')),
      body: Column(
        children: [
          // Filtres horizontaux
          _buildFilters(textColor, textLightColor, isDark, ordersState),

          // Contenu
          Expanded(
            child: _buildContent(
              ordersState,
              surfaceColor,
              textColor,
              textLightColor,
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(Color textColor, Color textLightColor, bool isDark, OrdersListState ordersState) {
    final selectedStatus = ordersState.selectedStatus;
    final statusOptions = ordersState.statusOptions;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Row(
          children: [
            _buildFilterChip(
              'Toutes',
              null,
              selectedStatus == null,
              textColor,
              textLightColor,
              isDark,
            ),
            SizedBox(width: 8.w),
            // Generer les chips depuis les statuts API
            ...statusOptions.map((option) {
              final count = ordersState.counts?.get(option.value ?? '') ?? 0;
              final label = count > 0
                  ? '${option.label ?? option.value} ($count)'
                  : option.label ?? option.value ?? '';
              return Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: _buildFilterChip(
                  label,
                  option.value,
                  selectedStatus == option.value,
                  textColor,
                  textLightColor,
                  isDark,
                ),
              );
            }),
            // Fallback si pas de statuts chargés
            if (statusOptions.isEmpty) ...[
              _buildFilterChip('En attente', 'pending', selectedStatus == 'pending', textColor, textLightColor, isDark),
              SizedBox(width: 8.w),
              _buildFilterChip('Confirmée', 'confirmed', selectedStatus == 'confirmed', textColor, textLightColor, isDark),
              SizedBox(width: 8.w),
              _buildFilterChip('En préparation', 'preparing', selectedStatus == 'preparing', textColor, textLightColor, isDark),
              SizedBox(width: 8.w),
              _buildFilterChip('Prête', 'ready', selectedStatus == 'ready', textColor, textLightColor, isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String? statusValue,
    bool isSelected,
    Color textColor,
    Color textLightColor,
    bool isDark,
  ) {
    // Chip pilule (ZeetRadius.pill = 999). Aligne le style sur
    // wallet/_FilterChip pour cohérence inter-surface.
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: isSelected ? AppColors.primary : scheme.surfaceContainerLow,
      borderRadius: const BorderRadius.all(Radius.circular(ZeetRadius.pill)),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(ZeetRadius.pill)),
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(ordersListProvider.notifier).filterByStatus(statusValue);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 40, minWidth: 72),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : textColor,
              fontSize: 13.sp,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    OrdersListState ordersState,
    Color surfaceColor,
    Color textColor,
    Color textLightColor,
    bool isDark,
  ) {
    final isOnline = ref.watch(connectivityStatusProvider).maybeWhen(
      data: (v) => v,
      orElse: () => true,
    );

    final ZeetScreenState screenState = _resolveState(ordersState, isOnline);
    final String? filter = ordersState.selectedStatus;

    // Micro-copy contextualisée : si un filtre est actif, on le dit, sinon
    // on reste dans le ton partner (direct, efficace, opérationnel).
    final (String emptyTitle, String emptySubtitle) = filter != null
        ? (
            'Aucune commande "$filter"',
            'Les commandes avec ce statut apparaîtront ici',
          )
        : (
            'Aucune commande',
            'Les nouvelles commandes arriveront ici',
          );

    return RefreshIndicator(
      onRefresh: () => ref.read(ordersListProvider.notifier).refresh(),
      child: ZeetScreenScaffold(
        state: screenState,
        onRetry: () => ref.read(ordersListProvider.notifier).load(),
        emptyTitle: emptyTitle,
        emptySubtitle: emptySubtitle,
        emptyIcon: Icons.shopping_bag_outlined,
        errorMessage: ordersState.errorMessage,
        child: ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          itemCount: ordersState.orders.length +
              (ordersState.status == OrdersListStatus.loadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= ordersState.orders.length) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(16.h),
                  child: const CircularProgressIndicator(),
                ),
              );
            }
            final order = ordersState.orders[index];
            return _buildOrderCard(
              order,
              surfaceColor,
              textColor,
              textLightColor,
              isDark,
            );
          },
        ),
      ),
    );
  }

  /// Résout l'état ELOE depuis le [OrdersListState] merchant.
  ZeetScreenState _resolveState(OrdersListState state, bool isOnline) {
    switch (state.status) {
      case OrdersListStatus.initial:
      case OrdersListStatus.loading:
        return ZeetScreenState.loading;
      case OrdersListStatus.error:
        if (!isOnline) return ZeetScreenState.offline;
        return ZeetScreenState.error;
      case OrdersListStatus.loaded:
      case OrdersListStatus.loadingMore:
        if (state.orders.isEmpty) return ZeetScreenState.empty;
        return ZeetScreenState.content;
    }
  }

  Widget _buildOrderCard(
    Order order,
    Color surfaceColor,
    Color textColor,
    Color textLightColor,
    bool isDark,
  ) {
    final timeAgo = _getTimeAgo(order.createdAt);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Widget? inlineActions = _buildInlineActionsForStatus(order);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Routes.pushOrderDetails(order.id);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12.r),
          // DS ZEET §2 : pas de BoxShadow sur cards, border à la place.
          border: Border.all(
            color: scheme.outlineVariant,
            width: 1,
          ),
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
                        '#${order.code ?? order.id}',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      _buildStatusBadge(order.orderStatus),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      IconManager.getIcon('person_outline',
                          size: 16.r, color: textLightColor),
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
                      if (order.customerPhone.isNotEmpty)
                        IconButton(
                          icon: IconManager.getIcon('phone',
                              size: 20.r, color: AppColors.primary),
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
                  Row(
                    children: <Widget>[
                      if (order.items.isNotEmpty) ...<Widget>[
                        Text(
                          '${order.items.length} article${order.items.length > 1 ? 's' : ''}',
                          style: TextStyle(fontSize: 13.sp, color: textLightColor),
                        ),
                        SizedBox(width: 8.w),
                      ],
                      // Timer neuro-UX quand en préparation, sinon "il y a X min".
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
                            fontSize: 13.sp,
                            color: textLightColor,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Divider
            Divider(
              color: scheme.outlineVariant,
              height: 1,
            ),

            // Pied — total + actions inline selon statut (issue C-04).
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: textLightColor,
                        ),
                      ),
                      ZeetMoney(
                        amount: order.totalAmount ?? 0,
                        currency: ZeetCurrency.fcfa,
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  if (inlineActions != null) ...<Widget>[
                    SizedBox(height: 12.h),
                    inlineActions,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmOrder(Order order) async {
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

  Future<void> _cancelOrder(Order order) async {
    HapticFeedback.mediumImpact();
    // Bottom sheet chips presets (issue C-02 / M-14). Évite la saisie
    // clavier en cuisine.
    final reason = await showCancelReasonSheet(context);
    if (reason == null || !mounted) return;

    final notifier = ref.read(orderDetailProvider.notifier);
    final success =
        await notifier.cancel(order.id, cancelReason: reason);
    if (success && mounted) {
      HapticFeedback.heavyImpact();
      AppToast.showWarning(context: context, message: 'Commande refusée');
      ref.read(ordersListProvider.notifier).refresh();
    } else if (mounted) {
      final error = ref.read(orderDetailProvider).actionError;
      AppToast.showError(
          context: context, message: error ?? 'Erreur lors de l\'annulation');
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
          context: context, message: 'Préparation lancée');
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

  /// Actions inline selon le statut — `null` si aucune action merchant
  /// n'est pertinente. Atteint la règle POS "1-tap" pour transitions
  /// critiques (issue C-04).
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
            SizedBox(width: 8.w),
            Expanded(
              flex: 1,
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

  Widget _buildStatusBadge(OrderStatus? status) {
    if (status == null) return const SizedBox.shrink();
    // ZeetStatusChip garantit contraste WCAG AA + icône + label
    // sémantique (règle `zeet-pos-ergonomics` §6). Remplace l'ancien
    // badge texte-seul à ratio 2.3:1 (issue M-02 15/04).
    return ZeetStatusChip(
      status: partnerStatusFor(status.value),
      label: status.displayLabel,
      dense: true,
    );
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
