// lib/screens/order_details/widgets/items_section.dart
//
// Liste des articles d'une commande avec quantite, variant, options et prix
// total par ligne. Pas d'image volontaire (densite info > photo).

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/models/order_model.dart';
import 'package:zeet_ui/zeet_ui.dart';

class ItemsSection extends StatelessWidget {
  const ItemsSection({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    if (order.items.isEmpty) return const SizedBox.shrink();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color textColor = scheme.onSurface;
    final Color textLightColor = scheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Articles (${order.items.length})',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        SizedBox(height: 16.h),
        ...List<Widget>.generate(order.items.length, (int index) {
          final item = order.items[index];
          final double itemTotal = item.totalPrice ??
              ((item.unitPrice ?? 0) * item.quantity);
          return Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    '${item.quantity}x',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.productName ?? 'Produit #${item.productId}',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      if (item.variantName != null)
                        Text(
                          item.variantName!,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: textLightColor,
                          ),
                        ),
                      if (item.options.isNotEmpty)
                        ...item.options.map((opt) => Text(
                              '+ ${opt.name ?? 'Option'}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: textLightColor,
                              ),
                            )),
                    ],
                  ),
                ),
                ZeetMoney(
                  amount: itemTotal,
                  currency: ZeetCurrency.fcfa,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
