// DynamicActionBar — generation dynamique des CTAs de l'action bar du
// detail commande, depuis la liste d'actions retournee par le backend
// (`GET /v1/partner/orders/actions?status=<value>`).
//
// Phase 2 gap #4 : remplace le mapping hardcode `_buildActionsForStatus`
// (statut → boutons) par une UI pilotee par le backend. Avantages :
//  - Le backend devient la source de verite (cf. `orders.helpers.ts`).
//  - Si le backend ajoute / retire une action (ex: "view-pickup-otp"
//    sur `on-the-way`), l'UI suit sans deploiement mobile.
//  - Les `required_fields` (ex: `cancel_reason`, `estimated_minutes`)
//    sont declares cote backend → on peut afficher le bon prompt avant
//    d'envoyer.
//
// Mapping `key` action → handler local :
//  - `confirm`            → onConfirm (POST /confirm)
//  - `preparing`          → onMarkPreparing (POST /preparing)
//  - `ready`              → onMarkReady (POST /ready)
//  - `cancel`             → onCancel (POST /cancel + cancel_reason)
//  - `view-pickup-otp`    → onShowOtp (push fullscreen)
//  - `resend-pickup-otp`  → onResendOtp (POST /pickup-otp/resend)
//
// Si le backend renvoie une `key` inconnue (ex: future action), elle est
// silencieusement ignoree pour ne pas casser l'app — un debugPrint trace
// pour debug.
//
// Ergonomie POS :
//  - 1 action = 1 bouton plein largeur, hauteur 56pt minimum (ZeetButton.lg).
//  - 2 actions = paire cote a cote (ex: `confirm` + `cancel`).
//  - 3+ actions = empilees verticalement (rare, ex: `ready-for-delivery`
//    avec `view-pickup-otp` + `resend-pickup-otp`).
//  - Actions destructives (`cancel`) toujours en variant secondary/danger.
//  - Loading state global : tous les boutons disabled pendant qu'une
//    action est en cours.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/core/constants/copy.dart';
import 'package:merchant/models/order_model.dart';
import 'package:merchant/providers/orders_provider.dart' show OrderActionsStatus;
import 'package:zeet_ui/zeet_ui.dart';

/// Callback declenche quand le partner tape un bouton genere.
/// [key] correspond a `OrderActionItem.key` du backend.
typedef OrderActionTap = void Function(OrderActionItem action);

class DynamicActionBar extends StatelessWidget {
  /// Liste d'actions a afficher (vient de `OrderDetailState.actions`).
  /// Si vide, affiche un fallback informationnel ("Aucune action").
  final List<OrderActionItem> actions;

  /// Etat de fetch des actions. Si `loading` et `actions.isEmpty`, affiche
  /// un skeleton bouton plutot qu'un message vide (anti-flash).
  final OrderActionsStatus actionsStatus;

  /// Si true, desactive tous les boutons et affiche un loader sur le
  /// bouton primaire (ex: pendant un POST en cours).
  final bool isActing;

  /// Indique quelle action specifique est en cours (pour afficher le
  /// loader uniquement sur ce bouton, pas sur tous). Optionnel.
  final String? actingKey;

  /// Callback unique : recoit l'OrderActionItem complet — l'ecran appelant
  /// dispatch en interne (confirm/cancel/etc.).
  final OrderActionTap onAction;

  /// Padding externe (l'action bar est typiquement dans un Container deja
  /// stylise par le parent — la valeur par defaut applique un padding
  /// interne minimal).
  final EdgeInsets padding;

  const DynamicActionBar({
    super.key,
    required this.actions,
    required this.actionsStatus,
    required this.onAction,
    this.isActing = false,
    this.actingKey,
    this.padding = const EdgeInsets.all(0),
  });

