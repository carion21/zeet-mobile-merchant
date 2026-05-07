// lib/screens/order_details/steps/ready_layout.dart
//
// Layout step "Prête / En livraison" — la commande attend ou est en
// transit. Hierarchie :
// 1. Code commande + statut
// 2. OTP HERO (le rider arrive et demande le code)
// 3. Articles compact (verification rapide en remise)
// 4. Adresse + client (au cas ou contact rider/client)
// 5. Remuneration (compact)
//
// CTA hero : aucun cote partner (PassiveInfoBar bas).

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/models/order_model.dart';
import 'package:merchant/providers/orders_provider.dart';
import 'package:merchant/screens/order_details/widgets/address_section.dart';
import 'package:merchant/screens/order_details/widgets/client_section.dart';
import 'package:merchant/screens/order_details/widgets/items_section.dart';
import 'package:merchant/screens/order_details/widgets/order_code_header.dart';
import 'package:merchant/screens/order_details/widgets/order_status_strip.dart';
import 'package:merchant/screens/order_details/widgets/pickup_otp_teaser.dart';
import 'package:merchant/screens/order_details/widgets/summary_section.dart';

class ReadyLayout extends StatelessWidget {
  const ReadyLayout({
    super.key,
    required this.order,
    required this.detailState,
    required this.onTapOtpFullscreen,
  });

  final Order order;
  final OrderDetailState detailState;
  final VoidCallback onTapOtpFullscreen;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color dividerColor = scheme.outlineVariant;
    final bool showOtp =
        order.status == 'ready' || order.status == 'picked_up';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(height: 12.h),
          OrderCodeHeader(order: order),
          SizedBox(height: 16.h),
          OrderStatusStrip(order: order),
          SizedBox(height: 24.h),
          if (showOtp) ...<Widget>[
            PickupOtpTeaser(
              order: order,
              detailState: detailState,
              onTapFullscreen: onTapOtpFullscreen,
            ),
            Divider(color: dividerColor, height: 32.h),
          ],
          if (order.items.isNotEmpty) ...<Widget>[
            ItemsSection(order: order),
            Divider(color: dividerColor, height: 32.h),
          ],
          AddressSection(order: order),
          Divider(color: dividerColor, height: 32.h),
          ClientSection(order: order),
          Divider(color: dividerColor, height: 32.h),
          SummarySection(order: order),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }
}
