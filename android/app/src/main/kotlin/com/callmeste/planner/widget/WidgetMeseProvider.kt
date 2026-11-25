package com.callmeste.planner.widget

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

private const val TAG = "PlannerWidget"

/** Lo stato **di un widget**: mese guardato e giorno scelto, per `appWidgetId`. */
object WidgetMeseStato {
    private val FORMA_MESE = Regex("\\d{4}-\\d{2}")
    private val FORMA_GIORNO = Regex("\\d{4}-\\d{2}-\\d{2}")

    fun chiaveVista(id: Int) = "widget_mese_vista_$id"
    fun chiaveScelto(id: Int) = "widget_mese_scelto_$id"

    fun vista(prefs: SharedPreferences, id: Int): String =
        prefs.getString(chiaveVista(id), null)?.takeIf { FORMA_MESE.matches(it) }
            ?: WidgetPayload.annoMese(WidgetPayload.dataOggi(prefs))

    fun scelto(prefs: SharedPreferences, id: Int): String =
        prefs.getString(chiaveScelto(id), null)?.takeIf { FORMA_GIORNO.matches(it) }
            ?: WidgetPayload.dataOggi(prefs)

    fun scriviVista(prefs: SharedPreferences, id: Int, annoMese: String) {
        prefs.edit().putString(chiaveVista(id), annoMese).apply()
    }

    fun scriviScelto(prefs: SharedPreferences, id: Int, data: String) {
        prefs.edit().putString(chiaveScelto(id), data).apply()
    }

    fun pulisci(prefs: SharedPreferences, id: Int) {
        prefs.edit().remove(chiaveVista(id)).remove(chiaveScelto(id)).apply()
    }
}

/**
 * La base dei tre widget del mese. Cambia solo il vestito scelto dal renderer:
 * 4x2 con agenda, 4x4 grande, 2x2 compatto.
 */
abstract class MeseWidgetBase(
    private val variante: WidgetMeseRenderer.Variante,
) : HomeWidgetProvider() {

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
        for (id in appWidgetIds) {
            WidgetMeseStato.pulisci(prefs, id)
            WidgetKit.pulisciOpzioni(prefs, id)
        }
    }

    private fun aggiorna(
        context: Context,
        manager: AppWidgetManager,
        prefs: SharedPreferences,
        id: Int,
    ) {
        if (variante == WidgetMeseRenderer.Variante.MESE_2X2) {
            manager.updateAppWidget(id, disegnaSicuro(context, manager, prefs, id, variante))
        } else {
            WidgetMeseNuovoRenderer.aggiorna(context, manager, prefs, id, variante)
        }
    }
}

/** «Mese» 4x2: griglia + agenda laterale. */
class MeseWidgetProvider : MeseWidgetBase(WidgetMeseRenderer.Variante.MESE_4X2)

/** «Mese grande» 4x4: griglia piena e ridimensionabile. */
class MeseGrandeWidgetProvider : MeseWidgetBase(WidgetMeseRenderer.Variante.MESE_4X4)

/** «Mese compatto» 2x2: solo griglia. */
class MeseCompattoWidgetProvider : MeseWidgetBase(WidgetMeseRenderer.Variante.MESE_2X2)

internal fun disegnaSicuro(
    context: Context,
    manager: AppWidgetManager,
    prefs: SharedPreferences,
    appWidgetId: Int,
    variante: WidgetMeseRenderer.Variante,
): RemoteViews {
    val vista = WidgetMeseRenderer.disegna(
        context = context,
        prefs = prefs,
        appWidgetId = appWidgetId,
        altezzaDp = WidgetKit.altezza(manager, appWidgetId),
        variante = variante,
    )
    try {
        vista.apply(context, null)
    } catch (errore: Exception) {
        Log.e(TAG, "il widget del mese non si applica (id $appWidgetId)", errore)
    }
    return vista
}

/**
 * I tocchi interni al mese: freccia e giorno. Per il 4x2 il giorno cambia la
 * selezione e il pannello laterale; per 4x4/2x2 il tocco apre direttamente
 * l'app su quella data (il renderer crea una PendingIntent di launch).
 */
class WidgetMeseReceiver : BroadcastReceiver() {

    companion object {
        const val AZIONE_MESE = "com.callmeste.planner.widget.MESE"
        const val AZIONE_GIORNO = "com.callmeste.planner.widget.GIORNO"
        const val AZIONE_TODO = "com.callmeste.planner.widget.TODO"
        const val EXTRA_ID = "appWidgetId"
        const val EXTRA_MESE = "mese"
        const val EXTRA_GIORNO = "giorno"
        const val EXTRA_VARIANTE = "variante"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(EXTRA_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        if (id == AppWidgetManager.INVALID_APPWIDGET_ID) return

        val prefs = HomeWidgetPlugin.getData(context)
        val pubblicati = WidgetPayload.mesiPubblicati(prefs)
        when (intent.action) {
            AZIONE_MESE -> {
                val mese = intent.getStringExtra(EXTRA_MESE)
                if (mese != null && pubblicati.contains(mese)) cambiaMese(prefs, id, mese)
            }

            AZIONE_GIORNO -> {
                val data = intent.getStringExtra(EXTRA_GIORNO)
                if (data != null && pubblicati.contains(WidgetPayload.annoMese(data))) {
                    WidgetMeseStato.scriviVista(prefs, id, WidgetPayload.annoMese(data))
                    WidgetMeseStato.scriviScelto(prefs, id, data)
                }
            }

            AZIONE_TODO -> WidgetKit.invertiTodoAperto(prefs, id)
        }

        val manager = AppWidgetManager.getInstance(context)
        // Il To do della lista è lo stesso per mese e Agenda: il provider dice
        // quale renderer deve ridisegnare.
        val provider = manager.getAppWidgetInfo(id)?.provider?.className
        if (provider == OggiWidgetProvider::class.java.name) {
            AgendaWidgetRenderer.aggiorna(context, manager, prefs, id)
            return
        }

        val variante = intent.getStringExtra(EXTRA_VARIANTE)
            ?.let { runCatching { WidgetMeseRenderer.Variante.valueOf(it) }.getOrNull() }
            ?: WidgetMeseRenderer.Variante.MESE_4X2
        if (variante == WidgetMeseRenderer.Variante.MESE_2X2) {
            manager.updateAppWidget(id, disegnaSicuro(context, manager, prefs, id, variante))
        } else {
            WidgetMeseNuovoRenderer.aggiorna(context, manager, prefs, id, variante)
        }
    }

    private fun cambiaMese(prefs: SharedPreferences, id: Int, mese: String) {
        WidgetMeseStato.scriviVista(prefs, id, mese)
        val scelto = WidgetMeseStato.scelto(prefs, id)
        if (WidgetPayload.annoMese(scelto) != mese) {
            WidgetMeseStato.scriviScelto(prefs, id, WidgetPayload.primoDelMese(mese))
        }
    }
}
