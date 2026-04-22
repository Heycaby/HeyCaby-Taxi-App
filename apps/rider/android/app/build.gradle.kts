import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val hasReleaseKeystore = keystorePropertiesFile.exists()

android {
    namespace = "com.heycaby.rider"
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
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")!!
                keyPassword = keystoreProperties.getProperty("keyPassword")!!
                val storeFileProp = keystoreProperties.getProperty("storeFile")!!
                storeFile = file(storeFileProp)
                storePassword = keystoreProperties.getProperty("storePassword")!!
            }
        }
    }

    defaultConfig {
        applicationId = "com.heycaby.rider"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig =
                if (hasReleaseKeystore) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }
}

afterEvaluate {
    listOf("bundleRelease", "assembleRelease").forEach { taskName ->
        tasks.findByName(taskName)?.let { t ->
            t.doFirst {
                if (!keystorePropertiesFile.exists()) {
                    throw org.gradle.api.GradleException(
                        "Missing ${keystorePropertiesFile.absolutePath}. " +
                            "Copy key.properties.example to key.properties and add your Play upload keystore. " +
                            "Google Play does not accept debug-signed release bundles."
                    )
                }
            }
        }
    }
}

flutter {
    source = "../.."
}
