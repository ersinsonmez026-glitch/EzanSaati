package com.ezansaati.app.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import com.ezansaati.app.MainActivity
import com.ezansaati.app.R
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Widget'ları çizer. */
object Widgets {

    fun updateAll(ctx: Context) {
        updatePlayers(ctx)
        update(ctx, ZikirWidget::class.java) { id -> zikir(ctx) }
        update(ctx, VakitWidget::class.java) { vakit(ctx) }
        scheduleTick(ctx)
    }

    fun updatePlayers(ctx: Context) {
        val m = AppWidgetManager.getInstance(ctx)
        val ids = m.getAppWidgetIds(ComponentName(ctx, PlayerListWidget::class.java))
        for (id in ids) m.updateAppWidget(id, playerList(ctx, id))
        if (ids.isNotEmpty()) m.notifyAppWidgetViewDataChanged(ids, R.id.list)
        update(ctx, PlayerLineWidget::class.java) { playerLine(ctx) }
    }

    fun updateZikir(ctx: Context) = update(ctx, ZikirWidget::class.java) { zikir(ctx) }

    private fun update(ctx: Context, cls: Class<out AppWidgetProvider>, build: (Int) -> RemoteViews) {
        val m = AppWidgetManager.getInstance(ctx)
        for (id in m.getAppWidgetIds(ComponentName(ctx, cls))) m.updateAppWidget(id, build(id))
    }

    // ------------------------------------------------------------------ ortak

