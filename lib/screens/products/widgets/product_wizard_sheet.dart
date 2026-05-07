// lib/screens/products/widgets/product_wizard_sheet.dart
//
// Wizard 3 etapes pour creer un produit. Pattern POS partner (skill
// `zeet-pos-ergonomics` §form-multistep) : remplace le formulaire mono-page
// par 3 ecrans focalises (un seul concept par etape) + brouillon
// auto-sauve dans SharedPreferences pour resume si l'app est tuee.
//
// Etapes :
//   1. Identite : nom + categorie (obligatoires)
//   2. Prix : montant FCFA (obligatoire)
//   3. Description + recap : description optionnelle + apercu final
//
// Brouillon : cle `partner_product_draft_v1` ecrite a chaque next-step,
// purgee a la creation reussie ou a l'annulation explicite (bouton X).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/core/tokens/durations.dart';
import 'package:merchant/models/category_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeet_ui/zeet_ui.dart';

const String _draftKey = 'partner_product_draft_v1';

class ProductWizardSheet extends StatefulWidget {
  const ProductWizardSheet({
    super.key,
    required this.categories,
    required this.onSubmit,
  });

  final List<CategorySelect> categories;
  final Future<void> Function({
    required String name,
    required int price,
    required int categoryId,
    String? description,
  }) onSubmit;

  @override
  State<ProductWizardSheet> createState() => _ProductWizardSheetState();
}

class _ProductWizardSheetState extends State<ProductWizardSheet> {
  static const int _stepCount = 3;
  int _currentStep = 0;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  int? _categoryId;
  bool _submitting = false;
  bool _draftLoaded = false;

