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
 * RECEIVE (official SUNMI broadcast + fallbacks for L2s Pro firmware variants):
 *   primary: `com.sunmi.scanner.ACTION_DATA_CODE_RECEIVED`, String extra `data`
 *   (Broadcast Output mode). Forwarded to Flutter via EventChannel
 *   `com.sanad.scanner/stream`. In KeyEvent/keyboard-wedge mode the physical
 *   scan key types directly into the focused TextField — no code needed.
 *   Fallbacks handled here: `android.intent.ACTION_DECODE_DATA`,
 *   `com.sunmi.scanner.ACTION_SCAN_RESULT`, `com.sunmi.scanner.ACTION_DECODE`,
 *   `com.sunmi.scan.ACTION_DATA_RECEIVED`, extras `barcode`/`code`/
 *   `scan_result`/`value`/`source` + exhaustive scan of ANY String/byte[]
 *   extra in the bundle (undocumented firmware keys).
 *
 * TRIGGER (software scan from inside the app):
 *   MethodChannel `com.sanad.scanner/control` methods `trigger` / `stop`
 *   are translated here into the documented SUNMI scan-control broadcasts so
 *   the built-in 1D/2D head starts scanning without opening any camera.
 *
 * HONEYWELL (no SDK): on listen the app claims the internal scanner via
 *   `com.honeywell.aidc.action.ACTION_CLAIM_SCANNER` (package
 *   `com.intermec.datacollectionservice`) with DPR_DATA_INTENT pointed at
 *   `com.sanad.scanner.HONEYWELL_DATA`, which this receiver forwards to
 *   Flutter. `trigger`/`stop` also send
 *   `com.honeywell.aidc.action.ACTION_CONTROL_SCANNER` (EXTRA_SCAN).
 *   Requires manifest permission `com.honeywell.decode.permission.DECODE`.
 */
