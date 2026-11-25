package com.callmeste.planner.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.text.TextPaint
import android.widget.RemoteViews
import com.callmeste.planner.R
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * «Agenda» 4x4: la settimana del giorno scelto, il giorno e la sua lista.
 *
 * Stesse regole dei widget 1 e 2: Inter in bitmap, testata e striscia fisse,
 * lista scorrevole in un'area che non cambia altezza.
 */
object AgendaWidgetRenderer {

    private const val PAD = 12
    private const val CELLA_ALTEZZA = 48

    fun aggiorna(
        context: Context,
        manager: AppWidgetManager,
        prefs: SharedPreferences,
        id: Int,
    ) {
        val vista = disegna(context, prefs, id)
        try {
            vista.apply(context, null)
        } catch (errore: Exception) {
            android.util.Log.e("PlannerWidget", "agenda non applicata (id $id)", errore)
        }
        manager.updateAppWidget(id, vista)
    }

    fun disegna(context: Context, prefs: SharedPreferences, id: Int): RemoteViews {
        val colori = WidgetKit.colori(context, prefs)
        val vista = RemoteViews(context.packageName, R.layout.widget_agenda)
        val (larghezza, _) = WidgetMeseNuovoRenderer.misura(context, id, 340, 340)
        val contenuto = larghezza - 2 * PAD
        val scelto = WidgetDayStato.scelto(prefs, id)
        val oggi = WidgetPayload.dataOggi(prefs)

        vista.setInt(R.id.agenda_radice, "setBackgroundColor", colori.sfondo)
        vista.setInt(R.id.agenda_divisore, "setBackgroundColor", WidgetKit.bordo(context, prefs))

        WidgetText.scrivi(
            context, vista, R.id.agenda_titolo, etichetta(scelto, oggi),
            sp = 12.5f, peso = WidgetText.SEMIBOLD, colore = colori.accento,
            larghezzaDp = contenuto - 86, altezzaDp = 34, spaziatura = 0.06f,
        )
        vista.setOnClickPendingIntent(R.id.agenda_titolo, WidgetKit.apriGiorno(context, scelto))
        vista.setImageViewBitmap(
            R.id.agenda_indietro,
            WidgetMeseNuovoRenderer.freccia(context, true, 28, colori.tenue),
        )
        vista.setImageViewBitmap(
            R.id.agenda_avanti,
            WidgetMeseNuovoRenderer.freccia(context, false, 28, colori.tenue),
        )
        vista.setImageViewBitmap(R.id.agenda_nuovo, WidgetMeseNuovoRenderer.piu(context, 26, colori))
        vista.setOnClickPendingIntent(R.id.agenda_nuovo, WidgetKit.nuovoEvento(context, scelto))
        vista.setOnClickPendingIntent(
            R.id.agenda_indietro,
            pendenteSettimana(context, id, scelto, -1),
        )
        vista.setOnClickPendingIntent(
            R.id.agenda_avanti,
            pendenteSettimana(context, id, scelto, 1),
        )

        vista.removeAllViews(R.id.agenda_striscia)
        val lunedi = lunediDi(scelto)
        val cella = contenuto / 7
        for (indice in 0 until 7) {
            val data = WidgetPayload.dataDopo(lunedi, indice)
            vista.addView(
                R.id.agenda_striscia,
                cella(context, prefs, id, data, scelto, oggi, colori, cella),
            )
        }

        val completo = WidgetPayload.leggiGiorno(prefs, scelto)
        val eventiRighe = completo?.righe?.filter { !it.isTodo }.orEmpty()
        vista.removeAllViews(R.id.agenda_eventi)
        if (eventiRighe.isEmpty()) {
            if (completo == null) {
                val meseFuori = WidgetPayload.leggiMese(prefs, WidgetPayload.annoMese(scelto))
                val anteprime = meseFuori?.giorni
                    ?.firstOrNull { it.data == scelto }?.anteprime.orEmpty()
                if (anteprime.isEmpty()) {
                    vista.addView(
                        R.id.agenda_eventi,
                        WidgetMeseNuovoRenderer.rigaVuoto(
                            context, "Apri Planner per questo giorno", scelto,
                            contenuto, colori,
                        ),
                    )
                } else {
                    anteprime.take(3).forEach { a ->
                        vista.addView(
                            R.id.agenda_eventi,
                            WidgetMeseNuovoRenderer.rigaAnteprima(
                                context, a.titolo, a.colore, a.coloreScuro, scelto,
                                contenuto, colori,
                            ),
                        )
                    }
                }
            } else {
                vista.addView(
                    R.id.agenda_eventi,
                    WidgetMeseNuovoRenderer.rigaVuoto(
                        context, "Niente in programma", scelto, contenuto, colori,
                    ),
                )
            }
        } else {
            eventiRighe.take(3).forEachIndexed { indice, riga ->
                vista.addView(
                    R.id.agenda_eventi,
                    WidgetMeseNuovoRenderer.rigaEvento(
                        context, riga, scelto, contenuto, colori, indice, id,
                    ),
                )
            }
        }

        val mode = WidgetKit.todoMode(prefs, id)
        val todoRighe = completo?.righe?.filter { it.isTodo }.orEmpty()
        val aperto = WidgetKit.todoAperto(prefs, id)
        val haTodo = mode != TodoMode.NESSUNO && todoRighe.isNotEmpty()

        WidgetKit.setVisibile(vista, R.id.agenda_todo_barra, haTodo && mode == TodoMode.COMPATTI)
        WidgetKit.setVisibile(
            vista,
            R.id.agenda_eventi,
            mode != TodoMode.ESTESI && !(mode == TodoMode.COMPATTI && aperto),
        )
        WidgetKit.setVisibile(
            vista,
            R.id.agenda_todo_righe,
            haTodo && mode == TodoMode.COMPATTI && aperto,
        )
        vista.setViewPadding(
            R.id.agenda_eventi, 0, 0, 0,
            if (mode == TodoMode.COMPATTI && haTodo && !aperto) WidgetText.px(context, 36) else 0,
        )
        vista.setInt(R.id.agenda_todo_righe, "setBackgroundColor", colori.sfondo)
        vista.removeAllViews(R.id.agenda_todo_righe)
        if (!haTodo) return vista

        if (mode == TodoMode.COMPATTI) {
            val azione = if (aperto) "Nascondi" else "Mostra"
            vista.setImageViewBitmap(
                R.id.agenda_todo_barra,
                WidgetMeseNuovoRenderer.barraTodo(
                    context, contenuto, todoRighe.size, azione, aperto,
                    colori, WidgetKit.bordo(context, prefs),
                ),
            )
            vista.setOnClickPendingIntent(
                R.id.agenda_todo_barra,
                pendenteTodo(context, id),
            )
            if (aperto) {
                todoRighe.take(3).forEach { riga ->
                    vista.addView(
                        R.id.agenda_todo_righe,
                        WidgetMeseNuovoRenderer.rigaTodo(context, riga, scelto, contenuto, colori),
                    )
                }
            }
        } else {
            vista.removeAllViews(R.id.agenda_eventi)
            eventiRighe.take(2).forEachIndexed { indice, riga ->
                vista.addView(
                    R.id.agenda_eventi,
                    WidgetMeseNuovoRenderer.rigaEvento(
                        context, riga, scelto, contenuto, colori, indice, id,
                    ),
                )
            }
            if (eventiRighe.isEmpty() && completo == null) {
                val meseFuori = WidgetPayload.leggiMese(prefs, WidgetPayload.annoMese(scelto))
                meseFuori?.giorni?.firstOrNull { it.data == scelto }?.anteprime
                    ?.take(2)?.forEach { a ->
                        vista.addView(
                            R.id.agenda_eventi,
                            WidgetMeseNuovoRenderer.rigaAnteprima(
                                context, a.titolo, a.colore, a.coloreScuro, scelto,
                                contenuto, colori,
                            ),
                        )
                    }
            }
            todoRighe.take(2).forEach { riga ->
                vista.addView(
                    R.id.agenda_eventi,
                    WidgetMeseNuovoRenderer.rigaTodo(context, riga, scelto, contenuto, colori),
                )
            }
        }
        return vista
    }