    private fun openApp(ctx: Context, req: Int): PendingIntent = PendingIntent.getActivity(
        ctx, req, Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    fun action(ctx: Context, action: String, req: Int): PendingIntent = PendingIntent.getBroadcast(
        ctx, req, Intent(ctx, WidgetActionReceiver::class.java).setAction(action),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    private fun tint(v: RemoteViews, id: Int, color: Int) = v.setInt(id, "setColorFilter", color)

    private fun controls(ctx: Context, v: RemoteViews, p: WidgetStore.Palette, playing: Boolean) {
        v.setInt(R.id.btn_prev, "setBackgroundResource", p.btn)
        v.setInt(R.id.btn_next, "setBackgroundResource", p.btn)
        tint(v, R.id.btn_prev, p.gold)
        tint(v, R.id.btn_next, p.gold)
        tint(v, R.id.btn_play, WidgetStore.Palette.BRONZE_TEXT)
        v.setImageViewResource(R.id.btn_play, if (playing) R.drawable.ic_w_pause else R.drawable.ic_w_play)
        v.setContentDescription(R.id.btn_play, if (playing) "Duraklat" else "Oynat")
        v.setOnClickPendingIntent(R.id.btn_prev, QuranPlayerService.pending(ctx, QuranPlayerService.ACTION_PREV, 11))
        v.setOnClickPendingIntent(R.id.btn_play, QuranPlayerService.pending(ctx, QuranPlayerService.ACTION_TOGGLE, 12))
        v.setOnClickPendingIntent(R.id.btn_next, QuranPlayerService.pending(ctx, QuranPlayerService.ACTION_NEXT, 13))
    }

    // ------------------------------------------------------------------ çalar (liste)

    private fun playerList(ctx: Context, widgetId: Int): RemoteViews {
        val p = WidgetStore.palette(ctx)
        val v = RemoteViews(ctx.packageName, R.layout.widget_player_list)
        v.setInt(R.id.root, "setBackgroundResource", p.bg)
        v.setInt(R.id.list_box, "setBackgroundResource", p.list)
        v.setInt(R.id.mode, "setBackgroundResource", p.chip)
        tint(v, R.id.icon, p.gold)
        tint(v, R.id.mode_icon, p.gold)
        val mode = WidgetStore.mode(ctx)
        v.setTextViewText(R.id.title, "Kur'an · " + WidgetStore.reciter(ctx).name)
        v.setTextColor(R.id.title, p.gold)
        v.setTextViewText(R.id.mode_text, WidgetStore.modeLabel(mode))
        v.setTextColor(R.id.mode_text, p.ink)
        v.setOnClickPendingIntent(R.id.mode, action(ctx, WidgetActionReceiver.ACTION_MODE, 21))
        v.setTextColor(R.id.empty, p.ink2)
        v.setTextViewText(
            R.id.empty,
            when {
                WidgetStore.str(ctx, "w_sureler") == null -> "Uygulamayı bir kez açın"
                mode == WidgetStore.MODE_FAV -> "Favori sûreniz yok. Sûreler sayfasında kalbe dokunarak ekleyin."
                else -> "Liste boş"
            }
        )
        val svc = Intent(ctx, PlayerListService::class.java)
            .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            .putExtra("v", mode + p.night) // liste görünümü değişince yeniden oluşturulsun
        svc.data = Uri.parse(svc.toUri(Intent.URI_INTENT_SCHEME))
        @Suppress("DEPRECATION")
        v.setRemoteAdapter(R.id.list, svc)
        v.setEmptyView(R.id.list, R.id.empty)
        val tmplFlags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0)
        val tmpl = if (Build.VERSION.SDK_INT >= 26) {
            PendingIntent.getForegroundService(ctx, 22, QuranPlayerService.intent(ctx, QuranPlayerService.ACTION_PLAY_INDEX), tmplFlags)
        } else {
            PendingIntent.getService(ctx, 22, QuranPlayerService.intent(ctx, QuranPlayerService.ACTION_PLAY_INDEX), tmplFlags)
        }
        v.setPendingIntentTemplate(R.id.list, tmpl)
        val items = WidgetStore.items(ctx)
        val idx = WidgetStore.index(ctx, items.size)
        if (items.isNotEmpty()) v.setScrollPosition(R.id.list, (idx - 1).coerceAtLeast(0))
        controls(ctx, v, p, QuranPlayerService.playing)
        return v
    }

    // ------------------------------------------------------------------ çalar (tek satır)

    private fun playerLine(ctx: Context): RemoteViews {
        val p = WidgetStore.palette(ctx)
        val v = RemoteViews(ctx.packageName, R.layout.widget_player_line)
        v.setInt(R.id.root, "setBackgroundResource", p.bg)
        tint(v, R.id.item_prev, p.gold)
        tint(v, R.id.item_next, p.gold)
        val items = WidgetStore.items(ctx)
        val idx = WidgetStore.index(ctx, items.size)
        val item = items.getOrNull(idx)
        val (playing, key, pos) = WidgetStore.playState(ctx)
        val reciter = WidgetStore.reciter(ctx).name
        v.setTextViewText(
            R.id.title,
            when {
                item == null -> "Kur'an"
                item.isSurah -> "${item.no}. ${item.title}"
                else -> item.title
            }
        )
        val here = item != null && key == WidgetStore.keyOf(ctx, item)
        v.setTextViewText(
            R.id.sub,
            when {
                item == null -> if (WidgetStore.str(ctx, "w_sureler") == null) "Uygulamayı bir kez açın" else "Liste boş"
                here && item.isSurah -> reciter + " · " + item.ayahAt(pos).let { if (it == 0) "Besmele" else "Ayet $it/${item.count}" }
                item.isSurah -> "$reciter · ${item.count} ayet"
                else -> reciter + " · " + WidgetStore.modeLabel(WidgetStore.mode(ctx))
            }
        )
        v.setTextColor(R.id.title, p.ink)
        v.setTextColor(R.id.sub, p.ink2)
        v.setOnClickPendingIntent(R.id.item_prev, action(ctx, WidgetActionReceiver.ACTION_ITEM_PREV, 31))
        v.setOnClickPendingIntent(R.id.item_next, action(ctx, WidgetActionReceiver.ACTION_ITEM_NEXT, 32))
        v.setOnClickPendingIntent(R.id.center, action(ctx, WidgetActionReceiver.ACTION_MODE, 33))
        controls(ctx, v, p, playing && QuranPlayerService.playing)
        return v
    }

    // ------------------------------------------------------------------ zikir

    private fun zikir(ctx: Context): RemoteViews {
        val p = WidgetStore.palette(ctx)
        val z = Zikir.state(ctx)
        val v = RemoteViews(ctx.packageName, R.layout.widget_zikir)
        v.setInt(R.id.root, "setBackgroundResource", p.bg)
        v.setTextViewText(R.id.name, z.title)
        v.setTextViewText(R.id.count, "${z.n}")
        v.setTextViewText(R.id.target, if (z.target > 0) "/ ${z.target}" + (if (z.rounds > 0) " · ${z.rounds} tur" else "") else "serbest")
        v.setTextColor(R.id.name, p.gold)
        v.setTextColor(R.id.count, p.ink)
        v.setTextColor(R.id.target, p.ink2)
        v.setTextColor(R.id.hint, p.ink2)
        v.setInt(R.id.btn_reset, "setBackgroundResource", p.btn)
        v.setInt(R.id.btn_skip, "setBackgroundResource", p.btn)
        tint(v, R.id.btn_reset, p.gold)
        tint(v, R.id.btn_skip, p.gold)
        v.setOnClickPendingIntent(R.id.tap, action(ctx, WidgetActionReceiver.ACTION_ZIKIR_ADD, 41))
        v.setOnClickPendingIntent(R.id.btn_reset, action(ctx, WidgetActionReceiver.ACTION_ZIKIR_RESET, 42))
        v.setOnClickPendingIntent(R.id.btn_skip, action(ctx, WidgetActionReceiver.ACTION_ZIKIR_NEXT, 43))
        return v
    }

    // ------------------------------------------------------------------ vakitler

    private val rows = intArrayOf(R.id.row0, R.id.row1, R.id.row2, R.id.row3, R.id.row4, R.id.row5)
    private val names = intArrayOf(R.id.name0, R.id.name1, R.id.name2, R.id.name3, R.id.name4, R.id.name5)
    private val timesIds = intArrayOf(R.id.time0, R.id.time1, R.id.time2, R.id.time3, R.id.time4, R.id.time5)

    private fun vakit(ctx: Context): RemoteViews {
        val p = WidgetStore.palette(ctx)
        val v = RemoteViews(ctx.packageName, R.layout.widget_vakit)
        v.setInt(R.id.root, "setBackgroundResource", p.bg)
        v.setOnClickPendingIntent(R.id.root, openApp(ctx, 51))
        val now = System.currentTimeMillis()
        val data = WidgetStore.times(ctx)
        val st = WidgetStore.status(ctx, now)
        v.setTextColor(R.id.loc, p.ink2)
        v.setTextColor(R.id.next, p.ink)
        v.setTextColor(R.id.left, p.ink)
        if (data == null || st == null) {
            v.setTextViewText(R.id.loc, "Ezan Saati")
            v.setTextViewText(R.id.next, "Konum seçin")
            v.setViewVisibility(R.id.left, View.GONE)
            for (i in 0 until 6) v.setViewVisibility(rows[i], View.INVISIBLE)
            return v
        }
        v.setTextViewText(R.id.loc, data.first)
        v.setTextViewText(R.id.next, WidgetStore.PRAYER_TO[st.next])
        v.setViewVisibility(R.id.left, View.VISIBLE)
        v.setChronometer(R.id.left, SystemClock.elapsedRealtime() + (st.nextAt - now), null, true)
        if (Build.VERSION.SDK_INT >= 24) v.setChronometerCountDown(R.id.left, true)
        val fmt = SimpleDateFormat("HH:mm", Locale("tr"))
        val todayCurrent = st.today.indexOfLast { it <= now }
        for (i in 0 until 6) {
            v.setViewVisibility(rows[i], View.VISIBLE)
            v.setTextViewText(names[i], WidgetStore.PRAYER_NAMES[i])
            v.setTextViewText(timesIds[i], fmt.format(Date(st.today[i])))
            val cur = i == todayCurrent
            v.setInt(rows[i], "setBackgroundResource", if (cur) R.drawable.wslot_current else 0)
            v.setTextColor(names[i], if (cur) WidgetStore.Palette.BRONZE_TEXT else p.ink2)
            v.setTextColor(timesIds[i], if (cur) WidgetStore.Palette.BRONZE_TEXT else p.ink)
        }
        return v
    }

    /** Sonraki vakitte (ve gündüz/gece geçişinde) widget'lar kendiliğinden yenilensin. */
    private fun scheduleTick(ctx: Context) {
        val st = WidgetStore.status(ctx, System.currentTimeMillis()) ?: return
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = action(ctx, WidgetActionReceiver.ACTION_TICK, 61)
        val at = st.nextAt + 1000
        try {
            if (Build.VERSION.SDK_INT >= 31 && !am.canScheduleExactAlarms()) {
                am.setAndAllowWhileIdle(AlarmManager.RTC, at, pi)
            } else {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC, at, pi)
            }
        } catch (e: SecurityException) {
            am.set(AlarmManager.RTC, at, pi)
        }
    }
}

