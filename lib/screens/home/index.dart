import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zeet_ui/zeet_ui.dart';
import 'package:merchant/core/widgets/notif_rationale_sheet.dart';
import 'package:merchant/core/widgets/partner_connectivity_banner.dart';
import 'package:merchant/models/business_day_window.dart';
import 'package:merchant/providers/auth_provider.dart';
import 'package:merchant/providers/orders_provider.dart';
import 'package:merchant/providers/connectivity_provider.dart';
import 'package:merchant/providers/cart_partner_provider.dart';
import 'package:merchant/providers/dashboard_provider.dart';
import 'package:merchant/providers/profile_provider.dart';
import 'package:merchant/screens/home/widgets/home_close_service_cta.dart';
import 'package:merchant/screens/home/widgets/home_compact_stats.dart';
import 'package:merchant/screens/home/widgets/home_insight_banner.dart';
import 'package:merchant/screens/home/widgets/home_earnings_card.dart';
import 'package:merchant/screens/home/widgets/home_header.dart';
import 'package:merchant/screens/home/widgets/home_orders_section.dart';
import 'package:merchant/services/fcm_service.dart';
import 'package:merchant/services/navigation_service.dart';

/// Home screen partner — squelette de l'architecture d'ecran :
/// - tient le cycle de vie du `TabController` et du pre-prompt notifs.
/// - orchestre les widgets fils : header, earnings, stats, orders section.
///
/// Cf. `widgets/` pour l'implementation de chaque section.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// Ticker qui detecte le passage du cutoff de journee commerciale
  /// (04h par defaut) pendant que l'ecran est ouvert → re-fetch dashboard
  /// pour reinitialiser orders_today / revenue_today. Cas critique : un
  /// partner qui reste sur l'ecran de 03h55 a 04h05 doit voir ses KPIs
  /// repartir a 0 sans action manuelle. Cf. brief PARTNER_BUSINESS_DAY §5.
  Timer? _businessDayTicker;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      // Rebuild le sliver de commandes à chaque changement de tab
      // (le contenu de la liste dépend de `_tabController.index`).
      ..addListener(() {
        if (mounted) setState(() {});
      });

    Future.microtask(() {
      ref.read(authProvider.notifier).checkAuthStatus();
      ref.read(dashboardProvider.notifier).loadSummary();
      ref.read(profileProvider.notifier).loadProfile();
      ref.read(ordersListProvider.notifier).load();
      // Cart stats — exploite GET /v1/partner/carts/stats (montant total,
      // valeur moyenne) au-dela du compteur "actifs" deja remonte par
      // /dashboard/summary. Permet d'afficher des insights de conversion
      // dans les widgets `cartStatsProvider`.
      ref.read(cartStatsProvider.notifier).load();
    });

    _businessDayTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      final BusinessDayWindow? bd =
          ref.read(dashboardProvider).summary?.businessDay;
      if (bd != null && bd.isExpired()) {
        ref.read(dashboardProvider.notifier).refresh();
      }
    });

    // Si le /me en arrière-plan découvre des tokens invalides → login.
    ref.listenManual(authProvider, (prev, next) {
      if (prev?.status == AuthStatus.authenticated &&
          next.status == AuthStatus.unauthenticated) {
        Routes.navigateAndRemoveAll(Routes.login);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowNotifRationale();
    });
  }

  /// Pre-prompt notifications — affiche le bottom sheet custom avant de
  /// demander la permission système (iOS one-shot). Cf.
  /// zeet-notification-strategy §8 : sans notifs, le restaurateur rate des
  /// commandes entrantes pendant le coup de feu.
  Future<void> _maybeShowNotifRationale() async {
    final alreadyShown = await NotifRationaleSheet.hasBeenShown();
    if (alreadyShown || !mounted) return;

    final accepted = await NotifRationaleSheet.show(context);
    if (accepted == true) {
      await NotifRationaleSheet.markAsShown();
      await FcmService.instance.requestPushPermission();
    }
    // Refus / dismiss : ne PAS marquer shown → on redemandera au prochain
    // cold-start (évite de brûler la permission iOS prématurément).
  }

  @override
  void dispose() {
    _businessDayTicker?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color backgroundColor = scheme.surface;

    final dashboardSummary = ref.watch(dashboardProvider).summary;
    final double todayEarnings = dashboardSummary?.revenueToday ?? 0;

    final bool isOnline = ref.watch(connectivityStatusProvider).maybeWhen(
          data: (v) => v,
          orElse: () => true,
        );

    // Refactor M-11 : plus de `SizedBox(height: 400.h)` qui limite la
    // TabBarView à un viewport fixe dans un SingleChildScrollView.
    // Top : header + bandeaux. Bas : Expanded(TabBarView) qui prend
    // tout l'espace → plus de double scroll, plus de contenu tronqué.
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const PartnerConnectivityBanner(),
            const HomeHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ZeetHaptics.success();
                  await Future.wait(<Future<void>>[
                    ref.read(dashboardProvider.notifier).loadSummary(),
                    ref.read(ordersListProvider.notifier).refresh(),
                  ]);
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: <Widget>[
                    SliverToBoxAdapter(
                      child: HomeEarningsCard(
                        earnings: todayEarnings,
                        isDark: isDark,
                        businessDay: dashboardSummary?.businessDay,
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 16.h)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: const HomeCompactStats(),
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 12.h)),
                    const SliverToBoxAdapter(child: HomeInsightBanner()),
                    SliverToBoxAdapter(child: SizedBox(height: 12.h)),
                    HomeOrdersSection(
                      tabController: _tabController,
                      isOnline: isOnline,
                    ),
                    // Phase 5.2 — CTA discret "Clôturer le service" en bas
                    // de la liste. Masque auto si restaurant deja ferme
                    // (cf. HomeCloseServiceCta).
                    const SliverToBoxAdapter(child: HomeCloseServiceCta()),
                    SliverToBoxAdapter(child: SizedBox(height: 24.h)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
