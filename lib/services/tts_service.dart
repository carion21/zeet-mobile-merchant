// Service de synthese vocale (Text-To-Speech) pour la lecture audio du
// code OTP de collecte.
//
// Contexte d'usage :
//  - Cuisine bruyante : le partner peut etre eloigne de la tablette de
//    caisse au moment ou le rider arrive. Le code OTP doit pouvoir etre
//    lu a voix haute (ex: "un, deux, trois, quatre") pour etre dicte au
//    rider sans avoir a regarder l'ecran.
//  - Plateforme : utilise les TTS systeme natifs (iOS AVSpeechSynthesizer
//    et Android TextToSpeech). Aucune dependance reseau, aucun cout.
//  - Lecture lente, chiffre par chiffre, avec un leger silence entre
//    chaque chiffre pour la clarte.
//
// Lifecycle :
//  - Singleton initialise paresseusement au premier appel a [speakOtp].
//  - [dispose] libere les ressources natives (a appeler quand l'ecran OTP
//    se ferme).
//
// Robustesse :
//  - Aucune exception n'est propagee : si le TTS systeme n'est pas
//    disponible (ex: emulator sans voice data), [speakOtp] retourne false
//    silencieusement et l'UI peut afficher un fallback ("Non disponible").

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Wrapper sur [FlutterTts] dedie aux usages partner (lecture OTP).
///
/// Singleton accede via [TtsService.instance].
class TtsService {
  TtsService._();

  static final TtsService instance = TtsService._();

  FlutterTts? _tts;
  bool _initialized = false;
  bool _speaking = false;

  /// Initialise le moteur TTS systeme. Idempotent et tolerant aux echecs
  /// (ex: voice data absente sur l'emulator).
  Future<bool> _ensureInit() async {
    if (_initialized) return _tts != null;
    _initialized = true;
    try {
      final tts = FlutterTts();
      // Langue francaise par defaut (le partner cible). Si la voix n'est
      // pas disponible, le systeme retombe sur la langue par defaut.
      await tts.setLanguage('fr-FR');
      // Lecture lente : on prefere clarte > rapidite (l'OTP est essentiel).
      await tts.setSpeechRate(0.4); // 0.0 = lent, 1.0 = normal, plus = rapide.
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);
      // Sur iOS, on veut que la lecture soit audible meme en mode silencieux
      // (cf. tablette POS souvent en mute pour eviter les notifs parasites).
      await tts.setSharedInstance(true);
      await tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        const <IosTextToSpeechAudioCategoryOptions>[
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
      );
      _tts = tts;
      return true;
    } catch (e) {
      debugPrint('[TtsService] init failed: $e');
      _tts = null;
      return false;
    }
  }

  /// Lit le code OTP a voix haute, chiffre par chiffre.
  ///
  /// Exemple : `speakOtp("1234")` → "un, deux, trois, quatre".
  ///
  /// Retourne `true` si la lecture a demarre, `false` si le TTS systeme
  /// n'est pas disponible. La fin de la lecture n'est pas attendue (fire
  /// and forget).
  Future<bool> speakOtp(String code) async {
    if (code.trim().isEmpty) return false;
    final ready = await _ensureInit();
    if (!ready || _tts == null) return false;
    try {
      // Annule toute lecture en cours pour repartir proprement (utile si
      // l'utilisateur retap rapidement le bouton).
      await _tts!.stop();
      _speaking = true;
      // Phrase en francais avec virgules pour menager les pauses naturelles
      // du synthe. Plus naturel et lisible que "un deux trois quatre" (qui
      // serait debite sans pause).
      final spelled = _spellOut(code);
      await _tts!.speak(spelled);
      // Note : flutter_tts ne propose pas un await fiable sur la fin de
      // lecture sur toutes les plateformes. On laisse fire-and-forget.
      _speaking = false;
      return true;
    } catch (e) {
      debugPrint('[TtsService] speakOtp failed: $e');
      _speaking = false;
      return false;
    }
  }

  /// Arrete toute lecture en cours.
  Future<void> stop() async {
    if (!_initialized || _tts == null) return;
    try {
      await _tts!.stop();
      _speaking = false;
    } catch (e) {
      debugPrint('[TtsService] stop failed: $e');
    }
  }

  /// Libere les ressources natives. A appeler dans `dispose()` de l'ecran.
  Future<void> dispose() async {
    if (_tts == null) return;
    try {
      await _tts!.stop();
    } catch (_) {}
    _tts = null;
    _initialized = false;
    _speaking = false;
  }

  bool get isSpeaking => _speaking;

  /// Convertit "1234" en "un, deux, trois, quatre". Les caracteres non-chiffres
  /// sont preserves tels quels (utile si le backend renvoyait "12-34" ou
  /// similaire un jour).
  String _spellOut(String code) {
    final buffer = StringBuffer();
    for (int i = 0; i < code.length; i++) {
      final ch = code[i];
      if (i > 0) buffer.write(', ');
      buffer.write(_digitToWord(ch));
    }
    return buffer.toString();
  }

  String _digitToWord(String ch) {
    switch (ch) {
      case '0':
        return 'zero';
      case '1':
        return 'un';
      case '2':
        return 'deux';
      case '3':
        return 'trois';
      case '4':
        return 'quatre';
      case '5':
        return 'cinq';
      case '6':
        return 'six';
      case '7':
        return 'sept';
      case '8':
        return 'huit';
      case '9':
        return 'neuf';
      default:
        return ch;
    }
  }
}
