pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("com.android.library") version "8.11.1" apply false
    // OpenClaw (4AIs) agent-core module: Compose compiler follows the Kotlin version.
    // Pinned to Kotlin 2.1.0 / KSP 2.1.0-1.0.29 to match the upstream 4AIs repo
    // (openclaw-android/gradle/libs.versions.toml) — mixing in a newer KSP
    // breaks Hilt codegen ("Expected @AndroidEntryPoint to have a value").
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.1.0" apply false
    id("com.google.dagger.hilt.android") version "2.53.1" apply false
    id("com.google.devtools.ksp") version "2.1.0-1.0.29" apply false
}

include(":app")
include(":openclaw")

