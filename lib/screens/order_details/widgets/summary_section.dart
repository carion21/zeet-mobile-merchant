// lib/screens/order_details/widgets/summary_section.dart
//
// Resume financier oriente partenaire : ce qui compte, c'est ce que le
// restaurateur touche, pas les frais de livraison ZEET facture au client.
// Net partenaire = `netAmount` backend si fourni, sinon calcule local
// (`subtotal - discount - commission`).

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/models/order_model.dart';
import 'package:zeet_ui/zeet_ui.dart';

class SummarySection extends StatelessWidget {
  const SummarySection({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color textColor = scheme.onSurface;
    final Color textLightColor = scheme.onSurfaceVariant;

    final double? netToPartner = order.netAmount ??
        _computeNetAmount(
          subtotal: order.subtotal,
          discount: order.discount,
          commission: order.commission,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Rémunération',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        SizedBox(height: 16.h),
        if (order.subtotal != null) ...<Widget>[
          _PriceRow(
            label: 'Sous-total articles',
            amount: order.subtotal!,
            textColor: textColor,
            textLightColor: textLightColor,
          ),
          SizedBox(height: 8.h),
        ],
        if (order.discount != null && order.discount! > 0) ...<Widget>[
          _PriceRow(
            label: 'Réduction',
            amount: -order.discount!,
            textColor: textColor,
            textLightColor: textLightColor,
          ),
          SizedBox(height: 8.h),
        ],
        if (order.commission != null && order.commission! > 0) ...<Widget>[
          _PriceRow(
            label: 'Commission ZEET',
            amount: -order.commission!,
            textColor: textColor,
            textLightColor: textLightColor,
          ),
          SizedBox(height: 8.h),
        ],
        SizedBox(height: 8.h),
        if (netToPartner != null)
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Vous touchez',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Crédité sur votre portefeuille',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: textLightColor,
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
                      amount: netToPartner,
                      currency: ZeetCurrency.fcfa,
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Total commande',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: textColor,
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
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  double? _computeNetAmount({
    required double? subtotal,
    required double? discount,
    required double? commission,
  }) {
    if (subtotal == null) return null;
    double net = subtotal;
    if (discount != null && discount > 0) net -= discount;
    if (commission != null && commission > 0) net -= commission;
    return net < 0 ? 0 : net;
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.amount,
    required this.textColor,
    required this.textLightColor,
  });

  final String label;
  final double amount;
  final Color textColor;
  final Color textLightColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15.sp, color: textLightColor),
          ),
        ),
        SizedBox(width: 8.w),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: ZeetMoney(
              amount: amount,
              currency: ZeetCurrency.fcfa,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
