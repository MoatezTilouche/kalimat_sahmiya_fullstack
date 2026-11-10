package com.jawhar.kalimat_sahmiya

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.speech.tts.TextToSpeech
import java.util.Locale

class MainActivity : FlutterActivity() {
    private var speech: TextToSpeech? = null
    private var ready = false
    private var pending: Pair<String, MethodChannel.Result>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kalimat_sahmiya/speech")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "speak" -> {
                        val text = (call.arguments as? String)?.take(TextToSpeech.getMaxSpeechInputLength())
                        if (text.isNullOrBlank()) result.success(false)
                        else if (speech == null) {
                            pending = Pair(text, result)
                            speech = TextToSpeech(applicationContext) { status ->
                                runOnUiThread {
                                    ready = status == TextToSpeech.SUCCESS
                                    val request = pending
                                    pending = null
                                    if (request != null) request.second.success(ready && speakArabic(request.first))
                                }
                            }
                        } else result.success(ready && speakArabic(text))
                    }
                    "stop" -> {
                        val request = pending
                        pending = null
                        request?.second?.success(false)
                        speech?.stop()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
    private fun speakArabic(text: String): Boolean {
        val engine = speech ?: return false
        val voice = engine.voices?.firstOrNull {
            it.locale.language == "ar" && !it.isNetworkConnectionRequired
        } ?: return false
        if (engine.setLanguage(Locale.forLanguageTag("ar")) < TextToSpeech.LANG_AVAILABLE) return false
        engine.voice = voice
        engine.setSpeechRate(0.85f)
        return engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, "arabic-word") == TextToSpeech.SUCCESS
    }
    override fun onDestroy() {
        pending?.second?.success(false)
        pending = null
        speech?.stop()
        speech?.shutdown()
        speech = null
        super.onDestroy()
    }
}
