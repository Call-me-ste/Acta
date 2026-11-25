package com.callmeste.planner.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.text.TextPaint
import android.view.View
import android.widget.RemoteViews
import com.callmeste.planner.R
import java.util.Locale

/**
 * Il disegno nuovo dei due widget del mese (4x2 e 4x4), fedele a
 * `docs/widget-linee-guida.md`:
 *
 * * tutto il testo è Inter disegnato in bitmap (`WidgetText`), mai un
 *   `TextView` che il launcher possa rendere col serif di sistema;
 * * la griglia del mese è **statica**: le misure vengono dai bounds del widget,
 *   non dal contenuto, quindi cambiare giorno non muove niente;
 * * un solo cerchio: il giorno scelto. Oggi, se non è scelto, resta normale.
 */
object WidgetMeseNuovoRenderer {

    private const val PAD_4X2 = 10
    private const val PAD_4X4 = 12

    private const val NUMERO_GRIGLIA = 14f
    private const val GIORNI_SETTIMANA = 10.5f

    /** Disegna e aggiorna, con il log se il launcher rifiuta le RemoteViews. */
    fun aggiorna(
        context: Context,
        manager: AppWidgetManager,
        prefs: SharedPreferences,
        id: Int,
        variante: WidgetMeseRenderer.Variante,
    ) {
        val vista = disegna(context, prefs, id, variante)
        try {
            vista.apply(context, null)
        } catch (errore: Exception) {
            android.util.Log.e("PlannerWidget", "mese nuovo non applicato (id $id)", errore)
        }
        manager.updateAppWidget(id, vista)
        if (variante == WidgetMeseRenderer.Variante.MESE_4X4) {
        }
    }

    fun disegna(
        context: Context,
        prefs: SharedPreferences,
        appWidgetId: Int,
        variante: WidgetMeseRenderer.Variante,
    ): RemoteViews {
        return when (variante) {
            WidgetMeseRenderer.Variante.MESE_4X2 -> disegna4x2(context, prefs, appWidgetId)
            WidgetMeseRenderer.Variante.MESE_4X4 -> disegna4x4(context, prefs, appWidgetId)
            WidgetMeseRenderer.Variante.MESE_2X2 -> WidgetMeseRenderer.disegna(
                context,
                prefs,
                appWidgetId,
                WidgetKit.altezza(AppWidgetManager.getInstance(context), appWidgetId),
                variante,
            )
        }
    }

    // ---------------------------------------------------------------- 4x2

    private fun disegna4x2(
        context: Context,
        prefs: SharedPreferences,
        id: Int,
    ): RemoteViews {
        val colori = WidgetKit.colori(context, prefs)
        val vista = RemoteViews(context.packageName, R.layout.widget_mese)
        vista.setInt(R.id.mese_radice, "setBackgroundColor", colori.sfondo)

        val (larghezza, altezza) = misura(context, id, 328, 150)
        val contenuto = larghezza - 2 * PAD_4X2
        val sinistra = (contenuto * 0.38f).toInt()
        val destra = (contenuto - sinistra - 8).coerceAtLeast(80)
        val testataGriglia = 13
        val altezzaGriglia = (altezza - 2 * PAD_4X2 - testataGriglia - 1).coerceAtLeast(60)
        val riga = altezzaGriglia / 6
        val cella = destra / 7

        val pubblicati = WidgetPayload.mesiPubblicati(prefs)
        val annoMese = WidgetMeseStato.vista(prefs, id)
        val scelto = WidgetMeseStato.scelto(prefs, id)
        val mese = WidgetPayload.leggiMese(prefs, annoMese)
        // Niente anno: «OTTOBRE» basta, e respira meglio.
        val etichettaMese = (mese?.etichetta?.ifEmpty { null }
            ?: WidgetPayload.etichettaMese(annoMese))
            .substringBefore(" ")
            .uppercase(Locale.ITALIAN)
        val numero = scelto.takeLast(2).trimStart('0').ifEmpty { "1" }
        val nomeGiorno = WidgetKit.etichettaGiornoLunga(scelto)

        WidgetText.scrivi(
            context, vista, R.id.mese_eyebrow, etichettaMese,
            sp = 14.5f, peso = WidgetText.SEMIBOLD, colore = colori.tenue,
            larghezzaDp = sinistra, altezzaDp = 18, spaziatura = 0.08f,
            align = Paint.Align.CENTER,
        )
        WidgetText.scrivi(
            context, vista, R.id.mese_giorno_nome, nomeGiorno,
            sp = 18f, peso = WidgetText.MEDIO, colore = colori.accento,
            larghezzaDp = sinistra, altezzaDp = 24,
            align = Paint.Align.CENTER,
        )
        WidgetText.scrivi(
            context, vista, R.id.mese_giorno_numero, numero,
            sp = 60f, peso = WidgetText.SEMIBOLD, colore = colori.testo,
            larghezzaDp = sinistra, altezzaDp = 64,
            align = Paint.Align.CENTER,
        )
        vista.setImageViewBitmap(
            R.id.mese_settimana_immagine,
            testataSettimana(context, destra, testataGriglia, cella, 7, colori.tenue),
        )

        vista.setOnClickPendingIntent(R.id.mese_giorno_numero, WidgetKit.apriGiorno(context, scelto))
        vista.setOnClickPendingIntent(R.id.mese_giorno_nome, WidgetKit.apriGiorno(context, scelto))
        vista.setOnClickPendingIntent(R.id.mese_eyebrow, WidgetKit.apriGiorno(context, scelto))

        vista.removeAllViews(R.id.mese_griglia)
        val griglia = griglia(
            context = context,
            prefs = prefs,
            vista = vista,
            id = id,
            variante = WidgetMeseRenderer.Variante.MESE_4X2,
            mese = mese,
            scelto = scelto,
            cella = cella,
            riga = riga,
            colori = colori,
            pubblicati = pubblicati,
        )
        if (!griglia) {
            WidgetKit.setVisibile(vista, R.id.mese_nota, true)
            vista.setTextColor(R.id.mese_nota, colori.tenue)
        } else {
            WidgetKit.setVisibile(vista, R.id.mese_nota, false)
        }
        return vista
    }

