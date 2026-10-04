package com.example.sanad

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * SUNMI L2s Pro scanner bridge — no third-party SDK needed.
 *
 * RECEIVE (official SUNMI broadcast):
 *   action `com.sunmi.scanner.ACTION_DATA_CODE_RECEIVED`, String extra `data`
 *   (Broadcast Output mode). Forwarded to Flutter via EventChannel
 *   `com.sanad.scanner/stream`. In KeyEvent/keyboard-wedge mode the physical
 *   scan key types directly into the focused TextField — no code needed.
 *
 * TRIGGER (software scan from inside the app):
 *   MethodChannel `com.sanad.scanner/control` methods `trigger` / `stop`
 *   are translated here into the documented SUNMI scan-control broadcasts so
 *   the built-in 1D/2D head starts scanning without opening any camera.
 */
class MainActivity : FlutterActivity() {
    companion object {
        const val STREAM = "com.sanad.scanner/stream"
        const val CONTROL = "com.sanad.scanner/control"
        const val ACTION_DATA = "com.sunmi.scanner.ACTION_DATA_CODE_RECEIVED"
        const val EXTRA_DATA = "data"
        // Documented SUNMI scan-control actions (L2 series / P series).
        // Sent as broadcasts; harmless on non-SUNMI devices.
        const val ACTION_START = "com.sunmi.scanner.ACTION_START_SCAN"
        const val ACTION_STOP = "com.sunmi.scanner.ACTION_STOP_SCAN"
        const val ACTION_TRIG = "com.sunmi.scanner.ACTION_TRIG_SCAN"
    }

    private var events: EventChannel.EventSink? = null
    private var receiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, STREAM)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                    events = sink
                    registerSunmiReceiver()
                }
                override fun onCancel(args: Any?) {
                    events = null
                    unregisterSunmiReceiver()
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTROL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "trigger" -> {
                        sendScanBroadcast(ACTION_START)
                        sendScanBroadcast(ACTION_TRIG)
                        result.success(true)
                    }
                    "stop" -> {
                        sendScanBroadcast(ACTION_STOP)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun sendScanBroadcast(action: String) {
        try { sendBroadcast(Intent(action)) } catch (_: Exception) {}
    }

    private fun registerSunmiReceiver() {
        if (receiver != null) return
        receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == ACTION_DATA) {
                    val code = intent.getStringExtra(EXTRA_DATA)
                        ?: intent.getStringExtra("source")
                        ?: intent.getStringExtra("data_code")
                    if (!code.isNullOrEmpty()) {
                        try { events?.success(code) } catch (_: Exception) {}
                    }
                }
            }
        }
        val filter = IntentFilter(ACTION_DATA)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                @Suppress("DEPRECATION")
                registerReceiver(receiver, filter)
            }
        } catch (_: Exception) {}
    }

    private fun unregisterSunmiReceiver() {
        try { receiver?.let { unregisterReceiver(it) } } catch (_: Exception) {}
        receiver = null
    }

    override fun onDestroy() {
        unregisterSunmiReceiver()
        super.onDestroy()
    }
}
