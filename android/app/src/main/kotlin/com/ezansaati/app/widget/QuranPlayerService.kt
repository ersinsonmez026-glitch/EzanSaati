package com.ezansaati.app.widget

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.ForwardingPlayer
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaStyleNotificationHelper
import com.ezansaati.app.MainActivity
import com.ezansaati.app.R

/**
 * Ana ekran Kur'an çaları: seçili listedeki (tüm sûreler, favori sûreler, sesli dualar) öğeyi ayet ayet
 * çalar, bitince sıradakine geçer. Uygulama kapalıyken de çalışır; çalarken bildirimde oynatıcı görünür
 * (Android kuralı). Ses internetten akar (Islamic Network CDN; kârî uygulamada seçilir).
 */
class QuranPlayerService : Service() {

    companion object {
        const val ACTION_TOGGLE = "com.ezansaati.app.widget.TOGGLE"
        const val ACTION_PLAY = "com.ezansaati.app.widget.PLAY"
        const val ACTION_PAUSE = "com.ezansaati.app.widget.PAUSE"
        const val ACTION_NEXT = "com.ezansaati.app.widget.NEXT"
        const val ACTION_PREV = "com.ezansaati.app.widget.PREV"
        const val ACTION_PLAY_INDEX = "com.ezansaati.app.widget.PLAY_INDEX"
        const val ACTION_STOP = "com.ezansaati.app.widget.STOP"
        const val EXTRA_INDEX = "index"

        private const val CHANNEL = "kuran_calar"
        private const val NOTIFICATION_ID = 7301
        private const val IDLE_STOP_MS = 10 * 60 * 1000L

        @Volatile
        var running = false

        @Volatile
        var playing = false

        fun intent(ctx: Context, action: String) = Intent(ctx, QuranPlayerService::class.java).setAction(action)

        /** Widget düğmeleri için (dokunuşla ön plan servisi başlatılabilir). */
        fun pending(ctx: Context, action: String, req: Int): PendingIntent {
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            return if (Build.VERSION.SDK_INT >= 26) {
                PendingIntent.getForegroundService(ctx, req, intent(ctx, action), flags)
            } else {
                PendingIntent.getService(ctx, req, intent(ctx, action), flags)
            }
        }
    }

    private lateinit var exo: ExoPlayer
    private lateinit var player: Player
    private var session: MediaSession? = null
    private val handler = Handler(Looper.getMainLooper())
    private val idleStop = Runnable { stopAll() }