  @override
  Widget build(BuildContext context) {
    // Loading initial — skeleton bouton pleine largeur (anti-flash).
    if (actionsStatus == OrderActionsStatus.loading && actions.isEmpty) {
      return Padding(
        padding: padding,
        child: SizedBox(
          height: 56.h,
          child: const ZeetSkeleton(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      );
    }

    // Aucune action exposee par le backend (ex: delivered/cancelled/failed).
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<OrderActionItem> visible =
        actions.where(_isKnownKey).toList();

    if (visible.isEmpty) {
      // Toutes les actions sont inconnues du frontend. On logue mais on
      // n'affiche rien plutot que de planter ou afficher un placeholder
      // perturbant pour le partner.
      debugPrint(
        '[DynamicActionBar] all actions unknown : ${actions.map((a) => a.key).toList()}',
      );
      return const SizedBox.shrink();
    }

    // Layout selon le nombre d'actions visibles.
    return Padding(
      padding: padding,
      child: visible.length == 2 && _isCancelPair(visible)
          ? _buildCancelPair(context, visible)
          : visible.length == 1
              ? _buildSingle(context, visible.first)
              : _buildStacked(context, visible),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Layouts
  // ───────────────────────────────────────────────────────────────────

  Widget _buildSingle(BuildContext context, OrderActionItem action) {
    return _buildButton(context, action, fullWidth: true);
  }

  /// Cas particulier : action positive + cancel cote a cote (ex:
  /// `payment-accepted` -> [confirm, cancel] / `confirmed` -> [preparing,
  /// cancel] / `preparing` -> [ready, cancel]).
  Widget _buildCancelPair(BuildContext context, List<OrderActionItem> visible) {
    // Re-ordonne pour mettre cancel a gauche (POS pattern : destructive a
    // gauche, primaire a droite — pouce naturel droitier).
    final cancel =
        visible.firstWhere((a) => _isDestructive(a.key), orElse: () => visible.first);
    final positive =
        visible.firstWhere((a) => !_isDestructive(a.key), orElse: () => visible.last);
    return Row(
      children: <Widget>[
        Expanded(child: _buildButton(context, cancel, fullWidth: true)),
        SizedBox(width: 12.w),
        Expanded(child: _buildButton(context, positive, fullWidth: true)),
      ],
    );
  }

  Widget _buildStacked(BuildContext context, List<OrderActionItem> visible) {
    // Action primaire en premier (ex: view-pickup-otp), secondaires en
    // dessous (ex: resend-pickup-otp).
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < visible.length; i++) ...<Widget>[
          if (i > 0) SizedBox(height: 12.h),
          _buildButton(context, visible[i], fullWidth: true),
        ],
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Bouton individuel
  // ───────────────────────────────────────────────────────────────────

  Widget _buildButton(
    BuildContext context,
    OrderActionItem action, {
    required bool fullWidth,
  }) {
    final bool isThisActing = isActing && actingKey == action.key;
    final bool disabled = isActing && actingKey != action.key;

    return ZeetButton(
      label: _labelFor(action),
      icon: _iconFor(action.key),
      variant: _variantFor(action.key),
      size: ZeetButtonSize.lg,
      fullWidth: fullWidth,
      loading: isThisActing,
      onPressed: disabled ? null : () => onAction(action),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Mapping key → label / icon / variant
  // ───────────────────────────────────────────────────────────────────

  bool _isKnownKey(OrderActionItem a) {
    return _knownKeys.contains(a.key);
  }

  static const Set<String> _knownKeys = <String>{
    'confirm',
    'preparing',
    'ready',
    'cancel',
    'view-pickup-otp',
    'resend-pickup-otp',
  };

  bool _isDestructive(String key) {
    return key == 'cancel' || key == 'refuse';
  }

  /// Detecte les paires "primaire + cancel" pour le layout cote a cote.
  bool _isCancelPair(List<OrderActionItem> visible) {
    final keys = visible.map((a) => a.key).toSet();
    return keys.contains('cancel') &&
        keys.any((k) => <String>{'confirm', 'preparing', 'ready'}.contains(k));
  }

  /// Label affiche : preferer le `label` backend, fallback sur des libelles
  /// canoniques cote frontend (zeet-micro-copy partner, vouvoiement).
  ///
  /// Les CTAs critiques passent par `Copy.cta*` — un meme geste ne doit
  /// pas avoir 3 libelles differents selon l'ecran. Le partner apprend
  /// un mot = un geste.
  String _labelFor(OrderActionItem action) {
    final fromBackend = action.label;
    if (fromBackend != null && fromBackend.isNotEmpty) return fromBackend;
    switch (action.key) {
      case 'confirm':
        return Copy.ctaAccept;
      case 'preparing':
        return Copy.ctaPrepare;
      case 'ready':
        return Copy.ctaMarkReady;
      case 'cancel':
        return Copy.ctaRefuse;
      case 'view-pickup-otp':
        return 'Afficher le code de collecte';
      case 'resend-pickup-otp':
        return 'Renvoyer le code';
      default:
        return action.key;
    }
  }

  IconData? _iconFor(String key) {
    switch (key) {
      case 'confirm':
        return Icons.check_circle_outline_rounded;
      case 'preparing':
        return Icons.restaurant_rounded;
      case 'ready':
        return Icons.check_rounded;
      case 'cancel':
        return Icons.close_rounded;
      case 'view-pickup-otp':
        return Icons.visibility_rounded;
      case 'resend-pickup-otp':
        return Icons.refresh_rounded;
      default:
        return null;
    }
  }

  ZeetButtonVariant _variantFor(String key) {
    switch (key) {
      case 'cancel':
        return ZeetButtonVariant.secondary;
      case 'ready':
        return ZeetButtonVariant.success;
      case 'view-pickup-otp':
        return ZeetButtonVariant.primary;
      case 'resend-pickup-otp':
        return ZeetButtonVariant.secondary;
      default:
        return ZeetButtonVariant.primary;
    }
  }
}
