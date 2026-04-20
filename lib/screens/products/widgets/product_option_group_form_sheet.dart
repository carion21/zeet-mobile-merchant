// lib/screens/products/widgets/product_option_group_form_sheet.dart
//
// Bottom sheet creation / edition d'un groupe d'options (contraintes
// min/max, required, duplicats).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/models/product_model.dart';
import 'package:merchant/screens/products/widgets/product_detail_helpers.dart';

class ProductOptionGroupFormSheet extends StatefulWidget {
  const ProductOptionGroupFormSheet({
    this.initial,
    required this.onSubmit,
    super.key,
  });

  final ProductOptionGroup? initial;

  /// (name, required, allowDuplicate, minSelect, maxSelect)
  final Future<void> Function(
    String name,
    bool required,
    bool allowDuplicate,
    int minSelect,
    int maxSelect,
  ) onSubmit;

  @override
  State<ProductOptionGroupFormSheet> createState() =>
      _ProductOptionGroupFormSheetState();
}

class _ProductOptionGroupFormSheetState
    extends State<ProductOptionGroupFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;
  late bool _required;
  late bool _allowDuplicate;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.initial?.name ?? '');
    _minCtrl = TextEditingController(
        text: widget.initial?.minSelect.toString() ?? '0');
    _maxCtrl = TextEditingController(
        text: widget.initial?.maxSelect.toString() ?? '0');
    _required = widget.initial?.required ?? false;
    _allowDuplicate = widget.initial?.allowDuplicate ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
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
                  ? 'Modifier le groupe'
                  : 'Nouveau groupe d\'options',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 16.h),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom *',
                hintText: 'Ex. Accompagnement, Sauce, Cuisson…',
                border: OutlineInputBorder(),
              ),
              validator: requiredValidator,
            ),
            SizedBox(height: 12.h),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _minCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Min selection',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: TextFormField(
                    controller: _maxCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Max selection',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Groupe requis'),
              subtitle: const Text(
                'Le client doit choisir au moins une option',
              ),
              value: _required,
              onChanged: (v) => setState(() => _required = v),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Duplicats autorises'),
              subtitle: const Text(
                'Le client peut choisir plusieurs fois la meme option',
              ),
              value: _allowDuplicate,
              onChanged: (v) => setState(() => _allowDuplicate = v),
            ),
            SizedBox(height: 16.h),
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
        _required,
        _allowDuplicate,
        int.tryParse(_minCtrl.text.trim()) ?? 0,
        int.tryParse(_maxCtrl.text.trim()) ?? 0,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
