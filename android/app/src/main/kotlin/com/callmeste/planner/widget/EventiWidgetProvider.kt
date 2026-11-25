package com.callmeste.planner.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.callmeste.planner.MainActivity
import com.callmeste.planner.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Â«Eventi di oggiÂ» 2x2: testata fissa e lista **scorribile** con una collection
 * Android vera. La lista non Ã¨ una LinearLayout travestita: Ã¨ un `ListView`
 * alimentato da [EventiWidgetService], quindi lo swipe verticale funziona.
 */
class EventiWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) aggiorna(context, appWidgetManager, widgetData, id)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        aggiorna(
            context,
            appWidgetManager,
            HomeWidgetPlugin.getData(context),
            appWidgetId,
        )
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        val prefs = HomeWidgetPlugin.getData(context)
        for (id in appWidgetIds) WidgetKit.pulisciOpzioni(prefs, id)
    }

    fun aggiorna(
        context: Context,
        manager: AppWidgetManager,
        prefs: SharedPreferences,
        id: Int,
    ) {
        val colori = WidgetKit.colori(context, prefs)
        val oggi = WidgetPayload.dataOggi(prefs)
        val giorno = WidgetPayload.leggiGiorno(prefs, oggi)
        val todoMode = WidgetKit.todoMode(prefs, id)
        val righe = giorno?.let {
            WidgetKit.righe(it, Contenuto.MISTO, todoMode)
        }.orEmpty()

        val vista = RemoteViews(context.packageName, R.layout.widget_eventi)
        vista.setInt(R.id.eventi_radice, "setBackgroundColor", colori.sfondo)
        vista.setTextColor(R.id.eventi_etichetta, colori.testo)
        vista.setTextColor(R.id.eventi_conteggi, colori.tenue)
        vista.setTextColor(R.id.eventi_piu, colori.accento)
        vista.setTextColor(R.id.eventi_vuoto_testo, colori.tenue)
        vista.setTextViewText(R.id.eventi_etichetta, "Oggi")
        vista.setTextViewText(
            R.id.eventi_conteggi,
            WidgetKit.conteggi(context, giorno, Contenuto.MISTO, todoMode),
        )
        vista.setOnClickPendingIntent(
            R.id.eventi_etichetta,
            WidgetKit.apriGiorno(context, oggi),
        )

        if (righe.isEmpty()) {
            WidgetKit.setVisibile(vista, R.id.eventi_lista, false)
            WidgetKit.setVisibile(vista, R.id.eventi_vuoto, true)
            vista.setTextViewText(
                R.id.eventi_vuoto_testo,
                if (giorno == null) {
                    context.getString(R.string.widget_aggiorna)
                } else {
                    context.getString(R.string.widget_aggiungi_evento)
                },
            )
            val click = if (giorno == null) {
                WidgetKit.apriGiorno(context, oggi)
            } else {
                WidgetKit.nuovoEvento(context, oggi)
            }
            vista.setOnClickPendingIntent(R.id.eventi_vuoto, click)
            vista.setOnClickPendingIntent(R.id.eventi_radice, click)
        } else {
            WidgetKit.setVisibile(vista, R.id.eventi_lista, true)
            WidgetKit.setVisibile(vista, R.id.eventi_vuoto, false)
            val adapter = Intent(context, EventiWidgetService::class.java).apply {
                putExtra(EventiWidgetService.EXTRA_ID, id)
            }
            vista.setRemoteAdapter(R.id.eventi_lista, adapter)
            vista.setOnClickPendingIntent(
                R.id.eventi_radice,
                WidgetKit.apriGiorno(context, oggi),
            )
        }

        try {
            vista.apply(context, null)
        } catch (errore: Exception) {
            android.util.Log.e("PlannerWidget", "eventi non applicati (id $id)", errore)
        }
        manager.updateAppWidget(id, vista)
        if (righe.isNotEmpty()) {
            manager.notifyAppWidgetViewDataChanged(id, R.id.eventi_lista)
        }
    }
}

/**
 * La collection: legge lo stesso pacchetto degli altri widget e costruisce una
 * riga per ogni evento/todo. Il click sulla riga porta all'elemento; il tocco
 * sul todo non Ã¨ una spunta (la spunta vive nel 4x4, dove c'Ã¨ spazio).
 */
class EventiWidgetService : RemoteViewsService() {
    companion object {
        const val EXTRA_ID = "appWidgetId"
    }

    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        EventiWidgetFactory(applicationContext, intent.getIntExtra(EXTRA_ID, -1))
}

