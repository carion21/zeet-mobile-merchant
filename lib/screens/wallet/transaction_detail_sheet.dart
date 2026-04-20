// lib/screens/wallet/transaction_detail_sheet.dart
//
// Bottom sheet affichant les details d'une transaction wallet (WalletEntry)
// pour l'app partner/merchant. Intention POS : dense, glanceable,
// contrastes forts, reference copiable pour support.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:zeet_ui/zeet_ui.dart';

import 'package:merchant/models/wallet_model.dart';

Future<void> showTransactionDetailSheet(
  BuildContext context,
  WalletEntry entry,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TransactionDetailSheet(entry: entry),
  );
}

class _TransactionDetailSheet extends StatelessWidget {
  const _TransactionDetailSheet({required this.entry});

  final WalletEntry entry;

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final DateTime dt = DateTime.parse(iso).toLocal();
      return DateFormat('EEEE d MMMM y · HH:mm', 'fr_FR').format(dt);
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    final bool isCredit = entry.isCredit;
    final Color amountColor =
        isCredit ? ZeetColors.successText : ZeetColors.dangerText;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(ZeetRadius.lg),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          ZeetSpacing.x4,
          ZeetSpacing.x3,
          ZeetSpacing.x4,
          ZeetSpacing.x5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: ZeetSpacing.x4),

            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Détail du mouvement',
                    style: tt.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: ZeetSpacing.x3),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isCredit
                        ? ZeetColors.successBg
                        : ZeetColors.dangerBg,
                    borderRadius: ZeetRadius.brMd,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    isCredit
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    color: amountColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: ZeetSpacing.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ZeetMoney(
                        amount: isCredit
                            ? entry.amount.abs()
                            : -entry.amount.abs(),
                        currency: ZeetCurrency.fcfa,
                        showSign: true,
                        style: tt.headlineSmall?.copyWith(
                          color: amountColor,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: ZeetSpacing.x1),
                      Text(
                        _formatDate(entry.createdAt),
                        style: tt.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (entry.status != null && entry.status!.isNotEmpty)
                  _statusChip(entry.status!),
              ],
            ),
            const SizedBox(height: ZeetSpacing.x4),

            if ((entry.description ?? '').isNotEmpty) ...<Widget>[
              Text(
                'LIBELLÉ',
                style: tt.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: ZeetSpacing.x1),
              Text(
                entry.description!,
                style: tt.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: ZeetSpacing.x4),
            ],

            ZeetCard(
              variant: ZeetCardVariant.outlined,
              padding: const EdgeInsets.symmetric(
                horizontal: ZeetSpacing.x3,
              ),
              child: Column(
                children: <Widget>[
                  _DetailRow(
                    label: 'Type',
                    value: _typeLabel(entry),
                  ),
                  if (entry.reference != null &&
                      entry.reference!.isNotEmpty)
                    _DetailRow(
                      label: 'Référence',
                      value: entry.reference!,
                      copyable: true,
                    ),
                  if (entry.balanceBefore != null)
                    _DetailRow(
                      label: 'Solde avant',
                      valueWidget: ZeetMoney(
                        amount: entry.balanceBefore!,
                        currency: ZeetCurrency.fcfa,
                        style: tt.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (entry.balanceAfter != null)
                    _DetailRow(
                      label: 'Solde après',
                      valueWidget: ZeetMoney(
                        amount: entry.balanceAfter!,
                        currency: ZeetCurrency.fcfa,
                        style: tt.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      isLast: true,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(WalletEntry e) {
    final String direction = e.isCredit ? 'Crédit' : 'Débit';
    final String raw = (e.type ?? '').trim();
    if (raw.isEmpty) return direction;
    return '$direction · $raw';
  }

  Widget _statusChip(String status) {
    final String s = status.toLowerCase();
    ZeetStatus sem;
    String label;
    if (s == 'completed' || s == 'success' || s == 'successful') {
      sem = ZeetStatus.success;
      label = 'Réussi';
    } else if (s == 'pending' || s == 'processing' || s == 'initiated') {
      sem = ZeetStatus.warning;
      label = 'En cours';
    } else if (s == 'failed' || s == 'rejected' || s == 'canceled' ||
        s == 'cancelled') {
      sem = ZeetStatus.danger;
      label = 'Échoué';
    } else {
      sem = ZeetStatus.neutral;
      label = status;
    }
    return ZeetStatusChip(status: sem, label: label, dense: true);
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    this.value,
    this.valueWidget,
    this.copyable = false,
    this.isLast = false,
  }) : assert(value != null || valueWidget != null);

  final String label;
  final String? value;
  final Widget? valueWidget;
  final bool copyable;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: ZeetSpacing.x3),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: tt.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                Flexible(
                  child: valueWidget ??
                      Text(
                        value!,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                ),
                if (copyable && value != null) ...<Widget>[
                  const SizedBox(width: ZeetSpacing.x1),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: value!));
                      ZeetHaptics.tap();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Référence copiée'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.copy_rounded,
                        color: scheme.primary,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
