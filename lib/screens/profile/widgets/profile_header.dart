import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/providers/auth_provider.dart';
import 'package:merchant/providers/profile_provider.dart';
import 'package:zeet_ui/zeet_ui.dart';

/// Header du profil partner : avatar/logo, nom du restaurant,
/// telephone, adresse.
///
/// Donnees lues depuis [authProvider] (fallback rapide post-login)
/// et [partnerDataProvider] (source canonique apres chargement).
class ProfileHeader extends ConsumerWidget {
  const ProfileHeader({required this.textColor, super.key});

  final Color textColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final partnerProfile = ref.watch(partnerDataProvider);
    final partner = authState.partner;
    final displayName = partnerProfile?.name ??
        partner?.restaurantName ??
        'Mon Restaurant';
    final displayPhone = partner != null ? '+225 ${partner.phone}' : '';
    final logoUrl = partnerProfile?.picture ?? partner?.partner?.picture;

    String initials = displayName
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((word) => word[0])
        .take(2)
        .join()
        .toUpperCase();
    if (initials.isEmpty) initials = 'MR';

    return Column(
      children: <Widget>[
        // Avatar avec initiales ou photo
        Container(
          width: 100.w,
          height: 100.h,
          decoration: const BoxDecoration(
            color: ZeetColors.primary,
            shape: BoxShape.circle,
          ),
          child: logoUrl != null
              ? ClipOval(
                  child: ZeetImage(
                    url: logoUrl,
                    width: 100.w,
                    height: 100.h,
                    fit: BoxFit.cover,
                    errorWidget: Center(
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),
        SizedBox(height: 16.h),

        // Nom du restaurant
        Text(
          displayName,
          style: TextStyle(
            color: textColor,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),

        // Numero de telephone
        SizedBox(height: 4.h),
        Text(
          displayPhone,
          style: TextStyle(
            color: ZeetColors.primary,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),

        // Adresse si disponible
        if (partnerProfile?.address != null ||
            partner?.partner?.address != null) ...<Widget>[
          SizedBox(height: 4.h),
          Text(
            partnerProfile?.address ?? partner!.partner!.address!,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.7),
              fontSize: 13.sp,
            ),
          ),
        ],
      ],
    );
  }
}
