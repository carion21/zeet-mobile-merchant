# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**ZEET Merchant App** - A Flutter mobile application for merchants (restaurateurs) of the ZEET food delivery platform. The app is written primarily in French and supports both iOS and Android platforms.

## Essential Commands

### Development
- `flutter run` - Run the app in development mode
- `flutter run -d ios` - Run on iOS simulator
- `flutter run -d android` - Run on Android emulator
- `flutter pub get` - Install dependencies
- `flutter pub upgrade` - Upgrade dependencies

### Testing & Quality
- `flutter test` - Run all tests
- `flutter analyze` - Run static analysis (uses flutter_lints)
- `flutter clean` - Clean build artifacts

### Build
- `flutter build apk` - Build Android APK
- `flutter build ios` - Build iOS app (requires Xcode)

## Architecture

### State Management

The app uses **Riverpod** for state management:
- All providers are in `lib/providers/`
- Key providers:
  - `themeModeProvider` - Manages light/dark/system theme mode with SharedPreferences persistence
  - `syncManagerProvider` - Singleton du SyncManager offline-first (boot au premier read).
  - `partnerDatabaseProvider` - Singleton Drift DB locale (disposed avec ProviderScope).
  - `cachedOrdersProvider` - Stream reactif des commandes en cache local.
  - `queuedActionsCountProvider` - Nombre d'actions en attente de sync.
  - `pendingActionsProvider` - Liste des QueuedAction pour l'écran `SyncPendingScreen`.
  - `connectivityStatusProvider` - Stream `bool` online/offline via `ZeetConnectivity`.

### Offline-first architecture (Drift + sync queue)

L'app suit le pattern **local-first** (voir skill `zeet-offline-first`) :
- **Source de vérité locale** : `PartnerDatabase` (Drift SQLite) avec 2 tables : `orders_cache` (snapshot reactif) et `queued_actions` (queue persistante).
- **Optimistic UI** : toute mutation (confirm / preparing / ready / cancel) passe par `SyncManager.optimisticXxx()` :
  1. Update Drift local immédiat (UI reagit via stream).
  2. Enqueue l'action dans `queued_actions`.
  3. Si online → tentative immédiate, sinon → replay au retour réseau (`connectivity_plus`).
- **Retry backoff** exponentiel : 1, 2, 4, 8, 16, 32, cap 60s. Dead letter après 10 échecs.
- **Banner** : `PartnerConnectivityBanner` (lib/core/widgets/) montre offline / synchronisation / compteur queue → tap ouvre `SyncPendingScreen` pour retry manuel.
- **Conflict resolution** : server-wins par défaut. Les actions 4xx (sauf 408/429) sont markees `failed` + `syncStatus=failed` sur l'ordre, l'UI peut offrir un rollback manuel.

Les commandes sont déjà branchées sur ce pattern. Pour brancher d'autres domaines (produits, wallet, etc.) :
1. Ajouter un type dans l'enum `QueuedActionType`.
2. Étendre le switch dans `SyncManager._executeQueuedAction`.
3. Wrapper les écritures du provider concerné via `SyncManager.optimisticXxx()`.

### Navigation System

Custom navigation service (`lib/services/navigation_service.dart`) with:
- Global navigator key for navigation from anywhere
- Named routes defined in `Routes` class with route map
- Custom slide transitions (300ms easeInOut)
- Key navigation methods:
  - `Routes.navigateTo(routeName)` - Standard named route navigation
  - `Routes.push(widget)` - Custom page with animation
  - `Routes.pushReplacement(widget)` - Replace current screen with animation
  - `Routes.navigateAndReplace(routeName)` - Replace with named route
  - `Routes.pushAndRemoveAll(widget)` - Clear stack with animation
  - `Routes.navigateAndRemoveAll(routeName)` - Clear stack with named route
  - `Routes.goBack([result])` - Pop with optional result

Named routes available: `home`

### Project Structure

- **`lib/core/`** - Core utilities and shared components
  - `constants/` - App-wide constants (colors, sizes, themes, icons, assets, API, texts, **copy**)
    - `copy.dart` : **micro-copy canonique** (CTAs, erreurs typées, empty states, etc.).
      Toujours ajouter les nouveaux libellés ici plutôt qu'en dur dans les widgets.
  - `widgets/` - Reusable widgets
    - `partner_connectivity_banner.dart` : bandeau offline/sync (remplace `ConnectivityBanner` brut).
    - `cancel_reason_sheet.dart` : bottom sheet 2 étapes (motif + swipe-to-confirm).
    - `notif_rationale_sheet.dart`, `preparation_timer.dart`, `app_popup.dart`, `toastification.dart`.

