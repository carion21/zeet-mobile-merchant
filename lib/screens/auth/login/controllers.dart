// screens/auth/login/controllers.dart
import 'package:flutter/material.dart';

/// Controller pour gerer la logique de la page de connexion partner.
/// Le partner se connecte avec telephone + mot de passe (pas OTP).
class LoginController {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final FocusNode phoneFocusNode = FocusNode();
  final FocusNode passwordFocusNode = FocusNode();

  // Etat du formulaire
  bool isLoading = false;
  bool isPhoneValid = false;
  bool isPasswordValid = false;
  bool isPhoneFocused = false;
  bool isPasswordFocused = false;
  bool isPasswordVisible = false;

  /// Verifie si le formulaire est pret a etre soumis.
  bool get isFormValid => isPhoneValid && isPasswordValid;

  /// Initialise les ecouteurs de focus et de validation.
  void initFocusListeners(Function setState) {
    // Ecouteurs de focus
    phoneFocusNode.addListener(() {
      setState(() => isPhoneFocused = phoneFocusNode.hasFocus);
    });

    passwordFocusNode.addListener(() {
      setState(() => isPasswordFocused = passwordFocusNode.hasFocus);
    });

    // Ecouteurs de validation
    phoneController.addListener(() {
      setState(() {
        isPhoneValid = _validatePhoneInput(phoneController.text);
      });
    });

    passwordController.addListener(() {
      setState(() {
        isPasswordValid = passwordController.text.length >= 4;
      });
    });
  }

  /// Verifie si le numero de telephone est valide selon les regles ivoiriennes.
  bool _validatePhoneInput(String value) {
    return value.length == 10 && RegExp(r'^(01|05|07)').hasMatch(value);
  }

  /// Valide le numero de telephone saisi.
  String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer votre numero';
    }
    if (value.length != 10) {
      return 'Le numero doit contenir 10 chiffres';
    }
    if (!RegExp(r'^(01|05|07)').hasMatch(value)) {
      return 'Le numero doit commencer par 01, 05 ou 07';
    }
    return null;
  }

  /// Valide le mot de passe saisi.
  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer votre mot de passe';
    }
    if (value.length < 4) {
      return 'Le mot de passe doit contenir au moins 4 caracteres';
    }
    return null;
  }

  /// Bascule la visibilite du mot de passe.
  void togglePasswordVisibility(Function setState) {
    setState(() {
      isPasswordVisible = !isPasswordVisible;
    });
  }

  /// Formate le numero de telephone pour affichage (+225 XXXXXXXXXX).
  String formatPhoneNumber(String phoneNumber) {
    if (phoneNumber.isEmpty) return '';
    return '+225 $phoneNumber';
  }

  /// Libere les ressources.
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    phoneFocusNode.dispose();
    passwordFocusNode.dispose();
  }
}
