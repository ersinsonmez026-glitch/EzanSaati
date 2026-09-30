package com.ezansaati.app.mosque

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import org.json.JSONArray

/**
 * Cami modu: uygulamanın yazdığı aralıklarda (flutter.cami_araliklar = [[başlangıç, bitiş] ms, ...])
 * telefonu sessize ya da titreşime alır, aralık bitince eski zil ayarına döndürür.
 * Her seferinde yalnız sıradaki olay için bir alarm kurulur; olay gelince bir sonrakine geçilir.
 */
object CamiMode {
    const val ACTION_START = "com.ezansaati.app.CAMI_START"
    const val ACTION_END = "com.ezansaati.app.CAMI_END"

    private const val FLUTTER = "FlutterSharedPreferences"
    private const val STATE = "cami_modu"
    private const val K_ACTIVE_END = "active_end" // sessizlik sürüyorsa bitiş zamanı
    private const val K_PREV = "prev_mode" // önceki zil ayarı
    private const val K_SET = "set_mode" // bizim kurduğumuz zil ayarı

    private fun windows(ctx: Context): List<LongArray> {
        val raw = ctx.getSharedPreferences(FLUTTER, Context.MODE_PRIVATE).getString("flutter.cami_araliklar", null)
            ?: return emptyList()
        return try {
            val a = JSONArray(raw)
            (0 until a.length()).map { i ->
                val w = a.getJSONArray(i)
                longArrayOf(w.getLong(0), w.getLong(1))
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun silent(ctx: Context) =
        ctx.getSharedPreferences(FLUTTER, Context.MODE_PRIVATE).getBoolean("flutter.cami_sessiz", false)

    fun hasDndAccess(ctx: Context): Boolean {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M || nm.isNotificationPolicyAccessGranted
    }

    private fun pending(ctx: Context, action: String): PendingIntent =
        PendingIntent.getBroadcast(
            ctx,
            if (action == ACTION_START) 7301 else 7302,
            Intent(ctx, CamiReceiver::class.java).setAction(action),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

    private fun setAlarm(ctx: Context, at: Long, action: String) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = pending(ctx, action)
        val exact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()
        if (exact) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
        } else {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
        }
    }

    private fun cancelAlarms(ctx: Context) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(pending(ctx, ACTION_START))
        am.cancel(pending(ctx, ACTION_END))
    }

    /** Sıradaki olayı kurar; şu an bir aralığın içindeysek sessizliği hemen başlatır. */
    fun schedule(ctx: Context) {
        cancelAlarms(ctx)
        val now = System.currentTimeMillis()
        val state = ctx.getSharedPreferences(STATE, Context.MODE_PRIVATE)
        val activeEnd = state.getLong(K_ACTIVE_END, 0L)
        if (activeEnd > now) {
            setAlarm(ctx, activeEnd, ACTION_END)
            return
        }
        if (activeEnd != 0L) restore(ctx) // bitişi kaçırılmış (telefon kapalıydı)
        val next = windows(ctx).firstOrNull { it[1] > now } ?: return
        if (next[0] <= now) start(ctx, next[1]) else setAlarm(ctx, next[0], ACTION_START)
    }

    /** Cami modu kapatıldı: alarmlar kalkar, sessizlik sürüyorsa zil geri açılır. */
    fun cancel(ctx: Context) {
        cancelAlarms(ctx)
        restore(ctx)
    }

    fun onStart(ctx: Context) {
        val now = System.currentTimeMillis()
        val w = windows(ctx).firstOrNull { it[0] <= now + 60_000 && it[1] > now }
        if (w == null) schedule(ctx) else start(ctx, w[1])
    }

    fun onEnd(ctx: Context) {
        restore(ctx)
        schedule(ctx)
    }

    private fun start(ctx: Context, end: Long) {
        val audio = ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val prev = audio.ringerMode
        var target = if (silent(ctx) && hasDndAccess(ctx)) AudioManager.RINGER_MODE_SILENT else AudioManager.RINGER_MODE_VIBRATE
        if (prev != AudioManager.RINGER_MODE_NORMAL) {
            // Kullanıcı zaten sessiz/titreşimde: dokunma, yalnız süreyi bekle.
            target = prev
        } else {
            try {
                audio.ringerMode = target
            } catch (e: SecurityException) {
                target = AudioManager.RINGER_MODE_VIBRATE
                try {
                    audio.ringerMode = target
                } catch (e2: Exception) {
                    target = prev
                }
            }
        }
        ctx.getSharedPreferences(STATE, Context.MODE_PRIVATE).edit()
            .putLong(K_ACTIVE_END, end)
            .putInt(K_PREV, prev)
            .putInt(K_SET, target)
            .apply()
        setAlarm(ctx, end, ACTION_END)
    }

    private fun restore(ctx: Context) {
        val state = ctx.getSharedPreferences(STATE, Context.MODE_PRIVATE)
        if (state.getLong(K_ACTIVE_END, 0L) == 0L) return
        val prev = state.getInt(K_PREV, AudioManager.RINGER_MODE_NORMAL)
        val set = state.getInt(K_SET, prev)
        val audio = ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        // Kullanıcı arada zil ayarını kendisi değiştirdiyse ona dokunma.
        if (set != prev && audio.ringerMode == set) {
            try {
                audio.ringerMode = prev
            } catch (e: Exception) {
            }
        }
        state.edit().remove(K_ACTIVE_END).remove(K_PREV).remove(K_SET).apply()
    }
}

class CamiReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            CamiMode.ACTION_START -> CamiMode.onStart(context)
            CamiMode.ACTION_END -> CamiMode.onEnd(context)
            else -> CamiMode.schedule(context) // açılış, güncelleme, saat/saat dilimi değişikliği
        }
    }
}