  final GlobalKey<FormState> _step1Key = GlobalKey<FormState>();
  final GlobalKey<FormState> _step2Key = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _categoryId = widget.categories.isNotEmpty
        ? widget.categories.first.id
        : null;
    _restoreDraft();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _restoreDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null) {
      if (mounted) setState(() => _draftLoaded = true);
      return;
    }
    try {
      final Map<String, dynamic> data =
          jsonDecode(raw) as Map<String, dynamic>;
      _nameCtrl.text = (data['name'] as String?) ?? '';
      _priceCtrl.text = (data['price'] as String?) ?? '';
      _descCtrl.text = (data['description'] as String?) ?? '';
      final int? draftCat = data['category_id'] as int?;
      if (draftCat != null &&
          widget.categories.any((CategorySelect c) => c.id == draftCat)) {
        _categoryId = draftCat;
      }
    } catch (_) {
      // Brouillon corrompu : on ignore.
    }
    if (mounted) setState(() => _draftLoaded = true);
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _draftKey,
      jsonEncode(<String, dynamic>{
        'name': _nameCtrl.text,
        'price': _priceCtrl.text,
        'description': _descCtrl.text,
        'category_id': _categoryId,
      }),
    );
  }

  Future<void> _purgeDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  void _next() {
    if (_currentStep == 0) {
      if (!(_step1Key.currentState?.validate() ?? false)) return;
      if (_categoryId == null) return;
    } else if (_currentStep == 1) {
      if (!(_step2Key.currentState?.validate() ?? false)) return;
    }
    _saveDraft();
    ZeetHaptics.tap();
    setState(() => _currentStep += 1);
  }

  void _back() {
    if (_currentStep == 0) return;
    ZeetHaptics.tap();
    setState(() => _currentStep -= 1);
  }

  Future<void> _submit() async {
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
      await _purgeDraft();
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancel() async {
    final bool hasDraft = _nameCtrl.text.isNotEmpty ||
        _priceCtrl.text.isNotEmpty ||
        _descCtrl.text.isNotEmpty;
    if (!hasDraft) {
      Navigator.of(context).pop();
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Abandonner le brouillon ?'),
        content: const Text(
          'Ce que vous avez saisi sera perdu. Vous pouvez aussi fermer cette feuille pour reprendre plus tard.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Garder le brouillon'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Abandonner',
              style: TextStyle(color: ZeetColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _purgeDraft();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    if (!_draftLoaded) {
      return SizedBox(
        height: 240.h,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 8.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _stepTitle(_currentStep),
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: _submitting ? null : _cancel,
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Fermer',
              ),
            ],
          ),
          SizedBox(height: 8.h),
          _StepperBar(
            currentStep: _currentStep,
            stepCount: _stepCount,
            color: scheme.primary,
            background: scheme.outlineVariant,
          ),
          SizedBox(height: 16.h),
          AnimatedSize(
            duration: ZeetDuration.std,
            curve: Curves.easeOut,
            child: _buildStepBody(),
          ),
          SizedBox(height: 16.h),
          _NavRow(
            currentStep: _currentStep,
            stepCount: _stepCount,
            submitting: _submitting,
            onBack: _currentStep == 0 ? null : _back,
            onNext: _currentStep == _stepCount - 1 ? _submit : _next,
            nextLabel: _currentStep == _stepCount - 1
                ? 'Créer'
                : 'Continuer',
          ),
        ],
      ),
    );
  }

  String _stepTitle(int step) {
    switch (step) {
      case 0:
        return 'Identité du produit';
      case 1:
        return 'Prix de vente';
      case 2:
        return 'Description et récap';
      default:
        return 'Nouveau produit';
    }
  }

  Widget _buildStepBody() {
    switch (_currentStep) {
      case 0:
        return _buildIdentityStep();
      case 1:
        return _buildPriceStep();
      case 2:
        return _buildRecapStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildIdentityStep() {
    return Form(
      key: _step1Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nom *',
              hintText: 'Ex. Poulet braisé, Tiep djeun…',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Nom requis' : null,
          ),
          SizedBox(height: 12.h),
          DropdownButtonFormField<int>(
            initialValue: _categoryId,
            decoration: const InputDecoration(
              labelText: 'Catégorie *',
              border: OutlineInputBorder(),
            ),
            items: widget.categories
                .map((CategorySelect c) => DropdownMenuItem<int>(
                      value: c.id,
                      child: Text(c.label),
                    ))
                .toList(),
            onChanged: (int? v) => setState(() => _categoryId = v),
            validator: (int? v) =>
                v == null ? 'Catégorie requise' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceStep() {
    return Form(
      key: _step2Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextFormField(
            controller: _priceCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Prix (FCFA) *',
              hintText: 'Ex. 3000',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            textInputAction: TextInputAction.done,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Prix requis';
              final int? parsed = int.tryParse(v.trim());
              if (parsed == null || parsed <= 0) return 'Prix invalide';
              return null;
            },
          ),
          SizedBox(height: 8.h),
          Text(
            'Le prix s\'affiche client TTC. La commission ZEET est déduite au paiement.',
            style: TextStyle(
              fontSize: 12.sp,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecapStep() {
    final TextTheme tt = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String catLabel = widget.categories
        .firstWhere(
          (CategorySelect c) => c.id == _categoryId,
          orElse: () => widget.categories.isNotEmpty
              ? widget.categories.first
              : const CategorySelect(id: 0, label: '—'),
        )
        .label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextFormField(
          controller: _descCtrl,
          decoration: const InputDecoration(
            labelText: 'Description (optionnelle)',
            hintText: 'Petite phrase qui donne envie au client…',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        SizedBox(height: 16.h),
        Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(ZeetRadius.md),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Récapitulatif',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8.h),
              _RecapLine(label: 'Nom', value: _nameCtrl.text.trim()),
              _RecapLine(label: 'Catégorie', value: catLabel),
              _RecapLine(
                label: 'Prix',
                value: '${_priceCtrl.text.trim()} FCFA',
              ),
              if (_descCtrl.text.trim().isNotEmpty)
                _RecapLine(
                  label: 'Description',
                  value: _descCtrl.text.trim(),
                  multiline: true,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepperBar extends StatelessWidget {
  const _StepperBar({
    required this.currentStep,
    required this.stepCount,
    required this.color,
    required this.background,
  });

  final int currentStep;
  final int stepCount;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(stepCount, (int i) {
        final bool active = i <= currentStep;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: i == 0 ? 0 : 4.w),
            child: AnimatedContainer(
              duration: ZeetDuration.std,
              curve: Curves.easeOut,
              height: 4.h,
              decoration: BoxDecoration(
                color: active ? color : background,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.currentStep,
    required this.stepCount,
    required this.submitting,
    required this.onBack,
    required this.onNext,
    required this.nextLabel,
  });

  final int currentStep;
  final int stepCount;
  final bool submitting;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        if (onBack != null) ...<Widget>[
          Expanded(
            child: OutlinedButton(
              onPressed: submitting ? null : onBack,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14.h),
              ),
              child: const Text('Retour'),
            ),
          ),
          SizedBox(width: 12.w),
        ],
        Expanded(
          flex: onBack == null ? 1 : 2,
          child: FilledButton(
            onPressed: submitting ? null : onNext,
            style: FilledButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 14.h),
            ),
            child: submitting
                ? SizedBox(
                    width: 20.r,
                    height: 20.r,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    nextLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }
}

class _RecapLine extends StatelessWidget {
  const _RecapLine({
    required this.label,
    required this.value,
    this.multiline = false,
  });

  final String label;
  final String value;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 90.w,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(
                fontSize: 14.sp,
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              maxLines: multiline ? 4 : 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
