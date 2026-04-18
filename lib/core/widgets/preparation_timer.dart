// lib/core/widgets/preparation_timer.dart
//
// Timer de préparation — pression positive neuro-UX.
//
// Affiche le temps écoulé depuis le début de la commande
// (accepted/confirmed/preparing) avec un changement de couleur
// progressif :
//   - < 10 min : `ZeetColors.inkMuted` (neutre)
//   - 10–20 min : `ZeetColors.warning` (jaune — pression douce)
//   - > 20 min : `ZeetColors.danger` (rouge — retard service)
//
// Le partner voit d'un coup d'œil quelles commandes sont à
// re-prioriser. Rafraîchi toutes les 30 secondes via Timer.
//
// Voir skills : `zeet-neuro-ux` §2 (pression positive).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zeet_ui/zeet_ui.dart';

class PreparationTimer extends StatefulWidget {
  const PreparationTimer({
    super.key,
    required this.createdAtIso,
    this.warningThreshold = const Duration(minutes: 10),
    this.dangerThreshold = const Duration(minutes: 20),
    this.dense = false,
  });

  final String? createdAtIso;
  final Duration warningThreshold;
  final Duration dangerThreshold;
  final bool dense;

  @override
  State<PreparationTimer> createState() => _PreparationTimerState();
}

class _PreparationTimerState extends State<PreparationTimer> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime? createdAt = _parseIso(widget.createdAtIso);
    if (createdAt == null) return const SizedBox.shrink();

    final Duration elapsed = DateTime.now().difference(createdAt);
    final (Color color, IconData icon) = _styleFor(elapsed);
    final TextTheme tt = Theme.of(context).textTheme;
    final String label = _formatElapsed(elapsed);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: widget.dense ? 12 : 14, color: color),
        const SizedBox(width: ZeetSpacing.x1),
        Text(
          label,
          style: (widget.dense ? tt.labelSmall : tt.labelMedium)?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  DateTime? _parseIso(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      return DateTime.parse(iso).toLocal();
    } catch (_) {
      return null;
    }
  }

  (Color, IconData) _styleFor(Duration elapsed) {
    if (elapsed >= widget.dangerThreshold) {
      return (ZeetColors.dangerText, Icons.timer_rounded);
    }
    if (elapsed >= widget.warningThreshold) {
      return (ZeetColors.warningText, Icons.schedule_rounded);
    }
    return (ZeetColors.inkMuted, Icons.access_time_rounded);
  }

  String _formatElapsed(Duration d) {
    if (d.inMinutes < 1) return '< 1 min';
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    final int h = d.inHours;
    final int m = d.inMinutes - h * 60;
    return m == 0 ? '${h}h' : '${h}h $m';
  }
}