    // ---------------------------------------------------------------- 4x4

    private fun disegna4x4(
        context: Context,
        prefs: SharedPreferences,
        id: Int,
    ): RemoteViews {
        val colori = WidgetKit.colori(context, prefs)
        val vista = RemoteViews(context.packageName, R.layout.widget_mese_grande)
        val (larghezza, altezza) = misura(context, id, 340, 340)
        vista.setInt(R.id.mese_radice, "setBackgroundColor", colori.sfondo)

        val contenuto = larghezza - 2 * PAD_4X4
        val sinistra = (contenuto * 0.34f).toInt()
        val destra = (contenuto - sinistra - 8).coerceAtLeast(80)
        val pesoTestata = 0.53f
        val altezzaTestata = ((altezza - 2 * PAD_4X4 - 7 - 34) * pesoTestata).toInt()
        val altezzaGriglia = (altezzaTestata - 22 - 12 - 1).coerceAtLeast(60)
        val riga = altezzaGriglia / 6
        val cella = destra / 7

        val pubblicati = WidgetPayload.mesiPubblicati(prefs)
        val annoMese = WidgetMeseStato.vista(prefs, id)
        val scelto = WidgetMeseStato.scelto(prefs, id)
        val mese = WidgetPayload.leggiMese(prefs, annoMese)
        val numero = scelto.takeLast(2).trimStart('0').ifEmpty { "1" }
        val oggi = WidgetPayload.dataOggi(prefs)

        WidgetText.scrivi(
            context, vista, R.id.mese_eyebrow,
            WidgetPayload.etichettaMese(annoMese).substringBefore(" ").uppercase(Locale.ITALIAN),
            sp = 14.5f, peso = WidgetText.SEMIBOLD, colore = colori.tenue,
            larghezzaDp = sinistra, altezzaDp = 19, spaziatura = 0.08f,
            align = Paint.Align.CENTER,
        )
        WidgetText.scrivi(
            context, vista, R.id.mese_giorno_nome, WidgetKit.etichettaGiornoLunga(scelto),
            sp = 18f, peso = WidgetText.MEDIO, colore = colori.accento,
            larghezzaDp = sinistra, altezzaDp = 25,
            align = Paint.Align.CENTER,
        )
        WidgetText.scrivi(
            context, vista, R.id.mese_giorno_numero, numero,
            sp = 60f, peso = WidgetText.SEMIBOLD, colore = colori.testo,
            larghezzaDp = sinistra, altezzaDp = 64,
            align = Paint.Align.CENTER,
        )
        val completo = WidgetPayload.leggiGiorno(prefs, scelto)
        val eventi = completo?.eventi ?: 0
        val todo = completo?.todo ?: 0
        val eventiMese = if (completo == null) {
            WidgetPayload.leggiMese(prefs, WidgetPayload.annoMese(scelto))
                ?.giorni?.firstOrNull { it.data == scelto }?.eventi ?: 0
        } else {
            0
        }
        WidgetText.scrivi(
            context, vista, R.id.mese_conteggio,
            when {
                completo == null && eventiMese == 0 -> "Niente in programma"
                completo == null && eventiMese == 1 -> "1 evento"
                completo == null -> "$eventiMese eventi"
                eventi == 0 && todo == 0 -> "Niente in programma"
                eventi == 0 -> if (todo == 1) "1 To do" else "$todo To do"
                eventi == 1 -> "1 evento"
                else -> "$eventi eventi"
            },
            sp = 11.5f, peso = WidgetText.MEDIO, colore = colori.tenue,
            larghezzaDp = sinistra, altezzaDp = 19,
            align = Paint.Align.CENTER,
        )
        vista.setImageViewBitmap(
            R.id.mese_titolo,
            titoloMese(context, larghezzaDp = destra - 56, altezzaDp = 22, annoMese, colori),
        )
        vista.setImageViewBitmap(
            R.id.mese_indietro,
            freccia(context, sinistra = true, latoDp = 28, colore = colori.tenue),
        )
        vista.setImageViewBitmap(
            R.id.mese_avanti,
            freccia(context, sinistra = false, latoDp = 28, colore = colori.tenue),
        )
        vista.setImageViewBitmap(
            R.id.mese_settimana_immagine,
            testataSettimana(context, destra, 12, cella, 7, colori.tenue),
        )
        vista.setInt(R.id.mese_divisore, "setBackgroundColor", WidgetKit.bordo(context, prefs))

        WidgetText.scrivi(
            context, vista, R.id.mese_giorno_titolo,
            etichettaGiorno(scelto, oggi),
            sp = 12.5f, peso = WidgetText.SEMIBOLD, colore = colori.accento,
            larghezzaDp = contenuto - 34, altezzaDp = 34, spaziatura = 0.06f,
        )
        vista.setImageViewBitmap(R.id.mese_nuovo, piu(context, 26, colori))
        vista.setOnClickPendingIntent(R.id.mese_nuovo, WidgetKit.nuovoEvento(context, scelto))
        vista.setOnClickPendingIntent(R.id.mese_giorno_titolo, WidgetKit.apriGiorno(context, scelto))
        vista.setOnClickPendingIntent(R.id.mese_giorno_numero, WidgetKit.apriGiorno(context, scelto))
        vista.setOnClickPendingIntent(R.id.mese_giorno_nome, WidgetKit.apriGiorno(context, scelto))
        collegaFrecce(
            context, vista, R.id.mese_indietro, R.id.mese_avanti, id, annoMese,
            pubblicati, WidgetMeseRenderer.Variante.MESE_4X4,
        )

        vista.removeAllViews(R.id.mese_griglia)
        griglia(
            context = context,
            prefs = prefs,
            vista = vista,
            id = id,
            variante = WidgetMeseRenderer.Variante.MESE_4X4,
            mese = mese,
            scelto = scelto,
            cella = cella,
            riga = riga,
            colori = colori,
            pubblicati = pubblicati,
        )
        WidgetKit.setVisibile(vista, R.id.mese_nota, false)

        val eventiRighe = completo?.righe?.filter { !it.isTodo }.orEmpty()
        vista.removeAllViews(R.id.mese_eventi)
        if (eventiRighe.isEmpty()) {
            if (completo == null) {
                val meseFuori = WidgetPayload.leggiMese(prefs, WidgetPayload.annoMese(scelto))
                val anteprime = meseFuori?.giorni
                    ?.firstOrNull { it.data == scelto }?.anteprime.orEmpty()
                if (anteprime.isEmpty()) {
                    vista.addView(
                        R.id.mese_eventi,
                        rigaVuoto(
                            context, "Apri Planner per questo giorno", scelto,
                            contenuto, colori,
                        ),
                    )
                } else {
                    anteprime.take(2).forEach { a ->
                        vista.addView(
                            R.id.mese_eventi,
                            rigaAnteprima(
                                context, a.titolo, a.colore, a.coloreScuro, scelto,
                                contenuto, colori,
                            ),
                        )
                    }
                }
            } else {
                vista.addView(
                    R.id.mese_eventi,
                    rigaVuoto(context, "Niente in programma", scelto, contenuto, colori),
                )
            }
        } else {
            eventiRighe.take(2).forEachIndexed { indice, riga ->
                vista.addView(
                    R.id.mese_eventi,
                    rigaEvento(context, riga, scelto, contenuto, colori, indice, id),
                )
            }
        }

        val mode = WidgetKit.todoMode(prefs, id)
        val todoRighe = completo?.righe?.filter { it.isTodo }.orEmpty()
        val aperto = WidgetKit.todoAperto(prefs, id)
        val haTodo = mode != TodoMode.NESSUNO && todoRighe.isNotEmpty()

        // Compatta: barra fissa in fondo. Aperta, i To do prendono il posto
        // degli eventi (lo spazio è quello, non si sovrappone niente).
        // Estesa: niente barra, eventi e To do nella stessa lista.
        WidgetKit.setVisibile(vista, R.id.mese_todo_barra, haTodo && mode == TodoMode.COMPATTI)
        WidgetKit.setVisibile(
            vista,
            R.id.mese_eventi,
            mode != TodoMode.ESTESI && !(mode == TodoMode.COMPATTI && aperto),
        )
        WidgetKit.setVisibile(
            vista,
            R.id.mese_todo_righe,
            haTodo && mode == TodoMode.COMPATTI && aperto,
        )
        vista.setViewPadding(
            R.id.mese_eventi, 0, 0, 0,
            if (mode == TodoMode.COMPATTI && haTodo && !aperto) WidgetText.px(context, 36) else 0,
        )
        vista.setInt(R.id.mese_todo_righe, "setBackgroundColor", colori.sfondo)
        vista.removeAllViews(R.id.mese_todo_righe)
        if (!haTodo) return vista

        if (mode == TodoMode.COMPATTI) {
            val azione = if (aperto) "Nascondi" else "Mostra"
            vista.setImageViewBitmap(
                R.id.mese_todo_barra,
                barraTodo(
                    context, contenuto, todoRighe.size, azione, aperto,
                    colori, WidgetKit.bordo(context, prefs),
                ),
            )
            vista.setOnClickPendingIntent(
                R.id.mese_todo_barra,
                pendenteTodo(context, id, WidgetMeseRenderer.Variante.MESE_4X4),
            )
            if (aperto) {
                todoRighe.take(3).forEach { riga ->
                    vista.addView(
                        R.id.mese_todo_righe,
                        rigaTodo(context, riga, scelto, contenuto, colori),
                    )
                }
            }
        } else {
            // Estesa: 1 evento + 2 To do entrano nell'area del 4x4.
            vista.removeAllViews(R.id.mese_eventi)
            eventiRighe.take(1).forEachIndexed { indice, riga ->
                vista.addView(
                    R.id.mese_eventi,
                    rigaEvento(context, riga, scelto, contenuto, colori, indice, id),
                )
            }
            if (eventiRighe.isEmpty() && completo == null) {
                val meseFuori = WidgetPayload.leggiMese(prefs, WidgetPayload.annoMese(scelto))
                meseFuori?.giorni?.firstOrNull { it.data == scelto }?.anteprime
                    ?.take(1)?.forEach { a ->
                        vista.addView(
                            R.id.mese_eventi,
                            rigaAnteprima(
                                context, a.titolo, a.colore, a.coloreScuro, scelto,
                                contenuto, colori,
                            ),
                        )
                    }
            }
            todoRighe.take(2).forEach { riga ->
                vista.addView(
                    R.id.mese_eventi,
                    rigaTodo(context, riga, scelto, contenuto, colori),
                )
            }
        }
        return vista
    }

