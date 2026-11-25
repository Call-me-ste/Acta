package com.callmeste.planner.widget

import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * Il pacchetto dei widget, letto dalle preferenze che scrive Dart.
 *
 * **Il contratto sta in Dart** (`lib/features/widgets/widget_contract.dart` e
 * `domain/widget_payload.dart`): qui si legge e basta, e i nomi delle chiavi
 * devono restare quelli. Una divergenza si vede solo sul telefono, quindi il
 * lato Dart ha i test sulla forma del JSON.
 *
 * Perche' i dati passano da Dart e non dal database: il disegno di un widget lo
 * fa il launcher, che non sa niente dell'app. Il pacchetto gli dice **cosa**
 * scrivere, con colori, emoji e frasi gia' decisi — cosi' la voce dell'app (e le
 * sue parole) resta in un posto solo.
 */
data class WidgetRow(
    val id: String,
    val tipo: String,
    val titolo: String,
    val ora: String,
    val colore: String,
    val coloreScuro: String,
    val tuttoIlGiorno: Boolean,
    val fatto: Boolean,
    val emoji: String,
    val inCorso: Boolean,
) {
    val isTodo: Boolean get() = tipo == TIPO_TODO

    /** Il colore giusto per il tema di sistema. */
    fun colore(night: Boolean): String = if (night) coloreScuro else colore

    companion object {
        const val TIPO_EVENTO = "evento"
        const val TIPO_TODO = "todo"

        fun from(json: JSONObject) = WidgetRow(
            id = json.optString("id"),
            tipo = json.optString("tipo", TIPO_EVENTO),
            titolo = json.optString("titolo"),
            ora = json.optString("ora"),
            colore = json.optString("colore"),
            coloreScuro = json.optString("coloreScuro"),
            tuttoIlGiorno = json.optBoolean("tuttoIlGiorno"),
            fatto = json.optBoolean("fatto"),
            emoji = json.optString("emoji"),
            inCorso = json.optBoolean("inCorso"),
        )
    }
}

/** Un giorno del pacchetto: le righe, i conteggi veri e le frasi da mostrare. */
data class WidgetGiorno(
    val data: String,
    val etichetta: String,
    val stato: String,
    val righe: List<WidgetRow>,
    val eventi: Int,
    val todo: Int,
    val todoFatti: Int,
    /**
     * Le due frasi degli stati vuoti. Arrivano **dentro il pacchetto** (scritte
     * da Dart, dove la voce dell'app e' una sola e si prova): qui restano solo come
     * ripiego per un pacchetto scritto da una versione piu' vecchia.
     */
    val fraseVuoto: String = "Niente in programma per oggi.",
    val fraseTuttoFatto: String = "Nient'altro in programma per oggi.",
) {
    val todoDaFare: Int get() = (todo - todoFatti).coerceAtLeast(0)
    val vuoto: Boolean get() = stato == STATO_VUOTO
    val tuttoFatto: Boolean get() = stato == STATO_TUTTO_FATTO

    companion object {
        const val STATO_OK = "ok"
        const val STATO_VUOTO = "vuoto"
        const val STATO_TUTTO_FATTO = "tuttoFatto"

        fun from(json: JSONObject): WidgetGiorno {
            val righe = json.optJSONArray("righe") ?: JSONArray()
            return WidgetGiorno(
                data = json.optString("data"),
                etichetta = json.optString("etichetta"),
                stato = json.optString("stato", STATO_OK),
                righe = (0 until righe.length()).map {
                    WidgetRow.from(righe.getJSONObject(it))
                },
                eventi = json.optInt("eventi"),
                todo = json.optInt("todo"),
                todoFatti = json.optInt("todoFatti"),
                fraseVuoto = json.optString("fraseVuoto").ifEmpty {
                    "Niente in programma per oggi."
                },
                fraseTuttoFatto = json.optString("fraseTuttoFatto").ifEmpty {
                    "Nient'altro in programma per oggi."
                },
            )
        }
    }
}

/** I colori dei due temi di sistema, per ruolo. */
data class WidgetTema(private val chiaro: Map<String, String>, private val scuro: Map<String, String>) {
    fun colori(night: Boolean): Map<String, String> = if (night) scuro else chiaro

    companion object {
        fun from(json: JSONObject): WidgetTema = WidgetTema(
            chiaro = leggiMappa(json.optJSONObject("light")),
            scuro = leggiMappa(json.optJSONObject("dark")),
        )

        private fun leggiMappa(json: JSONObject?): Map<String, String> {
            if (json == null) return emptyMap()
            return json.keys().asSequence().associateWith { json.optString(it) }
        }
    }
}

object WidgetPayload {
    const val CHIAVE_TEMA = "widget_tema"
    const val CHIAVE_ULTIMO_GIORNO = "widget_ultimo_giorno"

