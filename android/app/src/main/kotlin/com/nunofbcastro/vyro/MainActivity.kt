package com.nunofbcastro.vyro

import com.nunofbcastro.vyro.llm.OnDeviceLlmChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var llm: OnDeviceLlmChannel? = null
    private var video: LocalVideoChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        llm = OnDeviceLlmChannel(flutterEngine.dartExecutor.binaryMessenger)
        video = LocalVideoChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onDestroy() {
        llm?.dispose()
        llm = null
        video?.dispose()
        video = null
        super.onDestroy()
    }
}
