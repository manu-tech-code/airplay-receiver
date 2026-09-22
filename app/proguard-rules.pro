# Keep JNI callback interface (called from native code)
-keep class com.manutechcode.airplay.bridge.RaopCallbackHandler { *; }
-keep class * implements com.manutechcode.airplay.bridge.RaopCallbackHandler { *; }
-keep class com.manutechcode.airplay.bridge.LogListener { *; }
-keep class * implements com.manutechcode.airplay.bridge.LogListener { *; }

# Keep NativeBridge native methods
-keep class com.manutechcode.airplay.bridge.NativeBridge { *; }
