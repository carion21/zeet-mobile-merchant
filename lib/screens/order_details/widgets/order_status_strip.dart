// lib/screens/order_details/widgets/order_status_strip.dart
//
// Strip pleine largeur affichant le statut courant. Glance-first (POS §6) :
// statut = premiere info scannable. Couleur authoritative depuis backend
// `last_order_status.color` (jamais de mapping cote Flutter).

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/core/widgets/preparation_timer.dart';
import 'package:merchant/models/order_model.dart';
import 'package:zeet_ui/zeet_ui.dart';

class OrderStatusStrip extends StatelessWidget {
  const OrderStatusStrip({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final Color stripColor =
        order.orderStatus?.colorValue ?? ZeetColors.inkMuted;
    final bool isOngoing =
        order.status == 'confirmed' || order.status == 'preparing';
    final String? rawLabel = order.orderStatus?.displayLabel;
    final String statusLabel = (rawLabel != null && rawLabel.trim().isNotEmpty)
        ? rawLabel
        : fallbackStatusLabel(order.status);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: stripColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border(
          left: BorderSide(color: stripColor, width: 3),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      child: Row(
        children: <Widget>[
          Container(
            width: 8.w,
            height: 8.w,
            decoration: BoxDecoration(
              color: stripColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 10.w),
          Flexible(
            child: Text(
              statusLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: stripColor,
                letterSpacing: 0.2,
              ),
            ),
          ),
          if (isOngoing) ...<Widget>[
            SizedBox(width: 12.w),
            PreparationTimer(createdAtIso: order.createdAt, dense: true),
          ],
        ],
      ),
    );
  }
}

/// Fallback label si backend ne fournit pas `last_order_status.label`.
String fallbackStatusLabel(String? value) {
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
