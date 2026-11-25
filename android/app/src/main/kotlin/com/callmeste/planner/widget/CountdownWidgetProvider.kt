package com.callmeste.planner.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import com.callmeste.planner.MainActivity
import com.callmeste.planner.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

private const val TAG = "PlannerWidget"
private const val CHIAVE_EVENTO = "widget_countdown_evento_"
private const val CHIAVE_TITOLO = "widget_countdown_titolo_"
private const val CHIAVE_DATA = "widget_countdown_data_"

/** La scelta di un countdown: evento (per il tocco), nome, data ISO. */
data class CountdownScelto(
    val eventoId: String,
    val titolo: String,
    val data: String,
)

internal fun countdownScelto(prefs: SharedPreferences, id: Int): CountdownScelto? {
    val evento = prefs.getString("$CHIAVE_EVENTO$id", null)?.takeIf { it.isNotEmpty() }
        ?: return null
    val data = prefs.getString("$CHIAVE_DATA$id", null)
        ?.takeIf { Regex("\\d{4}-\\d{2}-\\d{2}").matches(it) }
        ?: return null
    return CountdownScelto(
        eventoId = evento,
        titolo = prefs.getString("$CHIAVE_TITOLO$id", null)?.ifEmpty { null } ?: "Evento",
        data = data,
    )
}

internal fun pulisciCountdown(prefs: SharedPreferences, id: Int) {
    prefs.edit()
        .remove("$CHIAVE_EVENTO$id")
        .remove("$CHIAVE_TITOLO$id")
        .remove("$CHIAVE_DATA$id")
        .apply()
}

/**
 * Il countdown 2x2: nome, numero grande, data sotto. Il tocco riapre il
 * selettore dell'evento; il tocco sulla data apre l'evento. Senza scelta, il
 * Â«+Â» e Â«Scegli eventoÂ».
 */
internal object CountdownRenderer {

    fun disegna(
        context: Context,
        prefs: SharedPreferences,
        appWidgetId: Int,
    ): RemoteViews {
        val colori = WidgetKit.colori(context, prefs)
        val vista = RemoteViews(context.packageName, R.layout.widget_countdown)
        vista.setInt(R.id.countdown_radice, "setBackgroundColor", colori.sfondo)
        vista.setTextColor(R.id.countdown_titolo, colori.testo)
        vista.setTextColor(R.id.countdown_numero, colori.accento)
        vista.setTextColor(R.id.countdown_sotto, colori.tenue)
        vista.setTextColor(R.id.countdown_frase, colori.tenue)
        vista.setTextColor(R.id.countdown_piu, colori.accento)

        val selettore = WidgetKit.apriCountdown(context, appWidgetId)
        val scelto = countdownScelto(prefs, appWidgetId)
        if (scelto == null) {
            vista.setTextViewText(R.id.countdown_titolo, "Countdown")
            vista.setViewVisibility(R.id.countdown_numero, View.GONE)
            vista.setViewVisibility(R.id.countdown_sotto, View.GONE)
            vista.setViewVisibility(R.id.countdown_frase, View.VISIBLE)
            vista.setTextViewText(R.id.countdown_frase, "Scegli evento")
            vista.setViewVisibility(R.id.countdown_piu, View.VISIBLE)
            vista.setOnClickPendingIntent(R.id.countdown_radice, selettore)
            return vista
        }

        val mancanti = WidgetKit.giorniTra(WidgetPayload.dataOggi(prefs), scelto.data)
        vista.setViewVisibility(R.id.countdown_frase, View.GONE)
        vista.setViewVisibility(R.id.countdown_piu, View.GONE)
        // ColorOS riusa la view gonfiata fra i disegni: le visibility del ramo
        // vuoto sopravvivono se non si ridicono VISIBLE.
        vista.setViewVisibility(R.id.countdown_numero, View.VISIBLE)
        vista.setViewVisibility(R.id.countdown_sotto, View.VISIBLE)
        vista.setTextViewText(R.id.countdown_titolo, scelto.titolo)

        when {
            mancanti == 0 -> {
                vista.setTextViewText(R.id.countdown_numero, "Oggi")
                vista.setTextViewText(R.id.countdown_sotto, WidgetKit.etichettaBreve(scelto.data))
            }
            mancanti == 1 -> {
                vista.setTextViewText(R.id.countdown_numero, "Domani")
                vista.setTextViewText(R.id.countdown_sotto, WidgetKit.etichettaBreve(scelto.data))
            }
            mancanti > 1 -> {
                vista.setTextViewText(R.id.countdown_numero, "$mancanti")
                vista.setTextViewText(
                    R.id.countdown_sotto,
                    "giorni Â· ${WidgetKit.etichettaBreve(scelto.data)}",
                )
            }
            else -> {
                vista.setViewVisibility(R.id.countdown_numero, View.GONE)
                vista.setViewVisibility(R.id.countdown_frase, View.VISIBLE)
                vista.setTextViewText(R.id.countdown_frase, "Concluso")
                vista.setTextViewText(
                    R.id.countdown_sotto,
                    "il ${WidgetKit.etichettaBreve(scelto.data)}",
                )
            }
        }

        vista.setOnClickPendingIntent(R.id.countdown_radice, selettore)
        vista.setOnClickPendingIntent(
            R.id.countdown_sotto,
            HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse(
                    "planner://apri?tipo=evento" +
                        "&id=${Uri.encode(scelto.eventoId)}&giorno=${scelto.data}",
                ),
            ),
        )
        return vista
    }
}

/** Il sesto widget: il countdown di un evento scelto, per singola istanza. */
class CountdownWidgetProvider : HomeWidgetProvider() {

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
        newOptions: android.os.Bundle,
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
        for (id in appWidgetIds) pulisciCountdown(prefs, id)
    }

    private fun aggiorna(
        context: Context,
        manager: AppWidgetManager,
        prefs: SharedPreferences,
        id: Int,
    ) {
        val vista = CountdownRenderer.disegna(context, prefs, id)
        try {
            vista.apply(context, null)
        } catch (errore: Exception) {
            Log.e(TAG, "countdown non applicato (id $id)", errore)
        }
        manager.updateAppWidget(id, vista)
    }
}
