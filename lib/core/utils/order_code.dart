/// Helpers d'affichage pour les codes commande.
///
/// Le backend renvoie des codes longs (ex. `ZEE-2026-04-21-0001-4587`).
/// Préférence UX : quand l'espace le permet, afficher le code **complet**
/// (référence sans ambiguïté pour le restaurateur, le client, le support).
/// Quand la ligne est contrainte, retomber sur les 9 derniers caractères
/// préfixés de `#…` — assez pour l'identifier au glance et l'énoncer au
/// téléphone.
///
/// Voir [OrderCodeText] pour le widget qui fait la bascule automatique en
/// fonction de la largeur disponible.
library;

/// Retourne la forme complète `#<code>` (ajoute le `#` s'il manque).
String fullOrderCode(String? code) {
  if (code == null || code.isEmpty) return '';
  return code.startsWith('#') ? code : '#$code';
}

/// Garde les [keep] derniers caractères du code, préfixés de `#…`.
///
/// Si le code est null/vide, retourne `''`. Si le code est déjà plus court
/// que [keep] caractères utiles (hors préfixe `#`), retourne `#<code>` sans
/// ellipsis — pas la peine d'afficher `…` pour abréger un code déjà court.
String shortOrderCode(String? code, {int keep = 9}) {
  if (code == null) return '';
  final String raw = code.startsWith('#') ? code.substring(1) : code;
  if (raw.isEmpty) return '';
  if (raw.length <= keep) return '#$raw';
  return '#…${raw.substring(raw.length - keep)}';
}
