package com.ezansaati.app.widget

import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.ezansaati.app.R

/** Listeli çaların satırları. */
class PlayerListService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory = Factory(applicationContext)

    private class Factory(private val ctx: Context) : RemoteViewsFactory {
        private var items: List<WidgetStore.Item> = emptyList()
        private var palette = WidgetStore.Palette(true)
        private var selected = 0
        private var playingKey = ""
        private var playingPos = 0
        private var playing = false

        override fun onCreate() {}

        override fun onDataSetChanged() {
            items = WidgetStore.items(ctx)
            palette = WidgetStore.palette(ctx)
            selected = WidgetStore.index(ctx, items.size)
            val (p, key, pos) = WidgetStore.playState(ctx)
            playing = p && QuranPlayerService.playing
            playingKey = key
            playingPos = pos
        }

        override fun onDestroy() {}
        override fun getCount() = items.size
        override fun getLoadingView(): RemoteViews? = null
        override fun getViewTypeCount() = 1
        override fun getItemId(position: Int) = position.toLong()
        override fun hasStableIds() = true

        override fun getViewAt(position: Int): RemoteViews {
            val v = RemoteViews(ctx.packageName, R.layout.widget_player_row)
            val item = items.getOrNull(position) ?: return v
            val p = palette
            val loaded = playingKey == WidgetStore.keyOf(ctx, item)
            val current = position == selected
            v.setInt(R.id.row, "setBackgroundResource", if (current) R.drawable.wrow_current else 0)
            val ink = if (current) WidgetStore.Palette.BRONZE_TEXT else p.ink
            v.setTextViewText(R.id.no, if (item.isSurah) "${item.no}" else "•")
            v.setTextColor(R.id.no, if (current) WidgetStore.Palette.BRONZE_TEXT else p.gold)
            v.setTextViewText(R.id.name, item.title)
            v.setTextColor(R.id.name, ink)
            if (current && loaded) {
                v.setViewVisibility(R.id.eq, if (playing) View.VISIBLE else View.GONE)
                v.setInt(R.id.eq, "setColorFilter", WidgetStore.Palette.BRONZE_TEXT)
                v.setTextViewText(
                    R.id.right,
                    if (item.isSurah) item.ayahAt(playingPos).let { if (it == 0) "Besmele" else "Ayet $it/${item.count}" }
                    else "${playingPos + 1}/${item.count}"
                )
            } else {
                v.setViewVisibility(R.id.eq, View.GONE)
                v.setTextViewText(R.id.right, if (item.isSurah) "${item.count} ayet" else "")
            }
            v.setTextColor(R.id.right, if (current) WidgetStore.Palette.BRONZE_TEXT else p.ink2)
            v.setOnClickFillInIntent(R.id.row, Intent().putExtra(QuranPlayerService.EXTRA_INDEX, position))
            return v
        }
    }
}
