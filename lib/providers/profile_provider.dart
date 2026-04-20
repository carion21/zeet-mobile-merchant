import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/models/partner_model.dart';
import 'package:merchant/services/api_client.dart';
import 'package:merchant/services/profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cle SharedPreferences qui memorise si un override manuel `open_now` est
/// actuellement actif. Le backend ne renvoie pas (encore) ce flag dans le
/// profil — on le tracke localement pour pouvoir afficher la pastille
/// "Override" et proposer un retour au schedule hebdomadaire.
const String kOpenNowOverrideActiveKey = 'partner.open_now.override_active';

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

  /// Indique qu'un override manuel `open_now` est actuellement actif
  /// (le partner a force ouvert/ferme via le toggle home, l'etat affiche
  /// ne provient pas du schedule hebdomadaire).
  ///
  /// Tracke cote client (SharedPreferences) puisque le backend n'expose
  /// pas (encore) ce flag dans le profil. Reset lors du clearOpenNow.
  final bool openNowOverrideActive;

  const ProfileState({
    this.status = ProfileStatus.initial,
    this.profile,
    this.commissionRate,
    this.errorMessage,
    this.isUpdating = false,
    this.openNowOverrideActive = false,
  });

  ProfileState copyWith({
    ProfileStatus? status,
    PartnerData? profile,
    double? commissionRate,
    String? errorMessage,
    bool? isUpdating,
    bool? openNowOverrideActive,
  }) {
    return ProfileState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      commissionRate: commissionRate ?? this.commissionRate,
      errorMessage: errorMessage,
      isUpdating: isUpdating ?? this.isUpdating,
      openNowOverrideActive:
          openNowOverrideActive ?? this.openNowOverrideActive,
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
        super(const ProfileState()) {
    _restoreOpenNowOverrideFlag();
  }

  /// Restaure le flag `openNowOverrideActive` depuis SharedPreferences au
  /// boot (idempotent, fire-and-forget). Permet de retrouver l'etat
  /// "Override actif" apres un kill/restart de l'app sans devoir
  /// re-toggler.
  Future<void> _restoreOpenNowOverrideFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final active = prefs.getBool(kOpenNowOverrideActiveKey) ?? false;
      if (active) {
        state = state.copyWith(openNowOverrideActive: true);
      }
    } catch (e) {
      debugPrint('[ProfileProvider] restore override flag failed: $e');
    }
  }

  Future<void> _persistOverrideFlag(bool active) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kOpenNowOverrideActiveKey, active);
    } catch (e) {
      debugPrint('[ProfileProvider] persist override flag failed: $e');
    }
  }

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
  // PATCH /v1/partner/open-now — force l'etat ouvert/ferme
  // ---------------------------------------------------------------------------
  /// Bascule manuellement l'etat ouvert/ferme du restaurant.
  ///
  /// [isOpen] : true = force ouvert, false = force ferme.
  /// [reason] : raison (defaut `manual`).
  /// Update optimiste : on met a jour `profile.openNow` des que la requete
  /// reussit. Retourne un message d'erreur ou null si succes.
  Future<String?> toggleOpenNow(
    bool isOpen, {
    String reason = 'manual',
    String? reopenAt,
  }) async {
    state = state.copyWith(isUpdating: true);
    try {
      await _profileService.setOpenNow(
        isOpen: isOpen,
        reason: reason,
        reopenAt: reopenAt,
      );
      // Persiste le flag override pour survivre a un restart de l'app.
      await _persistOverrideFlag(true);
      if (state.profile != null) {
        state = state.copyWith(
          profile: state.profile!.copyWith(openNow: isOpen),
          isUpdating: false,
          openNowOverrideActive: true,
        );
      } else {
        state = state.copyWith(
          isUpdating: false,
          openNowOverrideActive: true,
        );
      }
      return null;
    } on ApiException catch (e) {
      state = state.copyWith(isUpdating: false);
      // Mapping copy-friendly des erreurs typiques (cf. zeet-micro-copy §4).
      if (e.statusCode == 403) {
        return 'Compte suspendu. Contactez le support pour rouvrir.';
      }
      return e.message;
    } catch (e) {
      state = state.copyWith(isUpdating: false);
      return 'Impossible de modifier l\'etat du restaurant.';
    }
  }

  // ---------------------------------------------------------------------------
  // DELETE /v1/partner/open-now — retour au schedule hebdomadaire
  // ---------------------------------------------------------------------------
  /// Efface l'override manuel et recharge le profil pour recuperer l'etat
  /// calcule depuis le schedule. Retourne un message d'erreur ou null.
  Future<String?> clearOpenNowOverride() async {
    state = state.copyWith(isUpdating: true);
    try {
      await _profileService.clearOpenNow();
      await _persistOverrideFlag(false);
      // Recharge le profil pour recuperer l'etat calcule depuis le schedule.
      final updated = await _profileService.getProfile();
      state = state.copyWith(
        profile: updated,
        isUpdating: false,
        openNowOverrideActive: false,
      );
      return null;
    } on ApiException catch (e) {
      state = state.copyWith(isUpdating: false);
      if (e.statusCode == 403) {
        return 'Compte suspendu. Contactez le support pour rouvrir.';
      }
      return e.message;
    } catch (e) {
      state = state.copyWith(isUpdating: false);
      return 'Impossible de revenir aux horaires.';
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

/// Indique si un override manuel `open_now` est actif (pastille "Override"
/// affichee par le HomeHeader). Reset par `clearOpenNowOverride()`.
final openNowOverrideActiveProvider = Provider<bool>((ref) {
  return ref.watch(profileProvider).openNowOverrideActive;
});
