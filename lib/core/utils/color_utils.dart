// lib/core/utils/color_utils.dart
//
// Helpers de parsing des couleurs renvoyees par le backend ZEET Core.
//
// Le core transporte ses couleurs de status/priority sous forme de chaines
// hex `#RRGGBB` (cf. specs `last_order_status`, `status`, `priority`, etc.).
// Cet utilitaire centralise la conversion vers `Color?` Flutter en gerant
// les cas null/vide/invalide → retour `null` pour laisser l'appelant
// choisir son fallback neutre (typiquement `ZeetColors.inkMuted`).
//
// Voir : skills `zeet-design-system` §2 "Couleurs" + `zeet-pos-ergonomics`
// §6 "Statut au coup d'oeil".

import 'package:flutter/material.dart';

/// Parse une chaine hex (`#RRGGBB`, `RRGGBB`, `#AARRGGBB`, `AARRGGBB`)
/// vers un [Color] Flutter. Retourne `null` si la chaine est absente ou
/// invalide — l'appelant doit decider d'un fallback neutre.
///
/// Tolere :
/// - `#RRGGBB` / `RRGGBB` (alpha forcee a FF)
/// - `#AARRGGBB` / `AARRGGBB`
/// - espaces autour
/// - casse libre
Color? hexToColor(String? hex) {
  if (hex == null) return null;
  String value = hex.trim();
  if (value.isEmpty) return null;
  if (value.startsWith('#')) value = value.substring(1);
  if (value.length == 6) value = 'FF$value';
  if (value.length != 8) return null;
  final int? parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return null;
  return Color(parsed);
}