- **`lib/data/local/`** - Couche de persistance locale (offline-first)
  - `partner_database.dart` : Drift DB + DAOs (`upsertOrder`, `enqueueAction`, etc.).
  - `partner_database.g.dart` : code généré par drift_dev (ne pas éditer à la main).
  - `order_cache_serializer.dart` : encode/decode Order ↔ JSON pour le cache, avec
    helper `applyOptimisticStatus` pour muter un statut localement.

- **`lib/models/`** - Data models
  - Models for merchant-specific entities (products, orders, categories, etc.)
  - Parsing `fromJson` **défensif** (gère polymorphisme `int | Map | String` sur les champs comme `status`, `customer`, `payment_method`). Ne pas migrer vers `json_serializable` sans revisiter ce comportement.
  - Each model should have a `copyWith()` method for immutability (à compléter progressivement).

- **`lib/screens/`** - Feature screens
  - Each screen is typically an `index.dart` file
  - May include separate `controllers.dart` for business logic
  - May include a `widgets/` subfolder for screen-specific widgets
  - Examples: menu management, order list, order details, analytics, profile, settings

- **`lib/providers/`** - Riverpod state notifiers and providers
  - Each provider file defines StateNotifierProvider and related computed providers
  - Examples: menu provider, order provider, merchant profile provider, analytics provider

- **`lib/services/`** - Application services
  - `navigation_service.dart` - Centralized navigation (utilise `ZeetPageRoute` shared axis).
  - `api_client.dart` - Singleton HTTP (http package) + refresh 401 + `onSessionExpired` global.
  - `sync_manager.dart` - Offline-first orchestrator (voir section "Offline-first architecture").
  - `fcm_service.dart` + `local_notification_service.dart` : FCM + 5 channels Android + FullScreenIntent incoming_order + iOS category `zeet.partner.order` avec actions inline Accepter/Refuser.
  - `order_service`, `product_service`, etc. : services par domaine (un singleton par ressource API).

### Widgets `zeet_ui` critiques utilisés

Le package partagé `packages/zeet_ui/` expose les primitives. À utiliser systématiquement :
- **États ELOE** : `ZeetStateBuilder<T>` (mapping AsyncValue-like → 5 états) + `ZeetErrorState` (typologie `ZeetErrorKind` : network/server/unauthorized/notFound/parsing/paymentDeclined/generic).
- **Motion** : `ZeetRollingCounter` (montants animés), `ZeetPulse` (pulse bordure sur événements critiques), `ZeetPageRoute` (transitions shared axis).
- **POS** : `ZeetSwipeToConfirm` / `ZeetSwipeDanger` (slider "Glisser pour confirmer" avec 3 haptics), `ZeetButton` (scale-on-tap + haptic intégré).
- **Haptics sémantiques** : `ZeetHaptics.tap()` / `.success()` / `.warning()` / `.error()` / `.heavy()` / `.longPress()`.
  Toujours les préférer aux appels `HapticFeedback.*` bruts.

- **`lib/data/`** - Data layer (optional)
  - Repository pattern for data access
  - API clients and data sources

### Theming

Material 3 theme system with:
- Light and dark themes defined in `lib/core/constants/themes.dart`
- Google Fonts: Poppins for headings, Inter for body text
- Theme follows system preference by default (persisted via SharedPreferences)
- Custom color scheme in `lib/core/constants/colors.dart`
- To check dark mode: `Theme.of(context).brightness == Brightness.dark`

### Responsive Sizing

`AppSizes()` singleton provides responsive dimensions:
- Must call `AppSizes().initialize(context)` before use (done in theme initialization)
- Methods:
  - `percentWidth(percent)` / `percentHeight(percent)` - Safe area percentages
  - `fullPercentWidth(percent)` / `fullPercentHeight(percent)` - Full screen percentages
  - `scaledFontSize(size)` - Font size scaled to screen width (375px baseline)
- Predefined sizes:
  - Font sizes: `h1`, `h2`, `h3`, `bodyLarge`, `bodyMedium`, `bodySmall`
  - Paddings: `paddingSmall`, `paddingMedium`, `paddingLarge`, `paddingXLarge`
  - Radii: `radiusSmall`, `radiusMedium`

