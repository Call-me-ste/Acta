package com.callmeste.planner.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.text.TextPaint
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.callmeste.planner.R
import es.antonborri.home_widget.HomeWidgetPlugin
import java.util.Locale

/**
 * Le due liste del «Mese + giorno» e dell'«Agenda»: **eventi** e **To do**.
 *
 * Sono due collection separate perché hanno due template diversi: gli eventi
 * aprono l'app sul giorno, i To do si spuntano in background senza aprirla. Una
 * sola ListView non può avere due tipi di PendingIntent.
 */
class MeseWidgetService : RemoteViewsService() {

    companion object {
        const val EXTRA_ID = "appWidgetId"
        const val EXTRA_LARGHEZZA = "larghezza"
        const val EXTRA_SCELTO = "scelto"
        const val EXTRA_CONTENUTO = "contenuto"
        const val EVENTI = "eventi"
        const val TODO = "todo"
    }

    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory = MeseWidgetFactory(
        applicationContext,
        intent.getIntExtra(EXTRA_ID, AppWidgetManager.INVALID_APPWIDGET_ID),
        intent.getIntExtra(EXTRA_LARGHEZZA, 300),
        intent.getStringExtra(EXTRA_SCELTO) ?: WidgetPayload.dataOggi(),
        intent.getStringExtra(EXTRA_CONTENUTO) ?: EVENTI,
    )
}

