import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

// Supabase config from the git-ignored secrets.properties (see secrets.properties.example).
// Same rule as iOS: only a publishable key may ever be built into the app.
val secrets = Properties().apply {
    rootProject.file("secrets.properties").takeIf { it.exists() }?.inputStream()?.use { load(it) }
}
fun secret(name: String): String = secrets.getProperty(name, "").trim()
check(!secret("SUPABASE_PUBLISHABLE_KEY").startsWith("sb_secret_")) {
    "secrets.properties holds a Supabase SECRET key. Use the publishable key (sb_publishable_…)."
}

android {
    namespace = "be.gloop.app"
    compileSdk = 37

    defaultConfig {
        applicationId = "be.gloop.app"
        minSdk = 28
        targetSdk = 37
        versionCode = 1
        versionName = "1.0.0"
        buildConfigField("String", "SUPABASE_URL", "\"${secret("SUPABASE_URL")}\"")
        buildConfigField("String", "SUPABASE_PUBLISHABLE_KEY", "\"${secret("SUPABASE_PUBLISHABLE_KEY")}\"")
    }

    sourceSets {
        // The content both apps ship (prices, coach lines, quiz, legal, translations), no copies.
        getByName("main").assets.directories.add("../../Shared/Config")
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }
}


dependencies {
    implementation(project(":core"))
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.material3)
    implementation(libs.compose.ui.tooling.preview)
    debugImplementation(libs.compose.ui.tooling)
}
