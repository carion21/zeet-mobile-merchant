// lib/screens/order_details/widgets/address_section.dart
//
// Adresse de livraison + note client (italique). Source : `position.dropoff
// _address` ou fallback `deliveryAddress`.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/core/constants/icons.dart';
import 'package:merchant/models/order_model.dart';

class AddressSection extends StatelessWidget {
  const AddressSection({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color textColor = scheme.onSurface;
    final Color textLightColor = scheme.onSurfaceVariant;
    final String address = order.position?.dropoffAddress ??
        order.deliveryAddress ??
        'Adresse non renseignee';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Adresse de livraison',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        SizedBox(height: 16.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            IconManager.getIcon(
              'location',
              color: AppColors.primary,
              size: 20.r,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                address,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: textLightColor,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        if (order.noteCustomer != null &&
            order.noteCustomer!.isNotEmpty) ...<Widget>[
          SizedBox(height: 12.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              IconManager.getIcon(
                'note',
                color: textLightColor,
                size: 20.r,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  order.noteCustomer!,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: textLightColor,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
