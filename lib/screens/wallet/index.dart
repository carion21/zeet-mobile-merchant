// lib/screens/wallet/index.dart
//
// Ecran portefeuille partner — endpoints :
// - GET /v1/partner/wallet
// - GET /v1/partner/wallet/entries
//
// Intention POS partner : dense, glanceable, statuts couleur+icone+label.
// Hero solde en haut (1 tap depuis home), historique pagine en liste dense.
// Regles : composants Zeet*, pas de couleur en dur, haptic sur actions critiques.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zeet_ui/zeet_ui.dart';

import 'package:merchant/models/wallet_model.dart';
import 'package:merchant/providers/wallet_provider.dart';
import 'transaction_detail_sheet.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(walletProvider.notifier).load());
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
      ref.read(walletProvider.notifier).loadMore();
    }
  }

  Future<void> _refresh() async {
    await ZeetHaptics.success();
    await ref.read(walletProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final WalletState state = ref.watch(walletProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: const ZeetAppBar(title: Text('Portefeuille')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverToBoxAdapter(child: _BalanceHero(state: state)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  ZeetSpacing.x4,
                  ZeetSpacing.x5,
                  ZeetSpacing.x4,
                  ZeetSpacing.x3,
                ),
                child: _SectionTitle(label: 'Historique'),
              ),
            ),
            SliverToBoxAdapter(child: _FilterSegmented(current: state.filter)),
            const SliverToBoxAdapter(child: SizedBox(height: ZeetSpacing.x3)),
            _EntriesSliver(state: state),
            if (state.isLoadingMore)
              const SliverToBoxAdapter(
                // Skeleton > spinner plein écran (skill zeet-motion-system §9).
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ZeetSpacing.x4,
                    vertical: ZeetSpacing.x2,
                  ),
                  child: ZeetSkeleton(width: double.infinity, height: 64),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: ZeetSpacing.x8)),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// HERO SOLDE
