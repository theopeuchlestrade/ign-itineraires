package fr.ign.itineraires

import android.media.AudioAttributes
import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val channelName = "ign_itineraires/speech"
    private var speech: TextToSpeech? = null
    private var speechReady = false
    private var speechFailed = false
    private val pendingInitialization = mutableListOf<MethodChannel.Result>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        speech = TextToSpeech(this) { status ->
            speechReady = status == TextToSpeech.SUCCESS
            speechFailed = !speechReady
            if (speechReady) {
                speech?.language = Locale.FRANCE
                speech?.setSpeechRate(0.95f)
                speech?.setPitch(1f)
                speech?.setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build(),
                )
                pendingInitialization.forEach { it.success(null) }
            } else {
                pendingInitialization.forEach {
                    it.error("tts-unavailable", "La synthèse vocale Android est indisponible.", null)
                }
                channel.invokeMethod("onError", "tts-unavailable")
            }
            pendingInitialization.clear()
        }
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    if (speechReady) {
                        result.success(null)
                    } else if (speechFailed) {
                        result.error("tts-unavailable", "La synthèse vocale Android est indisponible.", null)
                    } else {
                        pendingInitialization.add(result)
                    }
                }
                "speak" -> {
                    val text = call.argument<String>("text")
                    if (!speechReady || text.isNullOrBlank()) {
                        result.error("tts-unavailable", "La synthèse vocale Android est indisponible.", null)
                    } else {
                        val status = speech?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "navigation")
                        if (status == TextToSpeech.ERROR) {
                            channel.invokeMethod("onError", "speak-error")
                            result.error("speak-error", "La lecture vocale a échoué.", null)
                        } else {
                            result.success(null)
                        }
                    }
                }
                "stop" -> {
                    speech?.stop()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        speech?.stop()
        speech?.shutdown()
        speech = null
        super.onDestroy()
    }
}
