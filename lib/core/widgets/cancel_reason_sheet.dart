// lib/core/widgets/cancel_reason_sheet.dart
//
// Bottom sheet 2 etapes pour le refus / annulation d'une commande :
// 1. Choix du motif (presets ou saisie libre) — skill zeet-pos-ergonomics §3.
// 2. SwipeToConfirm "Glisser pour refuser" — sécurise le geste irréversible
//    (skill `zeet-gesture-grammar` §2).
//
// Remplace les `AlertDialog + TextField(maxLines: 3)` dupliqués dans
// home / orders / order_details / incoming_order. L'API publique
// [showCancelReasonSheet] reste compatible : retourne `String?`.
//
// Voir aussi : `zeet-micro-copy` §4 (tone partner pro + description impact).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zeet_ui/zeet_ui.dart';

/// Affiche le bottom sheet et retourne le motif choisi, ou `null`
/// si l'utilisateur annule.
///
/// Le motif retourne est TOUJOURS non vide et a ete **confirme par swipe**.
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

enum _Step { pickReason, confirmSwipe }

class _CancelReasonSheetState extends State<_CancelReasonSheet> {
  static const List<String> _presets = <String>[
    'Rupture de stock',
    'Trop de commandes',
    'Produit indisponible',
    'Fermeture exceptionnelle',
  ];

  _Step _step = _Step.pickReason;
  bool _showFreeText = false;
  String? _selectedReason;
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSelectPreset(String reason) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedReason = reason;
      _step = _Step.confirmSwipe;
    });
  }

  void _onOpenFreeText() {
    HapticFeedback.selectionClick();
    setState(() => _showFreeText = true);
  }

  void _onSubmitFreeText() {
    final String trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedReason = trimmed;
      _step = _Step.confirmSwipe;
    });
  }

  void _onConfirmSwipe() {
    if (_selectedReason == null) return;
    Navigator.of(context).pop(_selectedReason);
  }

  void _onBackToReason() {
    HapticFeedback.selectionClick();
    setState(() => _step = _Step.pickReason);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
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

              ZeetStateSwitcher(
                stateKey: _step.name,
                child: _step == _Step.pickReason
                    ? _buildPickReason(scheme)
                    : _buildSwipeConfirm(scheme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickReason(ColorScheme scheme) {
    final TextTheme tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
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
        if (!_showFreeText) ...<Widget>[
          ..._presets.map(
            (String preset) => Padding(
              padding: const EdgeInsets.only(bottom: ZeetSpacing.x2),
              child: _PresetTile(
                label: preset,
                onTap: () => _onSelectPreset(preset),
              ),
            ),
          ),
          const SizedBox(height: ZeetSpacing.x1),
          _PresetTile(
            label: 'Autre motif…',
            icon: Icons.edit_outlined,
            onTap: _onOpenFreeText,
          ),
        ] else ...<Widget>[
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _onSubmitFreeText(),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Précisez la raison (obligatoire)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ZeetRadius.md),
              ),
            ),
          ),
          const SizedBox(height: ZeetSpacing.x3),
          ZeetButton(
            label: 'Continuer',
            onPressed:
                _controller.text.trim().isEmpty ? null : _onSubmitFreeText,
            variant: ZeetButtonVariant.danger,
            size: ZeetButtonSize.lg,
            fullWidth: true,
          ),
        ],
        const SizedBox(height: ZeetSpacing.x3),
        ZeetButton(
          label: 'Annuler',
          onPressed: () => Navigator.of(context).pop(),
          variant: ZeetButtonVariant.ghost,
          size: ZeetButtonSize.md,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildSwipeConfirm(ColorScheme scheme) {
    final TextTheme tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'Confirmer le refus ?',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: ZeetSpacing.x1),
        Text(
          'Le client sera notifié et remboursé. Action irréversible.',
          style: tt.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: ZeetSpacing.x4),
        Container(
          padding: const EdgeInsets.all(ZeetSpacing.x3),
          decoration: BoxDecoration(
            color: ZeetColors.dangerBg,
            borderRadius: ZeetRadius.brMd,
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.info_outline_rounded,
                  size: 18, color: ZeetColors.dangerText),
              const SizedBox(width: ZeetSpacing.x2),
              Expanded(
                child: Text(
                  _selectedReason ?? '',
                  style: tt.bodyMedium?.copyWith(
                    color: ZeetColors.dangerText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZeetSpacing.x5),
        ZeetSwipeToConfirm(
          variant: ZeetSwipeConfirmVariant.destructive,
          label: 'Glisser pour confirmer le refus',
          thresholdLabel: 'Relâchez pour confirmer',
          confirmedLabel: 'Refus envoyé',
          onConfirmed: _onConfirmSwipe,
        ),
        const SizedBox(height: ZeetSpacing.x3),
        ZeetButton(
          label: 'Revenir au motif',
          onPressed: _onBackToReason,
          variant: ZeetButtonVariant.ghost,
          size: ZeetButtonSize.md,
          fullWidth: true,
        ),
      ],
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
