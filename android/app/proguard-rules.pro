# =============================================================================
# Daddies Padel — ProGuard Rules (Production)
# =============================================================================

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep annotations
-keepattributes *Annotation*

# Prevent stripping of Serializable classes
-keepnames class * implements java.io.Serializable

# ImagePicker plugin
-keep class io.flutter.plugins.imagepicker.** { *; }

# SharedPreferences plugin
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Prevent obfuscation of model classes used with JSON
-keep class com.daddies.padel.** { *; }

# Google Play Core (referenced by Flutter engine for deferred components)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Remove debug logs in release
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}
