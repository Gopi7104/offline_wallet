# Flutter auto-enables R8 shrinking + obfuscation for release builds
# (FlutterPlugin.kt) and auto-includes this file if present. Without it, only
# each dependency's bundled consumer-rules apply.
#
# mobile_scanner's own consumer rule is `-keep class com.google.mlkit.* { *; }`
# — a single `*`, which in ProGuard/R8 syntax does NOT cross package
# boundaries. It only protects classes literally in the `com.google.mlkit`
# package, none of which exist; the real detector-creation code lives in
# `com.google.mlkit.vision.barcode.internal.*`, `com.google.mlkit.common.
# sdkinternal.*`, and the Play Services classes those delegate to
# (`com.google.android.gms.internal.mlkit_vision_barcode.*`), plus the
# Firebase Components reflection-based registrar discovery
# (`com.google.firebase.components.*`) that wires MlKitContext at app start.
# R8 renaming/inlining across these leaves the scanner's internal
# BarcodeScannerOptions -> ExecutorSelector -> MlKitContext chain broken,
# surfacing as a NullPointerException the first time the scan screen builds a
# detector (only in --release builds; debug builds are unaffected since R8
# doesn't run). Matches known upstream reports: googlesamples/mlkit#213,
# xamarin/GooglePlayServicesComponents#891 — the only reliable community fix
# is exempting these namespaces from shrinking entirely (`-keepnames` alone
# is insufficient; it still allows member removal/inlining).
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.firebase.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**
