# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Gson (Used by Flutter Local Notifications)
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-dontwarn com.google.gson.**

# Prevent R8 from stripping generic types (The core error)
-keepattributes Signature