private class MeseWidgetFactory(
    private val context: Context,
    private val appWidgetId: Int,
    private val larghezzaDp: Int,
    private val giorno: String,
    private val contenuto: String,
) : RemoteViewsService.RemoteViewsFactory {

    private sealed class Voce {
        data class Riga(val riga: WidgetRow) : Voce()
        data class Anteprima(val titolo: String, val colore: String, val coloreScuro: String) : Voce()
        object Vuoto : Voce()
    }

    private var voci: List<Voce> = emptyList()
    private var senzaDati: Boolean = false
    private var notte: Boolean = false
    private var colori: WidgetKit.Colori = WidgetKit.Colori(
        sfondo = android.graphics.Color.WHITE,
        superficie = android.graphics.Color.WHITE,
        testo = android.graphics.Color.BLACK,
        tenue = android.graphics.Color.DKGRAY,
        accento = android.graphics.Color.BLACK,
    )

    private val sonoTodo: Boolean get() = contenuto == MeseWidgetService.TODO

    override fun onCreate() = Unit

    override fun onDataSetChanged() {
        val prefs = HomeWidgetPlugin.getData(context)
        notte = WidgetKit.isNotte(context)
        colori = WidgetKit.colori(context, prefs)
        val completo = WidgetPayload.leggiGiorno(prefs, giorno)
        senzaDati = completo == null

        if (sonoTodo) {
            voci = completo?.righe?.filter { it.isTodo }?.map { Voce.Riga(it) }.orEmpty()
            return
        }

        if (completo == null) {
            // Fuori dalla finestra dei giorni: il mese sa i titoli delle
            // anteprime. Niente orari, ma la card non resta vuota.
            val mese = WidgetPayload.leggiMese(prefs, WidgetPayload.annoMese(giorno))
            val anteprime = mese?.giorni?.firstOrNull { it.data == giorno }?.anteprime.orEmpty()
            voci = if (anteprime.isEmpty()) {
                listOf(Voce.Vuoto)
            } else {
                anteprime.map { Voce.Anteprima(it.titolo, it.colore, it.coloreScuro) }
            }
            return
        }

        val eventi = completo.righe.filter { !it.isTodo }.map { Voce.Riga(it) }
        voci = if (eventi.isEmpty()) listOf(Voce.Vuoto) else eventi
    }

    override fun onDestroy() {
        voci = emptyList()
    }

    override fun getCount(): Int = voci.size

    override fun getViewAt(position: Int): RemoteViews? {
        val voce = voci.getOrNull(position) ?: return null
        val vista = RemoteViews(context.packageName, R.layout.widget_mese_voce2)
        val larghezza = WidgetText.px(context, larghezzaDp)
        val altezza = WidgetText.px(context, 42)
        val bitmap = Bitmap.createBitmap(larghezza, altezza, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val densita = WidgetText.densita(context)

        when (voce) {
            is Voce.Riga -> {
                val riga = voce.riga
                val colore = WidgetKit.coloreRiga(riga, notte, colori.tenue)
                if (riga.isTodo) {
                    spunta(canvas, densita, colore, riga.fatto)
                } else {
                    barra(canvas, densita, colore)
                }
                val partenza = WidgetText.px(context, 24)
                if (riga.ora.isNotBlank()) {
                    testo(
                        canvas,
                        riga.ora,
                        sp = 12.5f,
                        peso = WidgetText.SEMIBOLD,
                        colore = colori.testo,
                        x = partenza.toFloat(),
                        larghezza = WidgetText.px(context, 48),
                        altezza = altezza,
                    )
                }
                val xTitolo = if (riga.ora.isNotBlank()) {
                    partenza + WidgetText.px(context, 54)
                } else {
                    partenza
                }
                testo(
                    canvas,
                    riga.titolo,
                    sp = 15f,
                    peso = WidgetText.SEMIBOLD,
                    colore = if (riga.fatto) colori.tenue else colori.testo,
                    x = xTitolo.toFloat(),
                    larghezza = bitmap.width - xTitolo - WidgetText.px(context, 4),
                    altezza = altezza,
                )
                vista.setOnClickFillInIntent(
                    R.id.voce2_radice,
                    riempi(riga, giorno),
                )
            }

            is Voce.Anteprima -> {
                val colore = WidgetKit.coloreInt(
                    if (notte) voce.coloreScuro else voce.colore,
                    colori.tenue,
                )
                barra(canvas, densita, colore)
                testo(
                    canvas,
                    voce.titolo,
                    sp = 15f,
                    peso = WidgetText.SEMIBOLD,
                    colore = colori.testo,
                    x = WidgetText.px(context, 24).toFloat(),
                    larghezza = bitmap.width - WidgetText.px(context, 28),
                    altezza = altezza,
                )
                vista.setOnClickFillInIntent(
                    R.id.voce2_radice,
                    Intent().setData(
                        android.net.Uri.parse("planner://apri?giorno=$giorno"),
                    ),
                )
            }

            Voce.Vuoto -> {
                testo(
                    canvas,
                    if (senzaDati) "Apri Planner per questo giorno" else "Niente in programma",
                    sp = 13.5f,
                    peso = WidgetText.MEDIO,
                    colore = colori.tenue,
                    x = 0f,
                    larghezza = bitmap.width,
                    altezza = altezza,
                )
                vista.setOnClickFillInIntent(
                    R.id.voce2_radice,
                    Intent().setData(android.net.Uri.parse("planner://apri?giorno=$giorno")),
                )
            }
        }

        vista.setImageViewBitmap(R.id.voce2_immagine, bitmap)
        vista.setContentDescription(R.id.voce2_radice, descrizione(voce))
        return vista
    }

    /** Il fill-in che il template della lista completa con l'URI giusto. */
    private fun riempi(riga: WidgetRow, giorno: String): Intent = if (riga.isTodo) {
        Intent().setData(
            android.net.Uri.parse(
                "planner://spunta?tipo=todo&id=${android.net.Uri.encode(riga.id)}&giorno=$giorno",
            ),
        )
    } else {
        Intent().setData(
            android.net.Uri.parse(
                "planner://apri?tipo=${riga.tipo}&id=${android.net.Uri.encode(riga.id)}&giorno=$giorno",
            ),
        )
    }

    private fun descrizione(voce: Voce): String = when (voce) {
        is Voce.Riga -> voce.riga.titolo
        is Voce.Anteprima -> voce.titolo
        Voce.Vuoto -> "Nessun evento"
    }

    private fun barra(canvas: Canvas, densita: Float, colore: Int) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = colore }
        val largo = 3 * densita
        canvas.drawRoundRect(
            0f,
            canvas.height / 2f - 11 * densita,
            largo,
            canvas.height / 2f + 11 * densita,
            densita,
            densita,
            paint,
        )
    }

    private fun spunta(canvas: Canvas, densita: Float, colore: Int, fatto: Boolean) {
        val centro = 8 * densita
        val raggio = 6.5f * densita
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = colore
            style = Paint.Style.STROKE
            strokeWidth = densita * 1.6f
        }
        canvas.drawCircle(centro, canvas.height / 2f, raggio, paint)
        if (fatto) {
            paint.style = Paint.Style.FILL
            canvas.drawCircle(centro, canvas.height / 2f, raggio, paint)
        }
    }

    private fun testo(
        canvas: Canvas,
        valore: String,
        sp: Float,
        peso: Int,
        colore: Int,
        x: Float,
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
            valore,
            paint,
            larghezza.toFloat(),
            android.text.TextUtils.TruncateAt.END,
        ).toString()
        val metriche = paint.fontMetrics
        val base = altezza / 2f - (metriche.ascent + metriche.descent) / 2f
        canvas.drawText(visibile, x, base, paint)
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = false
}
