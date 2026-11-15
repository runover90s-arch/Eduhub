package vn.eduhub.eduhub

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Only lifecycle observations for consented exams. It does not inspect other
 * applications, read their content, record audio or request accessibility.
 * The Flutter layer queues incidents to the authenticated scoring backend.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "eduhub/g2"
    private var active = false
    private var isReceiverRegistered = false
    private var lastSignalMs = 0L
    private val pending = mutableListOf<String>()
    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == Intent.ACTION_SCREEN_OFF) record("screen_off")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val filter = IntentFilter(Intent.ACTION_SCREEN_OFF)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(screenReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(screenReceiver, filter)
        }
        isReceiverRegistered = true
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "activate" -> {
                        active = (call.argument<Boolean>("active") == true)
                        if (active) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(null)
                    }
                    "drain" -> {
                        val events = pending.toList()
                        pending.clear()
                        result.success(events)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun record(kind: String) {
        if (!active) return
        val now = SystemClock.elapsedRealtime()
        // Screen off and Activity stop usually refer to one interruption.
        if (now - lastSignalMs < 1800) return
        lastSignalMs = now
        pending.add(kind)
    }

    override fun onStop() {
        if (!isChangingConfigurations) record("app_background")
        super.onStop()
    }

    override fun onMultiWindowModeChanged(isInMultiWindowMode: Boolean) {
        super.onMultiWindowModeChanged(isInMultiWindowMode)
        if (isInMultiWindowMode) record("multi_window")
    }

    override fun onDestroy() {
        active = false
        if (isReceiverRegistered) {
            try { unregisterReceiver(screenReceiver) } catch (_: IllegalArgumentException) { }
            isReceiverRegistered = false
        }
        super.onDestroy()
    }
}
