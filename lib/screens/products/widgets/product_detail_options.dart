// lib/screens/products/widgets/product_detail_options.dart
//
// Section Groupes d'options du detail produit : liste de groupes
// avec leurs items, plus CTA d'ajout/edition/suppression.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/models/product_model.dart';

class ProductDetailOptionGroupsSection extends StatelessWidget {
  const ProductDetailOptionGroupsSection({
    required this.productId,
    required this.groups,
    required this.onAddGroup,
    required this.onEditGroup,
    required this.onDeleteGroup,
    required this.onAddItem,
    required this.onEditItem,
    required this.onDeleteItem,
    super.key,
  });

  final int productId;
  final List<ProductOptionGroup> groups;
  final VoidCallback onAddGroup;
  final void Function(ProductOptionGroup) onEditGroup;
  final void Function(ProductOptionGroup) onDeleteGroup;
  final void Function(ProductOptionGroup) onAddItem;
  final void Function(ProductOptionGroup, ProductOptionItem) onEditItem;
  final void Function(ProductOptionGroup, ProductOptionItem) onDeleteItem;

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
                    'Groupes d\'options (${groups.length})',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onAddGroup,
                  icon: const Icon(Icons.add),
                  label: const Text('Groupe'),
                ),
              ],
            ),
          ),
          if (groups.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
              child: Text(
                'Aucun groupe. Cree des groupes comme "Accompagnement" ou "Sauce".',
                style: tt.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...groups.map((ProductOptionGroup g) => _OptionGroupCard(
                  group: g,
                  onEdit: () => onEditGroup(g),
                  onDelete: () => onDeleteGroup(g),
                  onAddItem: () => onAddItem(g),
                  onEditItem: (i) => onEditItem(g, i),
                  onDeleteItem: (i) => onDeleteItem(g, i),
                )),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }
}

class _OptionGroupCard extends StatelessWidget {
  const _OptionGroupCard({
    required this.group,
    required this.onEdit,
    required this.onDelete,
    required this.onAddItem,
    required this.onEditItem,
    required this.onDeleteItem,
  });

  final ProductOptionGroup group;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddItem;
  final void Function(ProductOptionItem) onEditItem;
  final void Function(ProductOptionItem) onDeleteItem;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;

    final String constraints = <String>[
      if (group.required) 'requis',
      if (group.minSelect > 0) 'min ${group.minSelect}',
      if (group.maxSelect > 0) 'max ${group.maxSelect}',
      if (group.allowDuplicate) 'duplic.',
    ].join(' • ');

    return Container(
      margin: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 8.h),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: <Widget>[
          ListTile(
            title: Text(
              group.name,
              style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            subtitle: constraints.isEmpty
                ? null
                : Text(
                    constraints,
                    style: tt.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
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
          ),
          if (group.items.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
              child: Text(
                'Aucune option dans ce groupe.',
                style: tt.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...group.items.map((ProductOptionItem i) => ListTile(
                  contentPadding: EdgeInsets.only(
                    left: 32.w,
                    right: 8.w,
                  ),
                  dense: true,
                  title: Text(
                    i.name,
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    i.priceDelta == 0
                        ? 'Sans supplement'
                        : '${i.priceDelta > 0 ? '+' : ''}${i.priceDelta} FCFA',
                    style: tt.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Modifier',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 20,
                        ),
                        onPressed: () => onEditItem(i),
                      ),
                      IconButton(
                        tooltip: 'Supprimer',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: AppColors.error,
                        ),
                        onPressed: () => onDeleteItem(i),
                      ),
                    ],
                  ),
                )),
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 8.w, 8.h),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAddItem,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter une option'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
