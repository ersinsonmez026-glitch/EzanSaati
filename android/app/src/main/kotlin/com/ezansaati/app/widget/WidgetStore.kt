package com.ezansaati.app.widget

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/**
 * Ana ekran widget'larının ortak verisi. Uygulama (Dart) verileri kendi ayar dosyasına yazar
 * (FlutterSharedPreferences, anahtarlar "flutter." ön ekli; bkz. lib/services/home_widgets.dart).
 * Widget'ların kendi durumu (çalar listesi, sırası) ayrı dosyada tutulur.
 */
object WidgetStore {
    private const val FLUTTER = "FlutterSharedPreferences"
    private const val OWN = "ezan_widget"

    fun flutter(ctx: Context): SharedPreferences = ctx.getSharedPreferences(FLUTTER, Context.MODE_PRIVATE)
    fun own(ctx: Context): SharedPreferences = ctx.getSharedPreferences(OWN, Context.MODE_PRIVATE)

    fun str(ctx: Context, key: String): String? = try {
        flutter(ctx).getString("flutter.$key", null)
    } catch (e: ClassCastException) {
        null
    }

    private fun long(ctx: Context, key: String): Long? = try {
        val p = flutter(ctx)
        if (p.contains("flutter.$key")) p.getLong("flutter.$key", 0) else null
    } catch (e: ClassCastException) {
        null
    }

    // ------------------------------------------------------------------ tema

    /** Renkler: gece (koyu yeşil) / gündüz (krem). */
    class Palette(val night: Boolean) {
        val ink = if (night) 0xFFF3E4C0.toInt() else 0xFF3A2708.toInt()
        val ink2 = if (night) 0xFFDCC697.toInt() else 0xFF6B4C12.toInt()
        val gold = if (night) 0xFFE2C584.toInt() else 0xFFB07F10.toInt()
        val bg = if (night) com.ezansaati.app.R.drawable.wbg_night else com.ezansaati.app.R.drawable.wbg_day
        val btn = if (night) com.ezansaati.app.R.drawable.wbtn_night else com.ezansaati.app.R.drawable.wbtn_day
        val list = if (night) com.ezansaati.app.R.drawable.wlist_night else com.ezansaati.app.R.drawable.wlist_day
        val chip = if (night) com.ezansaati.app.R.drawable.wchip_night else com.ezansaati.app.R.drawable.wchip_day

        companion object {
            const val BRONZE_TEXT = 0xFFFFE08A.toInt()
        }
    }

    /**
     * Uygulamadaki Gündüz/Gece seçimi (day_mode: 0 otomatik, 1 gündüz, 2 gece). Otomatikte imsak ile
     * akşam arası gündüzdür (bugünün vakitlerinden).
     */
    fun palette(ctx: Context): Palette {
        when (long(ctx, "day_mode")?.toInt() ?: 0) {
            1 -> return Palette(false)
            2 -> return Palette(true)
        }
        val now = System.currentTimeMillis()
        val today = todayTimes(ctx, now)
        if (today != null) return Palette(!(now >= today[0] && now < today[4]))
        val h = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        return Palette(h < 6 || h >= 19)
    }

    // ------------------------------------------------------------------ vakitler

    val PRAYER_NAMES = arrayOf("İmsak", "Güneş", "Öğle", "İkindi", "Akşam", "Yatsı")
    val PRAYER_TO = arrayOf("İmsaka", "Güneşe", "Öğleye", "İkindiye", "Akşama", "Yatsıya")

    /** (konum adı, günler: her gün 6 vaktin zamanı) */
    fun times(ctx: Context): Pair<String, List<LongArray>>? {
        val raw = str(ctx, "w_vakit") ?: return null
        return try {
            val o = JSONObject(raw)
            val d = o.getJSONArray("d")
            val days = (0 until d.length()).map { i ->
                val a = d.getJSONArray(i)
                LongArray(a.length()) { a.getLong(it) }
            }.filter { it.size == 6 }
            Pair(o.optString("loc", ""), days)
        } catch (e: Exception) {
            null
        }
    }

    /** Bugünün (takvim günü) vakitleri. */
    fun todayTimes(ctx: Context, now: Long): LongArray? {
        val days = times(ctx)?.second ?: return null
        val c = Calendar.getInstance().apply { timeInMillis = now }
        val y = c.get(Calendar.YEAR)
        val doy = c.get(Calendar.DAY_OF_YEAR)
        return days.firstOrNull {
            val t = Calendar.getInstance().apply { timeInMillis = it[0] }
            t.get(Calendar.YEAR) == y && t.get(Calendar.DAY_OF_YEAR) == doy
        }
    }

    /** Şu an: (bugünün vakitleri, şu anki vakit sırası 0-5, sonraki vaktin zamanı, sonraki vakit sırası). */
    fun status(ctx: Context, now: Long): Status? {
        val days = times(ctx)?.second ?: return null
        val all = days.flatMap { d -> d.indices.map { i -> Pair(d[i], i) } }.sortedBy { it.first }
        val nextIdx = all.indexOfFirst { it.first > now }
        if (nextIdx <= 0) return null
        val cur = all[nextIdx - 1]
        val today = todayTimes(ctx, now) ?: return null
        return Status(today, cur.second, all[nextIdx].first, all[nextIdx].second)
    }

