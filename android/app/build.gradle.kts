import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.orbit.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.orbit.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Keep packaged locales tight to reduce release size.
        resourceConfigurations.addAll(listOf("en", "es"))

        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
        }

        manifestPlaceholders["cameraPermissionNode"] = "merge"
        manifestPlaceholders["microphonePermissionNode"] = "merge"
        manifestPlaceholders["audioSettingsPermissionNode"] = "merge"
        manifestPlaceholders["postNotificationsPermissionNode"] = "merge"
        manifestPlaceholders["foregroundServicePermissionNode"] = "merge"
        manifestPlaceholders["wifiStatePermissionNode"] = "remove"
    }

    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    val hasReleaseKeystore = keystorePropertiesFile.exists()
    fun isPermissionEnabled(propertyName: String, defaultValue: Boolean): Boolean {
        return providers.gradleProperty(propertyName)
            .orNull
            ?.toBooleanStrictOrNull()
            ?: defaultValue
    }

    val enableCameraPermission = isPermissionEnabled("orbit.enableCameraPermission", true)
    val enableMicrophonePermission = isPermissionEnabled("orbit.enableMicrophonePermission", true)
    val enableAudioSettingsPermission = isPermissionEnabled("orbit.enableAudioSettingsPermission", true)
    val enablePostNotificationsPermission = isPermissionEnabled("orbit.enablePostNotificationsPermission", true)
    val enableForegroundServicePermission = isPermissionEnabled("orbit.enableForegroundServicePermission", true)
    val enableWifiStatePermission = isPermissionEnabled("orbit.enableWifiStatePermission", false)
    val lowMemoryBuild = providers.gradleProperty("orbit.lowMemoryBuild").orNull == "true"
    val isReleaseTask = gradle.startParameter.taskNames.any {
        val normalized = it.lowercase()
        normalized.contains("release") || normalized.contains("bundle")
    }
    if (hasReleaseKeystore) {
        keystoreProperties.load(keystorePropertiesFile.inputStream())
    }

    signingConfigs {
        getByName("debug") {
            // Keep debug signing explicit and isolated from release.
        }

        create("release") {
            if (hasReleaseKeystore) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
            manifestPlaceholders["usesCleartextTraffic"] = "true"
            manifestPlaceholders["networkSecurityConfig"] = "@xml/network_security_config_debug"
            manifestPlaceholders["cameraPermissionNode"] = if (enableCameraPermission) "merge" else "remove"
            manifestPlaceholders["microphonePermissionNode"] = if (enableMicrophonePermission) "merge" else "remove"
            manifestPlaceholders["audioSettingsPermissionNode"] = if (enableAudioSettingsPermission) "merge" else "remove"
            manifestPlaceholders["postNotificationsPermissionNode"] = if (enablePostNotificationsPermission) "merge" else "remove"
            manifestPlaceholders["foregroundServicePermissionNode"] = if (enableForegroundServicePermission) "merge" else "remove"
            manifestPlaceholders["wifiStatePermissionNode"] = if (enableWifiStatePermission) "merge" else "remove"
        }

        release {
            if (!hasReleaseKeystore && isReleaseTask) {
                throw GradleException(
                    "Release keystore missing. Create android/key.properties from android/key.properties.example before building release."
                )
            }

            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            manifestPlaceholders["usesCleartextTraffic"] = "false"
            manifestPlaceholders["networkSecurityConfig"] = "@xml/network_security_config"
            manifestPlaceholders["cameraPermissionNode"] = if (enableCameraPermission) "merge" else "remove"
            manifestPlaceholders["microphonePermissionNode"] = if (enableMicrophonePermission) "merge" else "remove"
            manifestPlaceholders["audioSettingsPermissionNode"] = if (enableAudioSettingsPermission) "merge" else "remove"
            manifestPlaceholders["postNotificationsPermissionNode"] = if (enablePostNotificationsPermission) "merge" else "remove"
            manifestPlaceholders["foregroundServicePermissionNode"] = if (enableForegroundServicePermission) "merge" else "remove"
            manifestPlaceholders["wifiStatePermissionNode"] = if (enableWifiStatePermission) "merge" else "remove"
        }
    }

    splits {
        abi {
            isEnable = true
            reset()
            include("armeabi-v7a", "arm64-v8a", "x86_64")
            isUniversalApk = false
        }
    }

    lint {
        checkReleaseBuilds = !lowMemoryBuild
        abortOnError = !lowMemoryBuild
        checkDependencies = !lowMemoryBuild
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation(platform("com.google.firebase:firebase-bom:33.10.0"))
    implementation("com.google.android.play:core:1.10.3")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

configurations.configureEach {
    exclude(group = "com.google.android.play", module = "core-common")
}
