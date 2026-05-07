import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/core/constants/copy.dart';
import 'package:merchant/core/constants/icons.dart';
import 'package:merchant/core/widgets/cancel_reason_sheet.dart';
import 'package:merchant/core/widgets/preparation_timer.dart';
import 'package:merchant/models/order_model.dart';
import 'package:merchant/providers/orders_provider.dart';
import 'package:merchant/providers/connectivity_provider.dart';
import 'package:merchant/core/widgets/order_code_text.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/core/utils/phone_launcher.dart';
import 'package:merchant/services/navigation_service.dart';
import 'package:merchant/services/order_service.dart';
import 'package:zeet_ui/zeet_ui.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _ongoingScrollController = ScrollController();
  final ScrollController _historyScrollController = ScrollController();
  late final TabController _tabController;

  // --- Search state (backend `GET /v1/partner/orders?search=`) ----------
  // Toggled via l'icône search dans l'app bar. Debounce 400ms pour éviter
  // de spammer le backend pendant la frappe. Min 2 caractères avant de
  // déclencher la requête (cohérence avec `Search Orders Autocomplete`).
  bool _searchActive = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _searchDebounce;

  // Selection multi-commandes pour bulk-accept (skill zeet-pos-ergonomics
  // §gesture-grammar). Long-press sur tile pending = entre en selection,
  // tap toggle, action bar bottom = "Confirmer X commandes".
  final Set<int> _selectedIds = <int>{};
  bool get _selectionMode => _selectedIds.isNotEmpty;
  bool _bulkSubmitting = false;

  void _toggleSelection(int orderId) {
    setState(() {
      if (_selectedIds.contains(orderId)) {
        _selectedIds.remove(orderId);
      } else {
        _selectedIds.add(orderId);
      }
    });
    ZeetHaptics.tap();
  }

  void _exitSelection() {
    setState(_selectedIds.clear);
  }

  Future<void> _bulkAccept() async {
    if (_selectedIds.isEmpty) return;
    final List<int> ids = _selectedIds.toList();
    setState(() => _bulkSubmitting = true);
    ZeetHaptics.warning();
    try {
      final result = await OrderService().bulkAcceptOrders(ids);
      if (!mounted) return;
      final int success = (result['success_count'] as int?) ?? 0;
      final int failed = (result['failed_count'] as int?) ?? 0;
      ZeetHaptics.heavy();
      if (failed == 0) {
        AppToast.showSuccess(
          context: context,
          message: '$success commande${success > 1 ? "s" : ""} confirmée${success > 1 ? "s" : ""}',
        );
      } else {
        AppToast.showWarning(
          context: context,
          message: '$success OK · $failed échec${failed > 1 ? "s" : ""}',
        );
      }
      _exitSelection();
      await ref.read(ordersListProvider.notifier).resetAndLoad();
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(
        context: context,
        message: 'Échec bulk-accept : ${e.toString()}',
      );
    } finally {
      if (mounted) setState(() => _bulkSubmitting = false);
    }
  }

  /// Statuts "en cours" côté partner — alignés sur le state machine backend
  /// (cf. `ORDERS_PARTNER_FLOW.md` §8). On inclut aussi les variantes client
  /// (`pending`, `awaiting-payment`, `ready`, `picked_up`) pour rester tolérant
  /// si l'API renvoie un statut côté client. Tout ce qui n'est pas ici tombe
  /// dans "Historique".
  static const Set<String> _ongoingStatuses = <String>{
    'pending',
    'awaiting-payment',
    'payment-accepted',
    'confirmed',
    'preparing',
    'ready',
    'ready-for-delivery',
    'picked_up',
    'on-the-way',
  };

  /// Statuts "terminaux" (historique) renvoyés par le backend partner.
  /// **Attention** : le backend renvoie `canceled` (orthographe US, un seul
  /// 'l') — pas `cancelled`. On garde les deux pour tolérer les 3 surfaces
  /// (partner/admin/client) qui n'ont pas toutes la même convention.
  static const Set<String> _terminalStatuses = <String>{
    'delivered',
    'canceled',
    'cancelled',
    'rejected',
    'failed',
    'refunded',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Reset filter (status + search) + reload. Le split En cours / Historique
    // se fait localement côté écran, donc la liste serveur doit contenir
    // tous les statuts — si un filtre hérité d'une session précédente
    // (ex: deep-link avec `?status=payment-accepted`) persiste dans le
    // provider, le tab "Historique" apparaîtrait vide.
    //
    // addPostFrameCallback > Future.microtask : on est certain que le
    // widget est monté et que les providers sont prêts avant de charger.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(ordersListProvider.notifier).resetAndLoad();
    });

    _ongoingScrollController.addListener(_onScroll);
    _historyScrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _ongoingScrollController.dispose();
    _historyScrollController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _toggleSearch() {
    ZeetHaptics.tap();
    setState(() {
      _searchActive = !_searchActive;
      if (_searchActive) {
        // Focus immédiat pour que le clavier apparaisse sans tap supplémentaire.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _searchFocus.requestFocus(),
        );
      } else {
        // Fermer = reset search serveur + vider le champ.
        _searchController.clear();
        _searchDebounce?.cancel();
        ref.read(ordersListProvider.notifier).searchOrders(null);
      }
    });
  }

  void _onSearchChanged(String value) {
    // Debounce 400ms — évite un hit par keystroke.
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      // < 2 caractères = reset (le backend attend min 2 char pour autocomplete).
      final String trimmed = value.trim();
      ref
          .read(ordersListProvider.notifier)
          .searchOrders(trimmed.length >= 2 ? trimmed : null);
    });
  }

  void _onScroll() {
    // Pagination infinie : n'importe quel tab qui scroll assez bas
    // déclenche loadMore (la liste backend est chronologique).
    final ScrollController ctrl =
        _tabController.index == 0 ? _ongoingScrollController : _historyScrollController;
    if (ctrl.position.pixels >= ctrl.position.maxScrollExtent - 200) {
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

    // Split local En cours / Historique. Les compteurs serveur sont
    // utilisés en priorité pour le label du tab (plus fiables que le
    // count de la page 1 courante, cf. pagination).
    final List<Order> ongoing = ordersState.orders
        .where((Order o) => _ongoingStatuses.contains(o.status))
        .toList();
    final List<Order> history = ordersState.orders
        .where((Order o) => !_ongoingStatuses.contains(o.status))
        .toList();

    // Bucketing direct des compteurs serveur — on itère la map `counts` et
    // on classe chaque clé comme "ongoing" (tout ce qui n'est pas terminal)
    // ou "history" (statuts terminaux). Évite le bug où l'API renvoie
    // `canceled` (un seul 'l') mais `statusOptions` renvoie `cancelled`
    // (double 'l') — la somme retombait à 0. Fallback sur le split local
    // (page courante) si `counts` est null ou vide.
    final (int? srvOngoing, int? srvHistory) = _serverBuckets(ordersState);
    final int ongoingCount = srvOngoing ?? ongoing.length;
    final int historyCount = srvHistory ?? history.length;

    final String? activeQuery = ordersState.search;
    final bool hasActiveQuery = activeQuery != null && activeQuery.isNotEmpty;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: ZeetAppBar(
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Annuler la sélection',
                onPressed: _exitSelection,
              )
            : null,
        title: Text(
          _selectionMode
              ? '${_selectedIds.length} sélectionnée${_selectedIds.length > 1 ? "s" : ""}'
              : 'Mes commandes',
        ),
        actions: <Widget>[
          if (!_selectionMode)
            IconButton(
              tooltip: _searchActive ? 'Fermer la recherche' : 'Rechercher',
              icon: Icon(
                _searchActive ? Icons.close_rounded : Icons.search_rounded,
              ),
              onPressed: _toggleSearch,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(56.h),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: textLightColor,
                labelStyle: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
                unselectedLabelStyle:
                    TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
                onTap: (_) => ZeetHaptics.tap(),
                tabs: <Widget>[
                  Tab(text: 'En cours ($ongoingCount)'),
                  Tab(text: 'Historique ($historyCount)'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: <Widget>[
          // Search panel — s'animé en slide down + fade via AnimatedSize
          // + spring curve (fluency heuristic §F : le motion doux = signal
          // de fiabilité pour l'inconscient). Quand inactif ET sans query
          // active, on ne prend aucune place (height 0).
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: (_searchActive || hasActiveQuery)
                ? _SearchPanel(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    onChanged: _onSearchChanged,
                    active: _searchActive,
                    activeQuery: hasActiveQuery ? activeQuery : null,
                    resultCount: hasActiveQuery ? ordersState.orders.length : null,
                    onClear: () {
                      ZeetHaptics.tap();
                      _searchController.clear();
                      _searchDebounce?.cancel();
                      ref.read(ordersListProvider.notifier).searchOrders(null);
                    },
                  )
                : const SizedBox.shrink(),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                _buildTab(
                  orders: ongoing,
                  ordersState: ordersState,
                  isOngoingTab: true,
                  scrollController: _ongoingScrollController,
                  surfaceColor: surfaceColor,
                  textColor: textColor,
                  textLightColor: textLightColor,
                  isDark: isDark,
                ),
                _buildTab(
                  orders: history,
                  ordersState: ordersState,
                  isOngoingTab: false,
                  scrollController: _historyScrollController,
                  surfaceColor: surfaceColor,
                  textColor: textColor,
                  textLightColor: textLightColor,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _selectionMode
          ? _BulkActionBar(
              selectedCount: _selectedIds.length,
              submitting: _bulkSubmitting,
              onConfirm: _bulkAccept,
            )
          : null,
    );
  }

  /// Bucketise la map `counts` renvoyée par `/counts-by-status` en
  /// (ongoing, history) en itérant toutes les clés présentes — aucune
  /// dépendance sur un set statique de statuts "historiques" côté front.
  ///
  /// Règles :
  /// - Clé dans `_ongoingStatuses` → bucket ongoing.
  /// - Clé dans `_terminalStatuses` → bucket history.
  /// - Clé inconnue → bucket history (par défaut : si on ne sait pas, on
  ///   considère comme terminal pour ne pas mentir sur "en cours").
  ///
  /// Retourne `(null, null)` si `counts` est null OU vide → l'appelant
  /// fallback sur le split local de la page courante.
  (int?, int?) _serverBuckets(OrdersListState state) {
    final counts = state.counts;
    if (counts == null || counts.counts.isEmpty) return (null, null);
    int ongoing = 0;
    int history = 0;
    counts.counts.forEach((String key, int value) {
      if (_ongoingStatuses.contains(key)) {
        ongoing += value;
      } else if (_terminalStatuses.contains(key)) {
        history += value;
      } else {
        history += value;
      }
    });
    return (ongoing, history);
  }

  Widget _buildTab({
    required List<Order> orders,
    required OrdersListState ordersState,
    required bool isOngoingTab,
    required ScrollController scrollController,
    required Color surfaceColor,
    required Color textColor,
    required Color textLightColor,
    required bool isDark,
  }) {
    final isOnline = ref.watch(connectivityStatusProvider).maybeWhen(
      data: (v) => v,
      orElse: () => true,
    );

    final ZeetScreenState screenState = _resolveTabState(
      ordersState: ordersState,
      tabOrders: orders,
      isOnline: isOnline,
    );

    final (String emptyTitle, String emptySubtitle) = isOngoingTab
        ? (
            'Aucune commande en cours',
            'Les nouvelles commandes arriveront ici',
          )
        : (
            'Aucun historique',
            'Les commandes livrées, annulées ou refusées apparaîtront ici',
          );

    final bool showLoadingMore =
        ordersState.status == OrdersListStatus.loadingMore;

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
          controller: scrollController,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: orders.length + (showLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= orders.length) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: const ZeetSkeleton(height: 96),
              );
            }
            return _buildOrderCard(
              orders[index],
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

  /// État ELOE par tab — on considère un tab "empty" seulement si le load
  /// est terminé et que le tab est vide, pas si la liste globale est vide.
  ZeetScreenState _resolveTabState({
    required OrdersListState ordersState,
    required List<Order> tabOrders,
    required bool isOnline,
  }) {
    switch (ordersState.status) {
      case OrdersListStatus.initial:
      case OrdersListStatus.loading:
        return ZeetScreenState.loading;
      case OrdersListStatus.error:
        if (!isOnline) return ZeetScreenState.offline;
        return ZeetScreenState.error;
      case OrdersListStatus.loaded:
      case OrdersListStatus.loadingMore:
        if (tabOrders.isEmpty) return ZeetScreenState.empty;
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
    final String timeAgo = _getTimeAgo(order.createdAt);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Widget? inlineActions = _buildInlineActionsForStatus(order);
    // Couleur authoritative depuis `last_order_status.color` backend.
    // Le dot + bordure + label partagent la meme teinte — le contraste
    // du texte reste lisible sur fond `alpha 0.08` (assure par le core).
    final Color stripColor =
        order.orderStatus?.colorValue ?? ZeetColors.inkMuted;
    final bool isOngoing =
        order.status == 'confirmed' || order.status == 'preparing';
    final String statusLabel =
        order.orderStatus?.displayLabel ?? _fallbackStatusLabel(order.status);
    final String code = order.code ?? '#${order.id}';

    final bool isPending = order.status == 'pending';
    final bool isSelected = _selectedIds.contains(order.id);

    return GestureDetector(
      onTap: () {
        ZeetHaptics.tap();
        if (_selectionMode) {
          // En mode selection : tap toggle uniquement les commandes pending
          // (bulk-accept ne s'applique qu'aux commandes en attente de
          // confirmation). Les autres tiles ne reagissent pas en selection.
          if (isPending) _toggleSelection(order.id);
        } else {
          Routes.pushOrderDetails(order.id);
        }
      },
      onLongPress: isPending ? () => _toggleSelection(order.id) : null,
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.06)
              : surfaceColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : scheme.outlineVariant,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status strip — bandeau teinté, pleine largeur, border-left
            // colorée. Glance-first (règle POS §6) : le statut est la chose
            // la plus scannable avant même de lire le nom du client.
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: stripColor.withValues(alpha: 0.08),
                border: Border(
                  left: BorderSide(color: stripColor, width: 3),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 6.w,
                    height: 6.w,
                    decoration: BoxDecoration(
                      color: stripColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Flexible(
                    child: Text(
                      statusLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: stripColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // Timer neuro-UX pour les ordres en préparation (pression
                  // positive §2) — sinon on affiche le temps relatif.
                  if (isOngoing)
                    PreparationTimer(
                      createdAtIso: order.createdAt,
                      dense: true,
                    )
                  else
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: textLightColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),

            // Corps — avatar client + nom + code (prominent + copy) + appel.
            // Le code est l'élément le plus utilisé hors contexte (support,
            // message WhatsApp, téléphone client). On le rend copiable en
            // 1 tap via _OrderCodeChip (copie presse-papier + haptic + toast).
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: IconManager.getIcon(
                      'person_outline',
                      size: 22.r,
                      color: textLightColor,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          order.customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          children: <Widget>[
                            // Code prominent, monospace, tap-to-copy.
                            Flexible(child: _OrderCodeChip(code: code)),
                            if (order.items.isNotEmpty) ...<Widget>[
                              SizedBox(width: 8.w),
                              Flexible(
                                child: Text(
                                  '${order.items.length} article${order.items.length > 1 ? 's' : ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: textLightColor,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (order.customerPhone.isNotEmpty)
                    SizedBox(
                      width: 44.w,
                      height: 44.w,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: IconManager.getIcon(
                          'phone',
                          size: 22.r,
                          color: AppColors.primary,
                        ),
                        tooltip: 'Appeler ${order.customerPhone}',
                        onPressed: () async {
                          ZeetHaptics.tap();
                          await launchPhoneCall(
                            order.customerPhone,
                            context: context,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            Divider(color: scheme.outlineVariant, height: 1),

            // Pied — total + actions inline selon statut (issue C-04).
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: textLightColor,
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
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
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

  /// Fallback si `orderStatus` objet est null mais qu'on a la string.
  /// Traite `null` ET `''` comme "inconnu" — le backend peut renvoyer
  /// une chaine vide pour des commandes freshly created, sans cette
  /// garde la chip affichait juste le dot sans label.
  String _fallbackStatusLabel(String? value) {
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

  Future<void> _confirmOrder(Order order) async {
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

  Future<void> _cancelOrder(Order order) async {
    ZeetHaptics.warning();
    // Bottom sheet chips presets (issue C-02 / M-14). Évite la saisie
    // clavier en cuisine.
    final reason = await showCancelReasonSheet(context);
    if (reason == null || !mounted) return;

    final notifier = ref.read(orderDetailProvider(order.id).notifier);
    final success =
        await notifier.cancel(order.id, cancelReason: reason);
    if (success && mounted) {
      ZeetHaptics.heavy();
      AppToast.showWarning(context: context, message: 'Commande refusée');
      ref.read(ordersListProvider.notifier).refresh();
    } else if (mounted) {
      final error = ref.read(orderDetailProvider(order.id)).actionError;
      AppToast.showError(
          context: context, message: error ?? 'Erreur lors de l\'annulation');
    }
  }

  Future<void> _markPreparing(Order order) async {
    ZeetHaptics.warning();
    final success = await ref
        .read(orderDetailProvider(order.id).notifier)
        .markPreparing(order.id);
    if (!mounted) return;
    if (success) {
      ZeetHaptics.heavy();
      AppToast.showSuccess(
          context: context, message: 'Préparation lancée');
      ref.read(ordersListProvider.notifier).refresh();
    } else {
      final error = ref.read(orderDetailProvider(order.id)).actionError;
      AppToast.showError(context: context, message: error ?? 'Erreur');
    }
  }

  Future<void> _markReady(Order order) async {
    ZeetHaptics.warning();
    final success = await ref
        .read(orderDetailProvider(order.id).notifier)
        .markReady(order.id);
    if (!mounted) return;
    if (success) {
      ZeetHaptics.heavy();
      AppToast.showSuccess(
        context: context,
        message: 'Commande prête pour collecte',
      );
      ref.read(ordersListProvider.notifier).refresh();
    } else {
      final error = ref.read(orderDetailProvider(order.id)).actionError;
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
                label: Copy.ctaAccept,
                onPressed: () => _confirmOrder(order),
                size: ZeetButtonSize.md,
                fullWidth: true,
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              flex: 1,
              child: ZeetButton.ghost(
                label: Copy.ctaRefuse,
                onPressed: () => _cancelOrder(order),
                size: ZeetButtonSize.md,
              ),
            ),
          ],
        );
      case 'confirmed':
        return ZeetButton.primary(
          label: Copy.ctaPrepare,
          onPressed: () => _markPreparing(order),
          size: ZeetButtonSize.md,
          fullWidth: true,
          icon: Icons.restaurant_rounded,
        );
      case 'preparing':
        return ZeetButton(
          label: Copy.ctaMarkReady,
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

/// Panel de recherche — s'affiche sous les tabs quand l'utilisateur
/// active la recherche OU tant qu'une query est active (Zeigarnik §6 :
/// la tâche "recherche en cours" reste visible avec son état).
///
/// Design :
/// - Pill pleine largeur, primary tint subtil (fluency §F : doux = fiable).
/// - Icône search primary en prefix (Fitts §2 : signal visuel fort).
/// - Bouton clear × en suffix si query non-vide (hit 36pt, POS §1).
/// - Hint humain "Code, client ou téléphone…" (micro-copy partner pro).
/// - Badge "N résultat(s)" si query active (commitment escalation §G :
///   feedback immédiat sur chaque action).
class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.active,
    required this.activeQuery,
    required this.resultCount,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool active;
  final String? activeQuery;
  final int? resultCount;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color textColor = scheme.onSurface;
    final Color textLightColor = scheme.onSurfaceVariant;
    final bool hasQuery = activeQuery != null;

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
      color: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Champ de recherche — pill primary-tinted avec icônes prefix/suffix
          Container(
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primary.withValues(alpha: 0.06)
                  : scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: active
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : scheme.outlineVariant,
                width: active ? 1.5 : 1,
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.search_rounded,
                  size: 20.r,
                  color:
                      active ? AppColors.primary : textLightColor,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: onChanged,
                    textInputAction: TextInputAction.search,
                    autocorrect: false,
                    enableSuggestions: false,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Code, client ou téléphone…',
                      hintStyle: TextStyle(
                        fontSize: 15.sp,
                        color: textLightColor,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 14.h),
                    ),
                  ),
                ),
                // Bouton clear — visible uniquement si query non-vide.
                // ValueListenableBuilder pour réagir aux keystrokes sans
                // rebuild du parent. AnimatedSize = apparition douce (fluency §F).
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (BuildContext context, TextEditingValue value, _) {
                    return AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: value.text.isEmpty
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: EdgeInsets.only(left: 6.w),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18.r),
                                onTap: onClear,
                                child: Padding(
                                  padding: EdgeInsets.all(6.w),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 18.r,
                                    color: textLightColor,
                                  ),
                                ),
                              ),
                            ),
                    );
                  },
                ),
              ],
            ),
          ),

          // État actif persistant — query active = badge filter + compteur
          // live + CTA undo. Un seul Text.rich pour éviter la course entre
          // plusieurs Flexible ; la query peut être longue (UUID, nom
          // composé), maxLines: 2 + ellipsis garantit aucun overflow.
          if (hasQuery) ...<Widget>[
            SizedBox(height: 10.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(top: 2.h),
                  child: Icon(
                    Icons.filter_alt_rounded,
                    size: 14.r,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: _resultsLabel(resultCount),
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        TextSpan(
                          text: ' pour ',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: textLightColor,
                          ),
                        ),
                        TextSpan(
                          text: '"$activeQuery"',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8.w),
                InkWell(
                  borderRadius: BorderRadius.circular(6.r),
                  onTap: onClear,
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    child: Text(
                      'Effacer',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (active) ...<Widget>[
            // État focus sans query : hint micro-copy discret pour guider
            // le partner (charge cognitive §1 : exemples concrets plutôt
            // qu'instructions abstraites). maxLines: 1 ellipsis anti-overflow.
            SizedBox(height: 8.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Text(
                'Ex : ORD-2026, Marie Dupont, 77 123 45 67',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: textLightColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _resultsLabel(int? count) {
    if (count == null) return 'Résultats';
    if (count == 0) return 'Aucun résultat';
    if (count == 1) return '1 résultat';
    return '$count résultats';
  }
}

/// Chip compact, monospace, tappable → copie le code commande dans le
/// presse-papier (haptic + toast confirmation).
///
/// **Pourquoi** : le partner utilise ce code pour communiquer (client,
/// support, chat), souvent sous pression service. Le rendre scannable au
/// premier coup d'œil et copiable en 1 tap économise plusieurs secondes
/// par interaction (règle POS §8 "zéro scroll pour action récurrente").
///
/// Style : `tabularFigures` pour alignement parfait des chiffres, teinte
/// primary subtile (ne concurrence pas le statut), letter-spacing 0.5
/// pour la lisibilité POS.
class _OrderCodeChip extends StatelessWidget {
  const _OrderCodeChip({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    // Le chip partage sa Row avec le nombre d'articles. `OrderCodeText`
    // affiche le code complet si ça rentre, sinon `#…<9 derniers>`. Le tap
    // copie TOUJOURS le code complet pour que le support matche sans
    // ambiguïté, même si le display est raccourci.
    return Semantics(
      button: true,
      label: 'Code commande $code, toucher pour copier',
      child: Material(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(6.r),
          // Stop propagation : le tap ne doit pas ouvrir le détail.
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
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.content_copy_rounded,
                  size: 12.r,
                  color: AppColors.primary,
                ),
                SizedBox(width: 4.w),
                Flexible(
                  child: OrderCodeText(
                    code: code,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                      fontFamily: 'monospace',
                      fontFamilyFallback: const <String>['Menlo', 'Consolas'],
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BulkActionBar extends StatelessWidget {
  const _BulkActionBar({
    required this.selectedCount,
    required this.submitting,
    required this.onConfirm,
  });

  final int selectedCount;
  final bool submitting;
  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            top: BorderSide(color: scheme.outlineVariant, width: 1),
          ),
        ),
        child: ZeetButton.primary(
          label: submitting
              ? 'Confirmation en cours…'
              : 'Confirmer $selectedCount commande${selectedCount > 1 ? "s" : ""}',
          icon: Icons.done_all_rounded,
          size: ZeetButtonSize.lg,
          fullWidth: true,
          loading: submitting,
          onPressed: submitting ? null : onConfirm,
        ),
      ),
    );
  }
}
