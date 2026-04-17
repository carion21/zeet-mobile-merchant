package com.zeet.merchant

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ProcessLifecycleOwner
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

/**
 * ZeetFirebaseMessagingService — intercepte les messages FCM AVANT que le plugin
 * Flutter ne les traite. Pour les events critiques `order.created`, demarre
 * immediatement [IncomingRingService] (native, plein ecran, sonnerie en boucle)
 * puis delegue au plugin Flutter pour la suite du flow normal.
 *
 * Doit etre declare dans le manifest avec intent-filter MESSAGING_EVENT. Android
 * selectionne ce service prioritairement car il est declare dans l'app meme.
 */
class ZeetFirebaseMessagingService : FlutterFirebaseMessagingService() {

    companion object {
        private const val TAG = "ZeetMessagingService"
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        val type = data["type"] ?: ""
        Log.d(TAG, "onMessageReceived type=$type")

        if (type == "order.created" || type == "new_order") {
            // Si l'app est deja en foreground, on laisse le flow Flutter
            // gerer (IncomingOrderDispatcher.handleRaw affiche l'ecran + ring
            // Flutter). On evite ainsi un double ring natif + Flutter.
            if (!isAppInForeground()) {
                startRingService(data, message)
            } else {
                Log.d(TAG, "app in foreground, skipping native ring")
            }
        }

        // Delegue toujours au plugin Flutter pour que onMessage /
        // onMessageOpenedApp / background handler Dart puissent faire leur job.
        super.onMessageReceived(message)
    }

    private fun startRingService(
        data: Map<String, String>,
        message: RemoteMessage,
    ) {
        val title = data["title"] ?: message.notification?.title ?: "Nouvelle commande"
        val body = data["body"] ?: message.notification?.body ?: "Appuyez pour voir les details"
        val orderId = data["entity_id"] ?: data["order_id"] ?: ""

        val intent = Intent(this, IncomingRingService::class.java).apply {
            putExtra(IncomingRingService.EXTRA_ORDER_ID, orderId)
            putExtra(IncomingRingService.EXTRA_TITLE, title)
            putExtra(IncomingRingService.EXTRA_BODY, body)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "startForegroundService failed: $e")
        }
    }

    private fun isAppInForeground(): Boolean {
        return try {
            ProcessLifecycleOwner.get()
                .lifecycle
                .currentState
                .isAtLeast(Lifecycle.State.STARTED)
        } catch (e: Exception) {
            false
        }
    }
}
