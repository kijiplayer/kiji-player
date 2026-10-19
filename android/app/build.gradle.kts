import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Clave de firma de las versiones release: fuera del repo, en <usuario>/kiji-keys/key.properties.
// Sin ese archivo (otra PC), la release se firma con la clave de depuración.
val kijiKeyProperties = Properties().apply {
    val file = File(System.getProperty("user.home"), "kiji-keys/key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    namespace = "com.example.kiji_player"
    // 37: lo exige InnerTubeX 0.10.0 (Tarea Z8). No cambia la versión mínima de Android.
    compileSdk {
        version = release(37) { minorApiLevel = 0 }
    }
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.kiji_player"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // "prod" es la Kiji de siempre; "dev" (Kiji Dev) se instala al lado, con otro id y sus
    // propios datos: ahí se hacen TODAS las pruebas en el celular (Tarea T2).
    flavorDimensions += "canal"
    productFlavors {
        create("prod") {
            dimension = "canal"
            manifestPlaceholders["appName"] = "Kiji Player"
        }
        create("dev") {
            dimension = "canal"
            applicationIdSuffix = ".dev"
            // Kiji Dev: la misma versión con "-dev.<compilación>" (0.5.0-beta.1-dev.2).
            versionNameSuffix = "-dev.${flutter.versionCode}"
            manifestPlaceholders["appName"] = "Kiji Dev"
        }
    }

    signingConfigs {
        if (kijiKeyProperties.containsKey("storeFile")) {
            create("release") {
                storeFile = file(kijiKeyProperties.getProperty("storeFile"))
                storePassword = kijiKeyProperties.getProperty("storePassword")
                keyAlias = kijiKeyProperties.getProperty("keyAlias")
                keyPassword = kijiKeyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
            // Reglas propias de R8 (WorkManager, InnerTubeX): ver proguard-rules.pro.
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Motor A de extracción (Tarea Z8): InnerTubeX de MetrolistGroup, GPL-3.0. Versión fija:
    // YouTube cambia sin aviso, así que se sube a mano después de leer su CHANGELOG.
    implementation("com.github.MetrolistGroup.innertubex:innertubex-android:v0.10.0")
    implementation("io.ktor:ktor-client-okhttp:3.6.0")
    implementation("io.ktor:ktor-client-content-negotiation:3.6.0")
    implementation("io.ktor:ktor-serialization-kotlinx-json:3.6.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")
    implementation("com.squareup.okhttp3:okhttp:5.1.0")
    implementation("androidx.collection:collection-ktx:1.5.0")
    // Prueba diaria del extractor (Tarea Z8): solo con WiFi y batería no baja.
    implementation("androidx.work:work-runtime-ktx:2.10.5")
}