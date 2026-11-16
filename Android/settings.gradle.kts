pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "Gloop"

// Mirrors the iOS packages (iOS/Packages). Add a module when a feature gets ported.
include(":app")   // Android app: screens, platform glue (alarms, billing, camera, widgets)
include(":core")  // Pure Kotlin logic + content models, unit-tested on the JVM (no emulator)
