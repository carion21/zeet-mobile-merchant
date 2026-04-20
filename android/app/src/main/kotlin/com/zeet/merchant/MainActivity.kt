package com.zeet.merchant

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val INCOMING_RING_CHANNEL = "zeet/incoming_ring"
        private const val APP_LAUNCHER_CHANNEL = "zeet/app_launcher"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // MethodChannel pour piloter IncomingRingService depuis Flutter
        // (arret du ring quand le partner accepte / refuse / quitte l'ecran).
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            INCOMING_RING_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "stop" -> {
                    val intent = Intent(this, IncomingRingService::class.java)
                        .setAction(IncomingRingService.ACTION_STOP)
                    startService(intent)
                    result.success(true)
                }
                "start" -> {
                    // Dev trigger : simule un FCM sans passer par le backend.
                    val title = call.argument<String>("title") ?: "Nouvelle commande"
                    val body = call.argument<String>("body") ?: ""
                    val intent = Intent(this, IncomingRingService::class.java).apply {
                        putExtra(IncomingRingService.EXTRA_TITLE, title)
                        putExtra(IncomingRingService.EXTRA_BODY, body)
                    }
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // MethodChannel pour ramener l'app au premier plan depuis un tap
        // sur la bulle flottante (overlay). Appele depuis le main isolate
        // quand il recoit {"action": "open_app"} via overlayListener.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_LAUNCHER_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "bringToFront" -> {
                    val launch = packageManager.getLaunchIntentForPackage(packageName)
                    if (launch != null) {
                        launch.addFlags(
                            Intent.FLAG_ACTIVITY_NEW_TASK
                                or Intent.FLAG_ACTIVITY_SINGLE_TOP
                                or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT,
                        )
                        startActivity(launch)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
