// lib/screens/order_details/widgets/pickup_otp_teaser.dart
//
// Teaser compact qui invite a ouvrir le plein ecran ou affiche un preview
// discret du code si deja recupere. La lisibilite a 1m est dans
// `PickupOtpFullscreen` (Phase 2 gap #2).

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/models/order_model.dart';
import 'package:merchant/providers/orders_provider.dart';
import 'package:zeet_ui/zeet_ui.dart';

class PickupOtpTeaser extends StatelessWidget {
  const PickupOtpTeaser({
    super.key,
    required this.order,
    required this.detailState,
    required this.onTapFullscreen,
  });

  final Order order;
  final OrderDetailState detailState;
  final VoidCallback onTapFullscreen;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color textColor = scheme.onSurface;
    final Color textLightColor = scheme.onSurfaceVariant;
    final String? otp = detailState.pickupOtp?.otp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Code de collecte',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        SizedBox(height: 12.h),
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: <Widget>[
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  Icons.vpn_key_outlined,
                  color: AppColors.primary,
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      otp != null
                          ? 'Code disponible — tapez pour l\'afficher en grand'
                          : 'Le code est genere automatiquement.',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: textLightColor,
                        height: 1.3,
                      ),
                    ),
                    if (otp != null) ...<Widget>[
                      SizedBox(height: 4.h),
                      Text(
                        otp,
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: 4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        ZeetButton.primary(
          label: 'Afficher le code en grand',
          icon: Icons.fullscreen_rounded,
          size: ZeetButtonSize.lg,
          fullWidth: true,
          onPressed: onTapFullscreen,
        ),
      ],
    );
  }
}
