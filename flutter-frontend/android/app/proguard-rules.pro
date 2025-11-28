-keepattributes *Annotation*
-keepclassmembers class * {
    @com.google.firebase.messaging.FirebaseMessagingService *;
}
-keep public class * extends com.google.firebase.messaging.FirebaseMessagingService
-keep class com.google.firebase.** { *; }
