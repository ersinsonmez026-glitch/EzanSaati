package com.ezansaati.app.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context

/** Kur'an çalar (liste): üstte sûre/dua adları, altta çalma tuşları. */
class PlayerListWidget : AppWidgetProvider() {
    override fun onUpdate(ctx: Context, m: AppWidgetManager, ids: IntArray) = Widgets.updatePlayers(ctx)
}

/** Kur'an çalar (tek satır): çalan sûre/dua adı ve çalma tuşları. */
class PlayerLineWidget : AppWidgetProvider() {
    override fun onUpdate(ctx: Context, m: AppWidgetManager, ids: IntArray) = Widgets.updatePlayers(ctx)
}

/** Zikir sayacı: dokundukça sayar (Zikir Sayacı ile aynı kayıt). */
class ZikirWidget : AppWidgetProvider() {
    override fun onUpdate(ctx: Context, m: AppWidgetManager, ids: IntArray) = Widgets.updateZikir(ctx)
}

/** Namaz vakitleri: sonraki vakte kalan süre ve günün vakitleri. */
class VakitWidget : AppWidgetProvider() {
    override fun onUpdate(ctx: Context, m: AppWidgetManager, ids: IntArray) = Widgets.updateAll(ctx)
}
