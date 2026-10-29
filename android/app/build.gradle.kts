plugins {
    id("com.android.application")
    id("kotlin-android")
    // Konfigurasi Firebase dari app/src/<flavor>/google-services.json.
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.pos_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Diwajibkan flutter_local_notifications (notifikasi push, Tahap 4).
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // applicationId ditentukan per flavor di bawah.
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Dua flavor dari kode yang sama:
    //   dev  — com.example.pos_mobile.dev, API dev (.env). Terpasang BERDAMPINGAN
    //          dengan aplikasi kasir produksi, jadi uji coba tidak menimpanya.
    //   prod — com.example.pos_mobile, API produksi (.env.prod). ID-nya sama dengan
    //          aplikasi kasir yang sudah terpasang di outlet, jadi APK ini menjadi
    //          update di atasnya (asal ditandatangani keystore yang sama dan
    //          versionCode lebih tinggi). Jangan ubah ID ini.
    // Flavor dev menjadi bawaan (default-flavor di pubspec.yaml), jadi
    // `flutter run` tanpa --flavor tetap mengarah ke dev.
    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationId = "com.example.pos_mobile.dev"
        }
        create("prod") {
            dimension = "env"
            applicationId = "com.example.pos_mobile"
        }
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Baru flavor dev yang terdaftar di Firebase (project es-teh-candi). Flavor
// prod tetap bisa dibangun tanpa google-services.json-nya: app jalan seperti
// biasa, hanya tanpa notifikasi push, sampai berkas prod ditaruh di
// app/src/prod/ saat rilis.
googleServices {
    missingGoogleServicesStrategy =
        com.google.gms.googleservices.GoogleServicesPlugin.MissingGoogleServicesStrategy.WARN
}