    private fun pendenteTodo(context: Context, id: Int): PendingIntent {
        val intent = Intent(context, WidgetMeseReceiver::class.java).apply {
            action = WidgetMeseReceiver.AZIONE_TODO
            putExtra(WidgetMeseReceiver.EXTRA_ID, id)
        }
        return PendingIntent.getBroadcast(
            context,
            (id and 0x3FFF) * 256 + 201,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun cella(
        context: Context,
        prefs: SharedPreferences,
        id: Int,
        data: String,
        scelto: String,
        oggi: String,
        colori: WidgetKit.Colori,
        larghezzaDp: Int,
    ): RemoteViews {
        val vista = RemoteViews(context.packageName, R.layout.widget_agenda_cella)
        val bitmap = Bitmap.createBitmap(
            WidgetText.px(context, larghezzaDp).coerceAtLeast(1),
            WidgetText.px(context, CELLA_ALTEZZA).coerceAtLeast(1),
            Bitmap.Config.ARGB_8888,
        )
        val canvas = Canvas(bitmap)
        val densita = WidgetText.densita(context)
        val selezionato = data == scelto
        val centroX = bitmap.width / 2f
        val centroY = bitmap.height * 0.62f
        val raggio = minOf(bitmap.width.toFloat(), bitmap.height * 0.46f) * 0.42f

        if (selezionato) {
            canvas.drawCircle(
                centroX,
                centroY,
                raggio,
                Paint(Paint.ANTI_ALIAS_FLAG).apply { color = colori.accento },
            )
        } else if (data == oggi) {
            canvas.drawCircle(
                centroX,
                centroY,
                raggio,
                Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = WidgetMeseNuovoRenderer.accentoConAlpha(colori.accento, 0x22)
                },
            )
        }

        val nome = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = WidgetText.typeface(context, WidgetText.SEMIBOLD)
            textSize = 10.5f * densita
            color = colori.tenue
            textAlign = Paint.Align.CENTER
            letterSpacing = 0.06f
        }
        canvas.drawText(
            WidgetKit.etichettaGiornoBreve(data).uppercase(Locale.ITALIAN),
            centroX,
            bitmap.height * 0.22f,
            nome,
        )

        val numero = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = WidgetText.typeface(
                context,
                if (selezionato) WidgetText.SEMIBOLD else WidgetText.MEDIO,
            )
            textSize = 15f * densita
            color = if (selezionato) scuroSu(colori.accento) else colori.testo
            textAlign = Paint.Align.CENTER
        }
        val metriche = numero.fontMetrics
        canvas.drawText(
            data.takeLast(2).trimStart('0').ifEmpty { "1" },
            centroX,
            centroY - (metriche.ascent + metriche.descent) / 2f,
            numero,
        )

