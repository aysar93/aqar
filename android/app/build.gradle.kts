plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

val fcmStaging = System.getenv("FCM_STAGING_BUILD") == "true"
val unsignedBridgeCandidate = System.getenv("PUSH_BRIDGE_UNSIGNED_RC") == "true" && !fcmStaging
val keystoreProperties = Properties().apply {
    val keyFile = rootProject.file("key.properties")
    if (!fcmStaging && keyFile.exists()) keyFile.inputStream().use { load(it) }
}
if (fcmStaging) {
    val config = file("google-services.json").readText()
    require(!config.contains("aqar-9f3f9") && (config.contains("aqar-fcm-test-") || config.contains("aqar-media-test-")) && config.contains("com.andalus.aqar.staging")) {
        "Install isolated staging google-services.json before building"
    }
}

// Debug builds do not require production signing secrets. Release builds must be signed outside isolated staging / unsigned bridge RC.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.name.contains("Release") } && !fcmStaging && !unsignedBridgeCandidate && keystoreProperties.getProperty("storeFile") == null) {
        throw GradleException("Release signing requires android/key.properties")
    }
}

android {
    namespace = "com.andalus.aqar"

    // استخدام إصدار SDK الخاص بـ Flutter
    compileSdk = 36

    // مطلوب لإضافات Firebase الحديثة
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = if (fcmStaging) "com.andalus.aqar.staging" else "com.andalus.aqar"
        manifestPlaceholders["aqarAppLabel"] = if (fcmStaging) "Aqar FCM staging" else "عقارات الانبار"
        manifestPlaceholders["facebookProviderAuthority"] = if (fcmStaging) "com.andalus.aqar.staging.facebook.provider" else "com.facebook.app.FacebookContentProvider1745018726927685"
        manifestPlaceholders["facebookAutoInit"] = (!fcmStaging).toString()

        minSdk = flutter.minSdkVersion
        targetSdk = 36

        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true
    }

    flavorDimensions += "environment"
    productFlavors {
        create("production") { dimension = "environment" }
        create("bookingsStaging") {
            dimension = "environment"
            applicationIdSuffix = ".bookingstest"
            versionNameSuffix = "-bookings-staging"
        }
        create("bookingsTest") {
            dimension = "environment"
            applicationIdSuffix = ".bookings.test"
            versionNameSuffix = "-bookings-test"
        }
        create("bookingsStagingDiagnostic") {
            dimension = "environment"
            applicationIdSuffix = ".bookings.stagediag"
            versionNameSuffix = "-staging-diagnostic"
            versionCode = 2026104306
        }
        create("bookingsOfflinePreview") {
            dimension = "environment"
            applicationIdSuffix = ".bookings.offlinepreview"
            versionNameSuffix = "-offline-ui-preview"
            versionCode = 2026104409
        }
        create("bookingsLocalDiagnostic") {
            dimension = "environment"
            applicationIdSuffix = ".bookings.localdiag"
            versionNameSuffix = "-local-diagnostic"
            versionCode = 2026104310
        }
    }

    signingConfigs {
        if (keystoreProperties.getProperty("storeFile") != null) create("release") {
            storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = if (unsignedBridgeCandidate) null else if (fcmStaging) signingConfigs.getByName("debug") else signingConfigs.findByName("release")

            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
}
