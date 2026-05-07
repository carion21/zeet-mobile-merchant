// lib/screens/order_details/steps/preparing_layout.dart
//
// Layout step "En préparation" — la commande est lancee en cuisine.
// Hierarchie :
// 1. Code commande + statut (timer integre dans le strip)
// 2. ARTICLES HERO (la cuisine consulte cette section en boucle)
// 3. Adresse (en cas de question rider)
// 4. Client (joignable)
// 5. Remuneration (compact)
//
// CTA hero : "Marquer prête" (gere par DynamicActionBar bas).

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/models/order_model.dart';
import 'package:merchant/screens/order_details/widgets/address_section.dart';
import 'package:merchant/screens/order_details/widgets/client_section.dart';
import 'package:merchant/screens/order_details/widgets/items_section.dart';
import 'package:merchant/screens/order_details/widgets/order_code_header.dart';
import 'package:merchant/screens/order_details/widgets/order_status_strip.dart';
import 'package:merchant/screens/order_details/widgets/summary_section.dart';

class PreparingLayout extends StatelessWidget {
  const PreparingLayout({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color dividerColor = scheme.outlineVariant;

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
