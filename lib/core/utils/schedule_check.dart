// lib/core/utils/schedule_check.dart
//
// Helper "Hors horaires" front. Skill plan §7-D : tant que le backend ne
// respecte pas les quiet hours par defaut (work order P1), le front affiche
// un badge "Hors horaires" sur les notifs `order.created` recues hors des
// creneaux declares dans `partner.schedules`. Le partner sait au moins
// "ZEET m'a envoye une commande hors mes creneaux" et peut decider en
// connaissance de cause (refuser sans culpabiliser).
//
// Pas une regle metier — purement informatif. Le backend reste source de
// verite pour la decision d'envoyer ou non la notif.

import 'package:merchant/models/partner_model.dart';

/// Map jour FR (lundi → '2026-05-08' day-of-week) → key utilise par
/// `partner.schedules` (DateTime.weekday est 1=lundi, 7=dimanche).
const List<String> _dayKeys = <String>[
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

/// Renvoie `true` si l'instant courant tombe DANS un creneau ouvert
/// declare par le partner pour ce jour. `false` sinon (ferme ou
/// schedules absent).
///
/// Le format `opening_time` / `closing_time` est attendu en `HH:mm`
/// (24h). Si le creneau de fermeture est avant l'ouverture (ex: 19h-02h
/// le lendemain), on considere ouvert si :
///   - now >= opening_time du jour courant, OU
///   - now < closing_time avec un jour J-1 ouvert qui se prolonge.
/// Pour simplifier l'edge case minuit, on ne traite que le cas standard
/// (closing > opening). Si pas le cas, on retourne `true` pour ne pas
/// alarmer faussement.
bool isWithinSchedule(
  List<PartnerSchedule>? schedules, {
  DateTime? now,
}) {
  if (schedules == null || schedules.isEmpty) return true; // pas de regle
  final DateTime n = now ?? DateTime.now();
  final String dayKey = _dayKeys[(n.weekday - 1).clamp(0, 6)];
  PartnerSchedule? today;
  for (final s in schedules) {
    if (s.day.toLowerCase() == dayKey) {
      today = s;
      break;
    }
  }
  if (today == null || !today.isOpen) return false;
  final open = _parseHHmm(today.openingTime);
  final close = _parseHHmm(today.closingTime);
  if (open == null || close == null) return true; // donnees floues, pas alarmer
  final cur = n.hour * 60 + n.minute;
  if (close <= open) return true; // edge case nuit
  return cur >= open && cur < close;
}

int? _parseHHmm(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}
