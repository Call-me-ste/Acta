package com.callmeste.planner.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

private const val TAG = "PlannerWidget"

/**
 * I due widget della giornata: «Giorno» (eventi, con todo opzionali) e «Todo»
 * (solo todo). La differenza è il filtro; testata, fascia dei giorni e righe
 * sono le stesse, così la famiglia resta coerente.
 */
abstract class PlannerWidget(
    private val contenuto: Contenuto,
) : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(
                id,
                disegna(context, appWidgetManager, widgetData, id),
            )
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        appWidgetManager.updateAppWidget(
            appWidgetId,
            disegna(
                context,
                appWidgetManager,
                HomeWidgetPlugin.getData(context),
                appWidgetId,
            ),
        )
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        val prefs = HomeWidgetPlugin.getData(context)
        for (id in appWidgetIds) {
            WidgetDayStato.pulisci(prefs, id)
            WidgetKit.pulisciOpzioni(prefs, id)
        }
    }

    private fun disegna(
        context: Context,
        manager: AppWidgetManager,
        prefs: SharedPreferences,
        id: Int,
    ): RemoteViews {
        val vista = WidgetRenderer.disegna(
            context = context,
            contenuto = contenuto,
            prefs = prefs,
            appWidgetId = id,
            altezzaDp = WidgetKit.altezza(manager, id),
        )
        try {
            vista.apply(context, null)
        } catch (errore: Exception) {
            Log.e(TAG, "il widget della giornata non si applica (id $id)", errore)
        }
        return vista
    }
}

/**
 * «Agenda» 4x4: striscia della settimana, giorno scelto e lista scorrevole.
 *
 * Non passa più da [PlannerWidget]: la testata è una striscia di giorni, non
 * cinque righe, e il disegno vive in [AgendaWidgetRenderer].
 */
class OggiWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            AgendaWidgetRenderer.aggiorna(context, appWidgetManager, widgetData, id)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        AgendaWidgetRenderer.aggiorna(
            context,
            appWidgetManager,
            HomeWidgetPlugin.getData(context),
            appWidgetId,
        )
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        val prefs = HomeWidgetPlugin.getData(context)
        for (id in appWidgetIds) {
            WidgetDayStato.pulisci(prefs, id)
            WidgetKit.pulisciOpzioni(prefs, id)
        }
    }
}

/** «Todo» 4x4: la lista da spuntare, con la stessa fascia dei giorni. */
class TodoWidgetProvider : PlannerWidget(Contenuto.TODO)
