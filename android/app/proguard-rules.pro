# Project-specific R8/ProGuard rules for release builds.
# Keep this file intentionally minimal so Flutter/Firebase defaults remain in control.

# Preserve Kotlin metadata used by reflection-based libraries.
-keep class kotlin.Metadata { *; }

# Keep line number/source information for better release crash diagnostics.
-keepattributes SourceFile,LineNumberTable,*Annotation*,EnclosingMethod,InnerClasses,Signature

# Do not warn on optional JDK classes that may be referenced by transitive deps.
-dontwarn javax.annotation.**
-dontwarn org.codehaus.mojo.animal_sniffer.IgnoreJRERequirement

# --- Additional project-specific rules ---

# Keep Firebase internal classes used via reflection
-keep class com.google.firebase.** { *; }
-keepnames class com.google.firebase.** { *; }

# Keep generated models in app package (adjust package as needed)
-keep class com.orbit.** { *; }

# ============================================
# Firebase-specific rules for R8/ProGuard
# ============================================

# Keep Firebase Cloud Messaging classes and services
-keep class com.google.firebase.messaging.** { *; }
-keepnames class com.google.firebase.messaging.** { *; }
-keep interface com.google.firebase.messaging.** { *; }

# Keep Firebase Core and Authentication
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.firebase.internal.** { *; }
-keep class com.google.firebase.iid.** { *; }
-keepnames class com.google.firebase.auth.** { *; }

# Keep Firestore
-keep class com.google.firebase.firestore.** { *; }
-keep class com.google.firestore.** { *; }
-keepnames class com.google.firebase.firestore.** { *; }

# Keep Firebase App Check
-keep class com.google.firebase.appcheck.** { *; }
-keepnames class com.google.firebase.appcheck.** { *; }

# Keep Firebase Remote Config
-keep class com.google.firebase.remoteconfig.** { *; }
-keepnames class com.google.firebase.remoteconfig.** { *; }

# Keep Firebase Storage
-keep class com.google.firebase.storage.** { *; }
-keepnames class com.google.firebase.storage.** { *; }

# Keep Firebase Analytics
-keep class com.google.firebase.analytics.** { *; }
-keepnames class com.google.firebase.analytics.** { *; }

# Keep Google Play Services (Firebase depends on this)
-keep class com.google.android.gms.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-keepnames class com.google.android.gms.** { *; }

# Keep reflection-based initialization
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Enum classes for Firebase configuration
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep callback interfaces used by Firebase
-keep interface com.google.firebase.** { *; }
-keep interface com.google.android.gms.** { *; }

# Remove common logging calls in release for smaller size and to avoid leaking
-assumenosideeffects class android.util.Log {
	public static *** d(...);
	public static *** v(...);
	public static *** i(...);
	public static *** w(...);
	public static *** e(...);
}

# Keep native methods used by Flutter engine
-keep class io.flutter.embedding.** { *; }

# Don't warn about javax.annotation since some transitive deps reference it
-dontwarn javax.annotation.**