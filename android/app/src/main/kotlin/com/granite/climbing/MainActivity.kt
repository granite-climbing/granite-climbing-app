package com.granite.climbing

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NATIVE_SOCIAL_LOGIN_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "loginWithNaver" -> result.error(
                    "not_configured",
                    "Naver native login is not configured.",
                    null,
                )
                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val NATIVE_SOCIAL_LOGIN_CHANNEL =
            "com.granite.climbing/native_social_login"
    }
}
