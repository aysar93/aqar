plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

// Debug builds do not require production signing secrets. Release builds must be signed.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.name.contains("Release") } && keystoreProperties.getProperty("storeFile") == null) {
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
        applicationId = "com.andalus.aqar"

        minSdk = flutter.minSdkVersion
        targetSdk = 36

        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true
    }

    flavorDimensions += "environment"
    productFlavors {
        create("production") { dimension = "environment" }
        create("bookingsTest") {
            dimension = "environment"
            applicationIdSuffix = ".bookings.test"
            versionNameSuffix = "-bookings-test"
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
        signingConfig = signingConfigs.findByName("release")

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