// =============================================================================

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.state});

  final WalletState state;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    final bool isLoading = state.balanceStatus == WalletStatus.loading &&
        state.wallet == null;
    final Wallet? wallet = state.wallet;
    final double balance = wallet?.balance ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ZeetSpacing.x4,
        ZeetSpacing.x4,
        ZeetSpacing.x4,
        ZeetSpacing.x2,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(ZeetSpacing.x5),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: ZeetRadius.brLg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.account_balance_wallet_rounded,
                  color: scheme.onPrimary,
                  size: 20,
                  semanticLabel: 'Portefeuille',
                ),
                const SizedBox(width: ZeetSpacing.x2),
                Text(
                  'Solde disponible',
                  style: tt.labelLarge?.copyWith(
                    color: scheme.onPrimary.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZeetSpacing.x3),
            if (isLoading)
              const ZeetSkeleton(width: 180, height: 36)
            else
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                // Rolling counter : signal de récompense #1 quand le solde
                // monte après livraison (skill zeet-neuro-ux §12bis dopamine).
                child: ZeetRollingCounter(
                  value: balance,
                  suffix: ' FCFA',
                  style: tt.headlineMedium?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            const SizedBox(height: ZeetSpacing.x3),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: ZeetSpacing.x3,
                vertical: ZeetSpacing.x2,
              ),
              decoration: BoxDecoration(
                color: scheme.onPrimary.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.all(
                  Radius.circular(ZeetRadius.pill),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: scheme.onPrimary,
                    semanticLabel: 'Information',
                  ),
                  const SizedBox(width: ZeetSpacing.x1),
                  Flexible(
                    child: Text(
                      'Versements selon votre cycle de commission',
                      style: tt.labelSmall?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// TITRE SECTION
// =============================================================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

// =============================================================================
// FILTRE SEGMENTED
// =============================================================================

class _FilterSegmented extends ConsumerWidget {
  const _FilterSegmented({required this.current});
  final WalletDirectionFilter current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: ZeetSpacing.x4),
      child: Row(
        children: WalletDirectionFilter.values.map((WalletDirectionFilter f) {
          final bool selected = f == current;
          return Padding(
            padding: const EdgeInsets.only(right: ZeetSpacing.x2),
            child: _FilterChip(
              label: f.label,
              selected: selected,
              onTap: () {
                ZeetHaptics.tap();
                ref.read(walletProvider.notifier).setFilter(f);
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainerLow,
      borderRadius: const BorderRadius.all(Radius.circular(ZeetRadius.pill)),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            const BorderRadius.all(Radius.circular(ZeetRadius.pill)),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40, minWidth: 72),
          padding: const EdgeInsets.symmetric(
            horizontal: ZeetSpacing.x4,
            vertical: ZeetSpacing.x2,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: tt.labelLarge?.copyWith(
              color: selected ? scheme.onPrimary : scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// LISTE ENTRIES
// =============================================================================

class _EntriesSliver extends StatelessWidget {
  const _EntriesSliver({required this.state});
  final WalletState state;

  @override
  Widget build(BuildContext context) {
    if (state.entriesStatus == WalletStatus.loading && state.entries.isEmpty) {
      return SliverList.builder(
        itemCount: 6,
        itemBuilder: (BuildContext context, int _) => const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: ZeetSpacing.x4,
            vertical: ZeetSpacing.x1,
          ),
          child: ZeetSkeleton(width: double.infinity, height: 64),
        ),
      );
    }

    if (state.entriesStatus == WalletStatus.error && state.entries.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Consumer(
          builder: (context, ref, _) => ZeetEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Chargement impossible',
            description: state.errorMessage ??
                'Une erreur est survenue lors du chargement de l\'historique.',
            actionLabel: 'Réessayer',
            onAction: () {
              ref.read(walletProvider.notifier).refresh();
            },
          ),
        ),
      );
    }

    if (state.entries.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: ZeetEmptyState(
          icon: Icons.receipt_long_rounded,
          title: 'Aucune transaction',
          description:
              'Vos credits et debits apparaitront ici apres vos premieres '
              'commandes livrees.',
        ),
      );
    }

    return SliverList.builder(
      itemCount: state.entries.length,
      itemBuilder: (BuildContext context, int index) {
        final WalletEntry entry = state.entries[index];
        return _WalletEntryTile(entry: entry);
      },
    );
  }
}

class _WalletEntryTile extends StatelessWidget {
  const _WalletEntryTile({required this.entry});
  final WalletEntry entry;

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final DateTime dt = DateTime.parse(iso).toLocal();
      return DateFormat('d MMM yyyy · HH:mm', 'fr_FR').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isCredit = entry.isCredit;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    final String title = entry.description?.trim().isNotEmpty == true
        ? entry.description!
        : (isCredit ? 'Credit' : 'Debit');

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ZeetSpacing.x4,
        vertical: ZeetSpacing.x1,
      ),
      child: Builder(
        builder: (BuildContext ctx) {
          return ZeetCard(
            variant: ZeetCardVariant.outlined,
            enableHaptic: false, // Haptic heavyImpact custom ci-dessous.
            padding: const EdgeInsets.symmetric(
              horizontal: ZeetSpacing.x4,
              vertical: ZeetSpacing.x3,
            ),
            onTap: () {
              // Haptic fort (revert: remettre enableHaptic: true + supprimer onTap).
              HapticFeedback.heavyImpact();
              showTransactionDetailSheet(ctx, entry);
            },
            child: Row(
          children: <Widget>[
            // Pastille direction (couleur + icone + label a11y).
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCredit ? ZeetColors.successBg : ZeetColors.dangerBg,
                borderRadius: ZeetRadius.brMd,
              ),
              alignment: Alignment.center,
              child: Icon(
                isCredit
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                color: isCredit
                    ? ZeetColors.successText
                    : ZeetColors.dangerText,
                size: 20,
                semanticLabel: isCredit ? 'Credit' : 'Debit',
              ),
            ),
            const SizedBox(width: ZeetSpacing.x3),
            // Title + date + reference
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: ZeetSpacing.x1),
                  Text(
                    <String>[
                      _formatDate(entry.createdAt),
                      if (entry.reference != null && entry.reference!.isNotEmpty)
                        'Ref ${entry.reference}',
                    ].where((String s) => s.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: ZeetSpacing.x3),
            // Montant signe
            ZeetMoney(
              amount: isCredit ? entry.amount.abs() : -entry.amount.abs(),
              currency: ZeetCurrency.fcfa,
              showSign: true,
              style: tt.titleMedium?.copyWith(
                color: isCredit ? ZeetColors.successText : ZeetColors.dangerText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
            ),
          );
        },
      ),
    );
  }
}
