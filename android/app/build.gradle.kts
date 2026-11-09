import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// مفتاح توقيع الإصدار: android/key.properties (مش بيترفع على Git).
// لو الملف مش موجود بنرجع لتوقيع debug عشان `flutter run --release` يفضل شغال،
// بس النسخة دي مينفعش تتنشر على المتجر.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
} else {
    println("WARNING: android/key.properties غير موجود - الإصدار هيتوقّع بمفتاح debug (غير صالح للنشر).")
}

// أمان: بناء release من غير مفتاح التوقيع بيفشل، بدل ما يطلع APK موقّع بـ debug بالغلط.
// للتجربة المحلية بس: flutter run --release -PallowDebugSigning=true
val allowDebugSigning = (findProperty("allowDebugSigning") as String?) == "true"
val isReleaseBuild = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
if (isReleaseBuild && !hasReleaseKeystore && !allowDebugSigning) {
    throw GradleException(
        "android/key.properties مش موجود: مينفعش تبني release من غير مفتاح التوقيع. " +
            "(للتجربة المحلية بس: -PallowDebugSigning=true)"
    )
}

android {
    namespace = "com.pariscurtains.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    

    compileOptions {
        // تفعيل Desugaring بالطريقة الصحيحة لـ Kotlin DSL
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // معرّف التطبيق النهائي على Google Play. مبيتغيرش بعد أول نشر أبدًا.
        // لازم يطابق package_name في google-services.json (docs/APP_ID_CHANGE.md).
        applicationId = "com.pariscurtains.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // تصغير وتشويش الكود وحذف الموارد غير المستخدمة (APK أصغر وأصعب في الفك)
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}