// lib/screens/order_details/steps/terminal_layout.dart
//
// Layout pour les statuts terminaux (delivered, cancelled, rejected). Pas
// d'action restante cote partner — le focus est sur l'historique pour
// permettre de relire la sequence et les performances.
//
// Hierarchie :
// 1. Code commande + statut final
// 2. Articles + remuneration (recap)
// 3. Adresse + client (archive)
// 4. HISTORIQUE HERO (logs + perf timer)

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/models/order_model.dart';
import 'package:merchant/screens/order_details/widgets/address_section.dart';
import 'package:merchant/screens/order_details/widgets/client_section.dart';
import 'package:merchant/screens/order_details/widgets/items_section.dart';
import 'package:merchant/screens/order_details/widgets/logs_section.dart';
import 'package:merchant/screens/order_details/widgets/order_code_header.dart';
import 'package:merchant/screens/order_details/widgets/order_status_strip.dart';
import 'package:merchant/screens/order_details/widgets/summary_section.dart';

class TerminalLayout extends StatelessWidget {
  const TerminalLayout({super.key, required this.order});

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
          SummarySection(order: order),
          Divider(color: dividerColor, height: 32.h),
          AddressSection(order: order),
          Divider(color: dividerColor, height: 32.h),
          ClientSection(order: order),
          if (order.logs.isNotEmpty || order.timings != null) ...<Widget>[
            Divider(color: dividerColor, height: 32.h),
            LogsSection(order: order),
          ],
          SizedBox(height: 24.h),
        ],
      ),
    );
  }
}