### Screen Structure Pattern

Screens follow consistent patterns:
1. Consumer widgets (StatefulWidget/StatelessWidget) using `ConsumerState` or `ConsumerWidget`
2. Use `ref.watch()` to listen to providers, `ref.read()` for one-time reads
3. Initialize responsive layout via `AppSizes().initialize(context)` (if not using theme)
4. Dark mode support via `Theme.of(context).brightness`

## Key Configurations

### App Initialization
- Portrait orientation only (enforced in `main.dart`)
- Wrapped in `ProviderScope` for Riverpod
- Initial route: configurable via `MyApp(initialRoute:)` parameter
- Material 3 enabled

### Dependencies
- `flutter_riverpod` - State management
- `google_fonts` - Typography
- `shared_preferences` - Local storage for theme and settings
- `battery_plus` - Battery status
- `intl` - Internationalization and formatting
- `toastification` - Toast notifications (replaces SnackBars)
- SDK: Dart ^3.7.0

### Assets
Configured in `pubspec.yaml`:
- `assets/images/onboarding/`
- `assets/images/category/`
- `assets/images/wallet/`
- `assets/images/resto/`

## Development Notes

- The app is primarily in French (comments, UI text, route names)
- Custom icon system via `IconManager` in `lib/core/constants/icons.dart`
- Debug logging uses emoji prefixes (e.g., 🏪 for merchant, 📦 for product operations)
- All navigation should go through `Routes` service, not direct `Navigator` calls

### Icon Management - IMPORTANT

**CRITICAL:** Always verify that icons exist in `IconManager` before using them in any screen.

The app uses a custom icon system (`lib/core/constants/icons.dart`) that provides cross-platform icons for both Material (Android) and Cupertino (iOS).

#### Before Using Icons:

1. **Always check `lib/core/constants/icons.dart` first** to see if the icon you need exists in both `_materialIcons` and `_cupertinoIcons` maps
2. **If the icon doesn't exist:**
   - Add it to BOTH the Material icons map (`_materialIcons`) and Cupertino icons map (`_cupertinoIcons`)
   - Use appropriate Material icon from `Icons.*` class
   - Use appropriate Cupertino icon from `CupertinoIcons.*` class
   - Ensure both icons represent the same concept visually

3. **Usage in code:**
   ```dart
   // For Icon widget
   IconManager.getIcon('icon_name', color: Colors.red, size: 24)

   // For IconData (e.g., in BottomNavigationBarItem)
   IconManager.getIconData('icon_name')
   ```

#### Example: Adding a New Icon

```dart
// In _materialIcons map:
'send': Icons.send,

// In _cupertinoIcons map:
'send': CupertinoIcons.paperplane,
```

**Never use icons that don't exist in IconManager** - this will cause null pointer exceptions and app crashes.

### Toast Notifications

The app uses `toastification` package for displaying notifications (toasts) instead of traditional SnackBars.

**Location:** `lib/core/widgets/toastification.dart`

**Usage:**
```dart
// Import
import 'package:merchant/core/widgets/toastification.dart';

// Show info toast (blue)
AppToast.showInfo(
  context: context,
  message: "Information message",
);

// Show success toast (green)
AppToast.showSuccess(
  context: context,
  message: "Success message",
);

// Show warning toast (orange)
AppToast.showWarning(
  context: context,
  message: "Warning message",
);

// Show error toast (red)
AppToast.showError(
  context: context,
  message: "Error message",
);
```

**Features:**
- Toasts appear at the **top center** of the screen
- Automatic dismissal after 4 seconds (configurable)
- Slide down animation with fade effect
- Support for dark/light themes
- Dismissible by dragging
- Optional callbacks on close

**Note:** The app is wrapped with `ToastificationWrapper` in `main.dart` to enable toast functionality.

## Development Workflow

### Creating a New Screen

1. Create a new folder in `lib/screens/` with the screen name
2. Add an `index.dart` file for the main screen widget
3. Optionally add `controllers.dart` for business logic
4. Optionally add a `widgets/` subfolder for screen-specific widgets
5. Add the route to `lib/services/navigation_service.dart`

