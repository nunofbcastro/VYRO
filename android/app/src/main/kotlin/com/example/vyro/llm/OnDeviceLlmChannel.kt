package com.example.vyro.llm

import com.google.mlkit.genai.common.DownloadStatus
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.prompt.GenerativeModel
import com.google.mlkit.genai.prompt.Generation
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Bridges Gemini Nano (Android AICore, via ML Kit GenAI Prompt API) to Dart.
 *
 * Everything runs on-device: no API key, no network inference. On devices
 * without AICore support `status` returns "unavailable" and the Dart side
 * shows a fallback. Channel: `vyro/on_device_llm`.
 */
class OnDeviceLlmChannel(messenger: BinaryMessenger) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val channel = MethodChannel(messenger, "vyro/on_device_llm")
    private var model: GenerativeModel? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> scope.launch {
                    result.success(runCatching { status() }.getOrDefault("unavailable"))
                }
                "download" -> download(result)
                "generate" -> {
                    val prompt = call.argument<String>("prompt")
                    if (prompt.isNullOrBlank()) {
                        result.error("bad_args", "Missing prompt", null)
                    } else {
                        generate(prompt, result)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun client(): GenerativeModel = model ?: Generation.getClient().also { model = it }

    private suspend fun status(): String = when (client().checkStatus()) {
        FeatureStatus.AVAILABLE -> "available"
        FeatureStatus.DOWNLOADABLE -> "downloadable"
        FeatureStatus.DOWNLOADING -> "downloading"
        else -> "unavailable"
    }

    private fun download(result: MethodChannel.Result) {
        scope.launch {
            var replied = false
            try {
                client().download().collect { status ->
                    when (status) {
                        is DownloadStatus.DownloadCompleted -> if (!replied) {
                            replied = true
                            result.success("available")
                        }
                        is DownloadStatus.DownloadFailed -> if (!replied) {
                            replied = true
                            result.error("download_failed", status.e.message, null)
                        }
                        else -> Unit
                    }
                }
                if (!replied) result.success(status())
            } catch (e: Exception) {
                if (!replied) result.error("download_failed", e.message, null)
            }
        }
    }

    private fun generate(prompt: String, result: MethodChannel.Result) {
        scope.launch {
            try {
                val response = client().generateContent(prompt)
                val text = response.candidates.joinToString("") { it.text.orEmpty() }
                result.success(text)
            } catch (e: Exception) {
                result.error("generation_failed", e.message, null)
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        model?.close()
        model = null
        scope.cancel()
    }
}