    // ----------------------------------------------------------- righe

    /** Una riga evento: barra, orario e titolo; il tocco apre l'elemento. */
    internal fun rigaEvento(
        context: Context,
        riga: WidgetRow,
        giorno: String,
        larghezzaDp: Int,
        colori: WidgetKit.Colori,
        indice: Int,
        id: Int,
    ): RemoteViews {
        val vista = RemoteViews(context.packageName, R.layout.widget_mese_voce2)
        val bitmap = bitmapRiga(context, larghezzaDp) { canvas, densita, larghezza, altezza ->
            barra(canvas, densita, WidgetKit.coloreRiga(riga, WidgetKit.isNotte(context), colori.tenue))
            val partenza = WidgetText.px(context, 24)
            if (riga.ora.isNotBlank()) {
                testoRiga(
                    context, canvas, riga.ora, 12.5f, WidgetText.SEMIBOLD, colori.testo,
                    partenza, WidgetText.px(context, 48), altezza,
                )
            }
            val x = if (riga.ora.isNotBlank()) partenza + WidgetText.px(context, 54) else partenza
            testoRiga(
                context, canvas, riga.titolo, 15f, WidgetText.SEMIBOLD, colori.testo,
                x, larghezza - x - WidgetText.px(context, 4), altezza,
            )
        }
        vista.setImageViewBitmap(R.id.voce2_immagine, bitmap)
        vista.setContentDescription(R.id.voce2_radice, riga.titolo)
        vista.setOnClickPendingIntent(
            R.id.voce2_radice,
            apriElemento(context, riga, giorno, (id and 0x3FFF) * 256 + 20 + indice),
        )
        return vista
    }

