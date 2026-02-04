// screens/auth/verify_otp/index.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/core/constants/sizes.dart';
import 'package:merchant/core/constants/icons.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/services/navigation_service.dart';
import 'controllers.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String? fullName; // Optionnel, présent seulement lors de l'inscription
  final String type; // 'login' ou 'register'

  const VerifyOtpScreen({
    super.key,
    required this.phoneNumber,
    this.fullName,
    required this.type,
  });

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  late final VerifyOtpController _controller;
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  final List<TextEditingController> _textControllers = List.generate(4, (_) => TextEditingController());

  @override
  void initState() {
    super.initState();
    _controller = VerifyOtpController(
      phoneNumber: widget.phoneNumber,
      fullName: widget.fullName,
      type: widget.type,
    );

    // Initialiser les écouteurs pour le déplacement automatique entre les champs
    for (int i = 0; i < 4; i++) {
      _textControllers[i].addListener(() {
        _updateOtpCode();
      });
    }

    // Démarrer le compte à rebours
    _controller.startTimer(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var controller in _textControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // Met à jour le code OTP complet
  void _updateOtpCode() {
    final otpCode = _textControllers.map((c) => c.text).join();
    _controller.updateOtpCode(otpCode);
    setState(() {});
  }

  // Gestion de la pression sur un chiffre du clavier numérique
  void _onNumberPressed(String number) {
    for (int i = 0; i < _textControllers.length; i++) {
      if (_textControllers[i].text.isEmpty) {
        _textControllers[i].text = number;
        if (i < 3) {
          _focusNodes[i + 1].requestFocus();
        } else {
          // Défocaliser tous les champs quand les 4 chiffres sont saisis
          for (var node in _focusNodes) {
            node.unfocus();
          }
          _verifyOtp();
        }
        break;
      }
    }
  }

  // Gestion du bouton effacer
  void _onDeletePressed() {
    for (int i = _textControllers.length - 1; i >= 0; i--) {
      if (_textControllers[i].text.isNotEmpty) {
        _textControllers[i].clear();
        _focusNodes[i].requestFocus();
        setState(() {});
        break;
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (_controller.otpCode.length != 4) {
      if (!mounted) return;
      AppToast.showWarning(
        context: context,
        message: "Veuillez saisir le code à 4 chiffres complet",
      );
      return;
    }

    setState(() => _controller.isLoading = true);

    final result = await _controller.verifyOtp();

    if (!mounted) return;
    setState(() => _controller.isLoading = false);

    if (result['success']) {
      if (!mounted) return;
      AppToast.showSuccess(
        context: context,
        message: "Vérification réussie !",
      );

      // Naviguer vers l'écran d'accueil sans possibilité de retour arrière
      Routes.navigateAndRemoveAll(Routes.home);
    } else {
      if (!mounted) return;
      AppToast.showError(
        context: context,
        message: result['message'] ?? "Échec de la vérification",
      );
    }
  }

  Future<void> _resendOtp() async {
    if (!_controller.canResend) return;

    setState(() => _controller.isResending = true);

    final result = await _controller.resendOtp();

    if (!mounted) return;
    setState(() {
      _controller.isResending = false;
      if (result['success']) {
        _controller.resetTimer(() {
          if (mounted) setState(() {});
        });
      }
    });

    if (result['success']) {
      if (!mounted) return;
      AppToast.showSuccess(
        context: context,
        message: "Un nouveau code a été envoyé",
      );
    } else {
      if (!mounted) return;
      AppToast.showError(
        context: context,
        message: result['message'] ?? "Échec de l'envoi du nouveau code",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    AppSizes().initialize(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppColors.darkText : AppColors.text;
    final textLightColor = isDarkMode ? AppColors.darkTextLight : AppColors.textLight;
    final backgroundColor = isDarkMode ? AppColors.darkBackground : Colors.white;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : Colors.white;
    final borderColor = isDarkMode ? AppColors.darkTextLight.withValues(alpha: 0.2) : const Color(0xFFEEEEEE);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: IconManager.getIcon('arrow_back', color: textColor),
          onPressed: () => Routes.goBack(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 40.h),

                  // Message avec numéro masqué
                  Center(
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14.0.sp,
                          color: textLightColor,
                        ),
                        children: [
                          const TextSpan(text: 'Un code à 4 chiffres vous a été envoyé au '),
                          TextSpan(
                            text: _controller.formatPhoneNumber(),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 48.h),

                  // Champs OTP (4 chiffres)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      4,
                      (index) => _buildOtpField(
                        controller: _textControllers[index],
                        focusNode: _focusNodes[index],
                        index: index,
                        isDarkMode: isDarkMode,
                        textColor: textColor,
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                      ),
                    ),
                  ),

                  SizedBox(height: 32.h),

                  // Bouton renvoyer le code
                  Center(
                    child: GestureDetector(
                      onTap: _controller.canResend ? _resendOtp : null,
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 14.0.sp,
                            color: textLightColor,
                          ),
                          children: [
                            const TextSpan(text: 'Code non reçu ? '),
                            TextSpan(
                              text: _controller.canResend
                                  ? 'Renvoyer le code'
                                  : 'Renvoyer dans ${_controller.timerText}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _controller.canResend
                                    ? AppColors.primary
                                    : textLightColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 40.h),
                ],
              ),
            ),
          ),

          // Clavier numérique personnalisé
          Container(
            padding: EdgeInsets.all(20.w),
            color: isDarkMode ? AppColors.darkSurface : Colors.grey[50],
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  // Lignes 1-3 (chiffres 1-9)
                  for (int row = 0; row < 3; row++)
                    Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (int col = 1; col <= 3; col++)
                            _buildNumberKey('${row * 3 + col}', textColor),
                        ],
                      ),
                    ),

                  // Ligne du bas (0 au centre, effacer à droite)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SizedBox(width: 60.w), // Espace vide à gauche
                      _buildNumberKey('0', textColor),
                      _buildDeleteKey(textLightColor),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget pour créer un champ de saisie OTP
  Widget _buildOtpField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required int index,
    required bool isDarkMode,
    required Color textColor,
    required Color surfaceColor,
    required Color borderColor,
  }) {
    return Container(
      width: 60.w,
      height: 60.h,
      decoration: BoxDecoration(
        border: Border.all(
          color: controller.text.isNotEmpty ? AppColors.primary : borderColor,
          width: 2.w,
        ),
        borderRadius: BorderRadius.circular(12.r),
        color: surfaceColor,
      ),
      child: Center(
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.none, // Désactive le clavier système
          maxLength: 1,
          style: TextStyle(
            fontSize: 24.0.sp,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            counterText: '',
          ),
          onTap: () {
            controller.selection = TextSelection.fromPosition(
              TextPosition(offset: controller.text.length),
            );
          },
        ),
      ),
    );
  }

  // Widget pour un bouton numérique
  Widget _buildNumberKey(String number, Color textColor) {
    return GestureDetector(
      onTap: () => _onNumberPressed(number),
      child: SizedBox(
        width: 60.w,
        height: 60.h,
        child: Center(
          child: Text(
            number,
            style: TextStyle(
              fontSize: 24.0.sp,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  // Widget pour le bouton effacer
  Widget _buildDeleteKey(Color iconColor) {
    return GestureDetector(
      onTap: _onDeletePressed,
      child: SizedBox(
        width: 60.w,
        height: 60.h,
        child: Center(
          child: Icon(
            Icons.backspace_outlined,
            size: 24.sp,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}