        val mese = WidgetPayload.leggiMese(prefs, WidgetPayload.annoMese(data))
        val giorno = mese?.giorni?.firstOrNull { it.data == data }
        vista.setContentDescription(
            R.id.agenda_cella_radice,
            "${WidgetKit.etichettaGiorno(data)}, ${giorno?.eventi ?: 0} eventi",
        )
        vista.setImageViewBitmap(R.id.agenda_cella_immagine, bitmap)
        vista.setOnClickPendingIntent(
            R.id.agenda_cella_radice,
            pendenteGiorno(context, id, data),
        )
        return vista
    }

    private fun pendenteGiorno(context: Context, id: Int, data: String): PendingIntent {
        val intent = Intent(context, AgendaWidgetReceiver::class.java).apply {
            action = AgendaWidgetReceiver.AZIONE_GIORNO
            putExtra(AgendaWidgetReceiver.EXTRA_ID, id)
            putExtra(AgendaWidgetReceiver.EXTRA_GIORNO, data)
        }
        return PendingIntent.getBroadcast(
            context,
            (id and 0x3FFF) * 256 + data.takeLast(2).toIntOrNull().orZero(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun pendenteSettimana(
        context: Context,
        id: Int,
        scelto: String,
        scarto: Int,
    ): PendingIntent {
        val intent = Intent(context, AgendaWidgetReceiver::class.java).apply {
            action = AgendaWidgetReceiver.AZIONE_SETTIMANA
            putExtra(AgendaWidgetReceiver.EXTRA_ID, id)
            putExtra(AgendaWidgetReceiver.EXTRA_SCARTO, scarto)
        }
        return PendingIntent.getBroadcast(
            context,
            (id and 0x3FFF) * 256 + if (scarto < 0) 50 else 51,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun etichetta(data: String, oggi: String): String {
        val breve = WidgetKit.etichettaGiorno(data).uppercase(Locale.ITALIAN)
        return if (data == oggi) "OGGI · $breve" else breve
    }

    private fun lunediDi(data: String): String {
        val forma = SimpleDateFormat("yyyy-MM-dd", Locale.ITALY)
        val calendario = Calendar.getInstance().apply {
            clear()
            time = forma.parse(data) ?: return data
        }
        val giorno = calendario.get(Calendar.DAY_OF_WEEK)
        val scarto = (giorno + 5) % 7
        return WidgetPayload.dataDopo(data, -scarto)
    }

    private fun scuroSu(colore: Int): Int {
        val luminanza = (0.299 * android.graphics.Color.red(colore) +
            0.587 * android.graphics.Color.green(colore) +
            0.114 * android.graphics.Color.blue(colore)) / 255.0
        return if (luminanza > 0.6) android.graphics.Color.rgb(17, 24, 28)
        else android.graphics.Color.WHITE
    }

    private fun Int?.orZero(): Int = this ?: 0
}

/** I tocchi interni all'Agenda: giorno della striscia e settimana. */
class AgendaWidgetReceiver : BroadcastReceiver() {

    companion object {
        const val AZIONE_GIORNO = "com.callmeste.planner.widget.AGENDA_GIORNO"
        const val AZIONE_SETTIMANA = "com.callmeste.planner.widget.AGENDA_SETTIMANA"
        const val EXTRA_ID = "appWidgetId"
        const val EXTRA_GIORNO = "giorno"
        const val EXTRA_SCARTO = "scarto"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(EXTRA_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        if (id == AppWidgetManager.INVALID_APPWIDGET_ID) return
        val prefs = HomeWidgetPluginData.of(context)
        when (intent.action) {
            AZIONE_GIORNO -> {
                val data = intent.getStringExtra(EXTRA_GIORNO) ?: return
                WidgetDayStato.scrivi(prefs, id, data)
            }

            AZIONE_SETTIMANA -> {
                val scarto = intent.getIntExtra(EXTRA_SCARTO, 0)
                val scelto = WidgetDayStato.scelto(prefs, id)
                WidgetDayStato.scrivi(prefs, id, WidgetPayload.dataDopo(scelto, scarto * 7))
            }
        }
        AgendaWidgetRenderer.aggiorna(
            context,
            AppWidgetManager.getInstance(context),
            prefs,
            id,
        )
    }
}

/** Piccolo aiuto per non importare il plugin in due punti. */
private object HomeWidgetPluginData {
    fun of(context: Context): SharedPreferences =
        es.antonborri.home_widget.HomeWidgetPlugin.getData(context)
}
