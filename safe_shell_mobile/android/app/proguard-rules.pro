# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Google Play Services & Firebase
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# AndroidX
-keep class androidx.lifecycle.** { *; }
-dontwarn androidx.**

# Common Flutter Plugins
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.tekartik.sqflite.** { *; }
-keep class io.flutter.plugins.firebase.** { *; }
-keep class io.flutter.plugins.firebasemessaging.** { *; }
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.videoplayer.** { *; }
-keep class io.flutter.plugins.webviewflutter.** { *; }

# Prevent obfuscation of certain classes
-keep class com.safeshell.safe_shell_mobile.** { *; }

# Handle Kotlin Reflection
-keep class kotlin.reflect.jvm.internal.** { *; }
-dontwarn kotlin.reflect.jvm.internal.**