    /** Una riga To do: spunta, titolo e orario; il tocco spunta in background. */
    internal fun rigaTodo(
        context: Context,
        riga: WidgetRow,
        giorno: String,
        larghezzaDp: Int,
        colori: WidgetKit.Colori,
    ): RemoteViews {
        val vista = RemoteViews(context.packageName, R.layout.widget_mese_voce2)
        val bitmap = bitmapRiga(context, larghezzaDp) { canvas, densita, larghezza, altezza ->
            spuntaRiga(
                canvas, densita,
                WidgetKit.coloreRiga(riga, WidgetKit.isNotte(context), colori.tenue),
                riga.fatto, altezza,
            )
            val partenza = WidgetText.px(context, 24)
            testoRiga(
                context, canvas, riga.titolo, 15f, WidgetText.SEMIBOLD,
                if (riga.fatto) colori.tenue else colori.testo,
                partenza, larghezza - partenza - WidgetText.px(context, 58), altezza,
            )
            if (riga.ora.isNotBlank()) {
                testoRiga(
                    context, canvas, riga.ora, 12.5f, WidgetText.SEMIBOLD, colori.tenue,
                    larghezza - WidgetText.px(context, 56), WidgetText.px(context, 48), altezza,
                    align = Paint.Align.RIGHT,
                )
            }
        }
        vista.setImageViewBitmap(R.id.voce2_immagine, bitmap)
        vista.setContentDescription(R.id.voce2_radice, riga.titolo)
        vista.setOnClickPendingIntent(
            R.id.voce2_radice,
            es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                context,
                android.net.Uri.parse(
                    "planner://spunta?tipo=todo&id=${android.net.Uri.encode(riga.id)}&giorno=$giorno",
                ),
            ),
        )
        return vista
    }

    /** Un titolo del mese per i giorni fuori finestra: apre il giorno. */
    internal fun rigaAnteprima(
        context: Context,
        titolo: String,
        colore: String,
        coloreScuro: String,
        giorno: String,
        larghezzaDp: Int,
        colori: WidgetKit.Colori,
    ): RemoteViews {
        val vista = RemoteViews(context.packageName, R.layout.widget_mese_voce2)
        val tinta = WidgetKit.coloreInt(
            if (WidgetKit.isNotte(context)) coloreScuro else colore,
            colori.tenue,
        )
        val bitmap = bitmapRiga(context, larghezzaDp) { canvas, densita, larghezza, altezza ->
            barra(canvas, densita, tinta)
            testoRiga(
                context, canvas, titolo, 15f, WidgetText.SEMIBOLD, colori.testo,
                WidgetText.px(context, 24), larghezza - WidgetText.px(context, 28), altezza,
            )
        }
        vista.setImageViewBitmap(R.id.voce2_immagine, bitmap)
        vista.setContentDescription(R.id.voce2_radice, titolo)
        vista.setOnClickPendingIntent(
            R.id.voce2_radice,
            WidgetKit.apriGiorno(context, giorno),
        )
        return vista
    }

    internal fun rigaVuoto(
        context: Context,
        testo: String,
        giorno: String,
        larghezzaDp: Int,
        colori: WidgetKit.Colori,
    ): RemoteViews {
        val vista = RemoteViews(context.packageName, R.layout.widget_mese_voce2)
        val bitmap = bitmapRiga(context, larghezzaDp) { canvas, _, larghezza, altezza ->
            testoRiga(
                context, canvas, testo, 13.5f, WidgetText.MEDIO, colori.tenue,
                0, larghezza, altezza,
            )
        }
        vista.setImageViewBitmap(R.id.voce2_immagine, bitmap)
        vista.setContentDescription(R.id.voce2_radice, testo)
        vista.setOnClickPendingIntent(
            R.id.voce2_radice,
            WidgetKit.apriGiorno(context, giorno),
        )
        return vista
    }

    private fun bitmapRiga(
        context: Context,
        larghezzaDp: Int,
        disegna: (Canvas, Float, Int, Int) -> Unit,
    ): Bitmap {
        val bitmap = Bitmap.createBitmap(
            WidgetText.px(context, larghezzaDp).coerceAtLeast(1),
            WidgetText.px(context, 42).coerceAtLeast(1),
            Bitmap.Config.ARGB_8888,
        )
        val canvas = Canvas(bitmap)
        disegna(canvas, WidgetText.densita(context), bitmap.width, bitmap.height)
        return bitmap
    }

    private fun barra(canvas: Canvas, densita: Float, colore: Int) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = colore }
        canvas.drawRoundRect(
            RectF(0f, canvas.height / 2f - 11 * densita, 3 * densita, canvas.height / 2f + 11 * densita),
            densita, densita, paint,
        )
    }

    private fun spuntaRiga(
        canvas: Canvas,
        densita: Float,
        colore: Int,
        fatto: Boolean,
        altezza: Int,
    ) {
        val centro = 8 * densita
        val raggio = 6 * densita
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = colore
            style = Paint.Style.STROKE
            strokeWidth = densita * 1.6f
        }
        canvas.drawCircle(centro, altezza / 2f, raggio, paint)
        if (fatto) {
            paint.style = Paint.Style.FILL
            canvas.drawCircle(centro, altezza / 2f, raggio, paint)
        }
    }

    private fun testoRiga(
        context: Context,
        canvas: Canvas,
        valore: String,
        sp: Float,
        peso: Int,
        colore: Int,
        x: Int,
        larghezza: Int,
        altezza: Int,
        align: Paint.Align = Paint.Align.LEFT,
    ) {
        if (larghezza <= 0) return
        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = WidgetText.typeface(context, peso)
            textSize = sp * WidgetText.densita(context)
            this.color = colore
            textAlign = align
        }
        val visibile = android.text.TextUtils.ellipsize(
            valore, paint, larghezza.toFloat(), android.text.TextUtils.TruncateAt.END,
        ).toString()
        val metriche = paint.fontMetrics
        val base = altezza / 2f - (metriche.ascent + metriche.descent) / 2f
        val partenza = if (align == Paint.Align.RIGHT) x + larghezza else x
        canvas.drawText(visibile, partenza.toFloat(), base, paint)
    }

    private fun apriElemento(
        context: Context,
        riga: WidgetRow,
        giorno: String,
        request: Int,
    ): PendingIntent {
        val uri = android.net.Uri.parse(
            "planner://apri?tipo=${riga.tipo}&id=${android.net.Uri.encode(riga.id)}&giorno=$giorno",
        )
        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
            setClass(context, com.callmeste.planner.MainActivity::class.java)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return PendingIntent.getActivity(
            context,
            request,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /** «To do del giorno (N)» + Mostra/Nascondi, disegnata in una bitmap. */
    internal fun barraTodo(
        context: Context,
        larghezzaDp: Int,
        quanti: Int,
        azione: String?,
        aperto: Boolean,
        colori: WidgetKit.Colori,
        bordo: Int,
    ): Bitmap {
        val densita = WidgetText.densita(context)
        val bitmap = Bitmap.createBitmap(
            WidgetText.px(context, larghezzaDp).coerceAtLeast(1),
            WidgetText.px(context, 36).coerceAtLeast(1),
            Bitmap.Config.ARGB_8888,
        )
        val canvas = Canvas(bitmap)
        // La barra copre la lista sotto: sfondo pieno del widget.
        canvas.drawColor(colori.sfondo)
        canvas.drawRoundRect(
            RectF(0f, (bitmap.height - 16 * densita) / 2f, 2 * densita, (bitmap.height + 16 * densita) / 2f),
            densita,
            densita,
            Paint(Paint.ANTI_ALIAS_FLAG).apply { color = bordo },
        )

        val titolo = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = WidgetText.typeface(context, WidgetText.SEMIBOLD)
            textSize = 12.5f * densita
            color = colori.testo
        }
        val spazioAzione = if (azione == null) 0f else 78 * densita
        val titoloVisibile = android.text.TextUtils.ellipsize(
            "To do del giorno ($quanti)",
            titolo,
            bitmap.width - 14 * densita - spazioAzione,
            android.text.TextUtils.TruncateAt.END,
        ).toString()
        val metriche = titolo.fontMetrics
        val base = bitmap.height / 2f - (metriche.ascent + metriche.descent) / 2f
        canvas.drawText(titoloVisibile, 9 * densita, base, titolo)

        if (azione != null) {
            val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                typeface = WidgetText.typeface(context, WidgetText.MEDIO)
                textSize = 11.5f * densita
                color = colori.tenue
                textAlign = Paint.Align.RIGHT
            }
            canvas.drawText(azione, bitmap.width - 20 * densita, base, paint)
            val cx = bitmap.width - 9 * densita
            val cy = bitmap.height / 2f
            val d = 3.5f * densita
            val path = android.graphics.Path().apply {
                if (aperto) {
                    moveTo(cx - d, cy + d / 2)
                    lineTo(cx, cy - d / 2)
                    lineTo(cx + d, cy + d / 2)
                } else {
                    moveTo(cx - d, cy - d / 2)
                    lineTo(cx, cy + d / 2)
                    lineTo(cx + d, cy - d / 2)
                }
            }
            canvas.drawPath(
                path,
                Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = colori.tenue
                    style = Paint.Style.STROKE
                    strokeWidth = 1.4f * densita
                    strokeCap = Paint.Cap.ROUND
                    strokeJoin = Paint.Join.ROUND
                },
            )
        }
        return bitmap
    }

    internal fun templateSpunta(context: Context, scelto: String): PendingIntent =
        es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
            context,
            android.net.Uri.parse("planner://spunta?tipo=todo&id=0&giorno=$scelto"),
        )

    private fun pendenteTodo(
        context: Context,
        id: Int,
        variante: WidgetMeseRenderer.Variante,
    ): PendingIntent {
        val intent = Intent(context, WidgetMeseReceiver::class.java).apply {
            action = WidgetMeseReceiver.AZIONE_TODO
            putExtra(WidgetMeseReceiver.EXTRA_ID, id)
            putExtra(WidgetMeseReceiver.EXTRA_VARIANTE, variante.name)
        }
        return PendingIntent.getBroadcast(
            context,
            (id and 0x3FFF) * 256 + 200,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    // ------------------------------------------------------------- griglia

    private fun griglia(
        context: Context,
        prefs: SharedPreferences,
        vista: RemoteViews,
        id: Int,
        variante: WidgetMeseRenderer.Variante,
        mese: WidgetMese?,
        scelto: String,
        cella: Int,
        riga: Int,
        colori: WidgetKit.Colori,
        pubblicati: List<String>,
    ): Boolean {
        if (mese == null) {
            vista.removeAllViews(R.id.mese_griglia)
            return false
        }
        for (settimana in 0 until 6) {
            val contenitore = RemoteViews(context.packageName, RIGHE[settimana])
            for (colonna in 0 until 7) {
                val indice = settimana * 7 + colonna
                val giorno = mese.giorni.getOrNull(indice) ?: continue
                contenitore.addView(
                    ID_RIGHE[settimana],
                    cellaGiorno(
                        context = context,
                        prefs = prefs,
                        id = id,
                        variante = variante,
                        giorno = giorno,
                        scelto = scelto,
                        larghezzaDp = cella,
                        altezzaDp = riga,
                        colori = colori,
                        pubblicati = pubblicati,
                    ),
                )
            }
            vista.addView(R.id.mese_griglia, contenitore)
        }
        return true
    }

    private fun cellaGiorno(
        context: Context,
        prefs: SharedPreferences,
        id: Int,
        variante: WidgetMeseRenderer.Variante,
        giorno: WidgetMeseGiorno,
        scelto: String,
        larghezzaDp: Int,
        altezzaDp: Int,
        colori: WidgetKit.Colori,
        pubblicati: List<String>,
    ): RemoteViews {
        val cella = RemoteViews(context.packageName, R.layout.widget_mese_cella_bitmap)
        val selezionato = giorno.data == scelto

        val bitmap = Bitmap.createBitmap(
            WidgetText.px(context, larghezzaDp).coerceAtLeast(1),
            WidgetText.px(context, altezzaDp).coerceAtLeast(1),
            Bitmap.Config.ARGB_8888,
        )
        val canvas = Canvas(bitmap)
        val densita = WidgetText.densita(context)

        if (selezionato) {
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = colori.accento }
            val raggio = (minOf(bitmap.width, bitmap.height) * 0.44f)
            canvas.drawCircle(bitmap.width / 2f, bitmap.height / 2f, raggio, paint)
        } else if (variante == WidgetMeseRenderer.Variante.MESE_4X4 && giorno.eventi > 0) {
            // La densità è lo stesso accento con più alpha: si legge quanto è
            // pieno il giorno senza diventare un arcobaleno.
            val alpha = when {
                giorno.eventi >= 5 -> 0x44
                giorno.eventi >= 3 -> 0x2C
                else -> 0x18
            }
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = accentoConAlpha(colori.accento, alpha)
            }
            val inset = densita * 1.5f
            val raggio = densita * 7
            canvas.drawRoundRect(
                RectF(inset, inset, bitmap.width - inset, bitmap.height - inset),
                raggio,
                raggio,
                paint,
            )
        }

        val colore = when {
            selezionato -> scuroSu(colori.accento)
            giorno.fuoriMese -> accentoConAlpha(colori.tenue, 0x66)
            else -> colori.testo
        }
        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = WidgetText.typeface(
                context,
                if (selezionato) WidgetText.SEMIBOLD else WidgetText.MEDIO,
            )
            textSize = NUMERO_GRIGLIA * densita
            this.color = colore
            textAlign = Paint.Align.CENTER
        }
        val metriche = paint.fontMetrics
        canvas.drawText(
            giorno.giorno.toString(),
            bitmap.width / 2f,
            bitmap.height / 2f - (metriche.ascent + metriche.descent) / 2f,
            paint,
        )
        cella.setImageViewBitmap(R.id.cella_immagine, bitmap)
        cella.setContentDescription(
            R.id.cella_radice,
            giorno.etichettaAccessibile(meseDi(giorno.data)),
        )
        cella.setOnClickPendingIntent(
            R.id.cella_radice,
            pendenteGiorno(context, id, variante, giorno.data, indiceDi(giorno), pubblicati),
        )
        return cella
    }

    // ------------------------------------------------------------ disegni

    private fun testataSettimana(
        context: Context,
        larghezzaDp: Int,
        altezzaDp: Int,
        cella: Int,
        colonne: Int,
        colore: Int,
    ): Bitmap {
        val bitmap = Bitmap.createBitmap(
            WidgetText.px(context, larghezzaDp).coerceAtLeast(1),
            WidgetText.px(context, altezzaDp).coerceAtLeast(1),
            Bitmap.Config.ARGB_8888,
        )
        val canvas = Canvas(bitmap)
        val passo = bitmap.width.toFloat() / colonne
        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = WidgetText.typeface(context, WidgetText.SEMIBOLD)
            textSize = GIORNI_SETTIMANA * WidgetText.densita(context)
            this.color = colore
            textAlign = Paint.Align.CENTER
        }
        val metriche = paint.fontMetrics
        val base = bitmap.height / 2f - (metriche.ascent + metriche.descent) / 2f
        NOMI_GIORNI.forEachIndexed { indice, nome ->
            canvas.drawText(nome, passo * indice + passo / 2f, base, paint)
        }
        return bitmap
    }

    private fun titoloMese(
        context: Context,
        larghezzaDp: Int,
        altezzaDp: Int,
        annoMese: String,
        colori: WidgetKit.Colori,
    ): Bitmap {
        val bitmap = Bitmap.createBitmap(
            WidgetText.px(context, larghezzaDp).coerceAtLeast(1),
            WidgetText.px(context, altezzaDp).coerceAtLeast(1),
            Bitmap.Config.ARGB_8888,
        )
        val canvas = Canvas(bitmap)
        val densita = WidgetText.densita(context)
        val mese = WidgetPayload.etichettaMese(annoMese).substringBefore(" ")
            .replaceFirstChar { it.titlecase(Locale.ITALIAN) }
        val anno = annoMese.take(4)
        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = WidgetText.typeface(context, WidgetText.SEMIBOLD)
            textSize = 18f * densita
        }
        val metriche = paint.fontMetrics
        val base = bitmap.height / 2f - (metriche.ascent + metriche.descent) / 2f
        val largoMese = paint.measureText("$mese ")
        val largoAnno = paint.measureText(anno)
        val inizio = (bitmap.width - largoMese - largoAnno) / 2f
        paint.color = colori.accento
        canvas.drawText(mese, inizio, base, paint)
        paint.color = colori.testo
        canvas.drawText(anno, inizio + largoMese, base, paint)
        return bitmap
    }

    internal fun freccia(
        context: Context,
        sinistra: Boolean,
        latoDp: Int,
        colore: Int,
    ): Bitmap {
        val lato = WidgetText.px(context, latoDp)
        val bitmap = Bitmap.createBitmap(lato, lato, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = colore
            style = Paint.Style.STROKE
            strokeWidth = WidgetText.densita(context) * 1.8f
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        val c = lato / 2f
        val d = lato * 0.16f
        // La punta guarda dove si va: a sinistra per il mese precedente.
        val punta = if (sinistra) -d else d
        val path = android.graphics.Path().apply {
            moveTo(c - punta, c - d * 1.4f)
            lineTo(c + punta, c)
            lineTo(c - punta, c + d * 1.4f)
        }
        canvas.drawPath(path, paint)
        return bitmap
    }

    internal fun piu(context: Context, latoDp: Int, colori: WidgetKit.Colori): Bitmap {
        val lato = WidgetText.px(context, latoDp)
        val bitmap = Bitmap.createBitmap(lato, lato, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val densita = WidgetText.densita(context)
        canvas.drawCircle(
            lato / 2f,
            lato / 2f,
            lato / 2f - densita,
            Paint(Paint.ANTI_ALIAS_FLAG).apply { color = colori.accento },
        )
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = scuroSu(colori.accento)
            style = Paint.Style.STROKE
            strokeWidth = densita * 1.8f
            strokeCap = Paint.Cap.ROUND
        }
        val c = lato / 2f
        val braccio = lato * 0.22f
        canvas.drawLine(c - braccio, c, c + braccio, c, paint)
        canvas.drawLine(c, c - braccio, c, c + braccio, paint)
        return bitmap
    }

    // -------------------------------------------------------------- tocchi

    private fun collegaFrecce(
        context: Context,
        vista: RemoteViews,
        indietro: Int,
        avanti: Int,
        id: Int,
        annoMese: String,
        pubblicati: List<String>,
        variante: WidgetMeseRenderer.Variante,
    ) {
        vista.setOnClickPendingIntent(
            indietro,
            pendenteMese(
                context, id, WidgetPayload.spostaMese(annoMese, -1), 100, pubblicati, variante,
            ),
        )
        vista.setOnClickPendingIntent(
            avanti,
            pendenteMese(
                context, id, WidgetPayload.spostaMese(annoMese, 1), 101, pubblicati, variante,
            ),
        )
    }

    private fun pendenteGiorno(
        context: Context,
        id: Int,
        variante: WidgetMeseRenderer.Variante,
        data: String,
        slot: Int,
        pubblicati: List<String>,
    ): PendingIntent {
        if (!pubblicati.contains(WidgetPayload.annoMese(data))) {
            return WidgetKit.apriGiorno(context, data)
        }
        val intent = Intent(context, WidgetMeseReceiver::class.java).apply {
            action = WidgetMeseReceiver.AZIONE_GIORNO
            putExtra(WidgetMeseReceiver.EXTRA_ID, id)
            putExtra(WidgetMeseReceiver.EXTRA_GIORNO, data)
            putExtra(WidgetMeseReceiver.EXTRA_VARIANTE, variante.name)
        }
        return PendingIntent.getBroadcast(
            context,
            richiesta(id, slot),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun pendenteMese(
        context: Context,
        id: Int,
        mese: String,
        slot: Int,
        pubblicati: List<String>,
        variante: WidgetMeseRenderer.Variante,
    ): PendingIntent {
        if (!pubblicati.contains(mese)) {
            return WidgetKit.apriGiorno(context, WidgetPayload.primoDelMese(mese))
        }
        val intent = Intent(context, WidgetMeseReceiver::class.java).apply {
            action = WidgetMeseReceiver.AZIONE_MESE
            putExtra(WidgetMeseReceiver.EXTRA_ID, id)
            putExtra(WidgetMeseReceiver.EXTRA_MESE, mese)
            putExtra(WidgetMeseReceiver.EXTRA_VARIANTE, variante.name)
        }
        return PendingIntent.getBroadcast(
            context,
            richiesta(id, slot),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    // -------------------------------------------------------------- utility

    fun misura(context: Context, id: Int, larghezzaDefault: Int, altezzaDefault: Int): Pair<Int, Int> {
        val opzioni = AppWidgetManager.getInstance(context).getAppWidgetOptions(id)
        val larghezza = opzioni.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        val altezza = opzioni.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        return (if (larghezza in 100..1200) larghezza else larghezzaDefault) to
            (if (altezza in 80..1200) altezza else altezzaDefault)
    }

    fun accentoConAlpha(accento: Int, alpha: Int): Int =
        (alpha shl 24) or (accento and 0xFFFFFF)

    private fun scuroSu(colore: Int): Int {
        val luminanza = (0.299 * android.graphics.Color.red(colore) +
            0.587 * android.graphics.Color.green(colore) +
            0.114 * android.graphics.Color.blue(colore)) / 255.0
        return if (luminanza > 0.6) android.graphics.Color.rgb(17, 24, 28)
        else android.graphics.Color.WHITE
    }

    private fun etichettaGiorno(data: String, oggi: String): String {
        val breve = WidgetKit.etichettaGiorno(data).uppercase(Locale.ITALIAN)
        return if (data == oggi) "OGGI · $breve" else breve
    }

    private fun meseDi(data: String): String = WidgetPayload.annoMese(data)

    private fun indiceDi(giorno: WidgetMeseGiorno): Int = giorno.giorno

    private val NOMI_GIORNI = listOf("lun", "mar", "mer", "gio", "ven", "sab", "dom")

    private val RIGHE = intArrayOf(
        R.layout.widget_mese_riga_g0,
        R.layout.widget_mese_riga_g1,
        R.layout.widget_mese_riga_g2,
        R.layout.widget_mese_riga_g3,
        R.layout.widget_mese_riga_g4,
        R.layout.widget_mese_riga_g5,
    )

    private val ID_RIGHE = intArrayOf(
        R.id.mese_riga_g0,
        R.id.mese_riga_g1,
        R.id.mese_riga_g2,
        R.id.mese_riga_g3,
        R.id.mese_riga_g4,
        R.id.mese_riga_g5,
    )

    private fun richiesta(id: Int, slot: Int): Int = (id and 0x3FFF) * 256 + slot
}
