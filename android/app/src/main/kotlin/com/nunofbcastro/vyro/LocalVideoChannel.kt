package com.nunofbcastro.vyro

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.roundToInt

/** Local files only. One decoder and one bounded JPEG at a time; no media saved. */
class LocalVideoChannel(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "vyro/local_video")
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var decoder: MediaMetadataRetriever? = null
    private var session = 0
    private var durationMs = 0L

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method !in listOf("open", "frame", "close")) {
                result.notImplemented()
            } else executor.execute {
                try {
                    val response: Any? = when (call.method) {
                        "open" -> {
                            val path = call.argument<String>("path") ?: error("Missing path")
                            val file = File(path).canonicalFile
                            val roots = listOf(context.cacheDir, context.filesDir).map { it.canonicalPath + File.separator }
                            require(file.isFile && roots.any { file.path.startsWith(it) }) { "Expected an app-owned local media copy" }
                            decoder?.release()
                            decoder = null
                            val opened = MediaMetadataRetriever()
                            try { opened.setDataSource(file.path) } catch (e: Exception) { opened.release(); throw e }
                            durationMs = opened.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0
                            if (durationMs <= 0) { opened.release(); error("Invalid duration") }
                            decoder = opened
                            session += 1
                            mapOf("id" to session, "durationMs" to durationMs)
                        }
                        "frame" -> {
                            require(call.argument<Int>("id") == session) { "Closed session" }
                            val position = (call.argument<Number>("timeMs")?.toLong() ?: 0).coerceIn(0, durationMs - 1)
                            val retriever = decoder ?: error("No video")
                            val frame = if (Build.VERSION.SDK_INT >= 27) {
                                retriever.getScaledFrameAtTime(position * 1000, MediaMetadataRetriever.OPTION_CLOSEST, 640, 640)
                            } else retriever.getFrameAtTime(position * 1000, MediaMetadataRetriever.OPTION_CLOSEST)
                            val original = frame ?: error("No frame at this time")
                            val ratio = 640.0 / maxOf(original.width, original.height)
                            val bitmap = if (ratio < 1) Bitmap.createScaledBitmap(original, (original.width * ratio).roundToInt().coerceAtLeast(2), (original.height * ratio).roundToInt().coerceAtLeast(2), true) else original
                            val output = ByteArrayOutputStream()
                            bitmap.compress(Bitmap.CompressFormat.JPEG, 85, output)
                            val bytes = output.toByteArray()
                            if (bitmap !== original) bitmap.recycle()
                            original.recycle()
                            // Retriever exposes the requested position, not a frame presentation timestamp.
                            mapOf("jpeg" to bytes, "timeMs" to position, "approximate" to true)
                        }
                        else -> {
                            if (call.argument<Int>("id") == session) { decoder?.release(); decoder = null; session += 1 }
                            null
                        }
                    }
                    main.post { result.success(response) }
                } catch (e: Exception) { main.post { result.error("video_failed", e.message, null) } }
            }
        }
    }
    fun dispose() {
        channel.setMethodCallHandler(null)
        executor.execute { decoder?.release(); decoder = null }
        executor.shutdown()
    }
}
