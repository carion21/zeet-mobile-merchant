// lib/screens/opening_hours/index.dart
//
// Ecran Horaires d'ouverture (schedule hebdomadaire) partner.
// Endpoints : GET /v1/partner/profile (schedules enrichis) et
// PATCH /v1/partner/availability pour sauvegarder.
//
// Intention POS partner : dense, glanceable, toggle/time-picker
// explicites. Enregistrement manuel via ZeetBottomBar (evite sync
// intempestive a chaque tap).
//
// Copy : tone pro partner (zeet-micro-copy §2 — vouvoiement, neutre).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zeet_ui/zeet_ui.dart';

import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/models/partner_model.dart';
import 'package:merchant/providers/profile_provider.dart';

/// Ordre canonique d'affichage (semaine fr : Lundi -> Dimanche).
const List<String> _weekDays = <String>[
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

const Map<String, String> _dayLabels = <String, String>{
  'monday': 'Lundi',
  'tuesday': 'Mardi',
  'wednesday': 'Mercredi',
  'thursday': 'Jeudi',
  'friday': 'Vendredi',
  'saturday': 'Samedi',
  'sunday': 'Dimanche',
};

/// Representation UI locale d'un horaire jour (pas encore envoye au backend).
class _DayHours {
  _DayHours({
    required this.day,
    required this.closed,
    this.openTime,
    this.closeTime,
  });

  final String day;
  bool closed;
  TimeOfDay? openTime;
  TimeOfDay? closeTime;

  /// Construit depuis le modele backend.
  factory _DayHours.fromSchedule(PartnerSchedule s) {
    return _DayHours(
      day: s.day,
      closed: !s.isOpen,
      openTime: _parseTime(s.openingTime),
      closeTime: _parseTime(s.closingTime),
    );
  }

  /// Defaults pour un jour absent du backend.
  factory _DayHours.defaults(String day) {
    return _DayHours(
      day: day,
      closed: false,
      openTime: const TimeOfDay(hour: 8, minute: 0),
      closeTime: const TimeOfDay(hour: 22, minute: 0),
    );
  }

  PartnerSchedule toSchedule({required int id}) {
    return PartnerSchedule(
      id: id,
      day: day,
      isOpen: !closed,
      openingTime: closed ? null : _formatTime(openTime),
      closingTime: closed ? null : _formatTime(closeTime),
    );
  }

  static TimeOfDay? _parseTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final List<String> parts = raw.split(':');
    if (parts.length < 2) return null;
    final int? h = int.tryParse(parts[0]);
    final int? m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  static String? _formatTime(TimeOfDay? t) {
    if (t == null) return null;
    final String h = t.hour.toString().padLeft(2, '0');
    final String m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class OpeningHoursScreen extends ConsumerStatefulWidget {
  const OpeningHoursScreen({super.key});

  @override
  ConsumerState<OpeningHoursScreen> createState() => _OpeningHoursScreenState();
}

class _OpeningHoursScreenState extends ConsumerState<OpeningHoursScreen> {
  List<_DayHours>? _draft;
  bool _loadedFromProfile = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final ProfileState pState = ref.read(profileProvider);
      if (pState.profile == null &&
          pState.status != ProfileStatus.loading) {
        ref.read(profileProvider.notifier).loadProfile();
      }
    });
  }

  /// Hydrate le draft depuis le profil backend (une seule fois).
  void _hydrateIfNeeded(PartnerData? profile) {
    if (_loadedFromProfile || profile == null) return;
    final Map<String, PartnerSchedule> byDay = <String, PartnerSchedule>{
      for (final PartnerSchedule s in profile.schedules) s.day: s,
    };
    _draft = _weekDays.map((String d) {
      final PartnerSchedule? s = byDay[d];
      return s != null ? _DayHours.fromSchedule(s) : _DayHours.defaults(d);
    }).toList();
    _loadedFromProfile = true;
  }

  Future<void> _pickTime({
    required _DayHours day,
    required bool isOpen,
  }) async {
    final TimeOfDay initial = isOpen
        ? (day.openTime ?? const TimeOfDay(hour: 8, minute: 0))
        : (day.closeTime ?? const TimeOfDay(hour: 22, minute: 0));
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
      // Force le format 24h (tone pro partner, pas de AM/PM en fr).
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null) return;
    ZeetHaptics.tap();
    setState(() {
      if (isOpen) {
        day.openTime = picked;
      } else {
        day.closeTime = picked;
      }
      _dirty = true;
    });
  }

  void _toggleClosed(_DayHours day, bool closed) {
    ZeetHaptics.tap();
    setState(() {
      day.closed = closed;
      // Si on re-ouvre apres un ferme, on re-propose des horaires par defaut.
      if (!closed) {
        day.openTime ??= const TimeOfDay(hour: 8, minute: 0);
        day.closeTime ??= const TimeOfDay(hour: 22, minute: 0);
      }
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (_draft == null) return;
    final PartnerData? profile = ref.read(profileProvider).profile;
    final Map<String, PartnerSchedule> existing = <String, PartnerSchedule>{
      for (final PartnerSchedule s in profile?.schedules ?? <PartnerSchedule>[])
        s.day: s,
    };
    final List<PartnerSchedule> payload = _draft!.map((_DayHours d) {
      // Conserve l'id si le jour existait deja pour compat backend.
      final int id = existing[d.day]?.id ?? 0;
      return d.toSchedule(id: id);
    }).toList();

    ZeetHaptics.tap();
    final String? error =
        await ref.read(profileProvider.notifier).updateAvailability(payload);
    if (!mounted) return;

    if (error == null) {
      ZeetHaptics.success();
      setState(() => _dirty = false);
      AppToast.showSuccess(
        context: context,
        message: 'Horaires enregistrés',
      );
    } else {
      ZeetHaptics.error();
      AppToast.showError(context: context, message: error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ProfileState pState = ref.watch(profileProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    _hydrateIfNeeded(pState.profile);

    final bool isLoading =
        pState.status == ProfileStatus.loading && pState.profile == null;
    final Object? error =
        pState.status == ProfileStatus.error && pState.profile == null
            ? (pState.errorMessage ?? 'Impossible de charger les horaires')
            : null;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: const ZeetAppBar(title: Text('Horaires')),
      body: ZeetStateBuilder<List<_DayHours>>(
        data: _draft,
        isLoading: isLoading,
        error: error,
        onRetry: () => ref.read(profileProvider.notifier).loadProfile(),
        loading: const _OpeningHoursSkeleton(),
        builder: (List<_DayHours> days) {
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              ZeetSpacing.x4,
              ZeetSpacing.x4,
              ZeetSpacing.x4,
              ZeetSpacing.x4,
            ),
            itemCount: days.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: ZeetSpacing.x2),
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: ZeetSpacing.x2),
                  child: Text(
                    'Définissez vos horaires pour chaque jour de la semaine.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                );
              }
              final _DayHours day = days[index - 1];
              return _DayCard(
                day: day,
                onToggleClosed: (bool closed) => _toggleClosed(day, closed),
                onPickOpen: () => _pickTime(day: day, isOpen: true),
                onPickClose: () => _pickTime(day: day, isOpen: false),
              );
            },
          );
        },
      ),
      bottomNavigationBar: _draft == null
          ? null
          : ZeetBottomBar(
              child: ZeetButton.primary(
                label: 'Enregistrer',
                icon: Icons.check_rounded,
                fullWidth: true,
                size: ZeetButtonSize.lg,
                loading: pState.isUpdating,
                onPressed: _dirty && !pState.isUpdating ? _save : null,
              ),
            ),
    );
  }
}

