// lib/screens/tickets/index.dart
//
// Ecran liste des tickets de support partner.
// Endpoints : GET /v1/partner/tickets, GET /v1/partner/tickets/select/priorities.
//
// Intention POS partner : liste dense, statut glanceable (couleur+icone+label),
// CTA bottom sticky pour creer un nouveau ticket.
// Atteignable en 2 taps depuis Home (Profile → Aide et support).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zeet_ui/zeet_ui.dart';

import 'package:merchant/models/ticket_model.dart';
import 'package:merchant/providers/ticket_provider.dart';
import 'package:merchant/screens/tickets/create.dart';
import 'package:merchant/screens/tickets/detail.dart';
import 'package:merchant/services/navigation_service.dart';

class TicketsScreen extends ConsumerStatefulWidget {
  const TicketsScreen({super.key});

  @override
  ConsumerState<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends ConsumerState<TicketsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(ticketsListProvider.notifier).load());
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
      ref.read(ticketsListProvider.notifier).loadMore();
    }
  }

  Future<void> _refresh() async {
    await HapticFeedback.lightImpact();
    await ref.read(ticketsListProvider.notifier).refresh();
  }

  void _openCreate() {
    HapticFeedback.selectionClick();
    Routes.push(const CreateTicketScreen());
  }

  @override
  Widget build(BuildContext context) {
    final TicketsListState state = ref.watch(ticketsListProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: ZeetAppBar(
        title: Row(
          children: <Widget>[
            const Text('Aide et support'),
            if (state.tickets.isNotEmpty) ...<Widget>[
              const SizedBox(width: ZeetSpacing.x2),
              Text(
                '(${state.tickets.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ZeetSpacing.x4,
                ZeetSpacing.x3,
                ZeetSpacing.x4,
                ZeetSpacing.x3,
              ),
              child: _FilterSegmented(current: state.filter),
            ),
            Expanded(child: _TicketsList(state: state, scroll: _scrollController)),
          ],
        ),
      ),
      bottomNavigationBar: ZeetBottomBar(
        child: ZeetButton.primary(
          label: 'Nouveau ticket',
          icon: Icons.add_rounded,
          fullWidth: true,
          size: ZeetButtonSize.lg,
          onPressed: _openCreate,
        ),
      ),
    );
  }
}

// =============================================================================
// FILTRES
// =============================================================================