/** Zikir Sayacı'nın kaydı (zikir_v2; lib/services/dhikr_store.dart ile aynı biçim). */
object Zikir {
    private val builtIn = linkedMapOf(
        "subhan" to Pair("Sübhânallâh", 33),
        "hamd" to Pair("Elhamdülillâh", 33),
        "tekbir" to Pair("Allâhü ekber", 33),
        "tevhid" to Pair("Lâ ilâhe illallâh", 100),
        "istigfar" to Pair("Estağfirullâh", 100),
        "salavat" to Pair("Salavât", 100),
    )

    class State(val id: String, val title: String, val n: Int, val rounds: Int, val target: Int, val vibrate: Boolean)

    private fun load(ctx: Context): JSONObject = try {
        JSONObject(WidgetStore.str(ctx, "zikir_v2") ?: "{}")
    } catch (e: Exception) {
        JSONObject()
    }

    private fun save(ctx: Context, o: JSONObject) =
        WidgetStore.flutter(ctx).edit().putString("flutter.zikir_v2", o.toString()).apply()

    /** (kimlik, ad, varsayılan hedef) sırasıyla bütün zikirler. */
    private fun all(o: JSONObject): List<Triple<String, String, Int>> {
        val l = builtIn.map { Triple(it.key, it.value.first, it.value.second) }.toMutableList()
        val c = o.optJSONArray("custom")
        if (c != null) for (i in 0 until c.length()) {
            val x = c.optJSONObject(i) ?: continue
            l.add(Triple(x.optString("id"), x.optString("t"), x.optInt("h", 100)))
        }
        return l
    }

