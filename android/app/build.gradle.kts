plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

val fcmStaging = System.getenv("FCM_STAGING_BUILD") == "true"
val keystoreProperties = Properties().apply {
    val keyFile = rootProject.file("key.properties")
    if (!fcmStaging && keyFile.exists()) load(keyFile.inputStream())
}
if (fcmStaging) {
    val config = file("google-services.json").readText()
    require(!config.contains("aqar-9f3f9") && config.contains("aqar-fcm-test-") && config.contains("com.andalus.aqar.staging")) {
        "Install isolated staging google-services.json before building"
    }
}
require(fcmStaging || keystoreProperties.containsKey("storeFile")) {
    "Production signing configuration is required outside the isolated staging build"
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


    signingConfigs {
    if (keystoreProperties.containsKey("storeFile")) create("release") {
        storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
        storePassword = keystoreProperties["storePassword"] as String
        keyAlias = keystoreProperties["keyAlias"] as String
        keyPassword = keystoreProperties["keyPassword"] as String
    }
}

    buildTypes {
    release {
        signingConfig = if (fcmStaging) signingConfigs.getByName("debug") else signingConfigs.getByName("release")

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
