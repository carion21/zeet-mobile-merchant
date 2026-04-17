plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase — push notifications "nouvelle commande" partner
    id("com.google.gms.google-services")
}

android {
    namespace = "com.zeet.merchant"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Requis par `flutter_local_notifications`.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.zeet.merchant"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Backport java.time.* requis par `flutter_local_notifications`.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Requis par `ZeetFirebaseMessagingService.kt` (custom service qui etend
    // `FlutterFirebaseMessagingService` -> `FirebaseMessagingService`) pour
    // avoir `com.google.firebase.messaging.*` sur le compile classpath du
    // module `:app`. Le plugin Flutter `firebase_messaging` l'ajoute en
    // `implementation` sur son sous-projet, ce qui est suffisant pour le
    // runtime mais pas pour la compilation d'un service Kotlin custom.
    // BOM : garde la version aligne sur celle du plugin pour eviter les
    // derives de classpath.
    implementation(platform("com.google.firebase:firebase-bom:34.12.0"))
    implementation("com.google.firebase:firebase-messaging")

    // `androidx.lifecycle:lifecycle-process` pour `ProcessLifecycleOwner`
    // (utilise par `ZeetFirebaseMessagingService.isAppInForeground`).
    implementation("androidx.lifecycle:lifecycle-process:2.8.7")
}
