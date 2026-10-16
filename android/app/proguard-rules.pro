# The ML Kit Flutter plugin references all optional script recognizers. This
# application bundles and invokes Japanese only; leave other missing classes
# as errors rather than suppressing ML Kit warnings globally.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions

# ML Kit discovers these registrars through AndroidManifest metadata and
# invokes their no-argument constructors through reflection. R8 full mode
# otherwise removes the constructors, leaving ML Kit components uninitialized.
-keep class com.google.mlkit.** implements com.google.firebase.components.ComponentRegistrar {
    public <init>();
}
