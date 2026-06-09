package com.gao.chatbox.flutter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "com.gao.chatbox/debug_log_view"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                "com.gao.chatbox/debug_log_list",
                DebugLogViewFactory(channel),
            )
    }
}