    private var items: List<WidgetStore.Item> = emptyList()
    private var index = 0
    private var loadedKey = ""

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        running = true
        exo = ExoPlayer.Builder(this)
            .setAudioAttributes(
                AudioAttributes.Builder().setUsage(C.USAGE_MEDIA).setContentType(C.AUDIO_CONTENT_TYPE_SPEECH).build(),
                true
            )
            .setHandleAudioBecomingNoisy(true)
            .setWakeMode(C.WAKE_MODE_NETWORK)
            .build()
        // Kilit ekranı / kulaklık "sonraki-önceki" tuşları ayet değil sûre değiştirsin.
        player = object : ForwardingPlayer(exo) {
            override fun getAvailableCommands(): Player.Commands = super.getAvailableCommands().buildUpon()
                .add(Player.COMMAND_SEEK_TO_NEXT).add(Player.COMMAND_SEEK_TO_PREVIOUS)
                .add(Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM).add(Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM)
                .build()

            override fun isCommandAvailable(command: Int): Boolean = when (command) {
                Player.COMMAND_SEEK_TO_NEXT, Player.COMMAND_SEEK_TO_PREVIOUS,
                Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM, Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM -> true
                else -> super.isCommandAvailable(command)
            }

            override fun seekToNext() = step(1)
            override fun seekToNextMediaItem() = step(1)
            override fun seekToPrevious() = step(-1)
            override fun seekToPreviousMediaItem() = step(-1)
            override fun play() = playCurrent()
        }
        exo.addListener(object : Player.Listener {
            override fun onIsPlayingChanged(isPlaying: Boolean) = changed()
            override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) = changed()
            override fun onPlaybackStateChanged(state: Int) {
                if (state == Player.STATE_ENDED) {
                    // Öğe bitti: sıradakine geç (liste sonunda dur).
                    if (index + 1 < items.size) {
                        index += 1
                        WidgetStore.setIndex(this@QuranPlayerService, index)
                        load(true)
                    } else {
                        exo.pause()
                        exo.seekTo(0, 0)
                    }
                }
                changed()
            }

            override fun onPlayerError(error: PlaybackException) {
                playing = false
                changed()
            }
        })
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        session = MediaSession.Builder(this, player).setSessionActivity(open).build()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Ön plan servisi olarak başlatıldıysa hemen bildirim gösterilmeli.
        goForeground()
        refreshItems()
        when (intent?.action) {
            ACTION_TOGGLE -> if (exo.isPlaying) exo.pause() else playCurrent()
            ACTION_PLAY -> playCurrent()
            ACTION_PAUSE -> exo.pause()
            ACTION_NEXT -> step(1)
            ACTION_PREV -> step(-1)
            ACTION_PLAY_INDEX -> {
                index = intent.getIntExtra(EXTRA_INDEX, 0).coerceIn(0, (items.size - 1).coerceAtLeast(0))
                WidgetStore.setIndex(this, index)
                loadedKey = ""
                playCurrent()
            }
            ACTION_STOP -> {
                stopAll()
                return START_NOT_STICKY
            }
        }
        changed()
        return START_NOT_STICKY
    }

    private fun refreshItems() {
        items = WidgetStore.items(this)
        index = WidgetStore.index(this, items.size)
    }

    private fun currentKey(): String = items.getOrNull(index)?.let {
        WidgetStore.keyOf(this, it) + "|" + WidgetStore.reciter(this).id
    } ?: ""

    /** Seçili öğeyi yükler (gerekirse) ve çalar. */
    private fun playCurrent() {
        if (items.isEmpty()) {
            changed()
            return
        }
        if (loadedKey != currentKey() || exo.playbackState == Player.STATE_IDLE || exo.playbackState == Player.STATE_ENDED) {
            load(true)
        } else {
            exo.play()
        }
    }

    private fun load(play: Boolean) {
        val item = items.getOrNull(index) ?: return
        val reciter = WidgetStore.reciter(this)
        exo.setMediaItems(item.urls.mapIndexed { i, u ->
            val ayah = item.ayahAt(i)
            MediaItem.Builder().setUri(u).setMediaId("$i").setMediaMetadata(
                MediaMetadata.Builder()
                    .setTitle(title(item))
                    .setArtist(if (item.isSurah) reciter.name + " · " + (if (ayah == 0) "Besmele" else "Ayet $ayah/${item.count}") else reciter.name)
                    .build()
            ).build()
        })
        exo.prepare()
        loadedKey = currentKey()
        if (play) exo.play()
    }

    private fun title(item: WidgetStore.Item) = if (item.isSurah) "${item.title} Sûresi" else item.title

    private fun step(d: Int) {
        if (items.isEmpty()) return
        val wasPlaying = exo.isPlaying || exo.playWhenReady
        index = (index + d).coerceIn(0, items.size - 1)
        WidgetStore.setIndex(this, index)
        loadedKey = ""
        if (wasPlaying) load(true) else changed()
    }

    /** Durum değişti: widget'ları ve bildirimi yenile; duraklatılınca bir süre sonra kapan. */
    private fun changed() {
        val item = items.getOrNull(index)
        val isPlaying = exo.isPlaying || (exo.playWhenReady && exo.playbackState == Player.STATE_BUFFERING)
        playing = isPlaying
        WidgetStore.setPlayState(
            this, isPlaying, if (item != null && loadedKey == currentKey()) WidgetStore.keyOf(this, item) else "",
            exo.currentMediaItemIndex
        )
        Widgets.updatePlayers(this)
        handler.removeCallbacks(idleStop)
        if (isPlaying) {
            goForeground()
        } else {
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_DETACH)
            notifyNow()
            handler.postDelayed(idleStop, IDLE_STOP_MS)
        }
    }

    private fun stopAll() {
        handler.removeCallbacks(idleStop)
        exo.stop()
        playing = false
        WidgetStore.setPlayState(this, false, "", 0)
        Widgets.updatePlayers(this)
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        handler.removeCallbacks(idleStop)
        running = false
        playing = false
        session?.release()
        session = null
        exo.release()
        WidgetStore.setPlayState(this, false, "", 0)
        Widgets.updatePlayers(this)
        super.onDestroy()
    }

    // ------------------------------------------------------------------ bildirim

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CHANNEL) == null) {
            val ch = NotificationChannel(CHANNEL, "Kur'an çalar", NotificationManager.IMPORTANCE_LOW)
            ch.description = "Ana ekran widget'ından çalınan sûre ve dualar"
            ch.setShowBadge(false)
            nm.createNotificationChannel(ch)
        }
    }

    private fun buildNotification(): Notification {
        val item = items.getOrNull(index)
        val reciter = WidgetStore.reciter(this)
        val isPlaying = exo.isPlaying || exo.playWhenReady
        val pos = exo.currentMediaItemIndex
        val text = when {
            item == null -> reciter.name
            item.isSurah -> reciter.name + " · " + (item.ayahAt(pos).let { if (it == 0) "Besmele" else "Ayet $it/${item.count}" })
            else -> reciter.name
        }
        val s = session
        val b = NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_w_book)
            .setContentTitle(item?.let { title(it) } ?: "Kur'an")
            .setContentText(text)
            .setOngoing(isPlaying)
            .setShowWhen(false)
            .setOnlyAlertOnce(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(s?.sessionActivity)
            .setDeleteIntent(servicePending(ACTION_STOP, 5))
            .addAction(R.drawable.ic_w_prev, "Önceki", servicePending(ACTION_PREV, 1))
            .addAction(
                if (isPlaying) R.drawable.ic_w_pause else R.drawable.ic_w_play,
                if (isPlaying) "Duraklat" else "Oynat",
                servicePending(ACTION_TOGGLE, 2)
            )
            .addAction(R.drawable.ic_w_next, "Sonraki", servicePending(ACTION_NEXT, 3))
        if (s != null) {
            b.setStyle(MediaStyleNotificationHelper.MediaStyle(s).setShowActionsInCompactView(0, 1, 2))
        }
        return b.build()
    }

    private fun servicePending(action: String, req: Int): PendingIntent =
        PendingIntent.getService(this, 100 + req, intent(this, action), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    private fun goForeground() {
        val n = buildNotification()
        val type = if (Build.VERSION.SDK_INT >= 29) ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK else 0
        try {
            ServiceCompat.startForeground(this, NOTIFICATION_ID, n, type)
        } catch (e: Exception) {
            notifyNow()
        }
    }

    private fun notifyNow() {
        try {
            val nm = ContextCompat.getSystemService(this, NotificationManager::class.java) ?: return
            nm.notify(NOTIFICATION_ID, buildNotification())
        } catch (e: SecurityException) {
            // Bildirim izni yoksa çalma yine sürer.
        }
    }
}
