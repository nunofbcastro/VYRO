package com.example.vyro

import com.example.vyro.llm.OnDeviceLlmChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var llm: OnDeviceLlmChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        llm = OnDeviceLlmChannel(flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onDestroy() {
        llm?.dispose()
        llm = null
        super.onDestroy()
    }
}