Example:
```dart
// lib/screens/menu_management/index.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MenuManagementScreen extends ConsumerWidget {
  const MenuManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestion du Menu')),
      body: const Center(child: Text('Liste des produits')),
    );
  }
}

// Add to navigation_service.dart:
static const String menuManagement = '/menu-management';
routes[menuManagement] = (context) => const MenuManagementScreen();
```

### Creating a New Model

1. Create a new file in `lib/models/` with the model name
2. Define the class with all properties
3. Add a `copyWith()` method for immutability
4. Add JSON serialization methods if needed

Example:
```dart
// lib/models/product_model.dart
class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final bool isAvailable;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    this.isAvailable = true,
  });

  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? category,
    bool? isAvailable,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}
```

### Creating a New Provider

1. Create a new file in `lib/providers/` with the provider name
2. Define the state notifier class
3. Export the provider

Example:
```dart
// lib/providers/menu_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/models/product_model.dart';

final menuProvider = StateNotifierProvider<MenuNotifier, List<Product>>((ref) {
  return MenuNotifier();
});

class MenuNotifier extends StateNotifier<List<Product>> {
  MenuNotifier() : super([]);

  void addProduct(Product product) {
    state = [...state, product];
  }

  void removeProduct(String id) {
    state = state.where((p) => p.id != id).toList();
  }

  void updateProduct(Product product) {
    state = [
      for (final p in state)
        if (p.id == product.id) product else p
    ];
  }

  void toggleAvailability(String id) {
    state = [
      for (final p in state)
        if (p.id == id) p.copyWith(isAvailable: !p.isAvailable) else p
    ];
  }
}
```

## API Integration

### Document de suivi
**IMPORTANT :** Le fichier `API_ENDPOINTS.md` à la racine du projet contient la liste complète des 80 endpoints API avec leur statut d'intégration. Ce document **DOIT** être mis à jour à la fin de chaque groupe d'intégration :
- Mettre le statut à `Implémenté` pour chaque endpoint intégré
- Mettre le statut à `À revoir` si un endpoint a un problème de parsing ou d'incohérence
- Mettre à jour le tableau résumé en bas du document
- Mettre à jour la date de dernière mise à jour

### Architecture d'intégration API
Pattern : `models → services → providers → screens`

| Couche | Rôle | Répertoire |
|--------|------|-----------|
| **Models** | Parsing JSON, classes de données | `lib/models/` |
| **Services** | Appels HTTP via ApiClient | `lib/services/` |
| **Providers** | State Riverpod + logique métier | `lib/providers/` |
| **Screens** | UI, ConsumerStatefulWidget | `lib/screens/` |

### Infrastructure API (à créer en premier)
- `lib/services/api_client.dart` — Client HTTP centralisé (singleton, auth headers Bearer, refresh auto 401, logging via ApiLogger). Le parsing d'erreur doit gérer `message` comme String OU List (validation NestJS).
- `lib/services/token_service.dart` — Stockage tokens via SharedPreferences (préfixe `zeet_merchant_`).
- `lib/core/utils/api_logger.dart` — **EXISTE DÉJÀ** — Logging des requêtes/réponses API.

### Spécificités Partner
- **Auth par login/password** (pas OTP comme client/rider) : `POST /v1/auth/login` avec `{"phone", "password", "surface": "partner"}`
- **Le partner est un restaurateur** — gestion de menus, produits, catégories, commandes entrantes
- **Endpoints** : tous les endpoints sont définis dans `lib/core/constants/api.dart`
- **Collection Postman** : `/Users/lycoris/workspace/zeet/ZEET-Core-API.postman_collection.json`

### Ordre d'intégration recommandé
1. Auth (4) — login, refresh, logout, me
2. Profile + Dashboard (7) — profil, commission, disponibilité, logo, summary
3. Orders (12) — liste, détail, actions (confirm/preparing/ready/cancel), OTP
4. Menus (6) — CRUD menus + publish
5. Product Categories (8) — CRUD catégories + image + bulk
6. Products (11) + Variants (4) + Option Groups (8) — CRUD complet
7. Stats (6) + Product Stats (2)
8. Carts (2) + Support Tickets (10)

### Référence
L'app client (`/Users/lycoris/workspace/zeet/zeet-mobile-client/`) et l'app rider (`/Users/lycoris/workspace/zeet/zeet-mobile-rider/`) ont déjà une intégration complète qui peut servir de modèle pour les services, models et providers.
