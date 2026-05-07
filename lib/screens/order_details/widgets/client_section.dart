// lib/screens/order_details/widgets/client_section.dart
//
// Card client : nom + telephone + bouton appel direct. Couleur tile aligne
// sur le token semantique ZEET success (#10B981).

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/core/constants/icons.dart';
import 'package:merchant/core/utils/phone_launcher.dart';
import 'package:merchant/models/order_model.dart';
import 'package:zeet_ui/zeet_ui.dart';

class ClientSection extends StatelessWidget {
  const ClientSection({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color textColor = scheme.onSurface;
    final Color textLightColor = scheme.onSurfaceVariant;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: IconManager.getIcon(
              'person_outline',
              color: AppColors.success,
              size: 24.r,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  order.customerName,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                if (order.customerPhone.isNotEmpty) ...<Widget>[
                  SizedBox(height: 4.h),
                  Text(
                    order.customerPhone,
                    style: TextStyle(fontSize: 14.sp, color: textLightColor),
                  ),
                ],
              ],
            ),
          ),
          if (order.customerPhone.isNotEmpty)
            IconButton(
              icon: IconManager.getIcon(
                'phone',
                size: 24.r,
                color: AppColors.primary,
              ),
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
      ),
    );
  }
}
