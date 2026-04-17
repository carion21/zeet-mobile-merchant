import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/core/constants/icons.dart';
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
    final backgroundColor = isDark ? AppColors.darkBackground : Colors.white;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.white;
    final textColor = isDark ? AppColors.darkText : AppColors.text;
    final textLightColor = isDark ? AppColors.darkTextLight : AppColors.textLight;

    final ordersState = ref.watch(ordersListProvider);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(textColor),

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
            // Fallback si pas de statuts charges
            if (statusOptions.isEmpty) ...[
              _buildFilterChip('En attente', 'pending', selectedStatus == 'pending', textColor, textLightColor, isDark),
              SizedBox(width: 8.w),
              _buildFilterChip('Confirmee', 'confirmed', selectedStatus == 'confirmed', textColor, textLightColor, isDark),
              SizedBox(width: 8.w),
              _buildFilterChip('En preparation', 'preparing', selectedStatus == 'preparing', textColor, textLightColor, isDark),
              SizedBox(width: 8.w),
              _buildFilterChip('Prete', 'ready', selectedStatus == 'ready', textColor, textLightColor, isDark),
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
    return InkWell(
      onTap: () {
        ref.read(ordersListProvider.notifier).filterByStatus(statusValue);
      },
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.darkSurface : Colors.grey[100]),
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
            final showActions = order.status == 'pending';
            return _buildOrderCard(
              order,
              surfaceColor,
              textColor,
              textLightColor,
              isDark,
              showActions,
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
    bool showActions,
  ) {
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
            // En-tete
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
                    children: [
                      if (order.items.isNotEmpty) ...[
                        Text(
                          '${order.items.length} article${order.items.length > 1 ? 's' : ''}',
                          style: TextStyle(fontSize: 13.sp, color: textLightColor),
                        ),
                        SizedBox(width: 8.w),
                        Text('', style: TextStyle(color: textLightColor)),
                        SizedBox(width: 8.w),
                      ],
                      Text(timeAgo,
                          style:
                              TextStyle(fontSize: 13.sp, color: textLightColor)),
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
                            Text('Total',
                                style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                    color: textLightColor)),
                            ZeetMoney(
                              amount: order.totalAmount ?? 0,
                              currency: ZeetCurrency.fcfa,
                              style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                  color: textColor),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        // Hiérarchie accept/refuse (quickwin vague 2 §QW3) :
                        // "Accepter" dominant (3/4 de la surface, ElevatedButton),
                        // "Refuser" affaibli (1/4, TextButton rouge tamisé,
                        // sans border) pour éviter les refus accidentels en
                        // coup de feu.
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: ElevatedButton(
                                onPressed: () => _confirmOrder(order),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 12.h),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(8.r)),
                                ),
                                child: Text('Accepter',
                                    style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              flex: 1,
                              child: TextButton(
                                onPressed: () => _cancelOrder(order),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red.shade400,
                                  padding: EdgeInsets.symmetric(vertical: 12.h),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(8.r)),
                                ),
                                child: Text('Refuser',
                                    style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w500)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total',
                            style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                                color: textLightColor)),
                        ZeetMoney(
                          amount: order.totalAmount ?? 0,
                          currency: ZeetCurrency.fcfa,
                          style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: textColor),
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
    HapticFeedback.mediumImpact();
    final notifier = ref.read(orderDetailProvider.notifier);
    final success = await notifier.confirm(order.id);
    if (success && mounted) {
      HapticFeedback.heavyImpact();
      AppToast.showSuccess(context: context, message: 'Commande confirmee');
      ref.read(ordersListProvider.notifier).refresh();
    } else if (mounted) {
      final error = ref.read(orderDetailProvider).actionError;
      AppToast.showError(
          context: context, message: error ?? 'Erreur lors de la confirmation');
    }
  }

  Future<void> _cancelOrder(Order order) async {
    // Haptic de confirmation sur l'intention (quickwin vague 2 §QW5).
    HapticFeedback.mediumImpact();
    final reason = await _showCancelDialog();
    if (reason == null || !mounted) return;

    final notifier = ref.read(orderDetailProvider.notifier);
    final success =
        await notifier.cancel(order.id, cancelReason: reason);
    if (success && mounted) {
      // Succès critique → haptic lourd.
      HapticFeedback.heavyImpact();
      AppToast.showWarning(context: context, message: 'Commande refusee');
      ref.read(ordersListProvider.notifier).refresh();
    } else if (mounted) {
      final error = ref.read(orderDetailProvider).actionError;
      AppToast.showError(
          context: context, message: error ?? 'Erreur lors de l\'annulation');
    }
  }

  Future<String?> _showCancelDialog() async {
    final controller = TextEditingController();
    // Le backend rejette desormais les refus sans raison (400). La modale
    // desactive donc le bouton tant que le champ est vide — feedback visuel
    // au lieu d'un tap silencieux.
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) {
          final trimmed = controller.text.trim();
          final canSubmit = trimmed.isNotEmpty;
          return AlertDialog(
            title: const Text('Refuser la commande'),
            content: TextField(
              controller: controller,
              autofocus: true,
              onChanged: (_) => setLocalState(() {}),
              decoration: const InputDecoration(
                hintText: 'Raison du refus (obligatoire)',
                helperText: 'Le client sera informe de ce motif',
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
                onPressed: canSubmit
                    ? () => Navigator.pop(context, trimmed)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.4),
                  disabledForegroundColor: Colors.white70,
                ),
                child: const Text('Confirmer'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(OrderStatus? status) {
    if (status == null) return const SizedBox.shrink();

    // Utiliser la couleur de l'API ou un fallback
    Color bgColor;
    final colorStr = status.color;
    if (colorStr != null && colorStr.startsWith('#')) {
      try {
        bgColor = Color(
            int.parse(colorStr.replaceFirst('#', '0xFF')));
      } catch (_) {
        bgColor = _fallbackStatusColor(status.value);
      }
    } else {
      bgColor = _fallbackStatusColor(status.value);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6.r),
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
