# Flutter / Dart
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# FFmpegKit — preserve all native bridge classes
-keep class com.arthenica.ffmpegkit.** { *; }
-dontwarn com.arthenica.ffmpegkit.**

# WorkManager
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**

# Drift / SQLite
-keep class com.example.** { *; }
-keep class com.downloda.** { *; }

# Kotlin serialization / reflection
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes EnclosingMethod

# Prevent stripping of Kotlin metadata
-keep class kotlin.** { *; }
-dontwarn kotlin.**
