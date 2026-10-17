package com.example.sanad

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.os.Build
import com.honeywell.aidc.AidcManager
import com.honeywell.aidc.BarcodeFailureEvent
import com.honeywell.aidc.BarcodeReadEvent
import com.honeywell.aidc.BarcodeReader
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
 * HONEYWELL: uses the official Data Collection SDK bundled as
 *   `app/libs/honeywell.aar` (`AidcManager`/`BarcodeReader`). On listen the
 *   app creates a `BarcodeReader`, claims the internal scanner and forwards
 *   `onBarcodeEvent` decodes to Flutter. `pause`/`resume` flip
 *   `PROPERTY_TRIGGER_CONTROL_MODE` and the notification (beep/vibrate)
 *   properties directly on the claimed reader — the only reliable way to
 *   silence the beep on EDA57 firmware. The Data Collection Intent API
 *   broadcasts are kept as a fallback for devices where `AidcManager`
 *   fails to connect. Requires manifest permission
 *   `com.honeywell.decode.permission.DECODE`.
 */
class MainActivity : FlutterActivity(),
    AidcManager.CreatedCallback,
    BarcodeReader.BarcodeListener {
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
        // Official SUNMI broadcast to enable/disable the PHYSICAL trigger
        // button at the firmware level (Boolean extra `enable`). Disabling it
        // is the only reliable way to stop the hardware scanning (and its
        // beep) while a message/dialog is on screen.
        const val ACTION_TRIGGER_CONTROL = "com.sunmi.scanner.ACTION_TRIGGER_CONTROL"

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
    // ── Honeywell SDK state ──
    private var aidcManager: AidcManager? = null
    private var barcodeReader: BarcodeReader? = null
    private var hwReady = false
    private var hwPaused = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, STREAM)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                    events = sink
                    registerSunmiReceiver()
                    // On Honeywell devices this attaches the SDK to the
                    // DataCollection service so the physical scan button
                    // delivers decodes straight to onBarcodeEvent().
                    initHoneywellSdk()
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
                        // Honeywell: make sure we own the scanner, then scan.
                        if (!hwReady) initHoneywellSdk()
                        setHoneywellMuted(false)
                        try { barcodeReader?.softwareTrigger(true) } catch (_: Exception) {}
                        result.success(true)
                    }
                    "stop" -> {
                        sendScanBroadcast(ACTION_STOP)
                        try { barcodeReader?.softwareTrigger(false) } catch (_: Exception) {}
                        result.success(true)
                    }
                    "pause" -> {
                        // Mute the scanner (no beep) + disable its physical
                        // trigger while a message is on screen; hardware
                        // vibrates instead so the user still feels feedback.
                        setTriggerEnabled(false)
                        sendScanBroadcast(ACTION_STOP)
                        setHoneywellMuted(true)
                        setDeviceMute(true)
                        result.success(true)
                    }
                    "resume" -> {
                        setTriggerEnabled(true)
                        setHoneywellMuted(false)
                        setDeviceMute(false)
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
     * SUNMI: enable/disable the physical trigger button via the official
     * `ACTION_TRIGGER_CONTROL` broadcast (Boolean extra `enable`). This is
     * what actually stops the scanner hardware (and its beep) — a plain
     * ACTION_STOP_SCAN only ends the current decode.
     */
    private fun setTriggerEnabled(enabled: Boolean) {
        try {
            sendBroadcast(Intent(ACTION_TRIGGER_CONTROL).apply {
                putExtra("enable", enabled)
            })
        } catch (_: Exception) {}
    }

    /**
     * Honeywell: attach to the Data Collection service through the official
     * SDK. The callback [onCreated] gives us an [AidcManager] we use to create
     * and claim a [BarcodeReader]. Everything decodes to [onBarcodeEvent].
     * Safe to call repeatedly — it no-ops once attached.
     */
    private fun initHoneywellSdk() {
        if (hwReady || aidcManager != null) return
        try {
            AidcManager.create(this, this)
        } catch (_: Exception) {
            // SDK unavailable (non-Honeywell device): fall back to the
            // Data Collection Intent API broadcasts.
            claimHoneywellFallback(hwPaused)
        }
    }

    override fun onCreated(mgr: AidcManager) {
        aidcManager = mgr
        try {
            val reader = mgr.createBarcodeReader()
            barcodeReader = reader
            reader.addBarcodeListener(this)
            applyHoneywellProps(reader, hwPaused)
            reader.claim()
            hwReady = true
        } catch (_: Exception) {
            // Claim failed — fall back to the Intent API path.
            claimHoneywellFallback(hwPaused)
        }
    }

    /**
     * Push the trigger + notification (beep/vibrate) settings straight onto
     * the claimed [BarcodeReader]. [muted] = true is used while a message/alert
     * is on screen: it disables the physical trigger, silences the good/bad
     * read beeps and turns on the hardware vibrator so pressing the trigger
     * gives haptic feedback instead of a beep. All property names are
     * com.honeywell.aidc.BarcodeReader constants.
     */
    private fun applyHoneywellProps(reader: BarcodeReader, muted: Boolean) {
        try {
            reader.setProperty(
                BarcodeReader.PROPERTY_TRIGGER_CONTROL_MODE,
                if (muted) BarcodeReader.TRIGGER_CONTROL_MODE_DISABLE
                else BarcodeReader.TRIGGER_CONTROL_MODE_AUTO_CONTROL,
            )
        } catch (_: Exception) {}
        try {
            reader.setProperty(BarcodeReader.PROPERTY_NOTIFICATION_GOOD_READ_ENABLED, !muted)
        } catch (_: Exception) {}
        try {
            reader.setProperty(BarcodeReader.PROPERTY_NOTIFICATION_BAD_READ_ENABLED, !muted)
        } catch (_: Exception) {}
        try {
            reader.setProperty(BarcodeReader.PROPERTY_NOTIFICATION_VIBRATE_ENABLED, muted)
        } catch (_: Exception) {}
    }

    /** Honeywell: mute/unmute via the SDK; fall back to the Intent API. */
    private fun setHoneywellMuted(muted: Boolean) {
        hwPaused = muted
        val reader = barcodeReader
        if (reader != null) {
            applyHoneywellProps(reader, muted)
            if (muted) {
                try { reader.softwareTrigger(false) } catch (_: Exception) {}
            }
        } else {
            claimHoneywellFallback(muted)
        }
    }

    override fun onBarcodeEvent(event: BarcodeReadEvent) {
        val code = event.barcodeData
        if (!code.isNullOrEmpty()) {
            runOnUiThread { try { events?.success(code) } catch (_: Exception) {} }
        }
    }

    override fun onFailureEvent(event: BarcodeFailureEvent) {
        // Nothing to forward — the Flutter side only consumes decoded strings.
    }

    /**
     * Fallback (Data Collection Intent API, no SDK): claim the internal
     * scanner and ask the DataCollection service to deliver decodes to
     * [HW_DATA_ACTION]. Used only when the SDK cannot attach. [muted] mirrors
     * [applyHoneywellProps]. The intent is sent BOTH explicitly (setPackage →
     * DataCollection service) and implicitly (bare action). Harmless on
     * non-Honeywell devices.
     */
    private fun claimHoneywellFallback(muted: Boolean = false) {
        val triggerMode = if (muted) "disable" else "enable"
        try {
            val trigProps = android.os.Bundle().apply {
                putString("TRIG_CONTROL_MODE", triggerMode)
            }
            sendBroadcast(Intent(HW_CLAIM).putExtra(HW_EXTRA_PROPS, trigProps))
        } catch (_: Exception) {}
        val props = android.os.Bundle().apply {
            putBoolean("DPR_DATA_INTENT", true)
            putString("DPR_DATA_INTENT_ACTION", HW_DATA_ACTION)
            putString("TRIG_CONTROL_MODE", triggerMode)
            putBoolean("NTF_GOOD_READ_ENABLED", !muted)
            putBoolean("NTF_BAD_READ_ENABLED", !muted)
            putBoolean("NTF_VIBRATE_ENABLED", muted)
        }
        for (pkg in arrayOf<String?>(HW_PKG, null)) {
            try {
                sendBroadcast(Intent(HW_CLAIM).apply {
                    pkg?.let { setPackage(it) }
                    putExtra(HW_EXTRA_SCANNER, "dcs.scanner.imager")
                    putExtra(HW_EXTRA_PROFILE, "DEFAULT")
                    putExtra(HW_EXTRA_PROPS, props)
                })
            } catch (_: Exception) {}
        }
        // Start/stop scanning through the same Intent API.
        for (pkg in arrayOf<String?>(HW_PKG, null)) {
            try {
                sendBroadcast(Intent(HW_CONTROL).apply {
                    pkg?.let { setPackage(it) }
                    putExtra(HW_EXTRA_SCAN, !muted)
                })
            } catch (_: Exception) {}
        }
    }

    /**
     * Last-resort mute of the device audio streams while a message is shown.
     * On some Honeywell firmwares the scanner beep is routed through the
     * Android notification/system streams, so muting them silences it even
     * when the scanner profile properties are ignored. ADJUST_UNMUTE restores
     * the previous volume, so nothing is permanently changed.
     */
    private fun setDeviceMute(muted: Boolean) {
        try {
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val dir = if (muted) AudioManager.ADJUST_MUTE else AudioManager.ADJUST_UNMUTE
            for (stream in intArrayOf(
                AudioManager.STREAM_SYSTEM,
                AudioManager.STREAM_NOTIFICATION,
                AudioManager.STREAM_MUSIC,
            )) {
                try { am.adjustStreamVolume(stream, dir, 0) } catch (_: Exception) {}
            }
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
        try { barcodeReader?.release() } catch (_: Exception) {}
        try { aidcManager?.close() } catch (_: Exception) {}
        barcodeReader = null
        aidcManager = null
        hwReady = false
        super.onDestroy()
    }
}
