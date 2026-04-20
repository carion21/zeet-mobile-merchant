// lib/screens/products/widgets/product_edit_sheet.dart
//
// Bottom sheet d'edition du produit (nom, prix, categorie, description).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/models/category_model.dart';
import 'package:merchant/models/product_model.dart';
import 'package:merchant/screens/products/widgets/product_detail_helpers.dart';

class ProductEditSheet extends StatefulWidget {
  const ProductEditSheet({
    required this.initial,
    required this.categories,
    required this.onSubmit,
    super.key,
  });

  final Product initial;
  final List<CategorySelect> categories;
  final Future<void> Function({
    required String name,
    required int price,
    required int categoryId,
    String? description,
  }) onSubmit;

  @override
  State<ProductEditSheet> createState() => _ProductEditSheetState();
}

class _ProductEditSheetState extends State<ProductEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _descCtrl;
  int? _categoryId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initial.name);
    _priceCtrl =
        TextEditingController(text: widget.initial.price.toString());
    _descCtrl = TextEditingController(
        text: widget.initial.description ?? '');
    _categoryId = widget.initial.categoryId ??
        (widget.categories.isNotEmpty
            ? widget.categories.first.id
            : null);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 8.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24.h,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Modifier le produit',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 16.h),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom *',
                border: OutlineInputBorder(),
              ),
              validator: requiredValidator,
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _priceCtrl,
              decoration: const InputDecoration(
                labelText: 'Prix (FCFA) *',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Prix requis';
                final int? parsed = int.tryParse(v.trim());
                if (parsed == null || parsed <= 0) return 'Prix invalide';
                return null;
              },
            ),
            SizedBox(height: 12.h),
            if (widget.categories.isNotEmpty)
              DropdownButtonFormField<int>(
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Categorie *',
                  border: OutlineInputBorder(),
                ),
                items: widget.categories
                    .map((CategorySelect c) => DropdownMenuItem<int>(
                          value: c.id,
                          child: Text(c.label),
                        ))
                    .toList(),
                onChanged: (int? v) =>
                    setState(() => _categoryId = v),
                validator: (v) =>
                    v == null ? 'Categorie requise' : null,
              ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 20.h),
            ProductFormActionsRow(
              submitting: _submitting,
              onSubmit: _submit,
              submitLabel: 'Enregistrer',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_categoryId == null) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        name: _nameCtrl.text.trim(),
        price: int.parse(_priceCtrl.text.trim()),
        categoryId: _categoryId!,
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
