// lib/screens/products/widgets/product_detail_variants.dart
//
// Section Variantes du detail produit : liste + tuile + CTA ajouter.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/models/product_model.dart';

class ProductDetailVariantsSection extends StatelessWidget {
  const ProductDetailVariantsSection({
    required this.productId,
    required this.variants,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final int productId;
  final List<ProductVariant> variants;
  final VoidCallback onAdd;
  final void Function(ProductVariant) onEdit;
  final void Function(ProductVariant) onDelete;

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
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 8.w, 4.h),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Variantes (${variants.length})',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
                ),
              ],
            ),
          ),
          if (variants.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
              child: Text(
                'Aucune variante. Ajoute des tailles, portions ou options principales.',
                style: tt.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...variants.map((ProductVariant v) => _VariantTile(
                  variant: v,
                  onEdit: () => onEdit(v),
                  onDelete: () => onDelete(v),
                )),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }
}

class _VariantTile extends StatelessWidget {
  const _VariantTile({
    required this.variant,
    required this.onEdit,
    required this.onDelete,
  });

  final ProductVariant variant;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;

    final String deltaText = variant.priceDelta == 0
        ? 'Aucun supplement'
        : '${variant.priceDelta > 0 ? '+' : ''}${variant.priceDelta} FCFA';

    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w),
      title: Text(
        variant.name,
        style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        <String>[
          deltaText,
          if (variant.description != null &&
              variant.description!.isNotEmpty)
            variant.description!,
        ].join(' • '),
        style: tt.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: 'Modifier',
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: 'Supprimer',
            icon: Icon(
              Icons.delete_outline,
              color: AppColors.error,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
