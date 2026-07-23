package app.daylink.daylink_mobile

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private var speechChannel: MethodChannel? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var activeSpeechSessionId: String? = null
    private var pendingSpeechStart: PendingSpeechStart? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SETTINGS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "openNotificationSettings") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                startActivity(
                    Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                        putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    },
                )
                result.success(null)
            } catch (_: Exception) {
                startActivity(
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = android.net.Uri.parse("package:$packageName")
                    },
                )
                result.success(null)
            }
        }

        speechChannel =
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                SPEECH_CHANNEL,
            ).also { channel ->
                channel.setMethodCallHandler { call, result ->
                    val sessionId = call.argument<String>("sessionId")
                    when (call.method) {
                        "start" -> {
                            val locale = call.argument<String>("locale") ?: "zh-CN"
                            if (sessionId.isNullOrBlank() || sessionId.length > 120) {
                                result.error("invalid_request", null, null)
                                return@setMethodCallHandler
                            }
                            requestSpeechStart(sessionId, locale, result)
                        }
                        "stop" -> {
                            stopSpeech(sessionId, cancelled = false)
                            result.success(null)
                        }
                        "cancel" -> {
                            stopSpeech(sessionId, cancelled = true)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                }
            }
    }

    private fun requestSpeechStart(
        sessionId: String,
        locale: String,
        result: MethodChannel.Result,
    ) {
        if (activeSpeechSessionId != null || pendingSpeechStart != null) {
            result.error("busy", null, null)
            return
        }
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            result.error("recognizer_unavailable", null, null)
            return
        }
        if (
            ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) !=
                PackageManager.PERMISSION_GRANTED
        ) {
            pendingSpeechStart = PendingSpeechStart(sessionId, locale, result)
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.RECORD_AUDIO),
                RECORD_AUDIO_REQUEST,
            )
            return
        }
        startSpeech(sessionId, locale, result)
    }

    private fun startSpeech(
        sessionId: String,
        locale: String,
        result: MethodChannel.Result,
    ) {
        try {
            speechRecognizer?.destroy()
            val recognizer = SpeechRecognizer.createSpeechRecognizer(this)
            speechRecognizer = recognizer
            activeSpeechSessionId = sessionId
            recognizer.setRecognitionListener(speechListener(sessionId))
            recognizer.startListening(
                Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(
                        RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                        RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
                    )
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, safeLocale(locale))
                    putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, packageName)
                },
            )
            result.success(null)
        } catch (_: Exception) {
            destroySpeech(sessionId)
            result.error("recognizer_unavailable", null, null)
        }
    }

    private fun speechListener(sessionId: String) =
        object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                emitSpeech("onLevel", sessionId, mapOf("level" to 0.08))
            }

            override fun onBeginningOfSpeech() = Unit

            override fun onRmsChanged(rmsdB: Float) {
                val level = ((rmsdB + 2f) / 12f).coerceIn(0f, 1f)
                emitSpeech("onLevel", sessionId, mapOf("level" to level.toDouble()))
            }

            override fun onBufferReceived(buffer: ByteArray?) = Unit

            override fun onEndOfSpeech() {
                emitSpeech("onLevel", sessionId, mapOf("level" to 0.0))
            }

            override fun onError(error: Int) {
                if (activeSpeechSessionId != sessionId) return
                emitSpeech("onError", sessionId, mapOf("code" to speechErrorCode(error)))
                destroySpeech(sessionId)
            }

            override fun onResults(results: Bundle?) {
                val transcript = firstTranscript(results)
                if (transcript.isNotBlank()) {
                    emitSpeech(
                        "onFinal",
                        sessionId,
                        mapOf("transcript" to transcript.take(MAX_TRANSCRIPT_LENGTH)),
                    )
                } else {
                    emitSpeech("onError", sessionId, mapOf("code" to "no_match"))
                }
                destroySpeech(sessionId)
            }

            override fun onPartialResults(partialResults: Bundle?) {
                val transcript = firstTranscript(partialResults)
                if (transcript.isNotBlank()) {
                    emitSpeech(
                        "onPartial",
                        sessionId,
                        mapOf("transcript" to transcript.take(MAX_TRANSCRIPT_LENGTH)),
                    )
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) = Unit
        }

    private fun firstTranscript(bundle: Bundle?): String =
        bundle
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.firstOrNull()
            ?.trim()
            .orEmpty()

    private fun emitSpeech(
        method: String,
        sessionId: String,
        values: Map<String, Any>,
    ) {
        if (activeSpeechSessionId != sessionId) return
        speechChannel?.invokeMethod(method, values + mapOf("sessionId" to sessionId))
    }

    private fun stopSpeech(
        requestedSessionId: String?,
        cancelled: Boolean,
    ) {
        val pending = pendingSpeechStart
        if (pending != null && pending.sessionId == requestedSessionId) {
            pendingSpeechStart = null
            pending.result.error("cancelled", null, null)
            return
        }
        val sessionId = activeSpeechSessionId
        if (sessionId == null || requestedSessionId != sessionId) return
        activeSpeechSessionId = null
        if (cancelled) {
            speechRecognizer?.cancel()
        } else {
            speechRecognizer?.stopListening()
        }
        speechRecognizer?.destroy()
        speechRecognizer = null
    }

    private fun destroySpeech(sessionId: String) {
        if (activeSpeechSessionId != sessionId) return
        activeSpeechSessionId = null
        speechRecognizer?.destroy()
        speechRecognizer = null
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != RECORD_AUDIO_REQUEST) return
        val pending = pendingSpeechStart ?: return
        pendingSpeechStart = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            startSpeech(pending.sessionId, pending.locale, pending.result)
        } else {
            pending.result.error("permission_denied", null, null)
        }
    }

    override fun onDestroy() {
        pendingSpeechStart?.result?.error("cancelled", null, null)
        pendingSpeechStart = null
        activeSpeechSessionId = null
        speechRecognizer?.cancel()
        speechRecognizer?.destroy()
        speechRecognizer = null
        speechChannel?.setMethodCallHandler(null)
        speechChannel = null
        super.onDestroy()
    }

    private fun safeLocale(value: String): String {
        val normalized = value.trim().take(20)
        return if (LOCALE_PATTERN.matches(normalized)) normalized else Locale.getDefault().toLanguageTag()
    }

    private fun speechErrorCode(error: Int): String =
        when (error) {
            SpeechRecognizer.ERROR_AUDIO -> "audio"
            SpeechRecognizer.ERROR_CLIENT -> "cancelled"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "permission_denied"
            SpeechRecognizer.ERROR_NETWORK, SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "network"
            SpeechRecognizer.ERROR_NO_MATCH, SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "no_match"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "busy"
            SpeechRecognizer.ERROR_SERVER, SpeechRecognizer.ERROR_SERVER_DISCONNECTED -> "server"
            else -> "recognition_failed"
        }

    private data class PendingSpeechStart(
        val sessionId: String,
        val locale: String,
        val result: MethodChannel.Result,
    )

    companion object {
        private const val SETTINGS_CHANNEL = "app.daylink.daylink_mobile/settings"
        private const val SPEECH_CHANNEL = "app.daylink.daylink_mobile/speech"
        private const val RECORD_AUDIO_REQUEST = 4117
        private const val MAX_TRANSCRIPT_LENGTH = 32768
        private val LOCALE_PATTERN = Regex("^[A-Za-z]{2,3}(?:[-_][A-Za-z]{2,4})?$")
    }
}
