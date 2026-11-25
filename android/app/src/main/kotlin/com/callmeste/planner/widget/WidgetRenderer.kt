package com.callmeste.planner.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import com.callmeste.planner.MainActivity
import com.callmeste.planner.R
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import java.text.SimpleDateFormat
import java.util.Locale

/** Lo stato del widget Â«GiornoÂ»: la data scelta nella fascia, per widget id. */
object WidgetDayStato {
    private val FORMA = Regex("\\d{4}-\\d{2}-\\d{2}")

    fun chiave(id: Int) = "widget_giorno_scelto_$id"

    fun scelto(prefs: SharedPreferences, id: Int): String =
        prefs.getString(chiave(id), null)?.takeIf { FORMA.matches(it) }
            ?: WidgetPayload.dataOggi(prefs)

    fun scrivi(prefs: SharedPreferences, id: Int, data: String) {
        prefs.edit().putString(chiave(id), data).apply()
    }

    fun pulisci(prefs: SharedPreferences, id: Int) {
        prefs.edit().remove(chiave(id)).apply()
    }
}

/**
 * Il disegno del **giorno 4x4**: testata fissa, fascia di cinque giorni
 * selezionabili e quattro righe grandi. La testata e la fascia non si muovono
 * quando non c'Ã¨ niente: cambia solo il corpo.
 */
object WidgetRenderer {

    private const val RIGHE_MASSIME = 4
    private const val CELLE_GIORNI = 7

    fun disegna(
        context: Context,
        contenuto: Contenuto,
        prefs: SharedPreferences,
        appWidgetId: Int,
        altezzaDp: Int,
    ): RemoteViews {
        val colori = WidgetKit.colori(context, prefs)
        val vista = RemoteViews(context.packageName, R.layout.widget_planner)
        val scelto = WidgetDayStato.scelto(prefs, appWidgetId)
        val oggi = WidgetPayload.dataOggi(prefs)
        val todoMode = if (contenuto == Contenuto.TODO) {
            TodoMode.ESTESI
        } else {
            WidgetKit.todoMode(prefs, appWidgetId)
        }
        val giorno = WidgetPayload.leggiGiorno(prefs, scelto)

        vista.setInt(R.id.widget_radice, "setBackgroundColor", colori.sfondo)
        vista.setTextColor(R.id.widget_titolo, colori.testo)
        vista.setTextColor(R.id.widget_conteggi, colori.tenue)
        vista.setTextColor(R.id.widget_stato_icon, colori.tenue)
        vista.setTextColor(R.id.widget_stato, colori.tenue)
        vista.setTextViewText(
            R.id.widget_titolo,
            giorno?.etichetta?.ifEmpty { etichettaLunga(scelto, oggi) }
                ?: etichettaLunga(scelto, oggi),
        )
        vista.setTextViewText(
            R.id.widget_conteggi,
            WidgetKit.conteggi(context, giorno, contenuto, todoMode),
        )
        vista.setOnClickPendingIntent(
            R.id.widget_intestazione,
            WidgetKit.apriGiorno(context, scelto),
        )
        vista.setOnClickPendingIntent(
            R.id.widget_radice,
            WidgetKit.apriGiorno(context, scelto),
        )
        vista.setOnClickPendingIntent(
            R.id.widget_stato_riga,
            WidgetKit.apriGiorno(context, scelto),
        )

        disegnaGiorni(
            context, vista, appWidgetId, scelto, oggi, contenuto, colori,
        )

        val righe = giorno?.let {
            WidgetKit.righe(it, contenuto, todoMode)
        }.orEmpty().take(RIGHE_MASSIME)

        vista.removeAllViews(R.id.widget_righe)
        for (riga in righe) {
            vista.addView(
                R.id.widget_righe,
                riga(context, todoMode, riga, colori, scelto),
            )
        }

        if (righe.isEmpty()) {
            WidgetKit.setVisibile(vista, R.id.widget_righe, false)
            WidgetKit.setVisibile(vista, R.id.widget_stato_riga, true)
            vista.setTextViewText(R.id.widget_stato_icon, "â—‹")
            vista.setTextViewText(
                R.id.widget_stato,
                WidgetKit.vuoto(context, giorno, contenuto, todoMode),
            )
        } else {
            WidgetKit.setVisibile(vista, R.id.widget_righe, true)
            WidgetKit.setVisibile(vista, R.id.widget_stato_riga, false)
        }
        return vista
    }

