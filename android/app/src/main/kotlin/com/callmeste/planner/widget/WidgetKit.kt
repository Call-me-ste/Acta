package com.callmeste.planner.widget

import android.app.PendingIntent
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import com.callmeste.planner.MainActivity
import com.callmeste.planner.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

/** Che cosa mostra un widget con agenda: eventi, todo o tutti e due. */
enum class Contenuto { MISTO, EVENTI, TODO }

/** Come mostrare i todo in un widget che li supporta. */
enum class TodoMode { NESSUNO, COMPATTI, ESTESI }

/**
 * Le poche cose che tutti i widget condividono: i colori del pacchetto, la
 * scelta «mostra anche i Todo» per singola istanza, le date italiane e i tocchi.
 *
 * Sta qui e non in ogni renderer perché la famiglia deve sembrare **una sola
 * app**: stessi ruoli di colore, stesse etichette, stesse PendingIntent.
 */
object WidgetKit {
    const val SCHEMA = "planner"

    /** I colori già risolti per il tema di sistema corrente. */
    data class Colori(
        val sfondo: Int,
        val superficie: Int,
        val testo: Int,
        val tenue: Int,
        val accento: Int,
    )

    fun colori(context: Context, prefs: SharedPreferences): Colori {
        val notte = isNotte(context)
        val mappa = WidgetPayload.leggiTema(prefs)?.colori(notte) ?: emptyMap()
        val fallbackSfondo = if (notte) Color.rgb(20, 20, 24) else Color.WHITE
        val fallbackTesto = if (notte) Color.WHITE else Color.BLACK
        val sfondo = colore(mappa, "sfondo", fallbackSfondo)
        return Colori(
            sfondo = sfondo,
            superficie = colore(mappa, "superficie", sfondo),
            testo = colore(mappa, "testo", fallbackTesto),
            tenue = colore(mappa, "testoTenue", if (notte) Color.LTGRAY else Color.DKGRAY),
            accento = colore(mappa, "accento", colore(mappa, "testo", fallbackTesto)),
        )
    }

    /** Il colore dei filetti e dei separatori: `outlineVariant` del tema. */
    fun bordo(context: Context, prefs: SharedPreferences): Int {
        val notte = isNotte(context)
        val mappa = WidgetPayload.leggiTema(prefs)?.colori(notte) ?: emptyMap()
        return colore(mappa, "bordo", if (notte) Color.DKGRAY else Color.LTGRAY)
    }

