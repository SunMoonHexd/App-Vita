package com.example.vita_app

import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.widget.Toast
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vita/call_notice")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "show" -> {
                        val message = call.argument<String>("message") ?: ""
                        val vibrate = call.argument<Boolean>("vibrate") ?: true
                        showNotice(message, vibrate)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun showNotice(message: String, vibrate: Boolean) {
        Toast.makeText(applicationContext, message, Toast.LENGTH_LONG).show()
        if (!vibrate) return
        try {
            val vibrator = getSystemService(VIBRATOR_SERVICE) as Vibrator
            val pattern = longArrayOf(0, 350, 200, 350)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(pattern, -1)
            }
        } catch (e: Exception) {
            // Si el celular no puede vibrar, el mensaje igual se muestra.
        }
    }
}
