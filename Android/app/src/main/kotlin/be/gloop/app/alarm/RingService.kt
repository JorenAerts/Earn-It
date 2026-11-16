package be.gloop.app.alarm

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import be.gloop.app.GloopApplication
import be.gloop.app.R
import be.gloop.app.mission.MissionActivity
import be.gloop.app.ui.alarmTitle
import be.gloop.core.model.AlarmSound

/**
 * The ringing alarm: loops the tone (alarm stream) and vibrates until the mission is done or the
 * fail-safe hits. Its notification has no dismiss/stop action; its full-screen intent opens the
 * mission over the lock screen.
 */
class RingService : Service() {
    private var player: MediaPlayer? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val controller = GloopApplication.controller(this)
        val plan = controller.activePlan
        if (plan == null || !controller.needsMission) {
            stopSelf()
            return START_NOT_STICKY
        }
        val notification = notification(this, alarmTitle(this, plan))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        if (player == null) play(plan.sound.builtIn)
        vibrate()
        return START_STICKY
    }

    private fun play(sound: AlarmSound) {
        player = MediaPlayer().apply {
            setAudioAttributes(AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build())
            setDataSource(this@RingService, soundUri(this@RingService, sound))
            isLooping = true
            setWakeMode(this@RingService, PowerManager.PARTIAL_WAKE_LOCK)
            setOnPreparedListener { it.start() }
            prepareAsync()
        }
    }

    private fun vibrate() {
        val vibrator = vibrator() ?: return
        val pattern = VibrationEffect.createWaveform(longArrayOf(0, 800, 600), 0)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            vibrator.vibrate(pattern, android.os.VibrationAttributes.createForUsage(android.os.VibrationAttributes.USAGE_ALARM))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(pattern, AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build())
        }
    }

    private fun vibrator(): Vibrator? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) getSystemService(VibratorManager::class.java)?.defaultVibrator
        else @Suppress("DEPRECATION") getSystemService(Vibrator::class.java)

    override fun onDestroy() {
        player?.run { runCatching { stop() }; release() }
        player = null
        vibrator()?.cancel()
        super.onDestroy()
    }

    companion object {
        const val CHANNEL_ID = "alarms"
        private const val NOTIFICATION_ID = 7

        fun start(context: Context) =
            ContextCompat.startForegroundService(context, Intent(context, RingService::class.java))

        fun stop(context: Context) = context.stopService(Intent(context, RingService::class.java))

        fun soundUri(context: Context, sound: AlarmSound): Uri =
            Uri.parse("android.resource://${context.packageName}/${soundRes(sound)}")

        /** Direct references, so release builds never strip a tone (files: scripts/convert_sounds.sh). */
        fun soundRes(sound: AlarmSound): Int = when (sound) {
            AlarmSound.CLASSIC -> R.raw.gloop_classic
            AlarmSound.CHIME -> R.raw.gloop_chime
            AlarmSound.SIREN -> R.raw.gloop_siren
            AlarmSound.DIGITAL -> R.raw.gloop_digital
            AlarmSound.PULSE -> R.raw.gloop_pulse
            AlarmSound.RADAR -> R.raw.gloop_radar
            AlarmSound.GENTLE_RISE -> R.raw.gloop_gentle_rise
            AlarmSound.REVEILLE -> R.raw.gloop_reveille
            AlarmSound.MORNING_MOOD -> R.raw.gloop_morning_mood
            AlarmSound.FUR_ELISE -> R.raw.gloop_fur_elise
            AlarmSound.RISE_AND_CONQUER -> R.raw.gloop_rise_and_conquer
        }

        fun createChannel(context: Context) {
            val channel = NotificationChannel(CHANNEL_ID, context.getString(R.string.channel_alarms), NotificationManager.IMPORTANCE_HIGH).apply {
                description = context.getString(R.string.channel_alarms_description)
                setSound(null, null) // the service plays the tone itself (alarm stream, looping)
                enableVibration(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setBypassDnd(true)
            }
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }

        /**
         * While the mission is on screen: the same notification without the full-screen intent, so
         * Android drops the sticky alarm banner that would cover the mission. `loud` restores it.
         */
        fun setMissionVisible(context: Context, visible: Boolean) {
            val controller = GloopApplication.controller(context)
            val plan = controller.activePlan ?: return
            if (!controller.needsMission) return
            context.getSystemService(NotificationManager::class.java)
                .notify(NOTIFICATION_ID, notification(context, alarmTitle(context, plan), fullScreen = !visible))
        }

        private fun notification(context: Context, title: String, fullScreen: Boolean = true): Notification {
            val open = PendingIntent.getActivity(context, 1,
                Intent(context, MissionActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            return NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_gloop)
                .setContentTitle(title)
                .setContentText(context.getString(R.string.tap_to_start_mission))
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setOngoing(true)
                .setAutoCancel(false)
                .setContentIntent(open)
                .apply { if (fullScreen) setFullScreenIntent(open, true) else setSilent(true) }
                .setOnlyAlertOnce(!fullScreen)
                .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
                .build()
        }
    }
}