class MainActivity : FlutterActivity() {
    companion object {
        const val STREAM = "com.sanad.scanner/stream"
        const val CONTROL = "com.sanad.scanner/control"
        const val ACTION_DATA = "com.sunmi.scanner.ACTION_DATA_CODE_RECEIVED"
        const val ACTION_DECODE = "android.intent.ACTION_DECODE_DATA"
        const val ACTION_SCAN_RESULT = "com.sunmi.scanner.ACTION_SCAN_RESULT"
        // Variants seen on other SUNMI firmwares — harmless to listen.
        const val ACTION_DECODE2 = "com.sunmi.scanner.ACTION_DECODE"
        const val ACTION_SCAN_DATA = "com.sunmi.scan.ACTION_DATA_RECEIVED"
        // Documented SUNMI scan-control actions (L2 series / P series).
        // Sent as broadcasts; harmless on non-SUNMI devices.
        const val ACTION_START = "com.sunmi.scanner.ACTION_START_SCAN"
        const val ACTION_STOP = "com.sunmi.scanner.ACTION_STOP_SCAN"
        const val ACTION_TRIG = "com.sunmi.scanner.ACTION_TRIG_SCAN"
        const val ACTION_ENABLE = "com.sunmi.scanner.ACTION_ENABLE_SCAN"

        // ── Honeywell (Data Collection Intent API, no SDK needed) ──
        // Our private data-intent action: the app claims the scanner and
        // asks the DataCollection service to deliver decodes to it.
        const val HW_DATA_ACTION = "com.sanad.scanner.HONEYWELL_DATA"
        const val HW_PKG = "com.intermec.datacollectionservice"
        const val HW_CLAIM = "com.honeywell.aidc.action.ACTION_CLAIM_SCANNER"
        const val HW_CONTROL = "com.honeywell.aidc.action.ACTION_CONTROL_SCANNER"
        const val HW_EXTRA_SCANNER = "com.honeywell.aidc.extra.EXTRA_SCANNER"
        const val HW_EXTRA_PROFILE = "com.honeywell.aidc.extra.EXTRA_PROFILE"
        const val HW_EXTRA_PROPS = "com.honeywell.aidc.extra.EXTRA_PROPERTIES"
        const val HW_EXTRA_SCAN = "com.honeywell.aidc.extra.EXTRA_SCAN"
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
                    // On Honeywell devices this makes the DataCollection
                    // service deliver every decode to HW_DATA_ACTION below,
                    // so the physical scan button works with zero settings.
                    claimHoneywell()
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
                        // L2s Pro needs ENABLE + START + TRIG on some firmwares.
                        sendScanBroadcast(ACTION_ENABLE)
                        sendScanBroadcast(ACTION_START)
                        sendScanBroadcast(ACTION_TRIG)
                        // Honeywell: (re)claim then start scanning.
                        claimHoneywell()
                        honeywellScan(true)
                        result.success(true)
                    }
                    "stop" -> {
                        sendScanBroadcast(ACTION_STOP)
                        honeywellScan(false)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun sendScanBroadcast(action: String) {
        try { sendBroadcast(Intent(action)) } catch (_: Exception) {}
    }

    /**
     * Honeywell: claim the internal scanner on the DEFAULT profile and ask
     * the DataCollection service to deliver decodes to [HW_DATA_ACTION].
     * setPackage() targets the Honeywell service, so this is a harmless
     * no-op on non-Honeywell devices. Only data-intent properties are
     * overridden — wedge/keyboard output settings are left untouched.
     */
    private fun claimHoneywell() {
        try {
            val props = android.os.Bundle().apply {
                putBoolean("DPR_DATA_INTENT", true)
                putString("DPR_DATA_INTENT_ACTION", HW_DATA_ACTION)
            }
            sendBroadcast(Intent(HW_CLAIM).apply {
                setPackage(HW_PKG)
                putExtra(HW_EXTRA_SCANNER, "dcs.scanner.imager")
                putExtra(HW_EXTRA_PROFILE, "DEFAULT")
                putExtra(HW_EXTRA_PROPS, props)
            })
        } catch (_: Exception) {}
    }

    /** Honeywell: start/stop the scanner programmatically. */
    private fun honeywellScan(enable: Boolean) {
        try {
            sendBroadcast(Intent(HW_CONTROL).apply {
                setPackage(HW_PKG)
                putExtra(HW_EXTRA_SCAN, enable)
            })
        } catch (_: Exception) {}
    }

    private fun extractCode(intent: Intent): String? {
        // 1) String extras — cover all known L2s Pro keys.
        val keys = arrayOf(
            "data", "barcode", "code", "scan_result", "value",
            "source", "data_code", "barcode_data", "scanData",
            "decode_data", "barcode_string", "result", "content"
        )
        for (k in keys) {
            try {
                val s = intent.getStringExtra(k)
                if (!s.isNullOrEmpty()) return s
            } catch (_: Exception) {}
        }
        // 2) Exhaustive fallback: ANY non-empty String extra in the bundle
        // (covers firmware variants with undocumented key names).
        // Skips obvious non-payload keys to avoid noise.
        try {
            val ex = intent.extras
            if (ex != null) {
                for (k in ex.keySet()) {
                    if (k.equals("length", true) ||
                        k.equals("type", true) ||
                        k.equals("symbology", true) ||
                        k.equals("action", true)) continue
                    try {
                        val o = ex.get(k)
                        if (o is String && o.trim().isNotEmpty()) return o
                    } catch (_: Exception) {}
                }
            }
        } catch (_: Exception) {}
        // 3) byte[] extras (some firmwares send source_byte / data_byte).
        // Known keys first, then any byte[] in the bundle.
        val byteKeys = arrayOf("source_byte", "data_byte", "barcode_bytes", "data")
        for (k in byteKeys) {
            try {
                val b = intent.getByteArrayExtra(k)
                if (b != null && b.isNotEmpty()) {
                    val s = try { String(b, Charsets.UTF_8).trim() } catch (_: Exception) { "" }
                    if (s.isNotEmpty()) return s
                }
            } catch (_: Exception) {}
        }
        try {
            val ex = intent.extras
            if (ex != null) {
                for (k in ex.keySet()) {
                    try {
                        val o = ex.get(k)
                        if (o is ByteArray && o.isNotEmpty()) {
                            val s = try { String(o, Charsets.UTF_8).trim() } catch (_: Exception) { "" }
                            if (s.isNotEmpty()) return s
                        }
                    } catch (_: Exception) {}
                }
            }
        } catch (_: Exception) {}
        // 4) Serializable fallback.
        try {
            val se = intent.getSerializableExtra("data")
            if (se != null) {
                val s = se.toString().trim()
                if (s.isNotEmpty()) return s
            }
        } catch (_: Exception) {}
        return null
    }

    private fun registerSunmiReceiver() {
        if (receiver != null) return
        receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent == null) return
                when (intent.action) {
                    ACTION_DATA, ACTION_DECODE, ACTION_SCAN_RESULT,
                    ACTION_DECODE2, ACTION_SCAN_DATA, HW_DATA_ACTION -> {
                        val code = extractCode(intent)
                        if (!code.isNullOrEmpty()) {
                            try { events?.success(code) } catch (_: Exception) {}
                        }
                    }
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(ACTION_DATA)
            addAction(ACTION_DECODE)
            addAction(ACTION_SCAN_RESULT)
            addAction(ACTION_DECODE2)
            addAction(ACTION_SCAN_DATA)
            addAction(HW_DATA_ACTION)
        }
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
