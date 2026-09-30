package com.ezansaati.app.widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/** Widget dokunuşları (çalma tuşları hariç; onlar doğrudan çalar servisine gider). */
class WidgetActionReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_MODE = "com.ezansaati.app.widget.MODE"
        const val ACTION_ITEM_PREV = "com.ezansaati.app.widget.ITEM_PREV"
        const val ACTION_ITEM_NEXT = "com.ezansaati.app.widget.ITEM_NEXT"
        const val ACTION_ZIKIR_ADD = "com.ezansaati.app.widget.ZIKIR_ADD"
        const val ACTION_ZIKIR_RESET = "com.ezansaati.app.widget.ZIKIR_RESET"
        const val ACTION_ZIKIR_NEXT = "com.ezansaati.app.widget.ZIKIR_NEXT"
        const val ACTION_TICK = "com.ezansaati.app.widget.TICK"
    }

    override fun onReceive(ctx: Context, intent: Intent) {
        when (intent.action) {
            ACTION_MODE -> {
                // Liste: tüm sûreler → favori sûreler → sesli dualar
                val modes = WidgetStore.MODES
                val i = modes.indexOf(WidgetStore.mode(ctx))
                WidgetStore.setMode(ctx, modes[(i + 1) % modes.size])
                Widgets.updatePlayers(ctx)
            }
            ACTION_ITEM_PREV, ACTION_ITEM_NEXT -> {
                val items = WidgetStore.items(ctx)
                if (items.isEmpty()) return
                val d = if (intent.action == ACTION_ITEM_NEXT) 1 else -1
                val i = (WidgetStore.index(ctx, items.size) + d).coerceIn(0, items.size - 1)
                if (QuranPlayerService.running && QuranPlayerService.playing) {
                    // Çalarken seçilen öğe hemen çalsın (servis zaten ön planda).
                    ctx.startService(
                        QuranPlayerService.intent(ctx, QuranPlayerService.ACTION_PLAY_INDEX)
                            .putExtra(QuranPlayerService.EXTRA_INDEX, i)
                    )
                } else {
                    WidgetStore.setIndex(ctx, i)
                    Widgets.updatePlayers(ctx)
                }
            }
            ACTION_ZIKIR_ADD -> {
                val round = Zikir.add(ctx)
                if (Zikir.state(ctx).vibrate) vibrate(ctx, if (round) 120L else 25L)
                Widgets.updateZikir(ctx)
            }
            ACTION_ZIKIR_RESET -> {
                Zikir.reset(ctx)
                Widgets.updateZikir(ctx)
            }
            ACTION_ZIKIR_NEXT -> {
                Zikir.next(ctx)
                Widgets.updateZikir(ctx)
            }
            ACTION_TICK -> Widgets.updateAll(ctx)
        }
    }

    private fun vibrate(ctx: Context, ms: Long) {
        try {
            val v: Vibrator? = if (Build.VERSION.SDK_INT >= 31) {
                (ctx.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                ctx.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }
            if (Build.VERSION.SDK_INT >= 26) {
                v?.vibrate(VibrationEffect.createOneShot(ms, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                v?.vibrate(ms)
            }
        } catch (e: Exception) {
        }
    }
}
