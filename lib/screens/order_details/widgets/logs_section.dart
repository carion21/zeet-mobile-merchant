// lib/screens/order_details/widgets/logs_section.dart
//
// Section "Historique" :
// 1. Card "Vos performances" — UNIQUEMENT durees que le partner controle
//    (acceptation + preparation). On omet pickup_wait/transit/total
//    (metriques rider, polluent la lecture partner).
// 2. Timeline verticale : dot colore depuis backend `order_status.color`,
//    label + heure droite, observation libre filtree (pas les "Synced
//    from delivery → ..." plumbing backend).
//
// Motion volontairement statique : budget POS partner ≤ 200ms, zero
// animation decorative sur ecran de flux operationnel.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/models/order_model.dart';
import 'package:merchant/screens/order_details/widgets/order_status_strip.dart'
    show fallbackStatusLabel;

class LogsSection extends StatelessWidget {
  const LogsSection({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color textColor = scheme.onSurface;
    final Color textLightColor = scheme.onSurfaceVariant;

    final List<OrderLog> logs = List<OrderLog>.from(order.logs)
      ..sort((OrderLog a, OrderLog b) {
        final DateTime? da = _parseLogDate(a.createdAt);
        final DateTime? db = _parseLogDate(b.createdAt);
        if (da != null && db != null) return da.compareTo(db);
        return (a.id ?? 0).compareTo(b.id ?? 0);
      });
    final OrderTimings? timings = order.timings;
    final bool showPerf = timings != null &&
        (timings.acceptanceSeconds != null ||
            timings.preparationSeconds != null);
    if (logs.isEmpty && !showPerf) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showPerf) ...<Widget>[
          Text(
            'Vos performances',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          SizedBox(height: 12.h),
          _PartnerPerformance(timings: timings),
          SizedBox(height: 24.h),
        ],
        if (logs.isNotEmpty) ...<Widget>[
          Text(
            'Historique',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          SizedBox(height: 12.h),
          ...List<Widget>.generate(logs.length, (int i) {
            return _LogEntry(
              log: logs[i],
              textColor: textColor,
              textLightColor: textLightColor,
              isLast: i == logs.length - 1,
              showConnector: i < logs.length - 1,
            );
          }),
        ],
      ],
    );
  }
}

class _LogEntry extends StatelessWidget {
  const _LogEntry({
    required this.log,
    required this.textColor,
    required this.textLightColor,
    required this.isLast,
    required this.showConnector,
  });

  final OrderLog log;
  final Color textColor;
  final Color textLightColor;
  final bool isLast;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color statusColor = log.orderStatus?.colorValue ?? scheme.outline;
    final String rawLabel = log.orderStatus?.displayLabel ?? '';
    final String label = rawLabel.trim().isNotEmpty
        ? rawLabel
        : fallbackStatusLabel(log.orderStatus?.value);
    final String? observation = _cleanLogObservation(log.observation);
    final String timeLabel = _formatLogTime(log.createdAt);
    final double dotSize = isLast ? 14.w : 10.w;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 18.w,
            child: Column(
              children: <Widget>[
                SizedBox(height: 4.h),
                Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: isLast
                        ? Border.all(
                            color: statusColor.withValues(alpha: 0.22),
                            width: 3,
                          )
                        : null,
                  ),
                ),
                if (showConnector)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: EdgeInsets.symmetric(vertical: 2.h),
                      color: scheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: 2.h,
                bottom: showConnector ? 14.h : 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: isLast
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: isLast ? statusColor : textColor,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                      if (timeLabel.isNotEmpty) ...<Widget>[
                        SizedBox(width: 8.w),
                        Text(
                          timeLabel,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: textLightColor,
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (observation != null) ...<Widget>[
                    SizedBox(height: 3.h),
                    Text(
                      observation,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: textLightColor,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PartnerPerformance extends StatelessWidget {
  const _PartnerPerformance({required this.timings});

  final OrderTimings timings;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color textColor = scheme.onSurface;
    final Color textLightColor = scheme.onSurfaceVariant;
    final List<_PerfTile> tiles = <_PerfTile>[
      if (timings.acceptanceSeconds != null)
        _PerfTile(
          label: 'Acceptation',
          value: _formatDuration(timings.acceptanceSeconds!),
          caption: 'Délai avant confirmation',
        ),
      if (timings.preparationSeconds != null)
        _PerfTile(
          label: 'Préparation',
          value: _formatDuration(timings.preparationSeconds!),
          caption: 'Temps en cuisine',
        ),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < tiles.length; i++) ...<Widget>[
              Expanded(
                child: _PerfTileWidget(
                  tile: tiles[i],
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
              ),
              if (i < tiles.length - 1)
                Container(
                  width: 1,
                  color: scheme.outlineVariant,
                  margin: EdgeInsets.symmetric(horizontal: 12.w),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PerfTileWidget extends StatelessWidget {
  const _PerfTileWidget({
    required this.tile,
    required this.textColor,
    required this.textLightColor,
  });

  final _PerfTile tile;
  final Color textColor;
  final Color textLightColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          tile.label,
          style: TextStyle(
            fontSize: 12.sp,
            color: textLightColor,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: 6.h),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            tile.value,
            style: TextStyle(
              fontSize: 24.sp,
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              height: 1.0,
              letterSpacing: -0.3,
              fontFeatures: const <FontFeature>[
                FontFeature.tabularFigures(),
              ],
            ),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          tile.caption,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.sp,
            color: textLightColor,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _PerfTile {
  const _PerfTile({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;
}

/// Filtre les observations plumbing backend (`"Synced from delivery →
/// on-the-way"`) qui n'ont aucune valeur cote partner et polluent
/// l'historique.
String? _cleanLogObservation(String? raw) {
  if (raw == null) return null;
  final String t = raw.trim();
  if (t.isEmpty) return null;
  if (t.toLowerCase().startsWith('synced from')) return null;
  return t;
}

DateTime? _parseLogDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    return DateTime.parse(raw).toLocal();
  } catch (_) {
    return null;
  }
}

/// Heure locale format compact : meme jour `HH:mm`, sinon `dd/MM · HH:mm`,
/// sinon `dd/MM/yyyy · HH:mm`.
String _formatLogTime(String? raw) {
  final DateTime? dt = _parseLogDate(raw);
  if (dt == null) return '';
  final DateTime now = DateTime.now();
  final bool sameDay =
      dt.year == now.year && dt.month == now.month && dt.day == now.day;
  if (sameDay) {
    return DateFormat('HH:mm', 'fr_FR').format(dt);
  }
  final String pattern =
      dt.year == now.year ? 'dd/MM · HH:mm' : 'dd/MM/yyyy · HH:mm';
  return DateFormat(pattern, 'fr_FR').format(dt);
}

/// Duree en secondes formatee copy partner :
/// `< 60 s` → `"12 s"`, `< 1 h` → `"13 min"` ou `"13 min 46 s"`,
/// `≥ 1 h` → `"1 h"` ou `"1 h 15 min"`. Valeurs negatives → absolues.
String _formatDuration(int seconds) {
  final int s = seconds < 0 ? -seconds : seconds;
  if (s < 60) return '$s s';
  final int minutes = s ~/ 60;
  final int remSec = s % 60;
  if (minutes < 60) {
    if (remSec == 0) return '$minutes min';
    return '$minutes min $remSec s';
  }
  final int hours = minutes ~/ 60;
  final int remMin = minutes % 60;
  if (remMin == 0) return '$hours h';
  return '$hours h $remMin min';
}
