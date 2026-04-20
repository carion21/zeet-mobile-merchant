import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:zeet_ui/zeet_ui.dart';

/// Fallback d'erreur de chargement du profil.
///
/// Garde le bouton "Se deconnecter" atteignable meme si le profil
/// ne charge pas, pour permettre de sortir d'un compte coince.
class ProfileErrorFallback extends StatelessWidget {
  const ProfileErrorFallback({
    required this.message,
    required this.onLogout,
    this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onLogout;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(height: 40.h),
          ZeetErrorState.fromError(
            message,
            onRetry: onRetry,
          ),
          SizedBox(height: 24.h),
          ZeetButton(
            label: 'Déconnexion',
            onPressed: onLogout,
            variant: ZeetButtonVariant.danger,
            size: ZeetButtonSize.md,
            icon: Icons.logout_rounded,
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}