private class EventiWidgetFactory(
    private val context: Context,
    private val appWidgetId: Int,
) : RemoteViewsService.RemoteViewsFactory {

    private var righe: List<WidgetRow> = emptyList()
    private var giorno: String = WidgetPayload.dataOggi()
    private var todoMode: TodoMode = TodoMode.NESSUNO
    private var notte: Boolean = false
    private var colori: WidgetKit.Colori = WidgetKit.Colori(
        sfondo = android.graphics.Color.WHITE,
        superficie = android.graphics.Color.WHITE,
        testo = android.graphics.Color.BLACK,
        tenue = android.graphics.Color.DKGRAY,
        accento = android.graphics.Color.BLACK,
    )

    override fun onCreate() = Unit

    override fun onDataSetChanged() {
        val prefs = HomeWidgetPlugin.getData(context)
        notte = WidgetKit.isNotte(context)
        colori = WidgetKit.colori(context, prefs)
        giorno = WidgetPayload.dataOggi(prefs)
        val pubblicato = WidgetPayload.leggiGiorno(prefs, giorno)
        todoMode = WidgetKit.todoMode(prefs, appWidgetId)
        righe = pubblicato?.let {
            WidgetKit.righe(it, Contenuto.MISTO, todoMode)
        }.orEmpty()
    }

    override fun onDestroy() {
        righe = emptyList()
    }

    override fun getCount(): Int = righe.size

    override fun getViewAt(position: Int): RemoteViews? {
        val riga = righe.getOrNull(position) ?: return null
        val colore = WidgetKit.coloreRiga(riga, notte, colori.tenue)

        if (todoMode == TodoMode.COMPATTI && riga.isTodo) {
            val compatto = RemoteViews(
                context.packageName,
                R.layout.widget_eventi_riga_compatta,
            )
            compatto.setViewVisibility(R.id.evento_riga_barra, View.GONE)
            compatto.setTextColor(R.id.evento_riga_titolo, colori.testo)
            compatto.setTextViewText(R.id.evento_riga_titolo, riga.titolo)
            compatto.setViewVisibility(R.id.evento_riga_todo, View.VISIBLE)
            compatto.setImageViewResource(
                R.id.evento_riga_todo,
                if (riga.fatto) R.drawable.widget_spunta_fatta else R.drawable.widget_spunta_vuota,
            )
            compatto.setInt(R.id.evento_riga_todo, "setColorFilter", colore)
            compatto.setOnClickPendingIntent(
                R.id.evento_riga_radice,
                WidgetKit.apriElemento(context, riga.tipo, riga.id, giorno),
            )
            return compatto
        }

        val vista = RemoteViews(context.packageName, R.layout.widget_eventi_riga)
        vista.setInt(R.id.evento_riga_barra, "setBackgroundColor", colore)
        vista.setTextColor(R.id.evento_riga_titolo, colori.testo)
        vista.setTextViewText(R.id.evento_riga_titolo, riga.titolo)
        if (riga.isTodo) {
            vista.setViewVisibility(R.id.evento_riga_barra, View.GONE)
            vista.setViewVisibility(R.id.evento_riga_ora, View.VISIBLE)
            vista.setTextColor(R.id.evento_riga_ora, colori.tenue)
            vista.setTextViewText(
                R.id.evento_riga_ora,
                if (riga.ora.isEmpty()) "oggi" else riga.ora,
            )
            vista.setViewVisibility(R.id.evento_riga_todo, View.VISIBLE)
            vista.setImageViewResource(
                R.id.evento_riga_todo,
                if (riga.fatto) R.drawable.widget_spunta_fatta else R.drawable.widget_spunta_vuota,
            )
            vista.setInt(R.id.evento_riga_todo, "setColorFilter", colore)
        } else {
            vista.setViewVisibility(R.id.evento_riga_barra, View.VISIBLE)
            vista.setViewVisibility(R.id.evento_riga_ora, View.VISIBLE)
            vista.setTextColor(R.id.evento_riga_ora, colori.tenue)
            vista.setTextViewText(
                R.id.evento_riga_ora,
                if (riga.ora.isEmpty()) "tutto il giorno" else riga.ora,
            )
            vista.setViewVisibility(R.id.evento_riga_todo, View.GONE)
        }
        vista.setOnClickPendingIntent(
            R.id.evento_riga_radice,
            WidgetKit.apriElemento(context, riga.tipo, riga.id, giorno),
        )
        return vista
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long =
        righe.getOrNull(position)?.id?.hashCode()?.toLong() ?: position.toLong()

    override fun hasStableIds(): Boolean = true
}

