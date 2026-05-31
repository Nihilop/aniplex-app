import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Keystore via key.properties (CI) ou debug sinon ─────────────────────────
val keyPropertiesFile = rootProject.file("key.properties")
val useReleaseKey = keyPropertiesFile.exists()
val keyProperties = Properties().apply {
    if (useReleaseKey) load(keyPropertiesFile.inputStream())
}

android {
    namespace = "com.aniplex.aniplex_tv"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        if (useReleaseKey) {
            create("release") {
                keyAlias     = keyProperties["keyAlias"]    as String
                keyPassword  = keyProperties["keyPassword"] as String
                storeFile    = file(keyProperties["storeFile"] as String)
                storePassword = keyProperties["storePassword"] as String
            }
        }
    }

    defaultConfig {
        applicationId = "com.aniplex.aniplex_tv"
        minSdk = flutter.minSdkVersion  // Android 5 — requis pour video_player HLS
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = if (useReleaseKey)
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
