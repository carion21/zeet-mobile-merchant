// lib/screens/products/widgets/product_option_item_form_sheet.dart
//
// Bottom sheet creation / edition d'un item (option) dans un groupe.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/models/product_model.dart';
import 'package:merchant/screens/products/widgets/product_detail_helpers.dart';

class ProductOptionItemFormSheet extends StatefulWidget {
  const ProductOptionItemFormSheet({
    this.initial,
    required this.onSubmit,
    super.key,
  });

  final ProductOptionItem? initial;

  /// (name, priceDelta, description?)
  final Future<void> Function(
          String name, int priceDelta, String? description)
      onSubmit;

  @override
  State<ProductOptionItemFormSheet> createState() =>
      _ProductOptionItemFormSheetState();
}

class _ProductOptionItemFormSheetState
    extends State<ProductOptionItemFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _deltaCtrl;
  late final TextEditingController _descCtrl;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.initial?.name ?? '');
    _deltaCtrl = TextEditingController(
        text: widget.initial?.priceDelta.toString() ?? '0');
    _descCtrl = TextEditingController(
        text: widget.initial?.description ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _deltaCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    final bool isEdit = widget.initial != null;

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
              isEdit
                  ? 'Modifier l\'option'
                  : 'Nouvelle option',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 16.h),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom *',
                hintText: 'Ex. Frites, Salade, Ketchup…',
                border: OutlineInputBorder(),
              ),
              validator: requiredValidator,
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _deltaCtrl,
              decoration: const InputDecoration(
                labelText: 'Supplement prix (FCFA)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                  signed: true),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
              ],
              validator: signedIntValidator,
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optionnel)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            SizedBox(height: 20.h),
            ProductFormActionsRow(
              submitting: _submitting,
              onSubmit: _submit,
              submitLabel: isEdit ? 'Enregistrer' : 'Creer',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        _nameCtrl.text.trim(),
        int.parse(_deltaCtrl.text.trim()),
        _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
