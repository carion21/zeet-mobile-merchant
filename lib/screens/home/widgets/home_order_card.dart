import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zeet_ui/zeet_ui.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/core/constants/icons.dart';
import 'package:merchant/core/utils/color_utils.dart';
import 'package:merchant/core/utils/order_status_utils.dart';
import 'package:merchant/core/widgets/order_code_text.dart';
import 'package:merchant/core/utils/phone_launcher.dart';
import 'package:merchant/core/widgets/cancel_reason_sheet.dart';
import 'package:merchant/core/widgets/preparation_timer.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/models/order_model.dart';
import 'package:merchant/providers/orders_provider.dart';
import 'package:merchant/services/incoming_order_dispatcher.dart';
import 'package:merchant/services/navigation_service.dart';

/// Card d'une commande dans la liste du home — grammaire gestuelle unifiee :
///
/// - **Swipe droit** (via `ZeetSwipeToConfirm` inline) : avance au statut
///   suivant (pending → confirmed → preparing → ready).
/// - **Swipe gauche** (via `Dismissible.endToStart`) : refuser / annuler,
///   ouvre le `showCancelReasonSheet`.
/// - **Tap** : ouvre le detail.
///
/// Le contenu est **riche** pour les `pending` (articles preview) et
/// **compact** pour les statuts actifs (client + total + timer) afin de
/// lever l'ambiguite visuelle entre les deux tabs (skill
/// `zeet-pos-ergonomics` §2bis + `zeet-gesture-grammar` §2).
class HomeOrderCard extends ConsumerWidget {
  const HomeOrderCard({
    super.key,
    required this.order,
  });

  final Order order;

  bool get _isPending =>
      order.status == 'pending' || order.status == 'payment-accepted';

  bool get _canCancel =>
      _isPending || order.status == 'confirmed' || order.status == 'preparing';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color surfaceColor = scheme.surface;
    final String semantics =
        'Commande ${order.code ?? order.id} — ${order.orderStatus?.displayLabel ?? ""} — ${order.customerName}';

    final Widget body = GestureDetector(
      onTap: () {
        ZeetHaptics.tap();
        Routes.pushOrderDetails(order.id);
      },
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: scheme.outlineVariant,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _CardBody(order: order),
            _CardAction(order: order),
          ],
        ),
      ),
    );

    final Widget child = _canCancel
        ? Dismissible(
            key: ValueKey<String>('order_${order.id}'),
            direction: DismissDirection.endToStart,
            // `confirmDismiss` retourne toujours false — la suppression
            // visuelle de la card est pilotee par le provider (refresh
            // apres cancel optimiste), sinon un echec reseau laisserait
            // l'utilisateur avec un trou dans la liste.
            confirmDismiss: (_) async {
              await _handleCancelSwipe(context, ref);
              return false;
            },
            background: _SwipeLeftBackground(status: order.status),
            child: body,
          )
        : body;

    return Semantics(
      container: true,
      button: true,
      label: semantics,
      child: child,
    );
  }

  Future<void> _handleCancelSwipe(BuildContext context, WidgetRef ref) async {
    // Verrouille le dispatcher : un push FCM incoming qui arriverait
    // pendant ce swipe/cancel sheet ne doit pas ouvrir l'ecran ring
    // par-dessus (race rapportee). Cf. IncomingOrderGestureLock.
    IncomingOrderGestureLock.markInteraction();
    HapticFeedback.heavyImpact();
    if (!context.mounted) return;
    final String? reason = await showCancelReasonSheet(context);
    if (reason == null || !context.mounted) return;

    // Re-lock apres le sheet : l'API call qui suit doit aussi etre
    // protege des pushs incoming.
    IncomingOrderGestureLock.markInteraction();
    final notifier = ref.read(orderDetailProvider(order.id).notifier);
    final bool success =
        await notifier.cancel(order.id, cancelReason: reason);
    if (!context.mounted) return;
    if (success) {
      AppToast.showWarning(
        context: context,
        message: _isPending ? 'Commande refusée' : 'Commande annulée',
      );
      ref.read(ordersListProvider.notifier).refresh();
    } else {
      final String? error =
          ref.read(orderDetailProvider(order.id)).actionError;
      AppToast.showError(
        context: context,
        message: error ?? 'Erreur lors de l\'annulation',
      );
    }
  }
}

