// lib/screens/carts/index.dart
//
// Ecran "Paniers actifs" partner — drill-down depuis HomeCompactStats.
// Exploite GET /v1/partner/carts (deja branche dans CartPartnerService +
// cartsListProvider) qui n'avait aucune surface UX.
//
// UX :
//  - Liste paginee, infinite scroll.
//  - Chaque tile : nom client + nb items + montant + chip activite (last_activity).
//  - Tap → bottom sheet detail (items + totals).
//  - Pull-to-refresh.
//  - ELAE complet (loading skeleton, empty, error).
//
// Skill `zeet-states-elae`, `zeet-pos-ergonomics`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:merchant/models/cart_partner_model.dart';
import 'package:merchant/providers/cart_partner_provider.dart';
import 'package:zeet_ui/zeet_ui.dart';

class CartsListScreen extends ConsumerStatefulWidget {
  const CartsListScreen({super.key});

  @override
  ConsumerState<CartsListScreen> createState() => _CartsListScreenState();
}

class _CartsListScreenState extends ConsumerState<CartsListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(cartsListProvider.notifier).load();
      ref.read(cartStatsProvider.notifier).load();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(cartsListProvider.notifier).loadMore();
    }
  }

  Future<void> _refresh() async {
    await ZeetHaptics.tap();
    await ref.read(cartsListProvider.notifier).refresh();
    await ref.read(cartStatsProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cartsListProvider);
    final stats = ref.watch(cartStatsProvider).stats;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final bool hasAny = state.carts.isNotEmpty;
    final bool isLoading =
        state.status == CartsListStatus.loading && !hasAny;
    final bool isLoadingMore =
        state.status == CartsListStatus.loadingMore;
    final Object? error = state.errorMessage != null && !hasAny
        ? state.errorMessage
        : null;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: ZeetAppBar(
        title: const Text('Paniers actifs'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ZeetStateBuilder<List<PartnerCart>>(
          data: hasAny ? state.carts : null,
          isLoading: isLoading,
          error: error,
          onRetry: () => ref.read(cartsListProvider.notifier).load(),
          emptyIcon: Icons.shopping_cart_outlined,
          emptyTitle: 'Aucun panier actif',
          emptySubtitle:
              "Quand vos clients composent leur commande sans la valider, "
              "elle apparait ici. C'est un signal de conversion.",
          loading: const ZeetSkeletonList(itemCount: 6, itemHeight: 80),
          builder: (List<PartnerCart> carts) {
            return ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
              itemCount: carts.length + 1 + (isLoadingMore ? 1 : 0),
              itemBuilder: (BuildContext context, int index) {
                if (index == 0) {
                  return _StatsHeader(stats: stats);
                }
                final i = index - 1;
                if (i >= carts.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return _CartTile(cart: carts[i]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  const _StatsHeader({required this.stats});

  final CartStats? stats;

  @override
  Widget build(BuildContext context) {
    if (stats == null) return const SizedBox.shrink();
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: ZeetColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ZeetRadius.md),
        border: Border.all(
          color: ZeetColors.success.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          _StatBlock(
            label: 'Actifs',
            value: '${stats!.activeCarts}',
          ),
          _Divider(),
          _StatBlock(
            label: 'Montant total',
            value: _fcfa(stats!.totalAmount),
          ),
          _Divider(),
          _StatBlock(
            label: 'Panier moyen',
            value: _fcfa(stats!.averageCartValue),
          ),
        ],
      ),
    );
  }

  static String _fcfa(double amount) {
    final s = amount.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return '${buf.toString()} FCFA';
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28.h,
      margin: EdgeInsets.symmetric(horizontal: 12.w),
      color: ZeetColors.success.withValues(alpha: 0.25),
    );
  }
}

class _CartTile extends StatelessWidget {
  const _CartTile({required this.cart});

  final PartnerCart cart;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final lastActivity = _formatRelative(cart.lastActivity);

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(ZeetRadius.md),
      ),
      child: ListTile(
        contentPadding:
            EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
        leading: CircleAvatar(
          backgroundColor: ZeetColors.primary.withValues(alpha: 0.12),
          child: Icon(
            Icons.shopping_cart_rounded,
            color: ZeetColors.primary,
            size: 18.sp,
          ),
        ),
        title: Text(
          cart.customer?.fullName ?? 'Client',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.sp),
        ),
        subtitle: Text(
          '${cart.itemCount} article${cart.itemCount > 1 ? 's' : ''}'
          '${lastActivity != null ? ' · $lastActivity' : ''}',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 12.sp,
          ),
        ),
        trailing: Text(
          _fcfa(cart.subtotal),
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 14.sp,
            fontWeight: FontWeight.w800,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }

  static String _fcfa(double amount) {
    final s = amount.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return '${buf.toString()} FCFA';
  }

  static String? _formatRelative(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final dt = DateTime.tryParse(raw);
    if (dt == null) return null;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'a l\'instant';
    if (diff.inHours < 1) return 'il y a ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'il y a ${diff.inHours} h';
    return DateFormat('d MMM, HH:mm', 'fr_FR').format(dt);
  }
}
