// lib/screens/products/widgets/product_detail_header.dart
//
// Header card du detail produit : image principale, nom/prix/categorie,
// description, toggle de disponibilite et bouton d'edition.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/models/product_model.dart';
import 'package:zeet_ui/zeet_ui.dart';

class ProductDetailHeader extends StatelessWidget {
  const ProductDetailHeader({
    required this.product,
    required this.onEdit,
    required this.onToggleAvailability,
    required this.onUploadPicture,
    super.key,
  });

  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onToggleAvailability;
  final VoidCallback onUploadPicture;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Image
          GestureDetector(
            onTap: onUploadPicture,
            child: Container(
              height: 180.h,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.r),
                  topRight: Radius.circular(16.r),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (product.mainImage != null &&
                      product.mainImage!.isNotEmpty)
                    Hero(
                      tag: 'product-${product.id}',
                      child: ZeetImage(
                        url: product.mainImage,
                        fit: BoxFit.cover,
                        errorWidget: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 40.r,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  else
                    Center(
                      child: Icon(
                        Icons.add_a_photo_outlined,
                        size: 40.r,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 10.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius:
                            BorderRadius.circular(ZeetRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const <Widget>[
                          Icon(Icons.camera_alt_outlined,
                              color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Modifier',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        product.name,
                        style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Modifier le produit',
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: ZeetMoney(
                    amount: product.price.toDouble(),
                    currency: ZeetCurrency.fcfa,
                    style: tt.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (product.categoryLabel != null) ...<Widget>[
                  SizedBox(height: 4.h),
                  Text(
                    product.categoryLabel!,
                    style: tt.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (product.description != null &&
                    product.description!.isNotEmpty) ...<Widget>[
                  SizedBox(height: 12.h),
                  Text(
                    product.description!,
                    style: tt.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                SizedBox(height: 12.h),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: product.available,
                  activeThumbColor: AppColors.primary,
                  onChanged: (_) => onToggleAvailability(),
                  title: Text(
                    product.available
                        ? 'Produit disponible'
                        : 'Produit indisponible',
                    style: tt.bodyLarge,
                  ),
                  subtitle: Text(
                    product.available
                        ? 'Visible et commandable'
                        : 'Masque pour les clients',
                    style: tt.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
