// screens/auth/verify_otp/controllers.dart
import 'dart:async';

/// Controller pour gérer la logique de la page de vérification OTP
class VerifyOtpController {
  final String phoneNumber;
  final String? fullName; // Optionnel, présent seulement lors de l'inscription
  final String type; // 'login' ou 'register'

  String otpCode = '';
  bool isLoading = false;
  bool isResending = false;

  // Compte à rebours pour renvoyer le code
  Timer? _timer;
  int _countdown = 60; // 60 secondes
  int get remainingTime => _countdown;
  bool get canResend => _countdown <= 0;
  String get timerText => '${_countdown}s';

  VerifyOtpController({
    required this.phoneNumber,
    this.fullName,
    required this.type,
  });

  /// Démarre le compte à rebours
  void startTimer(Function setState) {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        _countdown--;
        setState();
      } else {
        timer.cancel();
      }
    });
  }

  /// Réinitialise le compte à rebours
  void resetTimer(Function setState) {
    _countdown = 60;
    _timer?.cancel();
    startTimer(setState);
  }

  /// Met à jour le code OTP
  void updateOtpCode(String code) {
    otpCode = code;
  }

  /// Vérifie le code OTP
  Future<Map<String, dynamic>> verifyOtp() async {
    try {
      // Simulation d'un appel API pour vérifier le code OTP
      // final verifyResult = await _authService.verifyOtp(
      //   phoneNumber: phoneNumber,
      //   otp: otpCode,
      //   type: type,
      //   fullName: fullName,
      // );

      // Simulation d'un délai réseau
      await Future.delayed(const Duration(seconds: 1));

      // Simulation d'une réponse positive
      final verifyResult = {
        'success': true,
        'message': 'Code vérifié avec succès',
        'token': 'sample-jwt-token',
      };

      return verifyResult;
    } catch (e) {
      return {'success': false, 'message': 'Une erreur s\'est produite: $e'};
    }
  }

  /// Renvoie un nouveau code OTP
  Future<Map<String, dynamic>> resendOtp() async {
    try {
      // Simulation d'un appel API pour renvoyer un code OTP
      // final resendResult = await _authService.requestOtp(
      //   phoneNumber: phoneNumber,
      //   type: type,
      // );

      // Simulation d'un délai réseau
      await Future.delayed(const Duration(seconds: 1));

      // Simulation d'une réponse positive
      final resendResult = {
        'success': true,
        'message': 'Nouveau code envoyé avec succès',
      };

      return resendResult;
    } catch (e) {
      return {'success': false, 'message': 'Une erreur s\'est produite: $e'};
    }
  }

  /// Formate le numéro de téléphone pour affichage
  String formatPhoneNumber() {
    if (phoneNumber.isEmpty) return '';
    // Formater pour masquer partiellement le numéro (ex: +225 *******07)
    final lastTwoDigits = phoneNumber.substring(phoneNumber.length - 2);
    return '+225 *******$lastTwoDigits';
  }

  /// Libère les ressources
  void dispose() {
    _timer?.cancel();
  }
}
