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

    // Densite partner POS (design-system §4) : avatar 72pt, typo compacte,
    // gaps 8-10. Le header ne doit pas voler la moitie de l'ecran —
    // l'info qui interesse le partner c'est ses stats et ses actions, pas
    // son propre nom en gros (il sait qui il est).
    return Column(
      children: <Widget>[
        Container(
          width: 72.w,
          height: 72.h,
          decoration: const BoxDecoration(
            color: ZeetColors.primary,
            shape: BoxShape.circle,
          ),
          child: logoUrl != null
              ? ClipOval(
                  child: ZeetImage(
                    url: logoUrl,
                    width: 72.w,
                    height: 72.h,
                    fit: BoxFit.cover,
                    errorWidget: Center(
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24.sp,
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
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),
        SizedBox(height: 10.h),

        // Nom du restaurant — max 2 lignes pour eviter l'overflow sur
        // les noms longs (ex: "Le Palmier Moussa de Bingerville").
        Text(
          displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),

        SizedBox(height: 2.h),
        Text(
          displayPhone,
          style: TextStyle(
            color: ZeetColors.primary,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),

        if (partnerProfile?.address != null ||
            partner?.partner?.address != null) ...<Widget>[
          SizedBox(height: 2.h),
          Text(
            partnerProfile?.address ?? partner!.partner!.address!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.65),
              fontSize: 12.sp,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }
}
