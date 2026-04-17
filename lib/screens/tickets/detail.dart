// lib/screens/tickets/detail.dart
//
// Ecran detail d'un ticket partner : messages threades + composer bottom.
// Endpoints :
// - GET /v1/partner/tickets/:id
// - GET /v1/partner/tickets/:id/messages
// - POST /v1/partner/tickets/:id/messages
// - PATCH /v1/partner/tickets/:id/messages/read
// - GET /v1/partner/tickets/:id/logs
//
// Intention POS partner : bulles threadees, CTA envoyer en bottom sticky,
// statut chip haut-droite, haptic sur envoi.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zeet_ui/zeet_ui.dart';

import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/models/ticket_model.dart';
import 'package:merchant/providers/ticket_provider.dart';

class TicketDetailScreen extends ConsumerStatefulWidget {
  const TicketDetailScreen({super.key, required this.ticketId});
  final String ticketId;

  @override
  ConsumerState<TicketDetailScreen> createState() =>
      _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  final TextEditingController _composerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _composerFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        ref.read(ticketDetailProvider(widget.ticketId).notifier).load());
  }

  @override
  void dispose() {
    _composerController.dispose();
    _scrollController.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await HapticFeedback.lightImpact();
    await ref.read(ticketDetailProvider(widget.ticketId).notifier).refresh();
  }

  Future<void> _sendMessage() async {
    final String body = _composerController.text.trim();
    if (body.isEmpty) return;
    await HapticFeedback.mediumImpact();
    final bool ok = await ref
        .read(ticketDetailProvider(widget.ticketId).notifier)
        .sendMessage(body);
    if (!mounted) return;
    if (ok) {
      _composerController.clear();
      await HapticFeedback.lightImpact();
      // Scroll vers le dernier message
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    } else {
      final String? err =
          ref.read(ticketDetailProvider(widget.ticketId)).errorMessage;
      if (!mounted) return;
      AppToast.showError(
        context: context,
        message: err ?? 'Envoi impossible',
      );
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final TicketDetailState state =
        ref.watch(ticketDetailProvider(widget.ticketId));
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Ticket? ticket = state.ticket;
    final bool isLocked = ticket != null &&
        (ticket.status == TicketStatus.closed ||
            ticket.status == TicketStatus.rejected);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: ZeetAppBar(
        title: Text(
          ticket?.title ?? 'Ticket',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          if (ticket != null)
            Padding(
              padding: const EdgeInsets.only(right: ZeetSpacing.x3),
              child: Center(
                child: ZeetStatusChip(
                  status: _statusToZeet(ticket.status),
                  label: ticket.status.displayLabel,
                  dense: true,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (ticket != null) _TicketInfoBanner(ticket: ticket),
          if (ticket != null) _AvailableActionsBar(ticket: ticket),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _MessagesList(
                state: state,
                scroll: _scrollController,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _Composer(
        controller: _composerController,
        focusNode: _composerFocus,
        isSending: state.isSending,
        locked: isLocked,
        onSend: _sendMessage,
      ),
    );
  }
}

// =============================================================================
// BANNER INFO
// =============================================================================

class _TicketInfoBanner extends StatelessWidget {
  const _TicketInfoBanner({required this.ticket});
  final Ticket ticket;

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      return DateFormat('d MMM yyyy', 'fr_FR')
          .format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        ZeetSpacing.x4,
        ZeetSpacing.x3,
        ZeetSpacing.x4,
        0,
      ),
      padding: const EdgeInsets.all(ZeetSpacing.x4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: ZeetRadius.brMd,
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.flag_outlined,
                size: 16,
                color: scheme.onSurfaceVariant,
                semanticLabel: 'Priorite',
              ),
              const SizedBox(width: ZeetSpacing.x1),
              Text(
                'Priorite : ${ticket.priority.displayLabel}',
                style: tt.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: ZeetSpacing.x4),
              Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: scheme.onSurfaceVariant,
                semanticLabel: 'Date de creation',
              ),
              const SizedBox(width: ZeetSpacing.x1),
              Text(
                _formatDate(ticket.createdAt),
                style: tt.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (ticket.description != null &&
              ticket.description!.isNotEmpty) ...<Widget>[
            const SizedBox(height: ZeetSpacing.x2),
            Text(
              ticket.description!,
              style: tt.bodyMedium,
            ),
          ],
          if (ticket.orderCode != null) ...<Widget>[
            const SizedBox(height: ZeetSpacing.x2),
            Row(
              children: <Widget>[
                Icon(
                  Icons.receipt_long_rounded,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                  semanticLabel: 'Commande liee',
                ),
                const SizedBox(width: ZeetSpacing.x1),
                Text(
                  'Commande #${ticket.orderCode}',
                  style: tt.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// ACTIONS BAR (etat machine du ticket)
// =============================================================================

class _AvailableActionsBar extends ConsumerWidget {
  const _AvailableActionsBar({required this.ticket});
  final Ticket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<TicketActionOption>> actionsAsync =
        ref.watch(ticketActionsProvider(ticket.status.apiValue));
    // On precharge aussi les users mentionables du ticket (autocomplete
    // @mention future). Non bloquant.
    ref.watch(ticketMentionableUsersProvider(ticket.id.toString()));

    return actionsAsync.when(
      data: (List<TicketActionOption> actions) {
        if (actions.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            ZeetSpacing.x4,
            ZeetSpacing.x3,
            ZeetSpacing.x4,
            0,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: actions.map((TicketActionOption a) {
                return Padding(
                  padding: const EdgeInsets.only(right: ZeetSpacing.x2),
                  child: ZeetStatusChip(
                    status: ZeetStatus.info,
                    label: a.label,
                    customIcon: Icons.bolt_rounded,
                    dense: true,
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (Object _, StackTrace __) => const SizedBox.shrink(),
    );
  }
}

// =============================================================================
// MESSAGES LIST
// =============================================================================

class _MessagesList extends StatelessWidget {
  const _MessagesList({required this.state, required this.scroll});
  final TicketDetailState state;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    if (state.status == TicketsStatus.loading && state.messages.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.all(ZeetSpacing.x4),
        itemCount: 4,
        itemBuilder: (BuildContext context, int _) => const Padding(
          padding: EdgeInsets.symmetric(vertical: ZeetSpacing.x2),
          child: ZeetSkeleton(width: double.infinity, height: 56),
        ),
      );
    }

    if (state.status == TicketsStatus.error && state.messages.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.45,
            child: ZeetEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Chargement impossible',
              description: state.errorMessage ??
                  'Impossible de charger les messages.',
            ),
          ),
        ],
      );
    }

    if (state.messages.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.45,
            child: const ZeetEmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Conversation vierge',
              description:
                  'Envoyez un message ci-dessous pour demarrer la conversation '
                  'avec le support.',
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(ZeetSpacing.x4),
      itemCount: state.messages.length,
      itemBuilder: (BuildContext context, int index) {
        final TicketMessage msg = state.messages[index];
        final bool showDateHeader =
            index == 0 || _isDifferentDay(msg, state.messages[index - 1]);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (showDateHeader) _DateDivider(iso: msg.createdAt),
            _MessageBubble(msg: msg),
          ],
        );
      },
    );
  }

  bool _isDifferentDay(TicketMessage a, TicketMessage b) {
    try {
      final DateTime da = DateTime.parse(a.createdAt ?? '').toLocal();
      final DateTime db = DateTime.parse(b.createdAt ?? '').toLocal();
      return da.year != db.year || da.month != db.month || da.day != db.day;
    } catch (_) {
      return false;
    }
  }
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.iso});
  final String? iso;

  @override
  Widget build(BuildContext context) {
    String label = '';
    try {
      label = DateFormat('EEEE d MMMM', 'fr_FR')
          .format(DateTime.parse(iso ?? '').toLocal());
    } catch (_) {}
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ZeetSpacing.x3),
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.msg});
  final TicketMessage msg;

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      return DateFormat('HH:mm').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool mine = msg.isMine;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;

    final Color bubbleBg =
        mine ? scheme.primary : scheme.surfaceContainerLow;
    final Color textColor = mine ? scheme.onPrimary : scheme.onSurface;
    final Color metaColor = mine
        ? scheme.onPrimary.withValues(alpha: 0.8)
        : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ZeetSpacing.x1),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: <Widget>[
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: ZeetSpacing.x3,
                vertical: ZeetSpacing.x3,
              ),
              decoration: BoxDecoration(
                color: bubbleBg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(ZeetRadius.md),
                  topRight: const Radius.circular(ZeetRadius.md),
                  bottomLeft: Radius.circular(mine ? ZeetRadius.md : 4),
                  bottomRight: Radius.circular(mine ? 4 : ZeetRadius.md),
                ),
                border: mine ? null : Border.all(color: scheme.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (!mine && msg.authorName != null &&
                      msg.authorName!.isNotEmpty)
                    Padding(
                      padding:
                          const EdgeInsets.only(bottom: ZeetSpacing.x1),
                      child: Text(
                        msg.authorName!,
                        style: tt.labelSmall?.copyWith(
                          color: metaColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Text(
                    msg.body ?? '',
                    style: tt.bodyMedium?.copyWith(color: textColor),
                  ),
                  const SizedBox(height: ZeetSpacing.x1),
                  Text(
                    _formatTime(msg.createdAt),
                    style: tt.labelSmall?.copyWith(color: metaColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// COMPOSER
// =============================================================================

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.locked,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final bool locked;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;

    if (locked) {
      return ZeetBottomBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
              semanticLabel: 'Verrouille',
            ),
            const SizedBox(width: ZeetSpacing.x2),
            Text(
              'Ce ticket est ferme',
              style: tt.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ZeetBottomBar(
      padding: const EdgeInsets.symmetric(
        horizontal: ZeetSpacing.x3,
        vertical: ZeetSpacing.x2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 48, maxHeight: 140),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: ZeetRadius.brMd,
                border: Border.all(color: scheme.outline),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: ZeetSpacing.x3,
                vertical: ZeetSpacing.x2,
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Ecrire un message...',
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintStyle: tt.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                style: tt.bodyMedium,
              ),
            ),
          ),
          const SizedBox(width: ZeetSpacing.x2),
          SizedBox(
            height: 56,
            width: 56,
            child: Material(
              color: scheme.primary,
              borderRadius: ZeetRadius.brMd,
              child: InkWell(
                borderRadius: ZeetRadius.brMd,
                onTap: isSending ? null : onSend,
                child: Center(
                  child: isSending
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimary,
                          ),
                        )
                      : Icon(
                          Icons.send_rounded,
                          color: scheme.onPrimary,
                          size: 22,
                          semanticLabel: 'Envoyer',
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
