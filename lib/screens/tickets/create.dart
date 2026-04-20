// lib/screens/tickets/create.dart
//
// Ecran de creation d'un ticket partner.
// Endpoints :
// - POST /v1/partner/tickets
// - GET /v1/partner/tickets/select/priorities
//
// Intention POS partner : form court, chips presets priorite (pas de dropdown),
// CTA bottom sticky, haptic + toast sur succes.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zeet_ui/zeet_ui.dart';

import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/models/ticket_model.dart';
import 'package:merchant/providers/ticket_provider.dart';
import 'package:merchant/screens/tickets/detail.dart';
import 'package:merchant/services/navigation_service.dart';

class CreateTicketScreen extends ConsumerStatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  ConsumerState<CreateTicketScreen> createState() =>
      _CreateTicketScreenState();
}

class _CreateTicketScreenState extends ConsumerState<CreateTicketScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  TicketPriority _priority = TicketPriority.normal;
  bool _isSubmitting = false;
  String? _lastError;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      await HapticFeedback.lightImpact();
      return;
    }
    setState(() {
      _isSubmitting = true;
      _lastError = null;
    });
    await HapticFeedback.mediumImpact();

    final CreateTicketRequest request = CreateTicketRequest(
      title: _titleController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      priority: _priority,
    );

    final Ticket? created = await ref
        .read(ticketsListProvider.notifier)
        .createTicket(request);

    if (!mounted) return;

    if (created != null) {
      setState(() => _isSubmitting = false);
      HapticFeedback.heavyImpact();
      AppToast.showSuccess(
        context: context,
        message: 'Ticket cree — reponse sous 24h',
      );
      Routes.pushReplacement(TicketDetailScreen(ticketId: created.id.toString()));
    } else {
      final String? err = ref.read(ticketsListProvider).errorMessage;
      setState(() {
        _isSubmitting = false;
        _lastError = err ?? 'Impossible de creer le ticket';
      });
      AppToast.showError(
        context: context,
        message: err ?? 'Impossible de creer le ticket',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;

    // Precharge la liste des priorites serveur pour invalider/afficher
    // un eventuel override backend (evite un release si l'API ajoute une
    // priorite). Les enum locaux restent la source de rendu.
    ref.watch(ticketPrioritiesProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: const ZeetAppBar(title: Text('Nouveau ticket')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(ZeetSpacing.x4),
          children: <Widget>[
            Text(
              'Sujet',
              style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: ZeetSpacing.x2),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Ex : Probleme avec la commande #1234',
                border: OutlineInputBorder(
                  borderRadius: ZeetRadius.brMd,
                  borderSide: BorderSide(color: scheme.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: ZeetRadius.brMd,
                  borderSide: BorderSide(color: scheme.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: ZeetRadius.brMd,
                  borderSide: BorderSide(color: scheme.primary, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: ZeetSpacing.x3,
                  vertical: ZeetSpacing.x3,
                ),
              ),
              style: tt.bodyLarge,
              textInputAction: TextInputAction.next,
              maxLength: 120,
              validator: (String? v) {
                if (v == null || v.trim().length < 3) {
                  return 'Veuillez entrer un sujet (3 caracteres min.)';
                }
                return null;
              },
            ),
            const SizedBox(height: ZeetSpacing.x4),
            Text(
              'Priorite',
              style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: ZeetSpacing.x2),
            _PrioritySelector(
              current: _priority,
              onChanged: (TicketPriority p) {
                HapticFeedback.selectionClick();
                setState(() => _priority = p);
              },
            ),
            const SizedBox(height: ZeetSpacing.x4),
            Text(
              'Description',
              style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: ZeetSpacing.x2),
            TextFormField(
              controller: _descController,
              decoration: InputDecoration(
                hintText: 'Decrivez le probleme...',
                border: OutlineInputBorder(
                  borderRadius: ZeetRadius.brMd,
                  borderSide: BorderSide(color: scheme.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: ZeetRadius.brMd,
                  borderSide: BorderSide(color: scheme.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: ZeetRadius.brMd,
                  borderSide: BorderSide(color: scheme.primary, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: ZeetSpacing.x3,
                  vertical: ZeetSpacing.x3,
                ),
              ),
              style: tt.bodyLarge,
              maxLines: 6,
              minLines: 4,
            ),
            // Erreur API inline — persiste apres la disparition du toast
            // pour que l'utilisateur comprenne pourquoi le submit a echoue.
            if (_lastError != null) ...<Widget>[
              const SizedBox(height: ZeetSpacing.x4),
              ZeetErrorState.fromError(
                _lastError,
                compact: true,
                onRetry: _isSubmitting ? null : _submit,
              ),
            ],
            const SizedBox(height: ZeetSpacing.x6),
          ],
        ),
      ),
      bottomNavigationBar: ZeetBottomBar(
        child: ZeetButton.primary(
          label: 'Creer le ticket',
          icon: Icons.send_rounded,
          fullWidth: true,
          size: ZeetButtonSize.lg,
          loading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ),
    );
  }
}

// =============================================================================
// PRIORITY SELECTOR — chips presets
// =============================================================================

class _PrioritySelector extends StatelessWidget {
  const _PrioritySelector({required this.current, required this.onChanged});
  final TicketPriority current;
  final ValueChanged<TicketPriority> onChanged;

  @override
  Widget build(BuildContext context) {
    const List<TicketPriority> options = <TicketPriority>[
      TicketPriority.low,
      TicketPriority.normal,
      TicketPriority.high,
      TicketPriority.urgent,
    ];
    return Wrap(
      spacing: ZeetSpacing.x2,
      runSpacing: ZeetSpacing.x2,
      children: options
          .map((TicketPriority p) => _PriorityChip(
                priority: p,
                selected: p == current,
                onTap: () => onChanged(p),
              ))
          .toList(),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({
    required this.priority,
    required this.selected,
    required this.onTap,
  });

  final TicketPriority priority;
  final bool selected;
  final VoidCallback onTap;

  Color _selectedBg() {
    switch (priority) {
      case TicketPriority.low:
        return ZeetColors.successBg;
      case TicketPriority.normal:
        return ZeetColors.infoBg;
      case TicketPriority.high:
        return ZeetColors.warningBg;
      case TicketPriority.urgent:
        return ZeetColors.dangerBg;
      case TicketPriority.unknown:
        return ZeetColors.surfaceAlt;
    }
  }

  Color _selectedFg() {
    switch (priority) {
      case TicketPriority.low:
        return ZeetColors.successText;
      case TicketPriority.normal:
        return ZeetColors.infoText;
      case TicketPriority.high:
        return ZeetColors.warningText;
      case TicketPriority.urgent:
        return ZeetColors.dangerText;
      case TicketPriority.unknown:
        return ZeetColors.inkMuted;
    }
  }

  IconData _icon() {
    switch (priority) {
      case TicketPriority.low:
        return Icons.keyboard_double_arrow_down_rounded;
      case TicketPriority.normal:
        return Icons.drag_handle_rounded;
      case TicketPriority.high:
        return Icons.keyboard_arrow_up_rounded;
      case TicketPriority.urgent:
        return Icons.priority_high_rounded;
      case TicketPriority.unknown:
        return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    final Color bg = selected ? _selectedBg() : scheme.surfaceContainerLow;
    final Color fg = selected ? _selectedFg() : scheme.onSurface;
    final Color border =
        selected ? _selectedFg().withValues(alpha: 0.4) : scheme.outline;

    return Material(
      color: bg,
      borderRadius: const BorderRadius.all(Radius.circular(ZeetRadius.pill)),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            const BorderRadius.all(Radius.circular(ZeetRadius.pill)),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(
            horizontal: ZeetSpacing.x4,
            vertical: ZeetSpacing.x2,
          ),
          decoration: BoxDecoration(
            borderRadius:
                const BorderRadius.all(Radius.circular(ZeetRadius.pill)),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(_icon(), size: 16, color: fg),
              const SizedBox(width: ZeetSpacing.x1),
              Text(
                priority.displayLabel,
                style: tt.labelLarge?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
