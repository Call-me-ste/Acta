package com.callmeste.planner

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.StatFs
import android.provider.OpenableColumns
import android.system.ErrnoException
import android.system.OsConstants
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.io.InputStream

internal class BackupFilePicker(private val activity: Activity) {
    private var richiesta: MethodChannel.Result? = null
    private var selectedUri: Uri? = null
    private var copying = false
    @Volatile private var cancelled = false
    @Volatile private var activeInput: InputStream? = null
    private val codice = 1841

    fun registra(messenger: BinaryMessenger) {
        MethodChannel(messenger, "planner/backup").setMethodCallHandler { call, result ->
            when (call.method) {
                "scegliFile" -> {
                    if (richiesta != null || copying || selectedUri != null) {
                        result.error("busy", null, null)
                    } else scegliFile(result)
                }
                "leggiFile" -> {
                    val uri = selectedUri
                    val maximum = call.argument<Number>("maximumBytes")?.toLong() ?: 0
                    if (uri == null || copying || maximum <= 0) {
                        result.error("lettura", null, null)
                    } else {
                        selectedUri = null
                        copying = true
                        cancelled = false
                        leggiFile(uri, maximum, result)
                    }
                }
                "annullaLettura" -> {
                    selectedUri = null
                    cancelled = true
                    activeInput?.let { input -> Thread { runCatching { input.close() } }.start() }
                    result.success(null)
                }
                "gestisciSpazioDrive" -> {
                    try {
                        activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://one.google.com/storage/management")))
                        result.success(null)
                    } catch (_: RuntimeException) {
                        result.error("browser", null, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun scegliFile(result: MethodChannel.Result) {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
        }
        richiesta = result
        try {
            activity.startActivityForResult(intent, codice)
        } catch (_: RuntimeException) {
            richiesta = null
            result.error("picker", null, null)
        }
    }

    fun consegna(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != codice) return
        val result = richiesta ?: return
        richiesta = null
        selectedUri = data?.data?.takeIf { resultCode == Activity.RESULT_OK }
        result.success(selectedUri != null)
    }

    private fun leggiFile(uri: Uri, maximum: Long, result: MethodChannel.Result) {
        Thread {
            var copia: File? = null
            try {
                val resolver = activity.contentResolver
                var name = "copia"
                var size: Long? = null
                resolver.query(
                    uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null,
                )?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val nameColumn = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        val sizeColumn = cursor.getColumnIndex(OpenableColumns.SIZE)
                        if (nameColumn >= 0) name = cursor.getString(nameColumn) ?: name
                        if (sizeColumn >= 0 && !cursor.isNull(sizeColumn)) size = cursor.getLong(sizeColumn)
                    }
                }
                val space = StatFs(activity.cacheDir.path).availableBytes
                checkSize(size ?: 0, maximum, space)
                val file = File.createTempFile("planner-import-", ".db", activity.cacheDir)
                copia = file
                val input = resolver.openInputStream(uri) ?: throw IOException()
                activeInput = input
                input.use { source ->
                    file.outputStream().use { output ->
                        copyWithLimit(source, output, { cancelled }) { copied ->
                            checkSize(copied, maximum, space)
                        }
                    }
                }
                activity.runOnUiThread {
                    copying = false
                    if (cancelled) {
                        file.delete()
                        result.success(null)
                    } else {
                        result.success(mapOf("path" to file.path, "name" to name))
                    }
                }
            } catch (error: Exception) {
                copia?.delete()
                activity.runOnUiThread {
                    copying = false
                    when {
                        cancelled -> result.success(null)
                        error is CopyLimit -> result.error(error.code, null, null)
                        error.cause is ErrnoException &&
                            (error.cause as ErrnoException).errno == OsConstants.ENOSPC ->
                            result.error("device_full", null, null)
                        else -> result.error("lettura", null, null)
                    }
                }
            } finally {
                activeInput = null
            }
        }.start()
    }

    private fun checkSize(bytes: Long, maximum: Long, space: Long) {
        if (bytes > maximum) throw CopyLimit("too_large")
        if (bytes > space) throw CopyLimit("device_full")
    }

    private class CopyLimit(val code: String) : IOException()
}
