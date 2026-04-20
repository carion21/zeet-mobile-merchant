// lib/screens/products/widgets/product_detail_helpers.dart
//
// Helpers UI partages par les form sheets du detail produit : ligne
// Annuler/Valider avec spinner de soumission.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Ligne de boutons Annuler + Enregistrer/Creer, avec spinner pendant la
/// soumission. Utilisee par les 4 form sheets (produit / variante / groupe /
/// item d'option).
class ProductFormActionsRow extends StatelessWidget {
  const ProductFormActionsRow({
    required this.submitting,
    required this.onSubmit,
    required this.submitLabel,
    super.key,
  });

  final bool submitting;
  final VoidCallback onSubmit;
  final String submitLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton(
            onPressed:
                submitting ? null : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 14.h),
            ),
            child: const Text('Annuler'),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: FilledButton(
            onPressed: submitting ? null : onSubmit,
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
                : Text(submitLabel),
          ),
        ),
      ],
    );
  }
}

/// Validateur generique : "champ requis" si vide apres trim.
String? requiredValidator(String? v, {String message = 'Nom requis'}) {
  return (v == null || v.trim().isEmpty) ? message : null;
}

/// Validateur entier signed : "0 possible" mais doit etre un int valide.
String? signedIntValidator(String? v) {
  if (v == null || v.trim().isEmpty) {
    return 'Supplement requis (0 possible)';
  }
  if (int.tryParse(v.trim()) == null) {
    return 'Entier valide requis';
  }
  return null;
}
