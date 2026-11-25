package com.callmeste.planner.widget

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.ScrollView
import android.widget.TextView
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Configurazione del widget: scelta di come mostrare i To do, con una piccola
 * anteprima che cambia subito. Resta un'Activity nativa perché il launcher la
 * apre prima che Flutter sia pronto.
 */
class WidgetConfigActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private lateinit var prefs: android.content.SharedPreferences
    private lateinit var colori: WidgetKit.Colori
    private var mode = TodoMode.NESSUNO
    private lateinit var demoRighe: LinearLayout
    private lateinit var demoConteggi: TextView
    private val radios = mutableListOf<RadioButton>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setTheme(android.R.style.Theme_DeviceDefault_Light_NoActionBar)
        appWidgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        )
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        prefs = HomeWidgetPlugin.getData(this)
        colori = WidgetKit.colori(this, prefs)
        mode = WidgetKit.todoMode(prefs, appWidgetId)
        window.statusBarColor = colori.sfondo
        window.navigationBarColor = colori.sfondo
        window.decorView.systemUiVisibility = if (WidgetKit.isNotte(this)) {
            0
        } else {
            View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
        }

        val radice = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(
                dp(20),
                dp(20) + altezzaStatusBar(),
                dp(20),
                dp(20) + altezzaNavigazione(),
            )
            setBackgroundColor(colori.sfondo)
        }
        radice.addView(testo("PLANNER", 11f, colori.accento, Typeface.BOLD).apply {
            letterSpacing = 0.12f
        })
        radice.addView(testo(nomeWidget(), 26f, colori.testo, Typeface.BOLD).apply {
            setPadding(0, dp(2), 0, dp(4))
        })
        radice.addView(testo(
            "Scegli come mostrare questo widget.",
            14f,
            colori.tenue,
            Typeface.NORMAL,
        ).apply { setPadding(0, 0, 0, dp(18)) })

        radice.addView(testo("ANTEPRIMA", 10f, colori.tenue, Typeface.BOLD).apply {
            letterSpacing = 0.08f
            setPadding(0, 0, 0, dp(4))
        })
        radice.addView(anteprima())
        radice.addView(testo(
            "Tocca un'opzione: l'anteprima cambia subito. I dati reali dipendono dal giorno.",
            11f,
            colori.tenue,
            Typeface.NORMAL,
        ).apply { setPadding(0, dp(8), 0, dp(18)) })

        radice.addView(testo("To do", 17f, colori.testo, Typeface.BOLD))
        radice.addView(testo(
            "Gli eventi restano sempre visibili. Scegli se aggiungere i To do.",
            13f,
            colori.tenue,
            Typeface.NORMAL,
        ).apply { setPadding(0, dp(3), 0, dp(8)) })

        val gruppo = RadioGroup(this).apply {
            orientation = RadioGroup.VERTICAL
        }
        gruppo.addView(
            opzione(TodoMode.NESSUNO, "Non mostrare i To do", "Solo eventi, più spazio per gli appuntamenti."),
            RadioGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ),
        )
        gruppo.addView(
            opzione(
                TodoMode.COMPATTI,
                "To do compatti",
                "Barra fissa in fondo: si apre con un tocco, il calendario non si muove.",
            ),
            RadioGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ),
        )
        gruppo.addView(
            opzione(
                TodoMode.ESTESI,
                "To do estesi",
                "To do sempre in lista, con la spunta direttamente nel widget.",
            ),
            RadioGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ),
        )
        radice.addView(gruppo)

        radice.addView(testo(
            "Gli eventi ci sono sempre; i To do compaiono solo se ce ne sono.",
            11f,
            colori.tenue,
            Typeface.NORMAL,
        ).apply { setPadding(0, dp(8), 0, dp(12)) })

        radice.addView(bottoni())
        aggiornaDemo()
        setContentView(ScrollView(this).apply {
            isFillViewport = true
            addView(radice)
        })
        setResult(RESULT_CANCELED)
    }

    private fun anteprima(): LinearLayout {
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(14), dp(12), dp(14), dp(12))
            background = sfondo(
                colori.superficie,
                18f,
                Color.argb(48, Color.red(colori.tenue), Color.green(colori.tenue), Color.blue(colori.tenue)),
            )
        }
        val testata = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        testata.addView(testo("Oggi · sab 27", 14f, colori.testo, Typeface.BOLD), peso())
        demoConteggi = testo("", 11f, colori.tenue, Typeface.NORMAL)
        testata.addView(demoConteggi)
        card.addView(testata)
        card.addView(View(this).apply {
            setBackgroundColor(Color.argb(30, Color.red(colori.tenue), Color.green(colori.tenue), Color.blue(colori.tenue)))
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(1)).apply {
                topMargin = dp(8)
                bottomMargin = dp(6)
            }
        })
        demoRighe = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        card.addView(demoRighe)
        return card
    }

    private fun aggiornaDemo() {
        if (!::demoRighe.isInitialized) return
        demoRighe.removeAllViews()
        demoConteggi.text = if (mode == TodoMode.NESSUNO) "2 eventi" else "2 eventi · 2 To do"
        demoEvento("10:30", "Volontariato", colori.accento)
        demoEvento("18:30", "Cena con Anna", Color.rgb(232, 154, 44))
        if (mode != TodoMode.NESSUNO) {
            demoTodo("Ritirare il pacco", "09:00", mode == TodoMode.ESTESI)
            demoTodo("Spesa", "19:30", mode == TodoMode.ESTESI)
        }
    }

    private fun demoEvento(ora: String, titolo: String, colore: Int) {
        val riga = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, dp(3), 0, dp(3))
        }
        riga.addView(View(this).apply {
            setBackgroundColor(colore)
            layoutParams = LinearLayout.LayoutParams(dp(3), dp(16)).apply { marginEnd = dp(8) }
        })
        riga.addView(testo(ora, 10f, colori.tenue, Typeface.NORMAL).apply {
            layoutParams = LinearLayout.LayoutParams(dp(42), ViewGroup.LayoutParams.WRAP_CONTENT)
        })
        riga.addView(testo(titolo, 13f, colori.testo, Typeface.BOLD), peso())
        demoRighe.addView(riga)
    }

    private fun demoTodo(titolo: String, ora: String, esteso: Boolean) {
        val riga = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, dp(3), 0, dp(3))
        }
        riga.addView(testo("☐", 15f, colori.accento, Typeface.NORMAL).apply {
            layoutParams = LinearLayout.LayoutParams(dp(24), ViewGroup.LayoutParams.WRAP_CONTENT)
        })
        val testi = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        testi.addView(testo(titolo, 13f, colori.testo, Typeface.NORMAL))
        if (esteso) testi.addView(testo("oggi · $ora", 10f, colori.tenue, Typeface.NORMAL))
        riga.addView(testi, peso())
        demoRighe.addView(riga)
    }

    private fun opzione(
        valore: TodoMode,
        titolo: String,
        descrizione: String,
    ): LinearLayout {
        val riga = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.TOP
            setPadding(dp(4), dp(4), dp(4), dp(6))
            isClickable = true
        }
        val radio = RadioButton(this).apply {
            id = View.generateViewId()
            tag = valore
            isChecked = valore == mode
            buttonTintList = ColorStateList.valueOf(colori.accento)
            setPadding(0, 0, dp(6), 0)
        }
        radios.add(radio)
        radio.setOnCheckedChangeListener { _, checked ->
            if (checked) {
                radios.filter { it !== radio }.forEach { it.isChecked = false }
                mode = valore
                aggiornaDemo()
            }
        }
        riga.addView(radio, LinearLayout.LayoutParams(dp(44), dp(40)))
        val testi = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        testi.addView(testo(titolo, 14f, colori.testo, Typeface.BOLD))
        testi.addView(testo(descrizione, 12f, colori.tenue, Typeface.NORMAL))
        riga.addView(testi, peso())
        riga.setOnClickListener { radio.isChecked = true }
        return riga
    }

    private fun bottoni(): LinearLayout {
        val riga = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
            setPadding(0, dp(6), 0, 0)
        }
        riga.addView(Button(this).apply {
            text = "Annulla"
            isAllCaps = false
            setTextColor(colori.testo)
            background = null
            setOnClickListener {
                setResult(RESULT_CANCELED)
                finish()
            }
        })
        riga.addView(Button(this).apply {
            text = "Salva"
            isAllCaps = false
            setTextColor(if (luminanza(colori.accento) > 0.6) Color.BLACK else Color.WHITE)
            background = sfondo(colori.accento, 22f)
            minHeight = dp(48)
            setPadding(dp(20), 0, dp(20), 0)
            setOnClickListener { salva() }
        }, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            dp(48),
        ).apply { marginStart = dp(8) })
        return riga
    }

    private fun salva() {
        WidgetKit.scriviTodoMode(prefs, appWidgetId, mode)
        aggiornaWidget()
        setResult(
            RESULT_OK,
            Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId),
        )
        finish()
    }

    /**
     * La configurazione deve aggiornare subito il widget. Il broadcast da solo
     * non basta su tutti i launcher: per i provider che conosciamo ridisegniamo
     * qui la RemoteViews, così il risultato è visibile prima di uscire.
     */
    private fun aggiornaWidget() {
        val manager = AppWidgetManager.getInstance(this)
        val provider = manager.getAppWidgetInfo(appWidgetId)?.provider ?: return
        when (provider.className) {
            OggiWidgetProvider::class.java.name -> {
                AgendaWidgetRenderer.aggiorna(this, manager, prefs, appWidgetId)
            }
            MeseWidgetProvider::class.java.name -> {
                WidgetMeseNuovoRenderer.aggiorna(
                    this,
                    manager,
                    prefs,
                    appWidgetId,
                    WidgetMeseRenderer.Variante.MESE_4X2,
                )
            }
            MeseGrandeWidgetProvider::class.java.name -> {
                WidgetMeseNuovoRenderer.aggiorna(
                    this,
                    manager,
                    prefs,
                    appWidgetId,
                    WidgetMeseRenderer.Variante.MESE_4X4,
                )
            }
            EventiWidgetProvider::class.java.name -> {
                EventiWidgetProvider().aggiorna(this, manager, prefs, appWidgetId)
            }
            else -> {
                sendBroadcast(
                    Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE).apply {
                        component = provider
                        putExtra(
                            AppWidgetManager.EXTRA_APPWIDGET_IDS,
                            intArrayOf(appWidgetId),
                        )
                    },
                )
            }
        }
    }

    private fun nomeWidget(): String {
        val info = AppWidgetManager.getInstance(this).getAppWidgetInfo(appWidgetId)
        return when (info?.provider?.className?.substringAfterLast('.')) {
            "OggiWidgetProvider" -> "Agenda"
            "MeseWidgetProvider" -> "Mese"
            "MeseGrandeWidgetProvider" -> "Mese + giorno"
            "EventiWidgetProvider" -> "Eventi di oggi"
            else -> "Widget"
        }
    }

    private fun testo(
        valore: String,
        sizeSp: Float,
        colore: Int,
        stile: Int,
    ): TextView = TextView(this).apply {
        text = valore
        setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp)
        setTextColor(colore)
        setTypeface(Typeface.create("sans-serif", stile))
        includeFontPadding = false
    }

    private fun peso(): LinearLayout.LayoutParams =
        LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)

    private fun sfondo(colore: Int, raggioDp: Float, bordo: Int? = null): GradientDrawable =
        GradientDrawable().apply {
            setColor(colore)
            cornerRadius = dp(raggioDp).toFloat()
            if (bordo != null) setStroke(dp(1).coerceAtLeast(1), bordo)
        }

    private fun luminanza(colore: Int): Double {
        fun canale(v: Int): Double {
            val c = v / 255.0
            return if (c <= 0.03928) c / 12.92 else Math.pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * canale(Color.red(colore)) +
            0.7152 * canale(Color.green(colore)) +
            0.0722 * canale(Color.blue(colore))
    }

    private fun altezzaStatusBar(): Int =
        risorsaDimensione("status_bar_height", dp(24))

    private fun altezzaNavigazione(): Int =
        risorsaDimensione("navigation_bar_height", dp(0))

    private fun risorsaDimensione(nome: String, fallback: Int): Int {
        val id = resources.getIdentifier(nome, "dimen", "android")
        return if (id > 0) resources.getDimensionPixelSize(id) else fallback
    }

    private fun dp(valore: Int): Int =
        (valore * resources.displayMetrics.density).toInt()

    private fun dp(valore: Float): Int = dp(valore.toInt())
}
