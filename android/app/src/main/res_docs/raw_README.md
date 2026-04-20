# android/app/src/main/res/raw/

Raw resources Android — notamment les sons custom utilisés par les
`AndroidNotificationChannel` via `RawResourceAndroidNotificationSound(...)`.

## Fichiers attendus

- `incoming_order.mp3` — Sonnerie distincte du channel
  `zeet_partner_incoming_order_v2` (cf. `lib/services/local_notification_service.dart`).
  **Asset binaire à fournir par l'equipe sound design**, voir
  `assets/sounds/README.md` pour les specs.

## Contraintes Android

- Nom de fichier en **lowercase**, pas d'espaces, pas de tirets,
  pas d'accents (contrainte resource id).
- Pas de sous-dossier (les raw resources sont à plat).
- Format MP3, OGG ou WAV. Pas de `.m4a` (rejeté par certains OEM).

## Build

Ajouter / supprimer un fichier ici nécessite un `flutter clean` puis
`flutter run` pour que Gradle régénère la R class.
