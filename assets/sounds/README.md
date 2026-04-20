# assets/sounds/

Sons custom de l'app **Partner ZEET**.

## Fichiers attendus

| Fichier | Usage | Format | Durée | Loop |
|---|---|---|---|---|
| `incoming_order.mp3` | Sonnerie nouvelle commande (channel `zeet_partner_incoming_order_v2`) | MP3 44.1kHz / 192kbps mono | 3-5s | oui (loopable proprement) |

## Statut Phase 2

`incoming_order.mp3` n'est PAS encore commit dans le repo (asset binaire à
fournir par l'équipe sound design). Tant que le fichier est absent :

- **Android** : le channel `zeet_partner_incoming_order_v2` retombe
  automatiquement sur le son de notification système (par défaut alarm
  sound). La déclaration `RawResourceAndroidNotificationSound('incoming_order')`
  ne casse pas le build mais ne joue rien si la raw resource est absente.
- **iOS** : `DarwinNotificationDetails(sound: 'incoming_order.caf')` retombe
  également sur le son par défaut.
- **Fallback in-process** : `IncomingOrderScreen` lance un
  `FlutterRingtonePlayer().play(android: AndroidSounds.alarm, ios: IosSounds.alarm)`
  en boucle dès l'ouverture, ce qui couvre toutes les situations
  foreground (le rendu sonore est garanti).

## Quand le master arrive

1. Copier le fichier final `incoming_order.mp3` dans **ce dossier** (`assets/sounds/`).
2. Copier également la version `incoming_order.mp3` dans
   `android/app/src/main/res/raw/incoming_order.mp3`
   (lowercase, pas d'espaces, pas d'accents — contrainte Android resource).
3. Pour iOS : convertir en `incoming_order.caf` via :
   ```sh
   afconvert incoming_order.mp3 incoming_order.caf -d ima4 -f caff -v
   ```
   et drop dans `ios/Runner/incoming_order.caf` + ajouter dans le projet
   Xcode (Build Phases → Copy Bundle Resources).
4. Bumper la version du channel Android :
   `kIncomingOrderChannelId = 'zeet_partner_incoming_order_v3'`
   (Android refuse de modifier le son d'un channel après création — il
   faut un nouvel ID pour que le nouveau son soit pris en compte).

## Recommandations sound design

- **Pas de mélodie** : pattern percussif court (cloche grave + tap aigu).
- **Distinct des sons système** : ne pas reprendre une "ringtone" Android
  classique, sinon les utilisateurs filtrent inconsciemment.
- **Loop propre** : silence naturel à la fin (pas de "pop" au reboucle).
- **Mono** : la tablette POS partner est souvent montée dans un haut-parleur
  unique en cuisine — stéréo inutile.
- **Niveau** : -3 dBFS peak, normalisé loudness LUFS -16.
