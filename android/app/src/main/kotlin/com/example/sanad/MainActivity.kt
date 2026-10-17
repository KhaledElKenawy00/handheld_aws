package com.example.sanad

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.os.Build
import android.view.KeyEvent
import com.honeywell.aidc.AidcManager
import com.honeywell.aidc.BarcodeFailureEvent
import com.honeywell.aidc.BarcodeReadEvent
import com.honeywell.aidc.BarcodeReader
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Native scanner bridge. Only ONE driver talks to the scan head at a time:
 *
 * SUNMI (L2s Pro etc.) — handled entirely by the Flutter `sunmi_scanner`
 *   plugin, which binds the SUNMI scanner service via AIDL (scan()/stop())
 *   and listens to `com.sunmi.scanner.ACTION_DATA_CODE_RECEIVED`. This class
 *   does NOT read SUNMI decodes anymore, so a scan is never delivered twice.
 *
 * HONEYWELL — uses the official Data Collection SDK bundled as
 *   `app/libs/honeywell.aar` (`AidcManager`/`BarcodeReader`). It is attached
 *   lazily through the `initHoneywell` control call, which the Dart side only
 *   issues on genuine Honeywell hardware. On SUNMI units that carry a
 *   Honeywell scan engine, claiming the head through this SDK fought the SUNMI
 *   scanner service and produced partial/garbled reads — hence the split.
 *   `pause`/`resume` flip `PROPERTY_TRIGGER_CONTROL_MODE` and the notification
 *   (beep/vibrate) properties directly on the claimed reader. The Data
 *   Collection Intent API broadcast is kept as a fallback when `AidcManager`
 *   fails to connect. Requires manifest permission
 *   `com.honeywell.decode.permission.DECODE`.
 *
 * SHARED control (MethodChannel `com.sanad.scanner/control`):
 *   `initHoneywell`, `trigger`, `stop`, `pause`, `resume`. `pause`/`resume`
 *   also use the documented SUNMI `ACTION_TRIGGER_CONTROL` broadcast to
 *   disable/enable the physical trigger while a dialog is on screen.
 */
class MainActivity : FlutterActivity(),
    AidcManager.CreatedCallback,
    BarcodeReader.BarcodeListener {
    companion object {
        const val STREAM = "com.sanad.scanner/stream"
        const val CONTROL = "com.sanad.scanner/control"
        // Documented SUNMI scan-control action (L2 series / P series).
        // Sent as a broadcast; harmless on non-SUNMI devices.
        const val ACTION_STOP = "com.sunmi.scanner.ACTION_STOP_SCAN"
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
    // SUNMI: drop the scanner's keyboard-wedge keystrokes (see setSuppressWedge).
    private var suppressWedge = false
    // ── Honeywell SDK state ──
    private var aidcManager: AidcManager? = null
    private var barcodeReader: BarcodeReader? = null
    private var hwReady = false
    private var hwPaused = false

    /**
     * On SUNMI we consume the physical scanner's character keystrokes so the
     * keyboard-wedge output never reaches the focused Flutter field (the code
     * already arrives cleanly through the broadcast). Only printable
     * characters are dropped — navigation/volume/back keys pass through. The
     * on-screen keyboard is NOT affected: IMEs commit text, not key events.
     */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (suppressWedge && event.action == KeyEvent.ACTION_DOWN &&
            event.unicodeChar != 0
        ) {
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, STREAM)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                    events = sink
                    registerHoneywellFallbackReceiver()
                    // NOTE: we intentionally do NOT attach the Honeywell SDK
                    // here. On SUNMI L2s Pro units that ship a Honeywell scan
                    // engine, claiming the scanner through the Honeywell SDK
                    // fights the SUNMI scanner service over the same head and
                    // produces partial/garbled reads. The Dart side detects the
                    // device and calls `initHoneywell` only on real Honeywell
                    // hardware.
                }
                override fun onCancel(args: Any?) {
                    events = null
                    unregisterHoneywellFallbackReceiver()
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTROL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Attach the Honeywell SDK on demand. Called by Dart only
                    // on genuine Honeywell hardware (never on SUNMI), so the
                    // two scanner drivers never compete for the same head.
                    "initHoneywell" -> {
                        initHoneywellSdk()
                        result.success(true)
                    }
                    // SUNMI: swallow the keyboard-wedge output of the scanner so
                    // it can't be typed on top of the broadcast decode inside
                    // the focused field (which corrupts/shaves the code). The
                    // soft keyboard is unaffected (it commits text, not keys).
                    "setSuppressWedge" -> {
                        suppressWedge = call.argument<Boolean>("value") ?: false
                        result.success(true)
                    }
                    "trigger" -> {
                        // Honeywell: make sure we own the scanner, then scan.
                        // SUNMI software-trigger is handled by the Flutter
                        // `sunmi_scanner` plugin (AIDL scan()/stop()).
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

    /**
     * Honeywell Data Collection Intent API fallback only. SUNMI decodes are
     * NOT read here anymore — they arrive through the Flutter `sunmi_scanner`
     * plugin. Listening to the SUNMI broadcast actions here as well was
     * emitting the same scan twice (and the loose `extractCode` scan could
     * pick up a non-payload extra, which showed up as a partial barcode).
     */
    private fun registerHoneywellFallbackReceiver() {
        if (receiver != null) return
        receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent == null) return
                if (intent.action == HW_DATA_ACTION) {
                    val code = extractCode(intent)
                    if (!code.isNullOrEmpty()) {
                        try { events?.success(code) } catch (_: Exception) {}
                    }
                }
            }
        }
        val filter = IntentFilter().apply {
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

    private fun unregisterHoneywellFallbackReceiver() {
        try { receiver?.let { unregisterReceiver(it) } } catch (_: Exception) {}
        receiver = null
    }

    override fun onDestroy() {
        unregisterHoneywellFallbackReceiver()
        try { barcodeReader?.release() } catch (_: Exception) {}
        try { aidcManager?.close() } catch (_: Exception) {}
        barcodeReader = null
        aidcManager = null
        hwReady = false
        super.onDestroy()
    }
}