    private fun selected(o: JSONObject): Triple<String, String, Int> {
        val all = all(o)
        val sel = o.optString("sel", "subhan")
        return all.firstOrNull { it.first == sel } ?: all.first()
    }

    fun state(ctx: Context): State {
        val o = load(ctx)
        val (id, title, def) = selected(o)
        val c = o.optJSONObject("c")?.optJSONArray(id)
        val target = o.optJSONObject("tg")?.optInt(id, def) ?: def
        return State(id, title, c?.optInt(0) ?: 0, c?.optInt(1) ?: 0, target, o.optBoolean("vib", true))
    }

    /** Bir sayar; tur tamamlandıysa true. */
    fun add(ctx: Context): Boolean {
        val o = load(ctx)
        val (id, _, def) = selected(o)
        val cal = java.util.Calendar.getInstance()
        val day = "${cal.get(java.util.Calendar.YEAR)}-${cal.get(java.util.Calendar.MONTH) + 1}-${cal.get(java.util.Calendar.DAY_OF_MONTH)}"
        if (o.optString("day") != day) {
            o.put("day", day)
            o.put("dn", JSONObject())
        }
        val counts = o.optJSONObject("c") ?: JSONObject().also { o.put("c", it) }
        val arr = counts.optJSONArray(id)
        var n = arr?.optInt(0) ?: 0
        var rounds = arr?.optInt(1) ?: 0
        val t = o.optJSONObject("tg")?.optInt(id, def) ?: def
        if (t > 0 && n >= t) n = 0
        n += 1
        var round = false
        if (t > 0 && n == t) {
            rounds += 1
            round = true
        }
        counts.put(id, org.json.JSONArray().put(n).put(rounds))
        val dn = o.optJSONObject("dn") ?: JSONObject().also { o.put("dn", it) }
        dn.put(id, dn.optInt(id, 0) + 1)
        o.put("sel", id)
        save(ctx, o)
        return round
    }

    fun reset(ctx: Context) {
        val o = load(ctx)
        val id = selected(o).first
        val counts = o.optJSONObject("c") ?: JSONObject().also { o.put("c", it) }
        counts.put(id, org.json.JSONArray().put(0).put(0))
        save(ctx, o)
    }

    fun next(ctx: Context) {
        val o = load(ctx)
        val all = all(o)
        val i = all.indexOfFirst { it.first == selected(o).first }
        o.put("sel", all[(i + 1) % all.size].first)
        save(ctx, o)
    }
}
