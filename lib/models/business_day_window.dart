/// Fenetre de journee commerciale (business day) pour le dashboard partner.
///
/// Retournee par `GET /v1/partner/dashboard/summary` dans le bloc
/// `business_day`. La journee commerciale demarre a `cutoffHour` locale
/// (defaut 04h00 Africa/Abidjan) et dure 24h. Les KPIs `orders_today` et
/// `revenue_today` sont calcules cote backend sur cette fenetre
/// [start, end[ — un snack ouvert jusqu'a 02h voit donc ses commandes
/// rester dans le meme compteur apres minuit au lieu de retomber a 0.
///
/// Doc backend : `docs/PARTNER_BUSINESS_DAY.md`.
class BusinessDayWindow {
  /// Heure locale du cutoff (0-23). Affichee dans l'UI ("Depuis 04h00").
  /// Ne JAMAIS la hardcoder : elle peut varier par setting Directus.
  final int cutoffHour;

  /// Debut (inclus) de la journee commerciale courante, en heure locale.
  final DateTime start;

  /// Fin (exclu) de la journee commerciale courante = debut de la suivante.
  final DateTime end;

  const BusinessDayWindow({
    required this.cutoffHour,
    required this.start,
    required this.end,
  });

  factory BusinessDayWindow.fromJson(Map<String, dynamic> json) {
    final int cutoffHour = (json['cutoff_hour'] as num?)?.toInt() ?? 4;
    // tryParse : si le backend renvoie une date malformee, on ne crash
    // pas le parsing du dashboard — on retombe sur le fallback local
    // (fenetre 04h-04h alignee sur l'heure courante).
    final DateTime? start =
        DateTime.tryParse(json['start']?.toString() ?? '')?.toLocal();
    final DateTime? end =
        DateTime.tryParse(json['end']?.toString() ?? '')?.toLocal();
    if (start == null || end == null) {
      return BusinessDayWindow.fallback(cutoffHour: cutoffHour);
    }
    return BusinessDayWindow(
      cutoffHour: cutoffHour,
      start: start,
      end: end,
    );
  }

  /// Fenetre par defaut si le backend ne renvoie pas encore `business_day`
  /// (ancien deployment). Reconstruit une fenetre 04h → 04h locale alignee
  /// sur le moment courant (si on est avant 04h, on est encore dans la
  /// journee qui a demarre hier matin).
  factory BusinessDayWindow.fallback({DateTime? now, int cutoffHour = 4}) {
    final DateTime reference = now ?? DateTime.now();
    DateTime start = DateTime(
      reference.year,
      reference.month,
      reference.day,
      cutoffHour,
    );
    if (reference.isBefore(start)) {
      start = start.subtract(const Duration(days: 1));
    }
    return BusinessDayWindow(
      cutoffHour: cutoffHour,
      start: start,
      end: start.add(const Duration(days: 1)),
    );
  }

  /// Duree restante avant la reinitialisation des compteurs KPI.
  /// Negative si la fenetre est deja depassee — l'ecran parent doit alors
  /// rafraichir le dashboard pour recuperer la nouvelle fenetre.
  Duration timeUntilNextReset({DateTime? now}) {
    return end.difference(now ?? DateTime.now());
  }

  /// True si le cutoff est franchi. Parent responsable du refresh dashboard.
  bool isExpired({DateTime? now}) {
    return !(now ?? DateTime.now()).isBefore(end);
  }
}