/// Background rouge affiche pendant le swipe gauche — label adaptatif
/// (pending = "Refuser", autres = "Annuler").
class _SwipeLeftBackground extends StatelessWidget {
  const _SwipeLeftBackground({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final String label =
        (status == 'pending' || status == 'payment-accepted')
            ? 'Refuser'
            : 'Annuler';
    return Container(
      decoration: BoxDecoration(
        color: ZeetColors.danger,
        borderRadius: BorderRadius.circular(12.r),
      ),
      alignment: Alignment.centerRight,
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 8.w),
          Icon(Icons.close_rounded, color: Colors.white, size: 22.r),
        ],
      ),
    );
  }
}

/// Corps de la card :
/// - **Pending** : layout riche (preview items) pour décider accept/refuser
///   sans ouvrir le détail (skill `zeet-3-clicks-rule`).
/// - **En cours** (confirmed/preparing/ready/picked_up/…) : layout mono-ligne
///   compact via [_CompactBody] — bubble statut + client + code·statut + total.
///   Gain ~50% de hauteur vs ancien layout 3-rows, 0 overflow possible (tous
///   les Text sont bornés par Flexible/Expanded + ellipsis).
class _CardBody extends StatelessWidget {
  const _CardBody({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    // Vue riche (preview articles) pour les commandes qui attendent encore
    // l'accept merchant : backend envoie `payment-accepted`, le frontend
    // a historiquement utilise `pending`. On garde les deux par compat.
    final bool isPending =
        order.status == 'pending' || order.status == 'payment-accepted';
    if (!isPending) {
      return _CompactBody(order: order);
    }

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color textColor = scheme.onSurface;

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Header(order: order),
          SizedBox(height: 12.h),
          _ClientRow(order: order),
          SizedBox(height: 10.h),
          if (order.items.isNotEmpty) ...<Widget>[
            _ItemsPreview(items: order.items),
            SizedBox(height: 10.h),
          ],
          _TotalRow(order: order, textColor: textColor),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color textColor = scheme.onSurface;
    final Color textLightColor = scheme.onSurfaceVariant;

    return Row(
      children: <Widget>[
        Expanded(
          child: Row(
            children: <Widget>[
              Flexible(
                child: OrderCodeText(
                  // Affiche le code complet si la place le permet, sinon
                  // `#…<9 derniers>` — le StatusBadge à droite peut consommer
                  // la moitié de la ligne, le fallback évite l'ellipsis brut.
                  code: order.code ?? '${order.id}',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              if (order.status == 'confirmed' ||
                  order.status == 'preparing')
                PreparationTimer(
                  createdAtIso: order.createdAt,
                  dense: true,
                )
              else
                Flexible(
                  child: Text(
                    _timeAgo(order.createdAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: textLightColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        _StatusBadge(status: order.orderStatus),
      ],
    );
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    try {
      final DateTime dt = DateTime.parse(iso);
      final Duration diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'À l\'instant';
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
      return 'Il y a ${diff.inDays}j';
    } catch (_) {
      return '';
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final OrderStatus? status;

  @override
  Widget build(BuildContext context) {
    if (status == null) return const SizedBox.shrink();
    // Le backend peut renvoyer un `last_order_status` ou objet existe mais
    // label ET value vides. Sans garde, la chip affichait juste le dot
    // colore sans aucun texte (issue visuelle detail partner). On masque
    // plutot que de montrer une chip vide — le dot couleur d'a cote sur
    // la card suffit au glance.
    final String raw = status!.displayLabel.trim();
    if (raw.isEmpty) return const SizedBox.shrink();
    return ZeetStatusChip(
      status: partnerStatusFor(status!.value),
      label: raw,
      dense: true,
    );
  }
}

class _ClientRow extends StatelessWidget {
  const _ClientRow({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color textColor = scheme.onSurface;
    final Color textLightColor = scheme.onSurfaceVariant;

    return Row(
      children: <Widget>[
        IconManager.getIcon('person_outline',
            size: 16.r, color: textLightColor),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            order.customerName,
            style: TextStyle(fontSize: 14.sp, color: textColor),
          ),
        ),
        if (order.customerPhone.isNotEmpty)
          IconButton(
            icon: IconManager.getIcon('phone',
                size: 22.r, color: AppColors.primary),
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
    );
  }
}

/// Preview des 3 premiers articles de la commande — "3× Burger classic".
/// Permet au restaurateur de decider accept/refuser sans ouvrir le detail
/// (skill `zeet-3-clicks-rule` : info critique visible sans navigation).
class _ItemsPreview extends StatelessWidget {
  const _ItemsPreview({required this.items});
  final List<OrderItem> items;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color textColor = scheme.onSurface;
    final Color textLightColor = scheme.onSurfaceVariant;
    const int maxShown = 3;
    final List<OrderItem> visible = items.take(maxShown).toList();
    final int extra = items.length - visible.length;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final OrderItem item in visible)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 2.h),
              child: Text(
                '${item.quantity}× ${item.productName ?? 'Article'}${item.variantName != null ? ' — ${item.variantName}' : ''}',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (extra > 0)
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Text(
                '+ $extra autre${extra > 1 ? 's' : ''} article${extra > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: textLightColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.order, required this.textColor});
  final Order order;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final Color textLightColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Expanded(
          child: Row(
            children: <Widget>[
              IconManager.getIcon('shopping_bag',
                  size: 16.r, color: textLightColor),
              SizedBox(width: 8.w),
              Flexible(
                child: Text(
                  order.items.isNotEmpty
                      ? '${order.items.length} article${order.items.length > 1 ? 's' : ''}'
                      : 'Commande',
                  style:
                      TextStyle(fontSize: 14.sp, color: textLightColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
              amount: order.totalAmount ?? 0,
              currency: ZeetCurrency.fcfa,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Card compacte pour les statuts "en cours" : bubble statut colorée + client
/// (w600) + code·statut-court (12px muted) + montant, le tout sur un seul
/// bloc en 2 lignes internes. Laisse la card en ~60px de haut (vs ~140px
/// pour l'ancien layout 3-rows).
///
/// Le statut (bubble + label court) rend inutile un footer `_PassiveStatusRow`
/// pour les statuts passifs (ready/picked_up/awaiting-payment/…) : le
/// `_CardAction` retourne null → la card se ferme proprement sans bordure
/// vide (skill `zeet-design-system` §5 "un état = une info").
class _CompactBody extends StatelessWidget {
  const _CompactBody({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color textColor = scheme.onSurface;
    final Color textLightColor = scheme.onSurfaceVariant;
    final String statusValue = order.status;
    // Couleur authoritative : hex renvoye par le core via `last_order_status.color`.
    // Fallback neutre uniquement si le backend n'a pas fourni de couleur.
    final Color statusColor =
        order.orderStatus?.colorValue ?? ZeetColors.inkMuted;
    final IconData statusIcon = _statusIcon(statusValue);
    final String statusShort = _shortLabel(
      statusValue,
      fallback: order.orderStatus?.displayLabel ?? '',
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(statusIcon, color: statusColor, size: 18.r),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  order.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 2.h),
                Row(
                  children: <Widget>[
                    Flexible(
                      child: OrderCodeText(
                        // Row compacte (avatar · client · code · status · total).
                        // Si le code tient, on l'affiche complet — sinon
                        // `#…<9 derniers>`, ceux qu'on énonce au tel.
                        code: order.code ?? '${order.id}',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: textLightColor,
                        ),
                      ),
                    ),
                    Text(
                      '  ·  ',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: textLightColor,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        statusShort,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          ZeetMoney(
            amount: order.totalAmount ?? 0,
            currency: ZeetCurrency.fcfa,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'pending':
      case 'payment-accepted':
        return Icons.fiber_new_rounded;
      case 'confirmed':
        return Icons.check_circle_outline_rounded;
      case 'preparing':
        return Icons.restaurant_rounded;
      case 'ready':
      case 'ready-for-delivery':
        return Icons.shopping_bag_rounded;
      case 'picked_up':
      case 'on-the-way':
        return Icons.directions_bike_rounded;
      case 'awaiting-payment':
        return Icons.credit_card_rounded;
      case 'canceled':
      case 'cancelled':
      case 'rejected':
      case 'failed':
        return Icons.cancel_outlined;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  /// Labels courts pour la ligne compacte (évite "Prête pour la livraison"
  /// qui prend trop de place). Fallback sur `displayLabel` backend si valeur
  /// non mappée.
  String _shortLabel(String status, {required String fallback}) {
    switch (status) {
      case 'pending':
      case 'payment-accepted':
        return 'Nouvelle · à accepter';
      case 'confirmed':
        return 'Confirmée';
      case 'preparing':
        return 'En préparation';
      case 'ready':
      case 'ready-for-delivery':
        return 'Prête · attente livreur';
      case 'picked_up':
      case 'on-the-way':
        return 'En livraison';
      case 'awaiting-payment':
        return 'Attente paiement';
      case 'canceled':
      case 'cancelled':
        return 'Annulée';
      case 'rejected':
      case 'failed':
        return 'Refusée';
      default:
        return fallback;
    }
  }
}

/// Bas de card — slider `ZeetSwipeToConfirm` adaptatif selon le statut,
/// ou info passive pour `ready` / `picked_up` (pas d'action merchant).
class _CardAction extends ConsumerWidget {
  const _CardAction({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Widget? content = _buildContent(context, ref);
    if (content == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 12.h),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: content,
    );
  }

  Widget? _buildContent(BuildContext context, WidgetRef ref) {
    // Couleur pilotée par le statut cible (cf. skills neuro-ux & pos-
    // ergonomics §6 "Statut au coup d'œil") : tout-vert désensibilise,
    // donc le swipe prend la couleur du statut où la commande atterrira.
    final Map<String, OrderStatusOption> statusMap =
        ref.watch(orderStatusByValueProvider);

    switch (order.status) {
      case 'pending':
      case 'payment-accepted':
        return ZeetSwipeToConfirm(
          onConfirmed: () => _confirm(context, ref),
          fillColor: _resolveTargetColor(
            statusMap,
            'confirmed',
            fallback: ZeetColors.info,
          ),
          label: 'Glisser pour accepter',
          thresholdLabel: 'Relâchez pour accepter',
          confirmedLabel: 'Commande acceptée',
          height: 56,
        );
      case 'confirmed':
        return ZeetSwipeToConfirm(
          onConfirmed: () => _markPreparing(context, ref),
          fillColor: _resolveTargetColor(
            statusMap,
            'preparing',
            fallback: ZeetColors.warning,
          ),
          label: 'Glisser, on prépare',
          thresholdLabel: 'Relâchez pour démarrer',
          confirmedLabel: 'En préparation',
          height: 52,
        );
      case 'preparing':
        return ZeetSwipeToConfirm(
          onConfirmed: () => _markReady(context, ref),
          fillColor: _resolveTargetColor(
            statusMap,
            'ready',
            fallback: ZeetColors.success,
          ),
          label: 'Glisser, c\'est prêt',
          thresholdLabel: 'Relâchez, c\'est prêt',
          confirmedLabel: 'Prête pour le livreur',
          height: 52,
        );
      default:
        // Statuts passifs (ready/ready-for-delivery/picked_up/on-the-way/
        // awaiting-payment) : info deja visible dans la [_CompactBody]
        // (bubble + label court). Retour null → pas de footer + bordure
        // → gain ~50px vertical.
        return null;
    }
  }

  /// Résout la couleur hex du statut cible depuis la map (source backend
  /// `/v1/partner/orders/select/statuses`). Couvre la variante
  /// `ready-for-delivery` que certains environnements servent à la place
  /// de `ready`. Retombe sur [fallback] si la map n'est pas encore hydratée
  /// ou si la couleur backend est invalide.
  Color _resolveTargetColor(
    Map<String, OrderStatusOption> map,
    String value, {
    required Color fallback,
  }) {
    final OrderStatusOption? option = map[value] ?? map['$value-for-delivery'];
    final Color? parsed = hexToColor(option?.color);
    return parsed ?? fallback;
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    IncomingOrderGestureLock.markInteraction();
    ZeetHaptics.warning();
    final bool success = await ref
        .read(orderDetailProvider(order.id).notifier)
        .confirm(order.id);
    if (!context.mounted) return;
    if (success) {
      HapticFeedback.heavyImpact();
      AppToast.showSuccess(context: context, message: 'Commande confirmée');
      ref.read(ordersListProvider.notifier).refresh();
    } else {
      final String? error =
          ref.read(orderDetailProvider(order.id)).actionError;
      AppToast.showError(
        context: context,
        message: error ?? 'Erreur lors de la confirmation',
      );
    }
  }

  Future<void> _markPreparing(BuildContext context, WidgetRef ref) async {
    IncomingOrderGestureLock.markInteraction();
    ZeetHaptics.warning();
    final bool success = await ref
        .read(orderDetailProvider(order.id).notifier)
        .markPreparing(order.id);
    if (!context.mounted) return;
    if (success) {
      HapticFeedback.heavyImpact();
      AppToast.showSuccess(context: context, message: 'Préparation lancée');
      ref.read(ordersListProvider.notifier).refresh();
    } else {
      final String? error =
          ref.read(orderDetailProvider(order.id)).actionError;
      AppToast.showError(context: context, message: error ?? 'Erreur');
    }
  }

  Future<void> _markReady(BuildContext context, WidgetRef ref) async {
    IncomingOrderGestureLock.markInteraction();
    ZeetHaptics.warning();
    final bool success = await ref
        .read(orderDetailProvider(order.id).notifier)
        .markReady(order.id);
    if (!context.mounted) return;
    if (success) {
      HapticFeedback.heavyImpact();
      AppToast.showSuccess(
        context: context,
        message: 'Commande prête pour collecte',
      );
      ref.read(ordersListProvider.notifier).refresh();
    } else {
      final String? error =
          ref.read(orderDetailProvider(order.id)).actionError;
      AppToast.showError(context: context, message: error ?? 'Erreur');
    }
  }
}