    /** L'indice dei mesi pubblicati: `2026-08,2026-09,2026-10`. */
    const val CHIAVE_MESI_PUBBLICATI = "widget_mesi_pubblicati"

    fun chiaveGiorno(data: String) = "widget_giorno_$data"

    /** La chiave del mese: `widget_mese_2026-09`. */
    fun chiaveMese(annoMese: String) = "widget_mese_$annoMese"

    /** `2026-09` da una data `2026-09-24`. */
    fun annoMese(data: String): String = data.take(7)

    /**
     * I mesi che il pacchetto copre **adesso**.
     *
     * Serve a non servire una chiave rimasta da un giro vecchio: l'app puo'
     * essere rimasta chiusa un mese, e `widget_mese_2026-09` esisterebbe ancora.
     * La finestra la dice questo elenco, non l'esistenza della chiave.
     */
    fun mesiPubblicati(prefs: SharedPreferences): List<String> =
        (prefs.getString(CHIAVE_MESI_PUBBLICATI, null) ?: "")
            .split(",")
            .filter { it.isNotEmpty() }

    fun mesePubblicato(prefs: SharedPreferences, annoMese: String): Boolean =
        mesiPubblicati(prefs).contains(annoMese)

    /** Il mese precedente o successivo (`2026-09` → `2026-10`). */
    fun spostaMese(annoMese: String, scarto: Int): String {
        val parti = annoMese.split("-")
        val anno = parti.getOrNull(0)?.toIntOrNull() ?: return annoMese
        val mese = parti.getOrNull(1)?.toIntOrNull() ?: return annoMese
        val calendario = Calendar.getInstance().apply {
            clear()
            set(anno, mese - 1, 1)
            add(Calendar.MONTH, scarto)
        }
        return FORMA_ANNO_MESE.format(calendario.time)
    }

    /** Il mese in italiano senza pacchetto (`settembre 2026`): ripiego dell'intestazione. */
    fun etichettaMese(annoMese: String): String {
        val parti = annoMese.split("-")
        val anno = parti.getOrNull(0)?.toIntOrNull() ?: return annoMese
        val mese = parti.getOrNull(1)?.toIntOrNull() ?: return annoMese
        val calendario = Calendar.getInstance().apply {
            clear()
            set(anno, mese - 1, 1)
        }
        return FORMA_ETICHETTA_MESE.format(calendario.time)
    }

    /** Il primo giorno del mese, `2026-09-01`: la data con cui si apre l'app. */
    fun primoDelMese(annoMese: String): String = "$annoMese-01"

    /** Il mese del pacchetto, o `null` se non e' nella finestra pubblicata. */
    fun leggiMese(prefs: SharedPreferences, annoMese: String): WidgetMese? {
        if (!mesePubblicato(prefs, annoMese)) return null
        val testo = prefs.getString(chiaveMese(annoMese), null) ?: return null
        return try {
            WidgetMese.from(JSONObject(testo))
        } catch (errore: Exception) {
            null
        }
    }

    /**
     * La chiave che la build **di test** puo' scrivere per far credere ai widget
     * che oggi sia un altro giorno. Nella build ufficiale non la scrive nessuno; se
     * c'e' ma non e' una data, si usa la data vera (un avanzamento di prova non
     * deve poter mandare il widget su una chiave che non esiste).
     */
    const val CHIAVE_OGGI_DI_PROVA = "widget_oggi_di_prova"

    private val FORMA_DATA = Regex("\\d{4}-\\d{2}-\\d{2}")
    private val FORMA_DATA_ISO = SimpleDateFormat("yyyy-MM-dd", Locale.ITALY)

    private val FORMA_ANNO_MESE = SimpleDateFormat("yyyy-MM", Locale.ITALY)

    private val FORMA_ETICHETTA_MESE = SimpleDateFormat("LLLL yyyy", Locale.ITALIAN)

    /** La data di oggi in `AAAA-MM-GG`, nel fuso del telefono. */
    fun dataOggi(prefs: SharedPreferences? = null): String {
        val finta = prefs?.getString(CHIAVE_OGGI_DI_PROVA, null)
        if (finta != null && FORMA_DATA.matches(finta)) return finta

        return SimpleDateFormat("yyyy-MM-dd", Locale.ITALY)
            .format(Calendar.getInstance().time)
    }

    /** La data `data` spostata di [giorni], nella forma `AAAA-MM-GG`. */
    fun dataDopo(data: String, giorni: Int): String {
        val calendario = Calendar.getInstance().apply {
            clear()
            time = FORMA_DATA_ISO.parse(data) ?: return data
            add(Calendar.DAY_OF_MONTH, giorni)
        }
        return FORMA_DATA_ISO.format(calendario.time)
    }

