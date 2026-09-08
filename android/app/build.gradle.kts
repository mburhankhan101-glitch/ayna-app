plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ayna.ayna_app"
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
        // Locked in ADR-005. Permanent once published to Play: changing it is
        // not a rename, it is a new listing with zero installs.
        applicationId = "com.ayna.ayna_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion // auth0_flutter's floor
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // auth0_flutter builds its callback intent-filter from these at build
        // time. Neither is a secret: the domain is public and the scheme is
        // just a string the OS routes on.
        //
        // NOTE the scheme is deliberately NOT the applicationId. It cannot be:
        // a URI scheme may contain only letters, digits, "+", "-" and "."
        // (RFC 3986), and the applicationId above has an underscore. Auth0
        // rejects an underscored scheme outright when registering the callback.
        //
        // The full callback is:
        //   scheme://domain/android/APPLICATION_ID/callback
        // so the scheme drops the underscore while the path segment keeps the
        // real applicationId — underscores are perfectly legal in a path. The
        // two differ on purpose.
        //
        // This value must match AuthService.callbackScheme in Dart exactly. A
        // single character out and the browser returns to nothing: the login
        // hangs on a blank page with no error anywhere.
        //
        // Kept here rather than in a dart-define because the intent-filter is
        // baked into the manifest at build time; Dart cannot influence it.
        manifestPlaceholders["auth0Domain"] = "dev-yqk2n1s3sblxcyyj.us.auth0.com"
        manifestPlaceholders["auth0Scheme"] = "com.ayna.aynaapp"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
