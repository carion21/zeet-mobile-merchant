// screens/auth/login/controllers.dart
import 'package:merchant/services/navigation_service.dart';
import 'package:flutter/material.dart';

/// Controller pour gérer la logique de la page de connexion
class LoginController {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController phoneController = TextEditingController();

  final FocusNode phoneFocusNode = FocusNode();

  // État du formulaire
  bool isLoading = false;
  bool isPhoneValid = false;
  bool isPhoneFocused = false;

  /// Initialise les écouteurs de focus et de validation
  void initFocusListeners(Function setState) {
    // Écouteurs de focus
    phoneFocusNode.addListener(() {
      setState(() => isPhoneFocused = phoneFocusNode.hasFocus);
    });

    // Écouteurs de validation
    phoneController.addListener(() {
      setState(() {
        isPhoneValid = _validatePhoneInput(phoneController.text);
      });
    });
  }

  /// Vérifie si le numéro de téléphone est valide selon les règles
  bool _validatePhoneInput(String value) {
    // Vérifie si le numéro a 10 chiffres et respecte les préfixes ivoiriens
    return value.length == 10 && RegExp(r'^(01|05|07)').hasMatch(value);
  }

  /// Valide le numéro de téléphone saisi
  String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer votre numéro';
    }
    if (value.length != 10) {
      return 'Le numéro doit contenir 10 chiffres';
    }
    if (!RegExp(r'^(01|05|07)').hasMatch(value)) {
      return 'Le numéro doit commencer par 01, 05 ou 07';
    }
    return null;
  }

  /// Gère la soumission du formulaire de connexion
  Future<Map<String, dynamic>> handleSubmit() async {
    if (!formKey.currentState!.validate()) {
      return {'success': false, 'message': 'Veuillez corriger les erreurs du formulaire'};
    }

    try {
      isLoading = true;

      // Simulation d'un appel API pour demander un code OTP
      // En réalité, il faudrait appeler un service d'authentification
      // final otpResult = await _authService.requestOtp(
      //   type: "login",
      //   phoneNumber: phoneController.text
      // );

      // Simulation d'un délai réseau
      await Future.delayed(const Duration(seconds: 1));

      // Simulation d'une réponse positive
      final otpResult = {
        'success': true,
        'message': 'OTP créé avec succès et SMS envoyé avec succès.'
      };

      isLoading = false;

      if (otpResult['success'] == true) {
        // Ce code permettra de naviguer vers la page OTP
        Routes.pushVerifyOtp(
          phoneNumber: phoneController.text,
          type: 'login',
        );

        return {
          'success': true,
          'message': 'Code envoyé avec succès',
          'phoneNumber': phoneController.text
        };
      } else {
        return {
          'success': false,
          'message': otpResult['message'] ?? 'Erreur lors de l\'envoi du code OTP'
        };
      }
    } catch (e) {
      isLoading = false;
      return {'success': false, 'message': 'Une erreur s\'est produite: $e'};
    }
  }

  /// Formate le numéro de téléphone pour affichage (+225 XXXXXXXXXX)
  String formatPhoneNumber(String phoneNumber) {
    if (phoneNumber.isEmpty) return '';
    return '+225 $phoneNumber';
  }

  /// Libère les ressources
  void dispose() {
    phoneController.dispose();
    phoneFocusNode.dispose();
  }
}