class _FilterSegmented extends ConsumerWidget {
  const _FilterSegmented({required this.current});
  final TicketsFilter current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: ZeetRadius.brMd,
        border: Border.all(color: scheme.outline),
      ),
      padding: const EdgeInsets.all(ZeetSpacing.x1),
      child: Row(
        children: TicketsFilter.values.map((TicketsFilter f) {
          final bool selected = f == current;
          return Expanded(
            child: Material(
              color: selected ? scheme.primary : Colors.transparent,
              borderRadius: ZeetRadius.brSm,
              child: InkWell(
                borderRadius: ZeetRadius.brSm,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(ticketsListProvider.notifier).setFilter(f);
                },
                child: Container(
                  constraints: const BoxConstraints(minHeight: 40),
                  alignment: Alignment.center,
                  child: Text(
                    f.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: selected
                              ? scheme.onPrimary
                              : scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// =============================================================================
// LISTE
// =============================================================================

class _TicketsList extends StatelessWidget {
  const _TicketsList({required this.state, required this.scroll});
  final TicketsListState state;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    if (state.status == TicketsStatus.loading && state.tickets.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(
          horizontal: ZeetSpacing.x4,
          vertical: ZeetSpacing.x2,
        ),
        itemCount: 6,
        itemBuilder: (BuildContext context, int _) => const Padding(
          padding: EdgeInsets.symmetric(vertical: ZeetSpacing.x1),
          child: ZeetSkeleton(width: double.infinity, height: 72),
        ),
      );
    }

    if (state.status == TicketsStatus.error && state.tickets.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: ZeetEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Chargement impossible',
              description: state.errorMessage ??
                  'Une erreur est survenue lors du chargement des tickets.',
            ),
          ),
        ],
      );
    }

    final List<Ticket> filtered = state.filteredTickets;
    if (filtered.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: const ZeetEmptyState(
              icon: Icons.support_agent_rounded,
              title: 'Aucun ticket a afficher',
              description:
                  'Ouvrez un ticket pour poser une question à notre '
                  'équipe support. Réponse sous 24h.',
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        ZeetSpacing.x4,
        ZeetSpacing.x1,
        ZeetSpacing.x4,
        ZeetSpacing.x4,
      ),
      itemCount: filtered.length + (state.isLoadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: ZeetSpacing.x2),
      itemBuilder: (BuildContext context, int index) {
        if (index >= filtered.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: ZeetSpacing.x3),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _TicketTile(ticket: filtered[index]);
      },
    );
  }
}

// =============================================================================
// TILE
// =============================================================================

class _TicketTile extends ConsumerWidget {
  const _TicketTile({required this.ticket});
  final Ticket ticket;

  ZeetStatus _statusToZeet(TicketStatus s) {
    switch (s) {
      case TicketStatus.open:
      case TicketStatus.awaitingReply:
        return ZeetStatus.warning;
      case TicketStatus.inProgress:
        return ZeetStatus.info;
      case TicketStatus.resolved:
      case TicketStatus.closed:
        return ZeetStatus.success;
      case TicketStatus.rejected:
        return ZeetStatus.danger;
      case TicketStatus.unknown:
        return ZeetStatus.neutral;
    }
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final DateTime dt = DateTime.parse(iso).toLocal();
      final DateTime now = DateTime.now();
      final Duration diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'A l\'instant';
      if (diff.inHours < 1) return 'Il y a ${diff.inMinutes} min';
      if (diff.inDays < 1) return 'Il y a ${diff.inHours}h';
      if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
      return DateFormat('d MMM', 'fr_FR').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    // Precharge le compteur non-lu temps reel (fallback sur ticket.unreadCount).
    final AsyncValue<int> liveUnread =
        ref.watch(ticketUnreadCountProvider(ticket.id.toString()));
    final int unread = liveUnread.maybeWhen(
      data: (int c) => c,
      orElse: () => ticket.unreadCount,
    );

    return ZeetCard(
      variant: ZeetCardVariant.outlined,
      padding: const EdgeInsets.symmetric(
        horizontal: ZeetSpacing.x4,
        vertical: ZeetSpacing.x3,
      ),
      onTap: () {
        Routes.push(TicketDetailScreen(ticketId: ticket.id.toString()));
      },
      semanticLabel: 'Ticket ${ticket.title}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  ticket.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: ZeetSpacing.x2),
              ZeetStatusChip(
                status: _statusToZeet(ticket.status),
                label: ticket.status.displayLabel,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: ZeetSpacing.x2),
          Row(
            children: <Widget>[
              Icon(
                Icons.flag_outlined,
                size: 14,
                color: scheme.onSurfaceVariant,
                semanticLabel: 'Priorite',
              ),
              const SizedBox(width: ZeetSpacing.x1),
              Text(
                ticket.priority.displayLabel,
                style: tt.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: ZeetSpacing.x3),
              Icon(
                Icons.access_time_rounded,
                size: 14,
                color: scheme.onSurfaceVariant,
                semanticLabel: 'Date',
              ),
              const SizedBox(width: ZeetSpacing.x1),
              Expanded(
                child: Text(
                  _formatDate(ticket.lastMessageAt ?? ticket.updatedAt ??
                      ticket.createdAt),
                  style: tt.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (unread > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZeetSpacing.x2,
                    vertical: ZeetSpacing.x1,
                  ),
                  decoration: BoxDecoration(
                    color: ZeetColors.dangerBg,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(ZeetRadius.pill),
                    ),
                  ),
                  child: Text(
                    '$unread non lu${unread > 1 ? 's' : ''}',
                    style: tt.labelSmall?.copyWith(
                      color: ZeetColors.dangerText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
