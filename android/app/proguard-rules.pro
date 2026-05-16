# Project-specific R8/ProGuard rules for release builds.
# Keep this file intentionally minimal so Flutter/Firebase defaults remain in control.

# Preserve Kotlin metadata used by reflection-based libraries.
-keep class kotlin.Metadata { *; }

# Keep line number/source information for better release crash diagnostics.
-keepattributes SourceFile,LineNumberTable,*Annotation*,EnclosingMethod,InnerClasses,Signature

# Do not warn on optional JDK classes that may be referenced by transitive deps.
-dontwarn javax.annotation.**
-dontwarn org.codehaus.mojo.animal_sniffer.IgnoreJRERequirement