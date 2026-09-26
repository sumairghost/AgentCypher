plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.dagger.hilt.android")
    id("com.google.devtools.ksp")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.cypherghost.agentcypher"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Agent Cypher - Personal AI Assistant
        applicationId = "com.cypherghost.agentcypher"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // The embedded OpenClaw agent core ships arm64-v8a-only native libs
        // (libnode.so + companions); restrict the whole APK to arm64-v8a.
        ndk {
            abiFilters += "arm64-v8a"
        }
    }

    packaging {
        // OpenClaw's Node runtime must stay uncompressed & page-aligned on disk
        // so Android can execute libnode.so directly from nativeLibraryDir.
        jniLibs.useLegacyPackaging = true
    }

    androidResources {
        // Bundled archives (npm.tgz, shell scripts) ship pre-compressed; don't re-zip.
        noCompress.addAll(listOf("apk", "sh", "tgz", "node_modules"))
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

    // The Hilt bytecode transform (+ aggregated deps) must live on the app
    // module — the openclaw module is an android-library whose @HiltAndroidApp
    // class is NOT the app's Application (manifest points at OpenClawApp).
    // Plugin + Hilt deps therefore belong here, not in :openclaw's build.
    implementation("com.google.dagger:hilt-android:2.53.1")
    ksp("com.google.dagger:hilt-android-compiler:2.53.1")

    implementation(project(":openclaw"))
    // Coil (ImageLoaderFactory supertype inherited from OpenClawApp base).
    implementation("io.coil-kt:coil:2.7.0")
    implementation("io.coil-kt:coil-svg:2.7.0")
}