    /** La fascia di sette giorni: il selezionato al centro, gli altri intorno. */
    private fun disegnaGiorni(
        context: Context,
        vista: RemoteViews,
        appWidgetId: Int,
        scelto: String,
        oggi: String,
        contenuto: Contenuto,
        colori: WidgetKit.Colori,
    ) {
        vista.removeAllViews(R.id.widget_giorni)
        val inizio = WidgetPayload.dataDopo(scelto, -(CELLE_GIORNI / 2))
        for (indice in 0 until CELLE_GIORNI) {
            val data = WidgetPayload.dataDopo(inizio, indice)
            val cella = RemoteViews(context.packageName, R.layout.widget_giorno_cella)
            val selezionato = data == scelto
            val eOggi = data == oggi
            cella.setTextViewText(R.id.giorno_nome, nomeGiorno(data))
            cella.setTextViewText(R.id.giorno_numero, numero(data))
            cella.setTextColor(
                R.id.giorno_nome,
                if (selezionato) colori.accento else colori.tenue,
            )
            cella.setTextColor(
                R.id.giorno_numero,
                if (selezionato || eOggi) colori.accento else colori.testo,
            )
            cella.setViewVisibility(
                R.id.giorno_cerchio,
                if (selezionato) View.VISIBLE else View.INVISIBLE,
            )
            if (selezionato) {
                cella.setInt(
                    R.id.giorno_cerchio,
                    "setColorFilter",
                    accentoConAlpha(colori.accento, 0x45),
                )
            }
            cella.setViewVisibility(
                R.id.giorno_oggi,
                if (eOggi && !selezionato) View.VISIBLE else View.INVISIBLE,
            )
            if (eOggi) {
                cella.setInt(R.id.giorno_oggi, "setColorFilter", colori.accento)
            }
            cella.setContentDescription(
                R.id.giorno_radice,
                "${nomeGiorno(data)} ${numero(data)}" +
                    if (selezionato) ", selezionato" else "",
            )
            cella.setOnClickPendingIntent(
                R.id.giorno_radice,
                pendenteGiorno(context, appWidgetId, data, contenuto),
            )
            vista.addView(R.id.widget_giorni, cella)
        }
    }

