package com.callmeste.planner.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Typeface
import android.text.TextPaint
import android.text.TextUtils
import android.widget.RemoteViews
import java.util.concurrent.ConcurrentHashMap

/**
 * Il testo dei widget, disegnato con **Inter** su una bitmap.
 *
 * Perché non un `TextView`: il launcher gonfia le `RemoteViews` con il suo
 * contesto e ignora `android:fontFamily`/`@font`, quindi sul telefono compariva
 * il serif di sistema. L'unico modo per avere lo stesso carattere dell'app è
 * disegnarlo qui e passare un'`ImageView`.
 *
 * Le regole (misure, pesi) stanno in `docs/widget-linee-guida.md`: questo file
 * sa solo *come* si disegna, non *cosa*.
 */
object WidgetText {
    const val REGOLARE = 400
    const val MEDIO = 500
    const val SEMIBOLD = 600
    const val BOLD = 700

    private val caratteri = ConcurrentHashMap<Int, Typeface>()

    fun typeface(context: Context, peso: Int): Typeface = caratteri.getOrPut(peso) {
        val file = when (peso) {
            BOLD -> "flutter_assets/assets/fonts/Inter-Bold.ttf"
            SEMIBOLD -> "flutter_assets/assets/fonts/Inter-SemiBold.ttf"
            MEDIO -> "flutter_assets/assets/fonts/Inter-Medium.ttf"
            else -> "flutter_assets/assets/fonts/Inter-Regular.ttf"
        }
        try {
            Typeface.createFromAsset(context.assets, file)
        } catch (errore: Exception) {
            Typeface.create("sans-serif", Typeface.NORMAL)
        }
    }

    /** La densità: i widget non seguono la scala testo di sistema, la griglia è fissa. */
    fun densita(context: Context): Float = context.resources.displayMetrics.density

    fun px(context: Context, dp: Int): Int = (dp * densita(context)).toInt()

    fun px(context: Context, dp: Float): Int = (dp * densita(context)).toInt()

    /**
     * Una riga di testo come bitmap trasparente.
     *
     * [larghezzaPx] è anche il limite dell'ellissi: il testo non esce mai dalla
     * sua scatola (un titolo tagliato è meglio di un titolo che sborda).
     */
    fun bitmap(
        context: Context,
        testo: String,
        sp: Float,
        peso: Int,
        colore: Int,
        larghezzaPx: Int,
        altezzaPx: Int,
        align: Paint.Align = Paint.Align.LEFT,
        spaziatura: Float = 0f,
        ellissi: Boolean = true,
    ): Bitmap {
        val larghezza = larghezzaPx.coerceAtLeast(1)
        val altezza = altezzaPx.coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(larghezza, altezza, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = typeface(context, peso)
            textSize = sp * densita(context)
            color = colore
            textAlign = align
            letterSpacing = spaziatura
        }
        val visibile = if (ellissi && spaziatura == 0f) {
            TextUtils.ellipsize(testo, paint, larghezza.toFloat(), TextUtils.TruncateAt.END)
                .toString()
        } else {
            testo
        }
        val metriche = paint.fontMetrics
        val base = altezza / 2f - (metriche.ascent + metriche.descent) / 2f
        val x = when (align) {
            Paint.Align.CENTER -> larghezza / 2f
            Paint.Align.RIGHT -> larghezza.toFloat()
            else -> 0f
        }
        canvas.drawText(visibile, x, base, paint)
        return bitmap
    }

    /** Disegna [testo] in un'`ImageView` già presente nel layout. */
    fun scrivi(
        context: Context,
        vista: RemoteViews,
        id: Int,
        testo: String,
        sp: Float,
        peso: Int,
        colore: Int,
        larghezzaDp: Int,
        altezzaDp: Int,
        align: Paint.Align = Paint.Align.LEFT,
        spaziatura: Float = 0f,
    ) {
        vista.setImageViewBitmap(
            id,
            bitmap(
                context = context,
                testo = testo,
                sp = sp,
                peso = peso,
                colore = colore,
                larghezzaPx = px(context, larghezzaDp),
                altezzaPx = px(context, altezzaDp),
                align = align,
                spaziatura = spaziatura,
            ),
        )
        vista.setViewVisibility(id, android.view.View.VISIBLE)
    }
}
