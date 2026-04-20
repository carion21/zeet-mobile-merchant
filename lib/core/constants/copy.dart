// lib/core/constants/copy.dart
//
// Micro-copy canonique de l'app Partner ZEET (voir skill zeet-micro-copy).
//
// Tone : pro, sobre, operationnel, vouvoiement.
//
// Objectif : centraliser les strings UI pour :
// - garantir la coherence (zero doublons de "Une erreur est survenue"),
// - eviter les accents casses dans le code,
// - faciliter l'i18n futur (migration .arb sera un find/replace direct).
//
// Regles d'ajout :
// - Grouper par domaine (orders, products, wallet, etc.).
// - Un seul libelle par concept metier (ex: "Accepter" partout, pas
//   "Accepter la commande" parfois et "Confirmer" ailleurs).
// - Jamais de tutoiement (pro partner).
// - Accents francais corrects systematiquement.

abstract class Copy {
  Copy._();

  // ────────────────────────────────────────────────────────────────
  // Actions (CTAs)
  // ────────────────────────────────────────────────────────────────
  static const String accept = 'Accepter';
  static const String refuse = 'Refuser';
  static const String cancel = 'Annuler';
  static const String confirm = 'Confirmer';
  static const String save = 'Enregistrer';
  static const String create = 'Créer';
  static const String edit = 'Modifier';
  static const String delete = 'Supprimer';
  static const String retry = 'Réessayer';
  static const String close = 'Fermer';
  static const String back = 'Retour';
  static const String details = 'Détails';
  static const String viewMore = 'Voir plus';
  static const String contactSupport = 'Contacter le support';

  // ────────────────────────────────────────────────────────────────
  // Statuts commandes
  // ────────────────────────────────────────────────────────────────
  static const String statusNew = 'Nouvelle';
  static const String statusConfirmed = 'Confirmée';
  static const String statusPreparing = 'En préparation';
  static const String statusReady = 'Prête';
  static const String statusPickedUp = 'Récupérée';
  static const String statusDelivered = 'Livrée';
  static const String statusCancelled = 'Annulée';
  static const String statusRefused = 'Refusée';

  // ────────────────────────────────────────────────────────────────
  // Actions commandes (labels de STATUT — affichage informationnel)
  // ────────────────────────────────────────────────────────────────
  static const String orderConfirm = 'Accepter';
  static const String orderPreparing = 'En préparation';
  static const String orderReady = 'Prête';
  static const String orderHandedOver = 'Remise au livreur';
  static const String orderCancel = 'Annuler la commande';
  static const String orderRefuse = 'Refuser';
  static const String orderCallClient = 'Appeler le client';
  static const String orderCallRider = 'Appeler le livreur';

  // ────────────────────────────────────────────────────────────────
  // CTAs commandes (labels de BOUTON — verbe action, max 3 mots)
  //
  // À utiliser partout (home_order_card, orders/index, order_details,
  // dynamic_action_bar) pour éviter que le même geste ait 3 libellés
  // différents selon l'écran. Le partner apprend un mot = un geste,
  // pas un mot par surface. Voir skill zeet-micro-copy §3 (CTA library).
  // ────────────────────────────────────────────────────────────────
  static const String ctaAccept = 'Accepter';
  static const String ctaRefuse = 'Refuser';
  static const String ctaPrepare = 'Préparer';
  static const String ctaMarkReady = 'Prête';
  static const String ctaHandOver = 'Remettre au livreur';

  // ────────────────────────────────────────────────────────────────
  // Messages d'erreur typés
  // ────────────────────────────────────────────────────────────────
  static const String errorNetwork =
      'Problème de connexion. Vérifiez votre réseau et réessayez.';
  static const String errorServer =
      'Nos serveurs font une pause. On revient vite.';
  static const String errorUnauthorized =
      'Votre session a expiré. Reconnectez-vous pour continuer.';
  static const String errorNotFound = 'On ne trouve plus cet élément.';
  static const String errorParsing =
      'Une information manque. L\'équipe a été prévenue.';
  static const String errorGeneric = 'Une erreur est survenue.';

