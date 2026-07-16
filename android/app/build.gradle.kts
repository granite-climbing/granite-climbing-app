import org.gradle.api.GradleException
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()

if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use {
        keystoreProperties.load(it)
    }
}

fun releaseKeystoreProperty(name: String): String =
    keystoreProperties.getProperty(name)
        ?: throw GradleException("Missing '$name' in android/key.properties")

fun dartDefine(name: String): String? {
    val dartDefines = project.findProperty("dart-defines") as? String ?: return null

    return dartDefines.split(",").firstNotNullOfOrNull { encoded ->
        val decoded = runCatching {
            String(Base64.getDecoder().decode(encoded))
        }.getOrNull() ?: return@firstNotNullOfOrNull null
        val delimiterIndex = decoded.indexOf("=")
        if (delimiterIndex <= 0) return@firstNotNullOfOrNull null

        val key = decoded.substring(0, delimiterIndex)
        val value = decoded.substring(delimiterIndex + 1)
        if (key == name) value else null
    }
}

val kakaoNativeAppKey = dartDefine("KAKAO_NATIVE_APP_KEY") ?: ""

android {
    namespace = "com.granite.climbing"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.granite.climbing"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["kakaoNativeAppKey"] = kakaoNativeAppKey
    }

    buildFeatures {
        buildConfig = true
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = releaseKeystoreProperty("keyAlias")
                keyPassword = releaseKeystoreProperty("keyPassword")
                storeFile = file(releaseKeystoreProperty("storeFile"))
                storePassword = releaseKeystoreProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Flutter enables R8 shrinking for release builds. Naver OAuth 5.11.2
            // crashes while its initialization coroutine is optimized by R8.
            isMinifyEnabled = false
            isShrinkResources = false
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

gradle.taskGraph.whenReady {
    val releaseTaskRequested = allTasks.any {
        it.name.contains("Release", ignoreCase = true)
    }

    if (releaseTaskRequested && !hasReleaseKeystore) {
        throw GradleException(
            "Missing android/key.properties. Copy android/key.properties.example, " +
                "fill in the upload keystore values, then run the release build again.",
        )
    }
}

flutter {
    source = "../.."
}