    class Status(val today: LongArray, val current: Int, val nextAt: Long, val next: Int)

    // ------------------------------------------------------------------ Kur'an

    class Reciter(val id: String, val rate: Int, val name: String)

    fun reciter(ctx: Context): Reciter {
        try {
            val o = JSONObject(str(ctx, "w_kari") ?: "")
            return Reciter(o.getString("id"), o.getInt("rate"), o.getString("name"))
        } catch (e: Exception) {
        }
        return Reciter("ar.mahermuaiqly", 128, "Mâhir el-Muaykılî")
    }

    /** Çalınacak bir öğe: sûre ya da dua. */
    class Item(val no: Int, val title: String, val count: Int, val urls: List<String>, val isSurah: Boolean) {
        /** Sûrelerde başta besmele varsa ses listesindeki sıradan ayet no (0 = besmele). */
        fun ayahAt(index: Int): Int = if (isSurah && no != 1 && no != 9) index else index + 1
        val basmala: Boolean get() = isSurah && no != 1 && no != 9
    }

    private fun surahMeta(ctx: Context): List<Pair<String, Int>> = try {
        val a = JSONArray(str(ctx, "w_sureler") ?: "[]")
        (0 until a.length()).map { val x = a.getJSONArray(it); Pair(x.getString(0), x.getInt(1)) }
    } catch (e: Exception) {
        emptyList()
    }

    private fun surahItem(meta: List<Pair<String, Int>>, first: IntArray, r: Reciter, no: Int): Item {
        val (name, count) = meta[no - 1]
        val base = "https://cdn.islamic.network/quran/audio/${r.rate}/${r.id}/"
        val urls = ArrayList<String>()
        if (no != 1 && no != 9) urls.add(base + "1.mp3")
        for (a in 0 until count) urls.add(base + "${first[no - 1] + a}.mp3")
        return Item(no, name, count, urls, true)
    }

    const val MODE_ALL = "all"
    const val MODE_FAV = "fav"
    const val MODE_DUA = "dua"
    val MODES = arrayOf(MODE_ALL, MODE_FAV, MODE_DUA)
    fun modeLabel(m: String) = when (m) {
        MODE_FAV -> "Favori sûreler"
        MODE_DUA -> "Sesli dualar"
        else -> "Tüm sûreler"
    }

    fun mode(ctx: Context): String = own(ctx).getString("mode", MODE_ALL) ?: MODE_ALL

    /** Seçili listedeki öğeler. */
    fun items(ctx: Context): List<Item> {
        val r = reciter(ctx)
        return when (mode(ctx)) {
            MODE_DUA -> try {
                val a = JSONArray(str(ctx, "w_dualar") ?: "[]")
                (0 until a.length()).map {
                    val o = a.getJSONObject(it)
                    val u = o.getJSONArray("u")
                    val urls = (0 until u.length()).map { k -> u.getString(k) }
                    Item(it + 1, o.getString("t"), urls.size, urls, false)
                }
            } catch (e: Exception) {
                emptyList()
            }
            else -> {
                val meta = surahMeta(ctx)
                if (meta.size != 114) return emptyList()
                val first = IntArray(114)
                var n = 1
                for (i in 0 until 114) {
                    first[i] = n; n += meta[i].second
                }
                val nos = if (mode(ctx) == MODE_FAV) try {
                    val a = JSONArray(str(ctx, "w_fav_sure") ?: "[]")
                    (0 until a.length()).map { a.getInt(it) }.filter { it in 1..114 }
                } catch (e: Exception) {
                    emptyList()
                } else (1..114).toList()
                nos.map { surahItem(meta, first, r, it) }
            }
        }
    }

    /** Listedeki sıra (liste değişince sınırda tutulur). */
    fun index(ctx: Context, size: Int): Int {
        val key = "index_" + mode(ctx)
        // Tüm sûrelerde ilk kez: uygulamada en son okunan sûre.
        val start = if (mode(ctx) == MODE_ALL) ((long(ctx, "w_son") ?: 1L).toInt() - 1) else 0
        val i = own(ctx).getInt(key, start)
        return if (size == 0) 0 else i.coerceIn(0, size - 1)
    }

    fun setIndex(ctx: Context, i: Int) = own(ctx).edit().putInt("index_" + mode(ctx), i).apply()

    fun setMode(ctx: Context, m: String) = own(ctx).edit().putString("mode", m).apply()

    /** Çalma durumu (widget'larda gösterilir): çalıyor mu, çalan öğenin kimliği ve ses sırası. */
    fun playState(ctx: Context): Triple<Boolean, String, Int> {
        val p = own(ctx)
        return Triple(p.getBoolean("playing", false), p.getString("playing_key", "") ?: "", p.getInt("playing_pos", 0))
    }

    fun setPlayState(ctx: Context, playing: Boolean, key: String, pos: Int) =
        own(ctx).edit().putBoolean("playing", playing).putString("playing_key", key).putInt("playing_pos", pos).apply()

    fun keyOf(ctx: Context, item: Item) = mode(ctx).let { if (it == MODE_DUA) "d${item.no}" else "s${item.no}" }
}
