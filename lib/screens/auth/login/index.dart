// screens/auth/login/index.dart
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/core/constants/sizes.dart';
import 'package:merchant/core/constants/icons.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/providers/auth_provider.dart';
import 'package:merchant/services/navigation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'controllers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final LoginController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LoginController();
    _controller.initFocusListeners(setState);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_controller.formKey.currentState!.validate()) return;

    setState(() => _controller.isLoading = true);

    final error = await ref.read(authProvider.notifier).login(
          phone: _controller.phoneController.text,
          password: _controller.passwordController.text,
        );

    if (!mounted) return;
    setState(() => _controller.isLoading = false);

    if (error == null) {
      // Succes : naviguer vers l'ecran principal
      AppToast.showSuccess(
        context: context,
        message: 'Connexion reussie',
      );
      Routes.navigateAndRemoveAll(Routes.home);
    } else {
      // Erreur : afficher le message
      AppToast.showError(
        context: context,
        message: error,
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),

                // Logo centre
                Container(
                  width: 80.w,
                  height: 80.h,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconManager.getIcon(
                    'restaurant',
                    color: Colors.white,
                    size: 40.r,
                  ),
                ),

                const SizedBox(height: 40),

                // Titre principal
                Text(
                  'Connexion Restaurateur',
                  style: TextStyle(
                    fontSize: 28.0.sp,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                // Sous-titre
                Text(
                  'Connectez-vous pour gerer\nvotre restaurant',
                  style: TextStyle(
                    fontSize: 15.0.sp,
                    color: textLightColor,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 50),

                // Champ Numero de telephone
                _buildInputField(
                  controller: _controller.phoneController,
                  focusNode: _controller.phoneFocusNode,
                  label: 'Numero de telephone',
                  hintText: 'ex: 0707070707',
                  prefixIcon: 'phone',
                  keyboardType: TextInputType.phone,
                  prefix: '+225 ',
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: _controller.validatePhone,
                  isDarkMode: isDarkMode,
                  textColor: textColor,
                  textLightColor: textLightColor,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                ),

                const SizedBox(height: 20),

                // Champ Mot de passe
                _buildPasswordField(
                  controller: _controller.passwordController,
                  focusNode: _controller.passwordFocusNode,
                  label: 'Mot de passe',
                  hintText: 'Entrez votre mot de passe',
                  validator: _controller.validatePassword,
                  isDarkMode: isDarkMode,
                  textColor: textColor,
                  textLightColor: textLightColor,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                ),

                const SizedBox(height: 40),

                // Bouton Se connecter
                _buildMainButton(
                  onPressed: _controller.isFormValid && !_controller.isLoading ? _submitForm : null,
                  label: 'Se connecter',
                  isLoading: _controller.isLoading,
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget pour creer un champ de formulaire texte
  Widget _buildInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hintText,
    required String prefixIcon,
    required bool isDarkMode,
    required Color textColor,
    required Color textLightColor,
    required Color surfaceColor,
    required Color borderColor,
    String? prefix,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.0.sp,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: textLightColor.withValues(alpha: 0.6),
              fontSize: 14.0.sp,
            ),
            prefixIcon: IconManager.getIcon(
              prefixIcon,
              color: textLightColor,
              size: 18.r,
            ),
            prefixText: prefix,
            prefixStyle: TextStyle(
              color: textColor,
              fontSize: 14.0.sp,
              fontWeight: FontWeight.w500,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: borderColor,
                width: 1.w,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: borderColor,
                width: 1.w,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: AppColors.primary,
                width: 2.w,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.red,
                width: 1.w,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.red,
                width: 2.w,
              ),
            ),
            filled: true,
            fillColor: surfaceColor,
            suffixIcon: validator != null && validator(controller.text) == null && controller.text.isNotEmpty
                ? IconManager.getIcon('check', color: Colors.green, size: 18)
                : null,
          ),
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          style: TextStyle(
            color: textColor,
            fontSize: 14.0.sp,
          ),
        ),
      ],
    );
  }

  // Widget pour creer le champ mot de passe avec toggle visibilite
  Widget _buildPasswordField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hintText,
    required bool isDarkMode,
    required Color textColor,
    required Color textLightColor,
    required Color surfaceColor,
    required Color borderColor,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.0.sp,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: !_controller.isPasswordVisible,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: textLightColor.withValues(alpha: 0.6),
              fontSize: 14.0.sp,
            ),
            prefixIcon: IconManager.getIcon(
              'lock',
              color: textLightColor,
              size: 18.r,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _controller.isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                color: textLightColor,
                size: 20.r,
              ),
              onPressed: () => _controller.togglePasswordVisibility(setState),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: borderColor,
                width: 1.w,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: borderColor,
                width: 1.w,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: AppColors.primary,
                width: 2.w,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.red,
                width: 1.w,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.red,
                width: 2.w,
              ),
            ),
            filled: true,
            fillColor: surfaceColor,
          ),
          validator: validator,
          style: TextStyle(
            color: textColor,
            fontSize: 14.0.sp,
          ),
          onFieldSubmitted: (_) {
            if (_controller.isFormValid) _submitForm();
          },
        ),
      ],
    );
  }

  // Widget pour creer le bouton principal
  Widget _buildMainButton({
    required VoidCallback? onPressed,
    required String label,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50.h,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: isLoading
            ? SizedBox(
                height: 24.h,
                width: 24.w,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16.0.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconManager.getIcon('arrow_forward', size: 18),
                ],
              ),
      ),
    );
  }
}
