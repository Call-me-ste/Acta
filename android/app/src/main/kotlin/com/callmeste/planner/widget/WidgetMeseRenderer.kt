package com.callmeste.planner.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import com.callmeste.planner.R
import java.util.Locale

/**
 * Il disegno del **mese**, in tre vestiti:
 *
 * * `MESE_4X2` — griglia a sinistra e agenda del giorno scelto a destra;
 * * `MESE_4X4` — griglia grande, ridimensionabile;
 * * `MESE_2X2` — solo griglia compatta.
 *
 * Le righe del mese pesano sull'altezza (`0dp` + `weight=1`): il launcher può
 * dare 130, 230 o 370dp e il mese resta pieno, senza settimane tagliate. Le
 * celle si aggiungono al root della riga (id unico `mese_riga_gN`), perché
 * `addView` non porta con sé i dp del file riga su ColorOS.
 */
object WidgetMeseRenderer {

    enum class Variante { MESE_4X2, MESE_4X4, MESE_2X2 }

    /** Quante righe entrano nella parte bassa del 4x4 senza toccare il mese. */
    private const val EVENTI_VISIBILI = 2
    private const val TODO_VISIBILI = 2

    private val RIGHE = intArrayOf(
        R.id.mese_riga_g0,
        R.id.mese_riga_g1,
        R.id.mese_riga_g2,
        R.id.mese_riga_g3,
        R.id.mese_riga_g4,
        R.id.mese_riga_g5,
    )

    private val LAYOUT_RIGHE = intArrayOf(
        R.layout.widget_mese_riga_g0,
        R.layout.widget_mese_riga_g1,
        R.layout.widget_mese_riga_g2,
        R.layout.widget_mese_riga_g3,
        R.layout.widget_mese_riga_g4,
        R.layout.widget_mese_riga_g5,
    )

    private val ID_GIORNI = intArrayOf(
        R.id.mese_giorno_lun,
        R.id.mese_giorno_mar,
        R.id.mese_giorno_mer,
        R.id.mese_giorno_gio,
        R.id.mese_giorno_ven,
        R.id.mese_giorno_sab,
        R.id.mese_giorno_dom,
    )

    fun disegna(
        context: Context,
        prefs: SharedPreferences,
        appWidgetId: Int,
        altezzaDp: Int,
        variante: Variante,
    ): RemoteViews {
        val colori = WidgetKit.colori(context, prefs)
        val vista = RemoteViews(context.packageName, layout(variante))
        val pubblicati = WidgetPayload.mesiPubblicati(prefs)
        val annoMese = WidgetMeseStato.vista(prefs, appWidgetId)
        val scelto = WidgetMeseStato.scelto(prefs, appWidgetId)
        val oggi = WidgetPayload.dataOggi(prefs)

        vista.setInt(R.id.mese_radice, "setBackgroundColor", colori.sfondo)
        vista.setTextColor(R.id.mese_titolo, colori.testo)
        vista.setTextColor(R.id.mese_indietro, colori.tenue)
        vista.setTextColor(R.id.mese_avanti, colori.tenue)
        vista.setTextColor(R.id.mese_nota, colori.tenue)
        for (id in ID_GIORNI) vista.setTextColor(id, colori.testo)

        val mese = WidgetPayload.leggiMese(prefs, annoMese)
        val etichetta = mese?.etichetta?.ifEmpty { WidgetPayload.etichettaMese(annoMese) }
            ?: WidgetPayload.etichettaMese(annoMese)
        vista.setTextViewText(R.id.mese_titolo, etichetta.replaceFirstChar { it.titlecase() })

        vista.setOnClickPendingIntent(
            R.id.mese_indietro,
            pendenteMese(
                context, appWidgetId, variante,
                WidgetPayload.spostaMese(annoMese, -1), -1, pubblicati,
            ),
        )
        vista.setOnClickPendingIntent(
            R.id.mese_avanti,
            pendenteMese(
                context, appWidgetId, variante,
                WidgetPayload.spostaMese(annoMese, 1), 1, pubblicati,
            ),
        )
        vista.setOnClickPendingIntent(R.id.mese_titolo, WidgetKit.apriGiorno(context, scelto))
        vista.setOnClickPendingIntent(R.id.mese_radice, WidgetKit.apriGiorno(context, scelto))

        if (mese == null) {
            vista.removeAllViews(R.id.mese_griglia)
            WidgetKit.setVisibile(vista, R.id.mese_nota, true)
            vista.setTextViewText(
                R.id.mese_nota,
                context.getString(R.string.widget_mese_fuori_finestra),
            )
            vista.setOnClickPendingIntent(R.id.mese_nota, WidgetKit.apriGiorno(context, scelto))
            return vista
        }

        WidgetKit.setVisibile(vista, R.id.mese_nota, false)
        vista.removeAllViews(R.id.mese_griglia)
        // Il mese usa tutte le righe che ha davvero: nei mesi di cinque
        // settimane non lasciamo una riga vuota in fondo. La testata resta
        // ferma perché la griglia parte sempre dallo stesso punto.
        val settimane = mese.settimane.coerceIn(5, 6)
        for (settimana in 0 until settimane) {
            val riga = RemoteViews(context.packageName, LAYOUT_RIGHE[settimana])
            for (colonna in 0 until 7) {
                val indice = settimana * 7 + colonna
                val giorno = mese.giorni.getOrNull(indice) ?: continue
                riga.addView(
                    RIGHE[settimana],
                    cella(
                        context = context,
                        mese = mese,
                        giorno = giorno,
                        slot = indice,
                        variante = variante,
                        appWidgetId = appWidgetId,
                        scelto = scelto,
                        oggi = oggi,
                        pubblicati = pubblicati,
                        colori = colori,
                    ),
                )
            }
            vista.addView(R.id.mese_griglia, riga)
        }

        return vista
    }