  // ────────────────────────────────────────────────────────────────
  // Empty states (tone positif, sans "vide")
  // ────────────────────────────────────────────────────────────────
  static const String emptyNewOrders = 'Aucune nouvelle commande';
  static const String emptyNewOrdersSubtitle =
      'Les nouvelles commandes apparaîtront ici automatiquement.';
  static const String emptyActiveOrders = 'Aucune commande en cours';
  static const String emptyActiveOrdersSubtitle =
      'Les commandes en préparation ou prêtes apparaîtront ici.';
  static const String emptyCatalog = 'Votre catalogue est vide';
  static const String emptyCatalogSubtitle =
      'Ajoutez vos premiers produits pour commencer à recevoir des commandes.';
  static const String emptyTickets = 'Aucun ticket — tout va bien !';
  static const String emptyTicketsSubtitle =
      'En cas de souci, ouvrez un ticket et on vous répond au plus vite.';
  static const String emptyPayouts = 'Aucun virement pour l\'instant';
  static const String emptyPayoutsSubtitle =
      'Les virements apparaîtront ici après chaque clôture.';
  static const String emptyNotifications = 'Aucune notification';
  static const String emptyNotificationsSubtitle =
      'Vous êtes à jour.';

  // ────────────────────────────────────────────────────────────────
  // Offline / sync
  // ────────────────────────────────────────────────────────────────
  static const String offline = 'Mode hors ligne';
  static const String offlineWithQueue = 'Hors ligne · actions en attente';
  static const String syncingInProgress = 'Synchronisation en cours…';
  static const String syncQueueEmpty = 'Rien en attente';
  static const String syncQueueEmptySubtitle =
      'Vos actions sont synchronisées avec le serveur.';

  // ────────────────────────────────────────────────────────────────
  // Confirmations
  // ────────────────────────────────────────────────────────────────
  static const String confirmCancelOrderTitle = 'Confirmer le refus ?';
  static const String confirmCancelOrderSubtitle =
      'Le client sera notifié et remboursé. Action irréversible.';
  static const String confirmLogoutTitle = 'Se déconnecter ?';
  static const String confirmLogoutSubtitle =
      'Vous devrez vous reconnecter pour recevoir de nouvelles commandes.';

  // ────────────────────────────────────────────────────────────────
  // Toasts succès
  // ────────────────────────────────────────────────────────────────
  static const String orderAccepted = 'Commande acceptée';
  static const String orderMarkedReady = 'Commande prête pour collecte';
  static const String orderMarkedPreparing = 'Préparation lancée';
  static const String orderCancelled = 'Commande annulée';

  // ────────────────────────────────────────────────────────────────
  // Peak moment — fin de service (Phase 5, tone pro sobre vouvoiement)
  // ────────────────────────────────────────────────────────────────
  static const String serviceClosedTitle = 'Service clôturé';
  static const String serviceClosedSubtitle =
      'Voici le résumé de votre journée.';

  /// Label du CTA de clôture dans le home (sobre, non prédominant).
  static const String serviceCloseCta = 'Clôturer le service';

  /// Label du CTA "Terminer" sur le recap : valide la clôture et ferme
  /// le restaurant (PATCH /v1/partner/open-now avec isOpen=false).
  static const String serviceClosedFinish = 'Terminer';

  /// Toast succès après fermeture effective (isOpen=false).
  static const String serviceClosedToast =
      'Service terminé. À demain pour une nouvelle journée.';

  /// Labels des stats affichées sur le recap.
  static const String statOrdersHandled = 'Commandes traitées';
  static const String statRevenue = 'Chiffre d\'affaires';
  static const String statAverageBasket = 'Panier moyen';
  static const String statAcceptanceRate = 'Commandes acceptées';
  static const String statRating = 'Note moyenne';

  // ────────────────────────────────────────────────────────────────
  // Restaurant ouvert / fermé
  // ────────────────────────────────────────────────────────────────
  static const String restaurantOpen = 'Ouvert';
  static const String restaurantClosed = 'Fermé';
  static const String restaurantOpenedToast =
      'Restaurant ouvert — les clients peuvent commander';
  static const String restaurantClosedToast =
      'Restaurant fermé — commandes suspendues';
}
