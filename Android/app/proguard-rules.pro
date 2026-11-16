# kotlinx.serialization: keep generated serializers for the content models in :core.
-keepclassmembers class be.gloop.core.** {
    *** Companion;
    kotlinx.serialization.KSerializer serializer(...);
}
-keep,includedescriptorclasses class be.gloop.core.**$$serializer { *; }
