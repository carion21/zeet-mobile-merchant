// lib/core/widgets/business_day_label.dart
//
// Sous-label "Depuis 04h00 · reinit dans 6h22" affiche sous un KPI du
// dashboard partner. Rappelle a l'operateur que les compteurs du jour
// (orders_today / revenue_today) suivent la journee commerciale cutoff
// 04h par defaut et non minuit civil.
//
// Se rafraichit seul toutes les minutes (Timer.periodic + setState local
// — pattern identique a PreparationTimer). Le parent (HomeScreen) detient
// un autre ticker qui, lui, rafraichit le dashboard quand le cutoff est
// franchi : ce widget ne fait que formater.
//
// Voir `docs/PARTNER_BUSINESS_DAY.md` cote backend et le brief mobile
// partner "Journee commerciale".

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:merchant/models/business_day_window.dart';

class BusinessDayLabel extends StatefulWidget {
  const BusinessDayLabel({
    super.key,
    required this.businessDay,
    this.style,
  });

  final BusinessDayWindow businessDay;
  final TextStyle? style;

  @override
  State<BusinessDayLabel> createState() => _BusinessDayLabelState();
}

class _BusinessDayLabelState extends State<BusinessDayLabel> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
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
    final String label = _formatWindowLabel(widget.businessDay);
    return Text(
      label,
      style: widget.style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _formatWindowLabel(BusinessDayWindow bd) {
    final String cutoff = bd.cutoffHour.toString().padLeft(2, '0');
    final Duration remaining = bd.timeUntilNextReset();
    if (remaining.isNegative || remaining == Duration.zero) {
      // Cutoff franchi — le parent va rafraichir tres bientot.
      return 'Depuis ${cutoff}h00 · bascule en cours';
    }
    final int hours = remaining.inHours;
    final int minutes = remaining.inMinutes % 60;
    if (hours == 0) {
      return 'Depuis ${cutoff}h00 · réinit dans $minutes min';
    }
    final String mStr = minutes.toString().padLeft(2, '0');
    return 'Depuis ${cutoff}h00 · réinit dans ${hours}h$mStr';
  }
}
