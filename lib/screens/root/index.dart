// lib/screens/root/index.dart
//
// RootScaffold — coquille globale post-login avec navigation persistante.
//
// Accès aux 4 surfaces principales du partner en 1 tap :
//   - Accueil    (tableau de bord du jour)
//   - Commandes  (liste paginée + filtres)
//   - Portefeuille (solde + historique transactions)
//   - Profil     (compte, support, déconnexion)
//
// Règle `zeet-3-clicks-rule` §1 : le partenaire doit pouvoir
// basculer entre ces surfaces sans jamais repasser par un écran
// intermédiaire. L'`IndexedStack` préserve l'état de chaque onglet
// (scroll position, form data, providers locaux) — un retour rapide
// est gratuit.
//
// L'accès au tab courant / le switch programmatique passent par
// [rootTabProvider] pour éviter tout couplage via GlobalKey.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zeet_ui/zeet_ui.dart';

import 'package:merchant/screens/home/index.dart';
import 'package:merchant/screens/orders/index.dart';
import 'package:merchant/screens/profile/index.dart';
import 'package:merchant/screens/wallet/index.dart';

/// Index du tab actif dans le [RootScaffold]. Lisible / modifiable
/// depuis n'importe quel widget descendant pour commuter sans push.
final StateProvider<int> rootTabProvider = StateProvider<int>((ref) => 0);

/// Index officiels des onglets — ne pas réordonner sans mettre à jour
/// les call sites (`ref.read(rootTabProvider.notifier).state = ...`).
class RootTab {
  RootTab._();
  static const int home = 0;
  static const int orders = 1;
  static const int wallet = 2;
  static const int profile = 3;
}

class RootScaffold extends ConsumerWidget {
  const RootScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int index = ref.watch(rootTabProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const <Widget>[
          HomeScreen(),
          OrdersScreen(),
          WalletScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: scheme.outlineVariant, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: index,
          height: 72,
          backgroundColor: scheme.surface,
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          indicatorColor: scheme.primary.withValues(alpha: 0.12),
          onDestinationSelected: (int i) {
            ZeetHaptics.tap();
            ref.read(rootTabProvider.notifier).state = i;
          },
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: ZeetColors.primary),
              label: 'Accueil',
              tooltip: 'Tableau de bord',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon:
                  Icon(Icons.receipt_long_rounded, color: ZeetColors.primary),
              label: 'Commandes',
              tooltip: 'Mes commandes',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(
                Icons.account_balance_wallet_rounded,
                color: ZeetColors.primary,
              ),
              label: 'Portefeuille',
              tooltip: 'Portefeuille',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon:
                  Icon(Icons.person_rounded, color: ZeetColors.primary),
              label: 'Profil',
              tooltip: 'Mon profil',
            ),
          ],
        ),
      ),
    );
  }
}
