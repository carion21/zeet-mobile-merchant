// screens/auth/login/index.dart
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/core/constants/sizes.dart';
import 'package:merchant/core/constants/icons.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'controllers.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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

    final result = await _controller.handleSubmit();

    setState(() => _controller.isLoading = false);

    if (result['success']) {
      // Afficher un message de succès
      AppToast.showSuccess(
        context: context,
        message: "Un code a été envoyé au ${_controller.formatPhoneNumber(_controller.phoneController.text)}",
      );

      // La navigation est gérée dans le controller
    } else {
      // Afficher un message d'erreur
      AppToast.showError(
        context: context,
        message: result['message'] ?? "Une erreur s'est produite",
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
          padding: EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 60),

                // Logo centré
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

                SizedBox(height: 40),

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

                SizedBox(height: 12),

                // Sous-titre
                Text(
                  'Entrez votre numéro pour gérer\nvotre restaurant',
                  style: TextStyle(
                    fontSize: 15.0.sp,
                    color: textLightColor,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 50),

                // Champ Numéro de téléphone
                _buildInputField(
                  controller: _controller.phoneController,
                  focusNode: _controller.phoneFocusNode,
                  label: 'Numéro de téléphone',
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

                SizedBox(height: 12),

                // Message d'aide
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    'Un code vous sera envoyé par SMS pour vous connecter',
                    style: TextStyle(
                      fontSize: 12.0.sp,
                      color: textLightColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                SizedBox(height: 40),

                // Bouton Continuer
                _buildMainButton(
                  onPressed: _controller.isPhoneValid && !_controller.isLoading ? _submitForm : null,
                  label: 'Continuer',
                  isLoading: _controller.isLoading,
                ),

                SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget pour créer un champ de formulaire
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
          padding: EdgeInsets.only(left: 4, bottom: 8),
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
            contentPadding: EdgeInsets.symmetric(
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

  // Widget pour créer le bouton principal
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
          child: CircularProgressIndicator(
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
            SizedBox(width: 8),
            IconManager.getIcon('arrow_forward', size: 18),
          ],
        ),
      ),
    );
  }
}
