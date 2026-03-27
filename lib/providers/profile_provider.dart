import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/models/partner_model.dart';
import 'package:merchant/services/api_client.dart';
import 'package:merchant/services/profile_service.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum ProfileStatus { initial, loading, loaded, error }

class ProfileState {
  final ProfileStatus status;
  final PartnerData? profile;
  final double? commissionRate;
  final String? errorMessage;
  final bool isUpdating;

  const ProfileState({
    this.status = ProfileStatus.initial,
    this.profile,
    this.commissionRate,
    this.errorMessage,
    this.isUpdating = false,
  });

  ProfileState copyWith({
    ProfileStatus? status,
    PartnerData? profile,
    double? commissionRate,
    String? errorMessage,
    bool? isUpdating,
  }) {
    return ProfileState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      commissionRate: commissionRate ?? this.commissionRate,
      errorMessage: errorMessage,
      isUpdating: isUpdating ?? this.isUpdating,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class ProfileNotifier extends StateNotifier<ProfileState> {
  final ProfileService _profileService;

  ProfileNotifier({ProfileService? profileService})
      : _profileService = profileService ?? ProfileService(),
        super(const ProfileState());

  // ---------------------------------------------------------------------------
  // GET /v1/partner/profile
  // ---------------------------------------------------------------------------
  /// Charge le profil partner depuis l'API.
  Future<void> loadProfile() async {
    state = state.copyWith(status: ProfileStatus.loading);

    try {
      final profile = await _profileService.getProfile();
      state = state.copyWith(
        status: ProfileStatus.loaded,
        profile: profile,
      );
    } on ApiException catch (e) {
      debugPrint('[ProfileProvider] loadProfile failed: $e');
      state = state.copyWith(
        status: ProfileStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[ProfileProvider] loadProfile error: $e');
      state = state.copyWith(
        status: ProfileStatus.error,
        errorMessage: 'Impossible de charger le profil',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // PATCH /v1/partner/profile
  // ---------------------------------------------------------------------------
  /// Met a jour le profil. Retourne un message d'erreur ou null si succes.
  Future<String?> updateProfile({
    String? description,
    String? phone,
    int? prepTimeMin,
  }) async {
    state = state.copyWith(isUpdating: true);

    try {
      final updated = await _profileService.updateProfile(
        description: description,
        phone: phone,
        prepTimeMin: prepTimeMin,
      );
      state = state.copyWith(
        profile: updated,
        isUpdating: false,
      );
      return null;
    } on ApiException catch (e) {
      state = state.copyWith(isUpdating: false);
      return e.message;
    } catch (e) {
      state = state.copyWith(isUpdating: false);
      return 'Erreur lors de la mise a jour du profil';
    }
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/commission-rate
  // ---------------------------------------------------------------------------
  /// Charge le taux de commission.
  Future<void> loadCommissionRate() async {
    try {
      final rate = await _profileService.getCommissionRate();
      state = state.copyWith(commissionRate: rate);
    } on ApiException catch (e) {
      debugPrint('[ProfileProvider] loadCommissionRate failed: $e');
    } catch (e) {
      debugPrint('[ProfileProvider] loadCommissionRate error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // PATCH /v1/partner/availability
  // ---------------------------------------------------------------------------
  /// Met a jour les horaires d'ouverture.
  /// Retourne un message d'erreur ou null si succes.
  Future<String?> updateAvailability(List<PartnerSchedule> schedules) async {
    state = state.copyWith(isUpdating: true);

    try {
      final updatedSchedules = await _profileService.updateAvailability(schedules);
      // Mettre a jour les schedules dans le profil local
      if (state.profile != null) {
        state = state.copyWith(
          profile: state.profile!.copyWith(schedules: updatedSchedules),
          isUpdating: false,
        );
      } else {
        state = state.copyWith(isUpdating: false);
      }
      return null;
    } on ApiException catch (e) {
      state = state.copyWith(isUpdating: false);
      return e.message;
    } catch (e) {
      state = state.copyWith(isUpdating: false);
      return 'Erreur lors de la mise a jour des horaires';
    }
  }

  // ---------------------------------------------------------------------------
  // POST /v1/partner/profile/logo
  // ---------------------------------------------------------------------------
  /// Upload le logo du partner.
  /// Retourne un message d'erreur ou null si succes.
  Future<String?> uploadLogo(File imageFile) async {
    state = state.copyWith(isUpdating: true);

    try {
      final logoUrl = await _profileService.uploadLogo(imageFile);
      // Mettre a jour l'URL du logo dans le profil local
      if (state.profile != null && logoUrl != null) {
        state = state.copyWith(
          profile: state.profile!.copyWith(picture: logoUrl),
          isUpdating: false,
        );
      } else {
        state = state.copyWith(isUpdating: false);
      }
      return null;
    } on ApiException catch (e) {
      state = state.copyWith(isUpdating: false);
      return e.message;
    } catch (e) {
      state = state.copyWith(isUpdating: false);
      return 'Erreur lors de l\'upload du logo';
    }
  }

  // ---------------------------------------------------------------------------
  // DELETE /v1/partner/profile/logo
  // ---------------------------------------------------------------------------
  /// Supprime le logo du partner.
  /// Retourne un message d'erreur ou null si succes.
  Future<String?> deleteLogo() async {
    state = state.copyWith(isUpdating: true);

    try {
      await _profileService.deleteLogo();
      // Retirer l'URL du logo du profil local
      if (state.profile != null) {
        state = state.copyWith(
          profile: state.profile!.copyWith(clearPicture: true),
          isUpdating: false,
        );
      } else {
        state = state.copyWith(isUpdating: false);
      }
      return null;
    } on ApiException catch (e) {
      state = state.copyWith(isUpdating: false);
      return e.message;
    } catch (e) {
      state = state.copyWith(isUpdating: false);
      return 'Erreur lors de la suppression du logo';
    }
  }

  // ---------------------------------------------------------------------------
  // Chargement complet
  // ---------------------------------------------------------------------------
  /// Charge le profil et le taux de commission en parallele.
  Future<void> loadAll() async {
    state = state.copyWith(status: ProfileStatus.loading);

    try {
      final results = await Future.wait([
        _profileService.getProfile(),
        _profileService.getCommissionRate(),
      ]);

      state = ProfileState(
        status: ProfileStatus.loaded,
        profile: results[0] as PartnerData,
        commissionRate: results[1] as double,
      );
    } on ApiException catch (e) {
      debugPrint('[ProfileProvider] loadAll failed: $e');
      state = state.copyWith(
        status: ProfileStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[ProfileProvider] loadAll error: $e');
      state = state.copyWith(
        status: ProfileStatus.error,
        errorMessage: 'Impossible de charger le profil',
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final profileProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier();
});

/// Provider pratique pour acceder directement au PartnerData.
final partnerDataProvider = Provider<PartnerData?>((ref) {
  return ref.watch(profileProvider).profile;
});

/// Provider pratique pour le taux de commission.
final commissionRateProvider = Provider<double?>((ref) {
  return ref.watch(profileProvider).commissionRate;
});
