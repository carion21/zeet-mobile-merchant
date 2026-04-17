package com.zeet.merchant

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * IncomingRingService — Service Android en premier plan qui joue une sonnerie
 * en boucle pour une nouvelle commande partner et affiche une notification
 * full-screen intent pour reveiller l'ecran meme quand l'app est killed.
 *
 * Lancement :
 *   Intent(ctx, IncomingRingService::class.java).apply {
 *     putExtra(EXTRA_ORDER_ID, orderId)
 *     putExtra(EXTRA_TITLE, "Nouvelle commande ZT-...")
 *     putExtra(EXTRA_BODY, "Total 12 500 FCFA — 3 articles")
 *   }.also { ctx.startForegroundService(it) }
 *
 * Arret (depuis Flutter via MethodChannel) :
 *   ctx.startService(Intent(ctx, IncomingRingService::class.java)
 *     .setAction(ACTION_STOP))
 *
 * Sonnerie :
 *   - Cherche `res/raw/zeet_incoming` par nom (supporte .mp3, .ogg)
 *   - Fallback : alarme systeme Android (RingtoneManager.TYPE_ALARM)
 */
class IncomingRingService : Service() {

    companion object {
        private const val TAG = "IncomingRingService"

        const val ACTION_STOP = "com.zeet.merchant.ACTION_STOP_RING"
        const val EXTRA_ORDER_ID = "order_id"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"

        const val CHANNEL_ID = "zeet_partner_incoming_ring"
        const val CHANNEL_NAME = "Nouvelles commandes (sonnerie)"
        const val CHANNEL_DESC =
            "Sonnerie forte et permanente pour les nouvelles commandes entrantes."

        const val NOTIFICATION_ID = 1010
    }

    private var mediaPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            Log.d(TAG, "stop action received")
            stopSelfAndCleanup()
            return START_NOT_STICKY
        }

        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Nouvelle commande"
        val body = intent?.getStringExtra(EXTRA_BODY) ?: "Appuyez pour voir les details"

        Log.d(TAG, "starting ring: $title")

        // 1. Wake lock partiel pour garder le CPU allume
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "$TAG::ring",
            ).apply {
                setReferenceCounted(false)
                acquire(3 * 60 * 1000L) // 3 min max
            }
        } catch (e: Exception) {
            Log.w(TAG, "wake lock failed: $e")
        }

        // 2. Demarre le service en premier plan avec notification FSI
        val notif = buildNotification(title, body)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // Android 14+ : shortService autorise jusqu'a 3 min.
            startForeground(
                NOTIFICATION_ID,
                notif,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SHORT_SERVICE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notif)
        }

        // 3. Lance le MediaPlayer en loop
        playRing()

        return START_NOT_STICKY
    }

    private fun playRing() {
        stopPlayer() // securite idempotence

        val soundUri = resolveSoundUri()
        Log.d(TAG, "playing sound: $soundUri")

        try {
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                isLooping = true
                setVolume(1.0f, 1.0f)
                setDataSource(this@IncomingRingService, soundUri)
                setOnPreparedListener { start() }
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "MediaPlayer error what=$what extra=$extra")
                    false
                }
                prepareAsync()
            }

            // Force le volume d'alarme au max (temporairement).
            try {
                val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                val maxVol = am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                am.setStreamVolume(AudioManager.STREAM_ALARM, maxVol, 0)
            } catch (e: Exception) {
                Log.w(TAG, "failed to set alarm volume: $e")
            }
        } catch (e: Exception) {
            Log.e(TAG, "playRing failed: $e")
        }
    }

    /**
     * Recherche dynamiquement le fichier `res/raw/zeet_incoming` (n'importe
     * quelle extension audio valide). Fallback en cascade sur des sons
     * systeme si absent :
     *   1. TYPE_RINGTONE — son d'appel entrant du tel (le plus reconnaissable,
     *      correspond au mental model "le telephone sonne")
     *   2. TYPE_ALARM — alarme systeme, loud, insistent (ignore DND)
     *   3. TYPE_NOTIFICATION — dernier recours
     *
     * Permet de ne pas casser le build avant que l'equipe ait drop son fichier.
     */
    private fun resolveSoundUri(): Uri {
        val resId = resources.getIdentifier("zeet_incoming", "raw", packageName)
        if (resId != 0) {
            return Uri.parse("android.resource://$packageName/$resId")
        }
        Log.w(
            TAG,
            "zeet_incoming raw resource not found — falling back to system ringtone",
        )
        return RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            ?: Uri.EMPTY
    }

    private fun stopPlayer() {
        try {
            mediaPlayer?.apply {
                if (isPlaying) stop()
                release()
            }
        } catch (e: Exception) {
            Log.w(TAG, "stopPlayer: $e")
        }
        mediaPlayer = null
    }

    private fun stopSelfAndCleanup() {
        stopPlayer()
        try {
            wakeLock?.let { if (it.isHeld) it.release() }
        } catch (_: Exception) { }
        wakeLock = null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy")
        stopPlayer()
        try {
            wakeLock?.let { if (it.isHeld) it.release() }
        } catch (_: Exception) { }
        super.onDestroy()
    }

    // -------------------------------------------------------------------------
    // Notification + channel
    // -------------------------------------------------------------------------

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = CHANNEL_DESC
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 800, 400, 800, 400, 800, 400, 800)
            setBypassDnd(true)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            // Pas de son dans le canal : le MediaPlayer est utilise a la place
            // (plus de controle : loop, volume, source custom).
            setSound(null, null)
        }
        nm.createNotificationChannel(channel)
    }

    private fun buildNotification(title: String, body: String): Notification {
        // PendingIntent qui ouvre MainActivity (foreground Flutter) — au tap
        // l'app route sur IncomingOrderScreen via la logique existante.
        val contentIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("from_incoming_ring", true)
        }
        val pi = PendingIntent.getActivity(
            this,
            0,
            contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setOngoing(true)
            .setAutoCancel(false)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setFullScreenIntent(pi, true)
            .setContentIntent(pi)
            .setColorized(true)
            .setColor(0xFFFF5A1F.toInt())
            .build()
    }
}
