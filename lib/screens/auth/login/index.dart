// screens/auth/login/index.dart
//
// Login partner : phone + password (pas d'OTP).
// DA : calque sur la login client (hero title 28sp, ZeetButton.primary
// sticky bottom via ZeetBottomBar, fade+slide entry). Adapte pour 1 seule
// etape (pas de progress dots, pas de Google).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/core/constants/sizes.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/providers/auth_provider.dart';
import 'package:merchant/services/navigation_service.dart';
import 'package:zeet_ui/zeet_ui.dart';
import 'controllers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final LoginController _controller;
  late final AnimationController _enterController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = LoginController();
    _controller.initFocusListeners(setState);

    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _enterController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.02),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _enterController, curve: Curves.easeOut),
    );
    _enterController.forward();

    // Auto-focus sur le champ phone
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.phoneFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _enterController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus();
    if (!_controller.formKey.currentState!.validate()) return;

    setState(() => _controller.isLoading = true);

    final error = await ref.read(authProvider.notifier).login(
          phone: _controller.phoneController.text,
          password: _controller.passwordController.text,
        );

    if (!mounted) return;
    setState(() => _controller.isLoading = false);

    if (error == null) {
      AppToast.showSuccess(
        context: context,
        message: 'Connexion reussie',
      );
      Routes.navigateAndRemoveAll(Routes.home);
    } else {
      AppToast.showError(
        context: context,
        message: error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    AppSizes().initialize(context);
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDarkMode ? AppColors.darkText : AppColors.text;
    final Color textLightColor =
        isDarkMode ? AppColors.darkTextLight : AppColors.textLight;
    final Color backgroundColor =
        isDarkMode ? AppColors.darkBackground : AppColors.white;
    final Color surfaceColor =
        isDarkMode ? AppColors.darkSurface : AppColors.white;
    final Color borderColor = isDarkMode
        ? AppColors.darkTextLight.withValues(alpha: 0.2)
        : const Color(0xFFEEEEEE);

    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _controller.formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: 48),

                    // Hero title — typo display 28
                    Text(
                      'Connexion',
                      style: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                      semanticsLabel: 'Connexion restaurateur ZEET',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Entrez vos identifiants pour gerer votre restaurant.',
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: textLightColor,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Phone field
                    _PhoneField(
                      controller: _controller.phoneController,
                      focusNode: _controller.phoneFocusNode,
                      validator: _controller.validatePhone,
                      textColor: textColor,
                      textLightColor: textLightColor,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      onSubmitted: (_) =>
                          _controller.passwordFocusNode.requestFocus(),
                    ),

                    const SizedBox(height: 20),

                    // Password field
                    _PasswordField(
                      controller: _controller.passwordController,
                      focusNode: _controller.passwordFocusNode,
                      validator: _controller.validatePassword,
                      obscured: !_controller.isPasswordVisible,
                      onToggleVisibility: () =>
                          _controller.togglePasswordVisibility(setState),
                      textColor: textColor,
                      textLightColor: textLightColor,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      onSubmitted: (_) => _submitForm(),
                    ),

                    const SizedBox(height: 24),

                    // Footer legal discret
                    Center(
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: textLightColor,
                            height: 1.4,
                          ),
                          children: const <InlineSpan>[
                            TextSpan(
                              text:
                                  "En continuant, vous acceptez nos Conditions d'utilisation partenaire.",
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      // CTA primaire sticky bottom — un seul choix, pleine largeur
      bottomNavigationBar: ZeetBottomBar(
        child: ZeetButton.primary(
          label: 'Se connecter',
          onPressed: _controller.isLoading ? null : _submitForm,
          fullWidth: true,
          loading: _controller.isLoading,
          size: ZeetButtonSize.lg,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Phone field
// ---------------------------------------------------------------------------
class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.controller,
    required this.focusNode,
    required this.validator,
    required this.textColor,
    required this.textLightColor,
    required this.surfaceColor,
    required this.borderColor,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? Function(String?) validator;
  final Color textColor;
  final Color textLightColor;
  final Color surfaceColor;
  final Color borderColor;
  final void Function(String)? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Numero de telephone',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          onFieldSubmitted: onSubmitted,
          validator: validator,
          style: TextStyle(color: textColor, fontSize: 16.sp),
          decoration: InputDecoration(
            hintText: 'ex : 0707070707',
            hintStyle: TextStyle(
              color: textLightColor.withValues(alpha: 0.6),
              fontSize: 15.sp,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '+225',
                style: TextStyle(
                  color: textColor,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            filled: true,
            fillColor: surfaceColor,
            border: _outlineBorder(borderColor),
            enabledBorder: _outlineBorder(borderColor),
            focusedBorder: _outlineBorder(AppColors.primary, width: 2),
            errorBorder: _outlineBorder(AppColors.danger),
            focusedErrorBorder: _outlineBorder(AppColors.danger, width: 2),
          ),
        ),
      ],
    );
  }

  static OutlineInputBorder _outlineBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

// ---------------------------------------------------------------------------
// Password field
// ---------------------------------------------------------------------------
class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.focusNode,
    required this.validator,
    required this.obscured,
    required this.onToggleVisibility,
    required this.textColor,
    required this.textLightColor,
    required this.surfaceColor,
    required this.borderColor,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? Function(String?) validator;
  final bool obscured;
  final VoidCallback onToggleVisibility;
  final Color textColor;
  final Color textLightColor;
  final Color surfaceColor;
  final Color borderColor;
  final void Function(String)? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Mot de passe',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscured,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: onSubmitted,
          validator: validator,
          style: TextStyle(color: textColor, fontSize: 16.sp),
          decoration: InputDecoration(
            hintText: 'Votre mot de passe',
            hintStyle: TextStyle(
              color: textLightColor.withValues(alpha: 0.6),
              fontSize: 15.sp,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscured ? Icons.visibility_off : Icons.visibility,
                color: textLightColor,
                size: 20,
              ),
              onPressed: onToggleVisibility,
            ),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            filled: true,
            fillColor: surfaceColor,
            border: _outlineBorder(borderColor),
            enabledBorder: _outlineBorder(borderColor),
            focusedBorder: _outlineBorder(AppColors.primary, width: 2),
            errorBorder: _outlineBorder(AppColors.danger),
            focusedErrorBorder: _outlineBorder(AppColors.danger, width: 2),
          ),
        ),
      ],
    );
  }

  static OutlineInputBorder _outlineBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
