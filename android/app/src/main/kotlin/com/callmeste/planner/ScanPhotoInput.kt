package com.callmeste.planner

import android.app.Activity
import android.content.ContentResolver
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import android.os.Build
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import kotlin.math.roundToInt

private const val sideLimit = 2200

internal fun prepareScanPhoto(
    activity: Activity,
    uri: Uri?,
    result: MethodChannel.Result,
    cameraPath: String? = null,
) {
    Thread {
        var output: File? = null
        try {
            val source = uri ?: cameraPath?.let {
                val file = File(it).canonicalFile
                if (!file.path.startsWith(activity.cacheDir.canonicalPath + File.separator)) {
                    throw IOException("Percorso della fotocamera non valido")
                }
                Uri.fromFile(file)
            } ?: throw IOException("Foto assente")
            val bitmap = readScanBitmap(activity.contentResolver, source)
            try {
                val file = File.createTempFile("planner-scan-input-", ".jpg", activity.cacheDir)
                output = file
                file.outputStream().use {
                    if (!bitmap.compress(Bitmap.CompressFormat.JPEG, 91, it)) {
                        throw IOException("Conversione JPEG non riuscita")
                    }
                }
                activity.runOnUiThread {
                    if (uri != null) {
                        result.success(listOf(mapOf("path" to file.absolutePath, "name" to "Foto.jpg")))
                    } else {
                        result.success(file.absolutePath)
                    }
                }
            } finally {
                bitmap.recycle()
            }
        } catch (_: Exception) {
            output?.delete()
            activity.runOnUiThread {
                result.error("invalid_photo", "Impossibile leggere questa foto. Verifica che si apra in Galleria.", null)
            }
        }
    }.start()
}

private fun readScanBitmap(resolver: ContentResolver, uri: Uri): Bitmap {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
        return ImageDecoder.decodeBitmap(ImageDecoder.createSource(resolver, uri)) { decoder, info, _ ->
            val width = info.size.width
            val height = info.size.height
            val largest = maxOf(width, height)
            if (largest > sideLimit) {
                val scale = sideLimit.toDouble() / largest
                decoder.setTargetSize(maxOf(1, (width * scale).roundToInt()), maxOf(1, (height * scale).roundToInt()))
            }
            decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
        }
    }

    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
    val largest = maxOf(bounds.outWidth, bounds.outHeight)
    if (largest <= 0) throw IOException("Foto non leggibile")
    val settings = BitmapFactory.Options().apply {
        inSampleSize = 1
        while (largest / inSampleSize > sideLimit) inSampleSize *= 2
    }
    val bitmap = resolver.openInputStream(uri)?.use {
        BitmapFactory.decodeStream(it, null, settings)
    } ?: throw IOException("Foto non leggibile")
    val orientation = runCatching {
        resolver.openInputStream(uri)?.use {
            ExifInterface(it).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
        }
    }.getOrNull()
    val rotation = when (orientation) {
        ExifInterface.ORIENTATION_ROTATE_90 -> 90f
        ExifInterface.ORIENTATION_ROTATE_180 -> 180f
        ExifInterface.ORIENTATION_ROTATE_270 -> 270f
        else -> return bitmap
    }
    val matrix = Matrix().apply { postRotate(rotation) }
    return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
        .also { if (it !== bitmap) bitmap.recycle() }
}