    private fun layout(variante: Variante): Int = when (variante) {
        Variante.MESE_4X2 -> R.layout.widget_mese
        Variante.MESE_4X4 -> R.layout.widget_mese_grande
        Variante.MESE_2X2 -> R.layout.widget_mese_compatto
    }

    private fun layoutCella(variante: Variante): Int = when (variante) {
        Variante.MESE_4X2 -> R.layout.widget_mese_cella_solo
        Variante.MESE_4X4 -> R.layout.widget_mese_cella_grande
        Variante.MESE_2X2 -> R.layout.widget_mese_cella_mini
    }

    /** Una cella: numero, oggi/scelto e i pallini degli eventi. */
    private fun cella(
        context: Context,
        mese: WidgetMese,
        giorno: WidgetMeseGiorno,
        slot: Int,
        variante: Variante,
        appWidgetId: Int,
        scelto: String,
        oggi: String,
        pubblicati: List<String>,
        colori: WidgetKit.Colori,
    ): RemoteViews {
        val cella = RemoteViews(context.packageName, layoutCella(variante))
        if (giorno.fuoriMese) {
            cella.setTextViewText(R.id.cella_numero, "")
            cella.setViewVisibility(R.id.cella_cerchio, View.INVISIBLE)
            if (variante != Variante.MESE_4X2) {
                cella.setViewVisibility(R.id.cella_punto_1, View.GONE)
                cella.setViewVisibility(R.id.cella_punto_2, View.GONE)
            }
            if (variante == Variante.MESE_4X4) cella.setTextViewText(R.id.cella_piu, "")
            cella.setContentDescription(R.id.cella_radice, "")
            return cella
        }

        // Nel 4x4 il cerchio è **la selezione**: uno solo, quello scelto. Se
        // cerchiassimo anche oggi, al primo tocco su un altro giorno se ne
        // vedrebbero due e non si capirebbe più quale comanda la parte bassa.
        val evidenziato = if (variante == Variante.MESE_4X4) {
            giorno.data == scelto
        } else {
            giorno.data == scelto || giorno.data == oggi
        }
        cella.setTextViewText(R.id.cella_numero, giorno.giorno.toString())
        cella.setViewVisibility(
            R.id.cella_cerchio,
            if (evidenziato) View.VISIBLE else View.INVISIBLE,
        )
        if (evidenziato) {
            cella.setInt(
                R.id.cella_cerchio,
                "setColorFilter",
                accentoConAlpha(colori.accento, if (variante == Variante.MESE_4X2) 0xA0 else 0x45),
            )
            cella.setTextColor(
                R.id.cella_numero,
                if (variante == Variante.MESE_4X2) colori.testo else colori.accento,
            )
        } else {
            cella.setTextColor(R.id.cella_numero, colori.testo)
        }

        if (variante != Variante.MESE_4X2) {
            val primo = giorno.anteprime.getOrNull(0)
            val secondo = giorno.anteprime.getOrNull(1)
            cella.setViewVisibility(R.id.cella_punto_1, if (primo == null) View.GONE else View.VISIBLE)
            cella.setViewVisibility(R.id.cella_punto_2, if (secondo == null) View.GONE else View.VISIBLE)
            if (primo != null) {
                cella.setInt(
                    R.id.cella_punto_1,
                    "setColorFilter",
                    WidgetKit.coloreInt(primo.colore(WidgetKit.isNotte(context)), colori.tenue),
                )
            }
            if (secondo != null) {
                cella.setInt(
                    R.id.cella_punto_2,
                    "setColorFilter",
                    WidgetKit.coloreInt(secondo.colore(WidgetKit.isNotte(context)), colori.tenue),
                )
            }
        }
        if (variante == Variante.MESE_4X4) {
            cella.setTextViewText(
                R.id.cella_piu,
                if (giorno.altre > 0) "+${giorno.altre}" else "",
            )
            cella.setTextColor(R.id.cella_piu, colori.tenue)
        }

        cella.setContentDescription(
            R.id.cella_radice,
            giorno.etichettaAccessibile(mese.annoMese),
        )
        cella.setOnClickPendingIntent(
            R.id.cella_radice,
            pendenteGiorno(
                context, appWidgetId, variante, giorno.data, slot, pubblicati,
            ),
        )
        return cella
    }

