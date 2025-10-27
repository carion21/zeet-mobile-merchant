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
  - `constants/` - App-wide constants (colors, sizes, themes, icons, assets, API, texts)
  - `widgets/` - Reusable widgets (popups, toasts)

- **`lib/models/`** - Data models
  - Models for merchant-specific entities (products, orders, categories, etc.)
  - Each model should have a `copyWith()` method for immutability
  - Use JSON serialization for API communication

- **`lib/screens/`** - Feature screens
  - Each screen is typically an `index.dart` file
  - May include separate `controllers.dart` for business logic
  - May include a `widgets/` subfolder for screen-specific widgets
  - Examples: menu management, order list, order details, analytics, profile, settings

- **`lib/providers/`** - Riverpod state notifiers and providers
  - Each provider file defines StateNotifierProvider and related computed providers
  - Examples: menu provider, order provider, merchant profile provider, analytics provider

- **`lib/services/`** - Application services
  - `navigation_service.dart` - Centralized navigation
  - Future services: API service, notification service, analytics service

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

## Next Steps

This is a base setup for the Merchant app. The following needs to be implemented:

### Core Features
- **Authentication screens** (login, register, OTP verification)
- **Menu management** (product list, add/edit product, categories)
- **Order management** (active orders, order history, order details)
- **Analytics & Reports** (sales analytics, performance metrics)
- **Profile & Settings** (restaurant info, opening hours, preferences)

### Models to Create
- `Product` - Menu item information
- `Category` - Product categories
- `Order` - Customer order details
- `MerchantProfile` - Restaurant information
- `Analytics` - Sales and performance data
- `OpeningHours` - Restaurant schedule

### Providers to Create
- `menuProvider` - Manage products and menu
- `orderProvider` - Manage incoming orders
- `merchantProfileProvider` - Manage restaurant profile
- `analyticsProvider` - Track sales and metrics
- `categoryProvider` - Manage product categories

### Services to Implement
- `api_service.dart` - HTTP client for API calls
- `notification_service.dart` - Push notifications for new orders
- `analytics_service.dart` - Track business metrics
