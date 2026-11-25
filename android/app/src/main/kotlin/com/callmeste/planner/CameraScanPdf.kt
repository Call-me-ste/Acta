package com.callmeste.planner

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.pdf.PdfDocument
import android.media.ExifInterface
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

internal fun captureScanPdf(activity: Activity, paths: List<String>, result: MethodChannel.Result) {
    Thread {
        var output: File? = null
        try {
            if (paths.size !in 1..20) throw IOException()
            val cache = activity.cacheDir.canonicalPath + File.separator
            val file = File.createTempFile("planner-scan-", ".pdf", activity.cacheDir)
            output = file
            val pdf = PdfDocument()
            try {
                paths.forEachIndexed { index, path ->
                    val source = File(path).canonicalFile
                    if (!source.path.startsWith(cache) || source.length() !in 1..(18L * 1024 * 1024)) {
                        throw IOException()
                    }
                    appendImage(pdf, source, index + 1)
                }
                file.outputStream().use { pdf.writeTo(it) }
            } finally {
                pdf.close()
            }
            activity.runOnUiThread { result.success(file.absolutePath) }
        } catch (_: Exception) {
            output?.delete()
            activity.runOnUiThread {
                result.error("capture_failed", "Impossibile creare il PDF dalla foto.", null)
            }
        }
    }.start()
}

private fun appendImage(pdf: PdfDocument, source: File, number: Int) {
    val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeFile(source.path, options)
    val longest = maxOf(options.outWidth, options.outHeight)
    if (longest <= 0 || longest > 20000) throw IOException()
    options.inJustDecodeBounds = false
    options.inSampleSize = 1
    while (longest / options.inSampleSize > 1900) options.inSampleSize *= 2
    val bitmap = BitmapFactory.decodeFile(source.path, options) ?: throw IOException()
    try {
        val orientation = runCatching {
            ExifInterface(source.path).getAttributeInt(
                ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL,
            )
        }.getOrDefault(ExifInterface.ORIENTATION_NORMAL)
        val rotation = when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> 0f
        }
        val page = if (rotation == 0f) bitmap else Bitmap.createBitmap(
            bitmap, 0, 0, bitmap.width, bitmap.height,
            Matrix().apply { postRotate(rotation) }, true,
        )
        try {
            writeScanPage(pdf, page, number)
        } finally {
            if (page !== bitmap) page.recycle()
        }
    } finally {
        bitmap.recycle()
    }
}

private fun writeScanPage(pdf: PdfDocument, bitmap: Bitmap, number: Int) {
    val scale = 842.0 / maxOf(bitmap.width, bitmap.height)
    val width = (bitmap.width * scale).toInt().coerceAtLeast(1)
    val height = (bitmap.height * scale).toInt().coerceAtLeast(1)
    val page = pdf.startPage(PdfDocument.PageInfo.Builder(width, height, number).create())
    page.canvas.drawColor(Color.WHITE)
    page.canvas.drawBitmap(bitmap, null, Rect(0, 0, width, height), Paint(Paint.FILTER_BITMAP_FLAG))
    pdf.finishPage(page)
}
