// lib/screens/order_details/widgets/passive_info_bar.dart
//
// Ligne d'info affichee a la place de la ZeetActionBar quand il n'y a
// aucune action utilisateur cote partner (ready / picked_up / on-the-way).
// Anti-pattern POS : ne pas afficher un bouton mort.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/core/constants/icons.dart';
import 'package:merchant/models/order_model.dart';

class PassiveInfoBar extends StatelessWidget {
  const PassiveInfoBar({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconManager.getIcon('info', size: 20.r, color: AppColors.textLight),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            order.status == 'ready'
                ? 'En attente du livreur'
                : 'Le livreur est en route',
            style: TextStyle(fontSize: 14.sp, color: AppColors.textLight),
          ),
        ),
      ],
    );
  }
}