    fun isNotte(context: Context): Boolean =
        (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES

    fun colore(mappa: Map<String, String>, ruolo: String, fallback: Int): Int =
        mappa[ruolo]?.let { coloreInt(it, fallback) } ?: fallback

    fun coloreInt(hex: String, fallback: Int): Int = try {
        Color.parseColor(hex)
    } catch (errore: IllegalArgumentException) {
        fallback
    }

    fun coloreRiga(riga: WidgetRow, notte: Boolean, fallback: Int): Int =
        coloreInt(riga.colore(notte), fallback)

    /**
     * La scelta Todo è **per widget**, non globale.
     *
     * Le versioni precedenti salvavano un booleano: se c'è ancora, `true`
     * significa «estesi» (era l'unico modo di mostrarli) e `false` «nessuno».
     */
    fun todoMode(prefs: SharedPreferences, id: Int): TodoMode {
        val salvato = prefs.getString(chiaveTodoMode(id), null)
        val mode = if (salvato != null) {
            runCatching { TodoMode.valueOf(salvato) }.getOrDefault(TodoMode.NESSUNO)
        } else if (prefs.getBoolean(chiaveMostraTodo(id), false)) {
            TodoMode.ESTESI
        } else {
            TodoMode.NESSUNO
        }
        return mode
    }

    fun mostraTodo(prefs: SharedPreferences, id: Int): Boolean =
        todoMode(prefs, id) != TodoMode.NESSUNO

    fun scriviTodoMode(prefs: SharedPreferences, id: Int, mode: TodoMode) {
        prefs.edit()
            .putString(chiaveTodoMode(id), mode.name)
            .remove(chiaveMostraTodo(id))
            .apply()
    }

    fun chiaveTodoMode(id: Int): String = "widget_todo_mode_$id"

    fun chiaveMostraTodo(id: Int): String = "widget_mostra_todo_$id"

    /** Se la sezione To do di **questo** widget è aperta. */
    fun todoAperto(prefs: SharedPreferences, id: Int): Boolean =
        prefs.getBoolean(chiaveTodoAperto(id), false)

    fun invertiTodoAperto(prefs: SharedPreferences, id: Int) {
        prefs.edit().putBoolean(chiaveTodoAperto(id), !todoAperto(prefs, id)).apply()
    }

    fun chiaveTodoAperto(id: Int): String = "widget_todo_aperto_$id"

    fun pulisciOpzioni(prefs: SharedPreferences, id: Int) {
        prefs.edit()
            .remove(chiaveTodoMode(id))
            .remove(chiaveMostraTodo(id))
            .remove(chiaveTodoAperto(id))
            .apply()
    }

    /** Le righe che questo widget deve mostrare, già filtrate. */
    fun righe(
        giorno: WidgetGiorno,
        contenuto: Contenuto,
        todoMode: TodoMode,
    ): List<WidgetRow> = when (contenuto) {
        Contenuto.TODO -> giorno.righe.filter { it.isTodo }
        Contenuto.EVENTI -> giorno.righe.filter { !it.isTodo }
        Contenuto.MISTO -> if (todoMode == TodoMode.NESSUNO) {
            giorno.righe.filter { !it.isTodo }
        } else {
            giorno.righe
        }
    }

    fun totale(giorno: WidgetGiorno, contenuto: Contenuto, todoMode: TodoMode): Int =
        when (contenuto) {
            Contenuto.TODO -> giorno.todo
            Contenuto.EVENTI -> giorno.eventi
            Contenuto.MISTO -> if (todoMode != TodoMode.NESSUNO) {
                giorno.eventi + giorno.todo
            } else {
                giorno.eventi
            }
        }

    /** La riga dei conteggi: «1 evento · 5 todo», oppure «3 eventi». */
    fun conteggi(
        context: Context,
        giorno: WidgetGiorno?,
        contenuto: Contenuto,
        todoMode: TodoMode,
    ): String {
        if (giorno == null) return context.getString(R.string.widget_aggiorna)
        val eventi = context.resources.getQuantityString(
            R.plurals.widget_eventi,
            giorno.eventi,
            giorno.eventi,
        )
        val todo = context.resources.getQuantityString(
            R.plurals.widget_todo,
            giorno.todo,
            giorno.todo,
        )
        return when (contenuto) {
            Contenuto.TODO -> if (giorno.todoFatti > 0) {
                context.getString(R.string.widget_conteggi_todo_fatti, todo, giorno.todoFatti)
            } else {
                todo
            }
            Contenuto.EVENTI -> eventi
            Contenuto.MISTO -> if (todoMode != TodoMode.NESSUNO) {
                context.getString(R.string.widget_conteggi, eventi, giorno.todo)
            } else {
                eventi
            }
        }
    }

    fun vuoto(
        context: Context,
        giorno: WidgetGiorno?,
        contenuto: Contenuto,
        todoMode: TodoMode,
    ): String {
        if (giorno == null) return context.getString(R.string.widget_aggiorna)
        return when (contenuto) {
            Contenuto.TODO -> context.getString(R.string.widget_vuoto_todo)
            Contenuto.EVENTI -> context.getString(R.string.widget_vuoto_eventi)
            Contenuto.MISTO -> if (todoMode != TodoMode.NESSUNO) {
                giorno.fraseVuoto
            } else {
                context.getString(R.string.widget_vuoto_eventi)
            }
        }
    }

    /** «Oggi», «Domani», «24 ott». */
    fun etichettaData(data: String, oggi: String = WidgetPayload.dataOggi()): String =
        when (data) {
            oggi -> "Oggi"
            WidgetPayload.dataDopo(oggi, 1) -> "Domani"
            else -> etichettaBreve(data)
        }

    /** «sab 24 ott», per la testata del giorno. */
    fun etichettaGiorno(data: String): String = try {
        val forma = SimpleDateFormat("yyyy-MM-dd", Locale.ITALY)
        val uscita = SimpleDateFormat("EEE d MMM", Locale.ITALIAN)
        uscita.format(forma.parse(data)!!).replaceFirstChar { it.titlecase(Locale.ITALIAN) }
    } catch (errore: Exception) {
        data
    }

    /** «gio»: l'abbreviazione per la striscia dell'Agenda. */
    fun etichettaGiornoBreve(data: String): String = try {
        val forma = SimpleDateFormat("yyyy-MM-dd", Locale.ITALY)
        SimpleDateFormat("EEE", Locale.ITALIAN).format(forma.parse(data)!!)
    } catch (errore: Exception) {
        data
    }

    /** «mercoledì»: il nome intero per il blocco hero del widget. */
    fun etichettaGiornoLunga(data: String): String = try {
        val forma = SimpleDateFormat("yyyy-MM-dd", Locale.ITALY)
        SimpleDateFormat("EEEE", Locale.ITALIAN).format(forma.parse(data)!!)
    } catch (errore: Exception) {
        data
    }

    /** «24 ott». */
    fun etichettaBreve(data: String): String = try {
        val forma = SimpleDateFormat("yyyy-MM-dd", Locale.ITALY)
        SimpleDateFormat("d MMM", Locale.ITALIAN).format(forma.parse(data)!!)
    } catch (errore: Exception) {
        data
    }

    fun etichettaMese(data: String): String = WidgetPayload.etichettaMese(data.take(7))

    /** I giorni fra due date ISO, in UTC: il countdown non salta con l'ora legale. */
    fun giorniTra(dalla: String, alla: String): Int {
        val forma = SimpleDateFormat("yyyy-MM-dd", Locale.ITALY).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }
        val uno = calendario(forma, dalla) ?: return 0
        val due = calendario(forma, alla) ?: return 0
        return ((due.timeInMillis - uno.timeInMillis) / 86400000L).toInt()
    }

    private fun calendario(forma: SimpleDateFormat, data: String): Calendar? = try {
        val tempo = forma.parse(data) ?: return null
        Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            clear()
            time = tempo
        }
    } catch (errore: Exception) {
        null
    }

    fun apriGiorno(context: Context, data: String): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("$SCHEMA://apri?giorno=$data"),
        )

    fun apriElemento(context: Context, tipo: String, id: String, giorno: String): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("$SCHEMA://apri?tipo=$tipo&id=${Uri.encode(id)}&giorno=$giorno"),
        )

    fun nuovoEvento(context: Context, giorno: String = WidgetPayload.dataOggi()): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("$SCHEMA://nuovo?tipo=evento&giorno=$giorno"),
        )

    fun apriCountdown(context: Context, widgetId: Int): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("$SCHEMA://countdown?widget=$widgetId"),
        )

    fun apriApp(context: Context): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)

    /** L'altezza minima che il launcher ha dato a questo widget. */
    fun altezza(manager: android.appwidget.AppWidgetManager, id: Int): Int =
        manager.getAppWidgetOptions(id)
            ?.getInt(android.appwidget.AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
            ?: 0

    fun setVisibile(vista: RemoteViews, id: Int, visibile: Boolean) {
        vista.setViewVisibility(id, if (visibile) View.VISIBLE else View.GONE)
    }
}
