package dev.eduardom.chromapulse

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val multicastLock by lazy {
        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        wifi.createMulticastLock("chromapulse-sacn").apply { setReferenceCounted(false) }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.eduardom.chromapulse/multicast")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquire" -> multicastLock.acquire()
                    "release" -> if (multicastLock.isHeld) multicastLock.release()
                    else -> return@setMethodCallHandler result.notImplemented()
                }
                result.success(null)
            }
    }

    override fun onDestroy() {
        if (multicastLock.isHeld) multicastLock.release()
        super.onDestroy()
    }
}
