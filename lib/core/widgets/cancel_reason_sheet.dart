// lib/core/widgets/cancel_reason_sheet.dart
//
// Bottom sheet de motif de refus / annulation de commande.
//
// Remplace les `AlertDialog + TextField(maxLines: 3)` dupliqués dans
// `home`, `orders`, `order_details` et `incoming_order`. La saisie
// clavier libre est proscrite en ergonomie POS partner (cuisine,
// doigts gras, coup de feu) — le partenaire choisit un motif dans
// une liste de preset. Le champ texte libre n'est proposé qu'en
// dernier recours ("Autre").
//
// Voir skills : `zeet-pos-ergonomics` §3, `zeet-micro-copy` §4.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zeet_ui/zeet_ui.dart';

/// Affiche le bottom sheet et retourne le motif choisi, ou `null`
/// si l'utilisateur annule.
///
/// Le motif retourné est TOUJOURS non vide : soit un preset,
/// soit un texte libre non vide saisi après sélection d'« Autre ».
Future<String?> showCancelReasonSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(ZeetRadius.lg),
      ),
    ),
    builder: (_) => const _CancelReasonSheet(),
  );
}

class _CancelReasonSheet extends StatefulWidget {
  const _CancelReasonSheet();

  @override
  State<_CancelReasonSheet> createState() => _CancelReasonSheetState();
}

class _CancelReasonSheetState extends State<_CancelReasonSheet> {
  static const List<String> _presets = <String>[
    'Rupture de stock',
    'Trop de commandes',
    'Produit indisponible',
    'Fermeture exceptionnelle',
  ];

  bool _showFreeText = false;
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectPreset(String reason) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(reason);
  }

  void _openFreeText() {
    HapticFeedback.selectionClick();
    setState(() => _showFreeText = true);
  }

  void _submitFreeText() {
    final String trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ZeetSpacing.x4,
            ZeetSpacing.x3,
            ZeetSpacing.x4,
            ZeetSpacing.x4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Handle visuel.
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(ZeetRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: ZeetSpacing.x4),

              // Titre.
              Text(
                'Motif du refus',
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: ZeetSpacing.x1),
              Text(
                'Le client sera informé du motif choisi.',
                style: tt.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: ZeetSpacing.x4),

              // Presets.
              if (!_showFreeText) ...<Widget>[
                ..._presets.map(
                  (String preset) => Padding(
                    padding: const EdgeInsets.only(bottom: ZeetSpacing.x2),
                    child: _PresetTile(
                      label: preset,
                      onTap: () => _selectPreset(preset),
                    ),
                  ),
                ),
                const SizedBox(height: ZeetSpacing.x1),
                _PresetTile(
                  label: 'Autre motif…',
                  icon: Icons.edit_outlined,
                  onTap: _openFreeText,
                ),
              ] else ...<Widget>[
                // Mode saisie libre — minoritaire mais disponible.
                TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submitFreeText(),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Précise la raison (obligatoire)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ZeetRadius.md),
                    ),
                  ),
                ),
                const SizedBox(height: ZeetSpacing.x3),
                ZeetButton(
                  label: 'Confirmer le refus',
                  onPressed: _controller.text.trim().isEmpty
                      ? null
                      : _submitFreeText,
                  variant: ZeetButtonVariant.danger,
                  size: ZeetButtonSize.lg,
                  fullWidth: true,
                ),
              ],

              const SizedBox(height: ZeetSpacing.x3),

              // Annulation.
              ZeetButton(
                label: 'Annuler',
                onPressed: () => Navigator.of(context).pop(),
                variant: ZeetButtonVariant.ghost,
                size: ZeetButtonSize.md,
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(ZeetRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(ZeetRadius.md),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(
            horizontal: ZeetSpacing.x4,
            vertical: ZeetSpacing.x3,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                icon ?? Icons.cancel_outlined,
                size: 20,
                color: scheme.onSurface,
              ),
              const SizedBox(width: ZeetSpacing.x3),
              Expanded(
                child: Text(
                  label,
                  style: tt.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