// =============================================================================
// DAY CARD — toggle + time pickers
// =============================================================================

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.onToggleClosed,
    required this.onPickOpen,
    required this.onPickClose,
  });

  final _DayHours day;
  final ValueChanged<bool> onToggleClosed;
  final VoidCallback onPickOpen;
  final VoidCallback onPickClose;

  String _formatTime(TimeOfDay? t) {
    if (t == null) return '--:--';
    final String h = t.hour.toString().padLeft(2, '0');
    final String m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    final String label = _dayLabels[day.day] ?? day.day;
    final bool isOpen = !day.closed;

    return ZeetCard(
      variant: ZeetCardVariant.outlined,
      padding: const EdgeInsets.symmetric(
        horizontal: ZeetSpacing.x4,
        vertical: ZeetSpacing.x3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header : jour + toggle ouvert/ferme.
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              ZeetStatusChip(
                status: isOpen ? ZeetStatus.success : ZeetStatus.neutral,
                label: isOpen ? 'Ouvert' : 'Fermé',
                dense: true,
              ),
              const SizedBox(width: ZeetSpacing.x2),
              Switch.adaptive(
                value: isOpen,
                onChanged: (bool v) => onToggleClosed(!v),
              ),
            ],
          ),
          // Selecteurs d'heures visibles uniquement si ouvert.
          if (isOpen) ...<Widget>[
            const SizedBox(height: ZeetSpacing.x3),
            Row(
              children: <Widget>[
                Expanded(
                  child: _TimePickerField(
                    label: 'Ouverture',
                    value: _formatTime(day.openTime),
                    onTap: onPickOpen,
                  ),
                ),
                const SizedBox(width: ZeetSpacing.x3),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                  semanticLabel: 'à',
                ),
                const SizedBox(width: ZeetSpacing.x3),
                Expanded(
                  child: _TimePickerField(
                    label: 'Fermeture',
                    value: _formatTime(day.closeTime),
                    onTap: onPickClose,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TimePickerField extends StatelessWidget {
  const _TimePickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: ZeetRadius.brSm,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ZeetSpacing.x3,
          vertical: ZeetSpacing.x3,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: ZeetRadius.brSm,
          border: Border.all(color: scheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: tt.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: ZeetSpacing.x1),
            Row(
              children: <Widget>[
                Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: scheme.onSurface,
                  semanticLabel: label,
                ),
                const SizedBox(width: ZeetSpacing.x2),
                Text(
                  value,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SKELETON
// =============================================================================

class _OpeningHoursSkeleton extends StatelessWidget {
  const _OpeningHoursSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(ZeetSpacing.x4),
      itemCount: 7,
      separatorBuilder: (_, __) => const SizedBox(height: ZeetSpacing.x2),
      itemBuilder: (_, __) => const ZeetSkeleton(
        width: double.infinity,
        height: 84,
        borderRadius: ZeetRadius.brMd,
      ),
    );
  }
}
