import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:merchant/core/widgets/app_popup.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/providers/auth_provider.dart';
import 'package:merchant/providers/profile_provider.dart';
import 'package:zeet_ui/zeet_ui.dart';

/// Header du profil partner : avatar/logo, nom du restaurant,
/// telephone, adresse.
///
/// Donnees lues depuis [authProvider] (fallback rapide post-login)
/// et [partnerDataProvider] (source canonique apres chargement).
///
/// Tap sur le logo → bottom sheet "Changer / Supprimer la photo" avec
/// `image_picker` (galerie ou camera) puis `profileProvider.uploadLogo`.
class ProfileHeader extends ConsumerWidget {
  const ProfileHeader({required this.textColor, super.key});

  final Color textColor;

  Future<void> _pickAndUpload(
    BuildContext context,
    WidgetRef ref,
    ImageSource source,
  ) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null) return;
      final file = File(picked.path);
      if (!context.mounted) return;
      final err = await ref.read(profileProvider.notifier).uploadLogo(file);
      if (!context.mounted) return;
      if (err != null) {
        AppToast.showError(context: context, message: err);
      } else {
        ZeetHaptics.success();
        AppToast.showSuccess(
          context: context,
          message: 'Logo mis a jour.',
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      AppToast.showError(
        context: context,
        message: 'Selection d\'image impossible.',
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await AppPopup.showConfirmation(
      context: context,
      title: 'Supprimer le logo',
      message: 'Le logo sera retire du restaurant. Vous pouvez en uploader '
          'un nouveau a tout moment.',
      confirmLabel: 'Supprimer',
      cancelLabel: 'Annuler',
      isDestructive: true,
    );
    if (!confirm || !context.mounted) return;
    final err = await ref.read(profileProvider.notifier).deleteLogo();
    if (!context.mounted) return;
    if (err != null) {
      AppToast.showError(context: context, message: err);
    } else {
      ZeetHaptics.success();
      AppToast.showSuccess(
        context: context,
        message: 'Logo supprime.',
      );
    }
  }

  void _showLogoSheet(BuildContext context, WidgetRef ref, bool hasLogo) {
    ZeetHaptics.tap();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickAndUpload(context, ref, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickAndUpload(context, ref, ImageSource.gallery);
              },
            ),
            if (hasLogo)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: ZeetColors.danger,
                ),
                title: const Text(
                  'Supprimer le logo',
                  style: TextStyle(color: ZeetColors.danger),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _confirmDelete(context, ref);
                },
              ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }

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
    final isUpdating = ref.watch(profileProvider).isUpdating;

    return Column(
      children: <Widget>[
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            GestureDetector(
              onTap: isUpdating
                  ? null
                  : () => _showLogoSheet(context, ref, logoUrl != null),
              child: Container(
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
            ),
            // Camera badge bottom-right — affordance "tap pour changer".
            Positioned(
              right: -2,
              bottom: -2,
              child: GestureDetector(
                onTap: isUpdating
                    ? null
                    : () => _showLogoSheet(context, ref, logoUrl != null),
                child: Container(
                  width: 28.w,
                  height: 28.h,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ZeetColors.primary,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    isUpdating
                        ? Icons.hourglass_top_rounded
                        : Icons.photo_camera_rounded,
                    size: 14.sp,
                    color: ZeetColors.primary,
                  ),
                ),
              ),
            ),
          ],
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