    private fun pendenteGiorno(
        context: Context,
        appWidgetId: Int,
        data: String,
        contenuto: Contenuto,
    ): PendingIntent {
        val intent = Intent(context, WidgetGiornoReceiver::class.java).apply {
            action = WidgetGiornoReceiver.AZIONE_GIORNO
            putExtra(WidgetGiornoReceiver.EXTRA_ID, appWidgetId)
            putExtra(WidgetGiornoReceiver.EXTRA_GIORNO, data)
            putExtra(WidgetGiornoReceiver.EXTRA_CONTENUTO, contenuto.name)
        }
        return PendingIntent.getBroadcast(
            context,
            (appWidgetId and 0x3FFF) * 16 + (data.hashCode() and 0x0F),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /**
     * Una riga: colore, segno, titolo e ora. Gli eventi aprono il form; i todo
     * hanno anche la spunta che scrive in background.
     */
    private fun riga(
        context: Context,
        todoMode: TodoMode,
        riga: WidgetRow,
        colori: WidgetKit.Colori,
        data: String,
    ): RemoteViews {
        if (todoMode == TodoMode.COMPATTI && riga.isTodo) {
            return rigaCompatta(context, riga, colori, data)
        }
        val vista = RemoteViews(context.packageName, R.layout.widget_riga)
        val colore = WidgetKit.coloreRiga(riga, WidgetKit.isNotte(context), colori.tenue)
        vista.setTextViewText(R.id.riga_titolo, riga.titolo)
        vista.setTextColor(
            R.id.riga_titolo,
            if (riga.fatto) colori.tenue else colori.testo,
        )
        if (riga.isTodo) {
            // Un To-Do ha un solo segno a sinistra: la spunta. Niente emoji,
            // barretta o etichetta «todo» ripetuta a destra.
            vista.setViewVisibility(R.id.riga_segno, View.GONE)
            vista.setViewVisibility(R.id.riga_barretta, View.GONE)
            vista.setViewVisibility(R.id.riga_ora, View.VISIBLE)
            vista.setTextColor(R.id.riga_ora, colori.tenue)
            vista.setTextViewText(
                R.id.riga_ora,
                if (riga.ora.isEmpty()) "oggi" else riga.ora,
            )
            vista.setViewVisibility(R.id.riga_in_corso, View.GONE)
            vista.setViewVisibility(R.id.riga_spunta, View.VISIBLE)
            vista.setImageViewResource(
                R.id.riga_spunta,
                if (riga.fatto) R.drawable.widget_spunta_fatta else R.drawable.widget_spunta_vuota,
            )
            vista.setInt(R.id.riga_spunta, "setColorFilter", colore)
            vista.setOnClickPendingIntent(
                R.id.riga_spunta,
                HomeWidgetBackgroundIntent.getBroadcast(
                    context,
                    Uri.parse("planner://spunta?tipo=todo&id=${Uri.encode(riga.id)}&giorno=$data"),
                ),
            )
        } else {
            vista.setViewVisibility(R.id.riga_segno, View.VISIBLE)
            vista.setViewVisibility(R.id.riga_barretta, View.VISIBLE)
            vista.setViewVisibility(R.id.riga_ora, View.VISIBLE)
            vista.setViewVisibility(R.id.riga_spunta, View.GONE)
            vista.setTextColor(R.id.riga_ora, colori.tenue)
            vista.setTextViewText(
                R.id.riga_ora,
                if (riga.ora.isEmpty()) "Tutto il giorno" else riga.ora,
            )
            if (riga.emoji.isEmpty()) {
                vista.setTextViewText(R.id.riga_segno, "•")
                vista.setTextColor(R.id.riga_segno, colore)
            } else {
                vista.setTextViewText(R.id.riga_segno, riga.emoji)
            }
            if (riga.inCorso) {
                // Un solo segno colorato: la barretta «in corso» sostituisce
                // quella della categoria, non si somma a essa.
                vista.setViewVisibility(R.id.riga_in_corso, View.VISIBLE)
                vista.setInt(R.id.riga_in_corso, "setBackgroundColor", colore)
                vista.setViewVisibility(R.id.riga_barretta, View.GONE)
            } else {
                vista.setViewVisibility(R.id.riga_in_corso, View.GONE)
                vista.setViewVisibility(R.id.riga_barretta, View.VISIBLE)
                vista.setInt(R.id.riga_barretta, "setBackgroundColor", colore)
            }
        }

        vista.setOnClickPendingIntent(
            R.id.riga_radice,
            WidgetKit.apriElemento(context, riga.tipo, riga.id, data),
        )
        return vista
    }

    /** Todo compatto: una riga, senza orario, con la spunta sempre visibile. */
    private fun rigaCompatta(
        context: Context,
        riga: WidgetRow,
        colori: WidgetKit.Colori,
        data: String,
    ): RemoteViews {
        val vista = RemoteViews(context.packageName, R.layout.widget_riga_compatta)
        val colore = WidgetKit.coloreRiga(riga, WidgetKit.isNotte(context), colori.tenue)
        vista.setTextViewText(R.id.riga_titolo, riga.titolo)
        vista.setTextColor(
            R.id.riga_titolo,
            if (riga.fatto) colori.tenue else colori.testo,
        )
        vista.setViewVisibility(R.id.riga_barretta, View.GONE)
        vista.setViewVisibility(R.id.riga_spunta, View.VISIBLE)
        vista.setImageViewResource(
            R.id.riga_spunta,
            if (riga.fatto) R.drawable.widget_spunta_fatta else R.drawable.widget_spunta_vuota,
        )
        vista.setInt(R.id.riga_spunta, "setColorFilter", colore)
        vista.setOnClickPendingIntent(
            R.id.riga_spunta,
            HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse("planner://spunta?tipo=todo&id=${Uri.encode(riga.id)}&giorno=$data"),
            ),
        )
        vista.setOnClickPendingIntent(
            R.id.riga_radice,
            WidgetKit.apriElemento(context, riga.tipo, riga.id, data),
        )
        return vista
    }

    private fun etichettaLunga(data: String, oggi: String): String =
        "${WidgetKit.etichettaData(data, oggi)} Â· ${WidgetKit.etichettaGiorno(data)}"

    private fun nomeGiorno(data: String): String = try {
        val forma = SimpleDateFormat("yyyy-MM-dd", Locale.ITALY)
        SimpleDateFormat("EEE", Locale.ITALIAN)
            .format(forma.parse(data)!!)
            .lowercase(Locale.ITALIAN)
    } catch (errore: Exception) {
        ""
    }

    private fun numero(data: String): String = data.takeLast(2).trimStart('0')

    private fun accentoConAlpha(accento: Int, alpha: Int): Int =
        (alpha shl 24) or (accento and 0xFFFFFF)
}

/**
 * Il tocco su un giorno della fascia: salva la scelta **per questo widget** e
 * ridisegna. Non apre l'app: il giorno si guarda nel widget.
 */
class WidgetGiornoReceiver : android.content.BroadcastReceiver() {

    companion object {
        const val AZIONE_GIORNO = "com.callmeste.planner.widget.GIORNO_SCELTO"
        const val EXTRA_ID = "appWidgetId"
        const val EXTRA_GIORNO = "giorno"
        const val EXTRA_CONTENUTO = "contenuto"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(EXTRA_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        val data = intent.getStringExtra(EXTRA_GIORNO)
        if (id == AppWidgetManager.INVALID_APPWIDGET_ID || data == null) return
        val prefs = es.antonborri.home_widget.HomeWidgetPlugin.getData(context)
        WidgetDayStato.scrivi(prefs, id, data)
        val contenuto = intent.getStringExtra(EXTRA_CONTENUTO)
            ?.let { runCatching { Contenuto.valueOf(it) }.getOrNull() }
            ?: Contenuto.MISTO
        val manager = AppWidgetManager.getInstance(context)
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
            android.util.Log.e("PlannerWidget", "giorno non applicato", errore)
        }
        manager.updateAppWidget(id, vista)
    }
}