    private fun pendenteGiorno(
        context: Context,
        appWidgetId: Int,
        variante: Variante,
        data: String,
        slot: Int,
        pubblicati: List<String>,
    ): PendingIntent {
        val inWidget = variante == Variante.MESE_4X2 || variante == Variante.MESE_4X4
        if (!inWidget || !pubblicati.contains(WidgetPayload.annoMese(data))) {
            return WidgetKit.apriGiorno(context, data)
        }
        val intent = Intent(context, WidgetMeseReceiver::class.java).apply {
            action = WidgetMeseReceiver.AZIONE_GIORNO
            putExtra(WidgetMeseReceiver.EXTRA_ID, appWidgetId)
            putExtra(WidgetMeseReceiver.EXTRA_GIORNO, data)
            putExtra(WidgetMeseReceiver.EXTRA_VARIANTE, variante.name)
        }
        return PendingIntent.getBroadcast(
            context,
            richiesta(appWidgetId, slot),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun pendenteMese(
        context: Context,
        appWidgetId: Int,
        variante: Variante,
        annoMese: String,
        scarto: Int,
        pubblicati: List<String>,
    ): PendingIntent {
        if (!pubblicati.contains(annoMese)) {
            return WidgetKit.apriGiorno(context, WidgetPayload.primoDelMese(annoMese))
        }
        val intent = Intent(context, WidgetMeseReceiver::class.java).apply {
            action = WidgetMeseReceiver.AZIONE_MESE
            putExtra(WidgetMeseReceiver.EXTRA_ID, appWidgetId)
            putExtra(WidgetMeseReceiver.EXTRA_MESE, annoMese)
            putExtra(WidgetMeseReceiver.EXTRA_VARIANTE, variante.name)
        }
        return PendingIntent.getBroadcast(
            context,
            richiesta(appWidgetId, if (scarto < 0) 100 else 101),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun richiesta(appWidgetId: Int, slot: Int): Int =
        (appWidgetId and 0x3FFF) * 256 + slot

    private fun accentoConAlpha(accento: Int, alpha: Int): Int =
        (alpha shl 24) or (accento and 0xFFFFFF)
}
