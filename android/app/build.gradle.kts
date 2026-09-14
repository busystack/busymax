import java.util.Properties
import java.net.URLEncoder
import java.nio.charset.StandardCharsets

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "io.busystack.busymax"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        resValues = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    val publicConfig = Properties()
    val publicConfigFile = rootProject.file("busymax.android.properties")
    if (publicConfigFile.isFile) {
        publicConfigFile.inputStream().use(publicConfig::load)
    }
    val msalClientId = publicConfig.getProperty("microsoft.clientId", "").trim()
    val msalAuthorityTenant = publicConfig.getProperty("microsoft.authorityTenant", "common").trim()
    val msalSignatureHash = publicConfig.getProperty("microsoft.signatureHash", "busymax-not-configured").trim()
    val generatedBusyMaxResources = layout.buildDirectory
        .dir("generated/busymax/res")
        .get()
        .asFile
    sourceSets.getByName("main").res.srcDir(generatedBusyMaxResources)

    val signingProperties = Properties()
    val signingPropertiesFile = rootProject.file("key.properties")
    if (signingPropertiesFile.isFile) {
        signingPropertiesFile.inputStream().use(signingProperties::load)
    }

    signingConfigs {
        if (signingPropertiesFile.isFile) {
            create("release") {
                storeFile = file(signingProperties.getProperty("storeFile"))
                storePassword = signingProperties.getProperty("storePassword")
                keyAlias = signingProperties.getProperty("keyAlias")
                keyPassword = signingProperties.getProperty("keyPassword")
            }
        }
    }

    defaultConfig {
        applicationId = "io.busystack.busymax"
        minSdk = 24
        targetSdk = 37
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["busymaxMsalRedirectHost"] = applicationId!!
        manifestPlaceholders["busymaxMsalSignatureHash"] = msalSignatureHash
        resValue("string", "busymax_msal_client_id", msalClientId)
        resValue("string", "busymax_msal_authority_tenant", msalAuthorityTenant)
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            signingConfig = when {
                signingPropertiesFile.isFile -> signingConfigs.getByName("release")
                providers.gradleProperty("busymaxTestSigning").orNull == "true" ->
                    signingConfigs.getByName("debug")
                else -> null
            }
        }
    }
}

val generateBusyMaxAndroidConfiguration by tasks.registering {
    val clientId = providers.provider {
        val properties = Properties()
        val file = rootProject.file("busymax.android.properties")
        if (file.isFile) file.inputStream().use(properties::load)
        properties.getProperty("microsoft.clientId", "").trim()
    }
    val tenant = providers.provider {
        val properties = Properties()
        val file = rootProject.file("busymax.android.properties")
        if (file.isFile) file.inputStream().use(properties::load)
        properties.getProperty("microsoft.authorityTenant", "common").trim()
    }
    val signature = providers.provider {
        val properties = Properties()
        val file = rootProject.file("busymax.android.properties")
        if (file.isFile) file.inputStream().use(properties::load)
        properties.getProperty("microsoft.signatureHash", "").trim()
    }
    val outputDirectory = layout.buildDirectory.dir("generated/busymax/res/raw")
    inputs.property("microsoftClientId", clientId)
    inputs.property("microsoftAuthorityTenant", tenant)
    inputs.property("microsoftSignatureHash", signature)
    outputs.dir(outputDirectory)
    doLast {
        val output = outputDirectory.get().file("busymax_msal_config.json").asFile
        output.delete()
        if (clientId.get().isNotEmpty() && signature.get().isNotEmpty()) {
            output.parentFile.mkdirs()
            val encodedSignature = URLEncoder.encode(
                signature.get(),
                StandardCharsets.UTF_8,
            )
            output.writeText(
                """{
  "client_id": "${clientId.get()}",
  "redirect_uri": "msauth://io.busystack.busymax/$encodedSignature",
  "authorization_user_agent": "BROWSER",
  "account_mode": "MULTIPLE",
  "broker_redirect_uri_registered": false,
  "logging": {"pii_enabled": false, "log_level": "WARNING"},
  "authorities": [{
    "type": "AAD",
    "audience": {
      "type": "AzureADandPersonalMicrosoftAccount",
      "tenant_id": "${tenant.get()}"
    },
    "default": true
  }]
}
""",
            )
        }
    }
}

tasks.named("preBuild").configure {
    dependsOn(generateBusyMaxAndroidConfiguration)
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
