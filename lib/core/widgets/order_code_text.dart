import 'package:flutter/material.dart';

import 'package:merchant/core/utils/order_code.dart';

/// Affiche un code commande de façon responsive :
/// - si la largeur disponible permet d'écrire le code **complet** sur une
///   ligne, on l'affiche en entier (référence sans ambiguïté)
/// - sinon on retombe sur `#…<9 derniers chars>` (assez pour l'énoncer au
///   téléphone, garanti 1 ligne sans ellipsis)
///
/// À placer dans un parent avec largeur bornée ([Flexible], [Expanded],
/// [SizedBox]…) — sinon [LayoutBuilder] reçoit une contrainte infinie et le
/// code complet est toujours affiché.
class OrderCodeText extends StatelessWidget {
  const OrderCodeText({
    super.key,
    required this.code,
    this.style,
    this.keep = 9,
    this.textAlign,
  });

  /// Code brut renvoyé par le backend (peut ou non commencer par `#`).
  final String code;

  /// Style appliqué au texte. Utilisé aussi pour **mesurer** si le code
  /// complet rentre, donc doit refléter la fonte/size réels pour être juste.
  final TextStyle? style;

  /// Nombre de caractères conservés en fallback court (défaut 9).
  final int keep;

  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final TextStyle effective =
        DefaultTextStyle.of(context).style.merge(style);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final String full = fullOrderCode(code);
        if (full.isEmpty) return const SizedBox.shrink();

        // Sans contrainte de largeur (infinie), on affiche le code complet.
        // Le LayoutBuilder n'a aucun signal de serrage — l'appelant doit
        // borner la largeur pour que le fallback court se déclenche.
        String display = full;
        if (constraints.maxWidth.isFinite) {
          final TextPainter painter = TextPainter(
            text: TextSpan(text: full, style: effective),
            textDirection: Directionality.of(context),
            maxLines: 1,
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          // +0.5 de tolérance pour absorber les arrondis sub-pixel.
          final bool fits = painter.width <= constraints.maxWidth + 0.5;
          painter.dispose();
          if (!fits) {
            display = shortOrderCode(code, keep: keep);
          }
        }

        return Text(
          display,
          style: style,
          textAlign: textAlign,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
