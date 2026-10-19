# Reglas de R8 para las versiones release de Kiji (se suman a las de Flutter).

# WorkManager crea su base de datos (Room) por reflexión: sin esto, Kiji se cerraba al abrir.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.work.ListenableWorker { <init>(...); }

# Motor A (InnerTubeX): modelos con kotlinx.serialization, motor de JavaScript y clientes Ktor.
-keep class com.metrolist.innertubex.** { *; }
-keepattributes *Annotation*, InnerClasses, Signature, EnclosingMethod, Exceptions
-keepclassmembers class kotlinx.serialization.json.** { *** Companion; }
-keepclasseswithmembers class ** { kotlinx.serialization.KSerializer serializer(...); }
-keep class io.ktor.** { *; }
-keep class app.cash.quickjs.** { *; }
-keep class com.dokar.quickjs.** { *; }
-dontwarn org.slf4j.**
-dontwarn io.ktor.**

# El extractor de Kiji (canal kiji/innertubex, tokens y la prueba diaria).
-keep class com.example.kiji_player.** { *; }
