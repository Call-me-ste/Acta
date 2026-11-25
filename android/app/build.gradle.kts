// `java` da solo, in uno script Gradle Kotlin, e' l'estensione del plugin Java:
// per questo le classi di java.* vanno importate con il nome pieno.
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// La firma di release: chiave e password stanno **fuori dal repo**
// (`android/key.properties`, ignorato da git; la chiave in `_env\keys\`).
// Senza quel file la build **non si ferma**: ripiega sulla chiave di debug,
// cosi' il progetto si apre e si compila anche su una macchina nuova — ma
// l'aggiornamento di un'app installata con l'altra chiave fallisce, quindi e'
// una condizione da vedere, non da nascondere: la pagina «Dati e backup»
// mostra quale firma sta usando la build.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKey = keystorePropertiesFile.exists()
if (hasReleaseKey) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.callmeste.planner"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // `flutter_local_notifications` usa API Java recenti (java.time) anche su
        // Android vecchi: senza il desugaring la build si ferma con
        // «requires core library desugaring to be enabled» (verificato il
        // 2026-09-17: è lo spike in testa alla fase delle notifiche).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.callmeste.planner"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // `device_calendar_plus` richiede Android 24 (7.0).
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "distribution"
    productFlavors {
        create("production") {
            dimension = "distribution"
            manifestPlaceholders["actaLabel"] = "Acta"
        }
        create("qa") {
            dimension = "distribution"
            applicationIdSuffix = ".qa"
            manifestPlaceholders["actaLabel"] = "Acta Test"
        }
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                // Percorso assoluto (la chiave sta fuori dal repo): `file()` lo
                // accetta cosi' com'e', e un percorso relativo verrebbe risolto
                // rispetto alla cartella del modulo Android.
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Chiave personale se c'e', debug altrimenti (vedi sopra).
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
    implementation("com.google.android.gms:play-services-auth:22.0.0")
    // La libreria che rende disponibili le API Java nuove sui device vecchi:
    // la pretende `flutter_local_notifications` (vedi il commento sopra).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Le prove **pure** del widget del mese (geometria della griglia e chiavi
    // del mese): girano sulla JVM, senza emulatore. E' l'unica dipendenza di
    // test del progetto, e serve solo a `:app:testDebugUnitTest`.
    testImplementation("junit:junit:4.13.2")
}