    /**
     * Se il pacchetto copre ancora [data].
     *
     * Le chiavi dei giorni non si cancellano quando invecchiano: senza questo
     * controllo un giorno vecchio mostrerebbe i dati di settimane fa. La
     * finestra è quella scritta da Dart: l'ultimo giorno e i sette prima.
     */
    fun giornoPubblicato(prefs: SharedPreferences, data: String): Boolean {
        val ultimo = prefs.getString(CHIAVE_ULTIMO_GIORNO, null) ?: return false
        if (!FORMA_DATA.matches(ultimo) || !FORMA_DATA.matches(data)) return false
        return data <= ultimo && data >= dataDopo(ultimo, -7)
    }

    /** Il giorno di oggi, o `null` se il pacchetto non lo copre piu'. */
    fun leggiGiorno(
        prefs: SharedPreferences,
        data: String = dataOggi(prefs),
    ): WidgetGiorno? {
        if (!giornoPubblicato(prefs, data)) return null
        val testo = prefs.getString(chiaveGiorno(data), null) ?: return null
        return try {
            WidgetGiorno.from(JSONObject(testo))
        } catch (errore: Exception) {
            null
        }
    }

    fun leggiTema(prefs: SharedPreferences): WidgetTema? {
        val testo = prefs.getString(CHIAVE_TEMA, null) ?: return null
        return try {
            WidgetTema.from(JSONObject(testo))
        } catch (errore: Exception) {
            null
        }
    }
}

/**
 * Un'anteprima di evento nella cella del mese: il titolo (per l'accessibilita' e
 * per quando ci sta) e il colore nei due temi.
 *
 * Il contratto e' quello di `lib/features/widgets/domain/widget_mese.dart`: i
 * nomi delle chiavi devono restare quelli, e una divergenza la vedono i test
 * Dart sulla forma del JSON.
 */
data class WidgetMeseAnteprima(
    val titolo: String,
    val colore: String,
    val coloreScuro: String,
) {
    fun colore(night: Boolean): String = if (night) coloreScuro else colore

    companion object {
        fun from(json: JSONObject) = WidgetMeseAnteprima(
            titolo = json.optString("titolo"),
            colore = json.optString("colore"),
            coloreScuro = json.optString("coloreScuro"),
        )
    }
}

/** Un giorno della griglia: numero, se e' del mese mostrato, eventi e anteprime. */
data class WidgetMeseGiorno(
    val data: String,
    val giorno: Int,
    val fuoriMese: Boolean,
    val eventi: Int,
    val anteprime: List<WidgetMeseAnteprima>,
    val oggi: Boolean,
) {
    /** Quante anteprime restano fuori: e' il «+N» della cella. */
    val altre: Int get() = (eventi - anteprime.size).coerceAtLeast(0)

    /** «24 set»: solo per la descrizione accessibile della cella. */
    fun etichettaAccessibile(mese: String): String {
        val nomeMese = WidgetPayload.etichettaMese(mese).substringBefore(" ")
        return "$giorno $nomeMese" + if (eventi == 1) ", 1 evento" else ", $eventi eventi"
    }

    companion object {
        fun from(json: JSONObject): WidgetMeseGiorno {
            val anteprime = json.optJSONArray("anteprime") ?: JSONArray()
            return WidgetMeseGiorno(
                data = json.optString("data"),
                giorno = json.optInt("giorno"),
                fuoriMese = json.optBoolean("fuoriMese"),
                eventi = json.optInt("eventi"),
                anteprime = (0 until anteprime.length()).map {
                    WidgetMeseAnteprima.from(anteprime.getJSONObject(it))
                },
                oggi = json.optBoolean("oggi"),
            )
        }
    }
}

/** Un mese pronto per il widget mensile: l'intestazione e la griglia intera. */
data class WidgetMese(
    val anno: Int,
    val mese: Int,
    val etichetta: String,
    /** Quante righe ha la griglia: 4, 5 o 6. */
    val settimane: Int,
    val giorni: List<WidgetMeseGiorno>,
) {
    /** `2026-09`: la chiave con cui questo mese e' stato pubblicato. */
    val annoMese: String
        get() = "${anno.toString().padStart(4, '0')}-${mese.toString().padStart(2, '0')}"

    companion object {
        fun from(json: JSONObject): WidgetMese {
            val giorni = json.optJSONArray("giorni") ?: JSONArray()
            return WidgetMese(
                anno = json.optInt("anno"),
                mese = json.optInt("mese"),
                etichetta = json.optString("etichetta"),
                settimane = json.optInt("settimane"),
                giorni = (0 until giorni.length()).map {
                    WidgetMeseGiorno.from(giorni.getJSONObject(it))
                },
            )
        }
    }
}
