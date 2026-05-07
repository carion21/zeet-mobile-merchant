/// URLs publiques ZEET (site marketing + pages légales/aide).
///
/// Source unique de vérité : https://zeet.geasscorp.com
/// Toute redirection externe (CGU, confidentialité, support, contact, etc.)
/// doit passer par ce fichier — éviter les chaînes en dur dans les écrans.
class ZeetLinks {
  ZeetLinks._();

  static const String _base = 'https://zeet.geasscorp.com';

  // --- Pages produit ---
  static const String home = _base;
  static const String client = '$_base/client';
  static const String rider = '$_base/rider';
  static const String partner = '$_base/partner';

  // --- Entreprise ---
  static const String about = '$_base/a-propos';
  static const String safety = '$_base/securite';
  static const String communityRules = '$_base/regles-communaute';

  // --- Aide & support ---
  static const String support = '$_base/support';
  static const String supportContact = '$_base/support/contact';
  static const String accountDeletion = '$_base/suppression-compte';
  static const String refundPolicy = '$_base/politique-remboursement';

  // --- Légal ---
  static const String legalNotice = '$_base/mentions-legales';
  static const String privacy = '$_base/confidentialite';
  static const String terms = '$_base/cgu';
  static const String salesTerms = '$_base/cgv';
  static const String cookies = '$_base/cookies';

  // --- Contact direct ---
  static const String contactEmail = 'hello@zeet.geasscorp.com';
  static const String mailto = 'mailto:$contactEmail';
  static const String whatsapp = 'https://wa.me/2250757148321';
}
