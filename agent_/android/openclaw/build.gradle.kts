/*
 * OpenClaw agent core (4AIs) as an embedded library module inside Agent Cypher.
 *
 * Source: https://github.com/8crsk/openclaw-android (MIT License,
 * Copyright (c) 2026 Sanjay Keerthan (4AIs)) — see openclaw/LICENSE-NOTICE.
 *
 * The execution architecture (NodeProcess, GatewayService, PhoneAccessibilityService,
 * UiTreeBuilder, MarkAssigner, GestureController, ActionDispatcher, UiRoutes,
 * ShizukuBridge, WsRpcClient, ChatSession, approvals) is preserved unchanged;
 * only the Gradle module wrapper (application -> library) was adapted so the
 * 4AIs core can live inside the com.cypherghost.agentcypher APK.
 *
 * The prebuilt Node.js .so files are NOT in git — they come from the upstream
 * GitHub release (tag node-libs-v1) via the original fetch script. This task
 * fails the build early with instructions instead of producing an APK that
 * crashes at startup with no libnode.so.
 */
import java.util.Properties

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("com.google.dagger.hilt.android")
    id("com.google.devtools.ksp")
}

android {
    namespace = "com.crsk.openclaw"
    compileSdk = 35

    defaultConfig {
        minSdk = 26

        ndk {
            abiFilters += "arm64-v8a"
        }
    }

    packaging {
        jniLibs.useLegacyPackaging = true
    }

    // Bundled archives (npm.tgz, shell scripts) ship pre-compressed; don't re-zip.
    androidResources {
        noCompress.addAll(listOf("apk", "sh", "tgz", "node_modules"))
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
        aidl = true
        buildConfig = true
    }

    testOptions {
        // Android's Log.d/i etc. throw "not mocked" in JVM unit tests by default.
        // returnDefaultValues makes them silent no-ops, which is fine for our use.
        unitTests.isReturnDefaultValues = true
    }

    lint {
        abortOnError = false
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-process:2.8.7")
    implementation("androidx.activity:activity-compose:1.9.3")

    implementation(platform("androidx.compose:compose-bom:2024.12.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended:1.7.6")
    implementation("androidx.navigation:navigation-compose:2.8.5")

    implementation("com.google.dagger:hilt-android:2.53.1")
    ksp("com.google.dagger:hilt-android-compiler:2.53.1")
    implementation("androidx.hilt:hilt-navigation-compose:1.2.0")

    implementation("androidx.datastore:datastore-preferences:1.1.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    implementation("org.jetbrains.kotlinx:kotlinx-collections-immutable:0.3.7")
    // Real iOS-style backdrop blur for the composer and nav bar.
    implementation("dev.chrisbanes.haze:haze:1.2.2")
    // SF Symbol-esque line icons. Replaces Material Icons where we want a less Material feel.
    implementation("com.composables:icons-lucide:1.0.0")
    implementation("io.coil-kt:coil-compose:2.7.0")
    implementation("io.coil-kt:coil-svg:2.7.0")
    implementation("androidx.browser:browser:1.8.0")
    implementation("androidx.security:security-crypto:1.1.0-alpha06")

    implementation("dev.rikka.shizuku:api:13.1.5")
    implementation("dev.rikka.shizuku:provider:13.1.5")
    implementation("org.nanohttpd:nanohttpd:2.3.1")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    // Flutter embedding (MethodChannel/EventChannel used by CypherAgentCore).
    // compileOnly + flatDir: the real classes come from the app's Flutter
    // embedding at APK link time; the library only needs them to compile.
    // The AAR is resolved from the Flutter SDK cache (no network artifact).
    compileOnly(files("${System.getenv("FLUTTER_ROOT") ?: "C:/src/flutter"}/bin/cache/artifacts/engine/android-arm64-release/flutter.jar"))
    // Installs the bundled Baseline Profile at first launch so AOT-compiled
    // critical paths (startup -> first chat frame) are fast on cold start.
    implementation("androidx.profileinstaller:profileinstaller:1.3.1")

    debugImplementation("androidx.compose.ui:ui-tooling")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.9.0")
}

val checkNodeLibs by tasks.registering {
    doFirst {
        val libnode = file("src/main/jniLibs/arm64-v8a/libnode.so")
        if (!libnode.exists() || libnode.length() < 1_000_000) {
            throw GradleException(
                "Missing prebuilt Node.js libraries in openclaw/src/main/jniLibs/. " +
                    "Download jniLibs-arm64-v8a.tar.gz from the openclaw-android " +
                    "release tag node-libs-v1 (sha256 in scripts/node-libs.sha256 of the " +
                    "upstream repo) and unpack it there, then rebuild."
            )
        }
    }
}
tasks.named("preBuild") { dependsOn(checkNodeLibs) }
