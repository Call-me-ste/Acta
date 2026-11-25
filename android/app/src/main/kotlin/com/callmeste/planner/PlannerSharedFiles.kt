package com.callmeste.planner

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.os.StatFs
import android.system.ErrnoException
import android.system.OsConstants
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

class PlannerSharedFiles(private val activity: Activity) {
    private var channel: MethodChannel? = null
    private val queue = ArrayDeque<List<Uri>>()
    private var picker: MethodChannel.Result? = null
    private var scannerPick = false
    private val requestCode = 5047

    fun register(messenger: BinaryMessenger) {
        val methods = MethodChannel(messenger, "planner/shared_files")
        channel = methods
        methods.setMethodCallHandler { call, result ->
            when (call.method) {
                "take" -> {
                    val next = queue.removeFirstOrNull()
                    if (next == null) result.success(batch(emptyList(), emptyList()))
                    else stage(next, result)
                }
                "pick" -> select(
                    call.argument<Boolean>("pdf") == true,
                    call.argument<Boolean>("single") != true,
                    call.argument<Boolean>("scanPhoto") == true,
                    result,
                )
                else -> result.notImplemented()
            }
        }
        accept(activity.intent)
    }

    @Suppress("DEPRECATION")
    fun accept(intent: Intent?) {
        val incoming = intent ?: return
        val items = when (incoming.action) {
            Intent.ACTION_SEND ->
                listOfNotNull(incoming.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))
            Intent.ACTION_SEND_MULTIPLE ->
                incoming.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM).orEmpty()
            else -> return
        }.filter { it.scheme == "content" && !it.authority.orEmpty().startsWith(activity.packageName) }
        if (items.isEmpty()) return
        if (queue.size >= 4) queue.removeFirst()
        queue.addLast(items)
        incoming.removeExtra(Intent.EXTRA_STREAM)
        channel?.invokeMethod("ready", null)
    }

    @Suppress("DEPRECATION")
    private fun select(pdf: Boolean, multiple: Boolean, scan: Boolean, result: MethodChannel.Result) {
        if (picker != null) {
            result.error("busy", "Un selettore è già aperto", null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = if (pdf) "application/pdf" else "image/*"
            if (!pdf && !scan) putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/jpeg", "image/png", "image/webp"))
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        picker = result
        scannerPick = scan
        try {
            activity.startActivityForResult(intent, requestCode)
        } catch (_: Exception) {
            picker = null
            scannerPick = false
            result.error("unavailable", "Selettore documenti non disponibile", null)
        }
    }

    fun complete(code: Int, resultCode: Int, data: Intent?) {
        if (code != requestCode) return
        val result = picker ?: return
        val scan = scannerPick
        scannerPick = false
        picker = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(if (scan) emptyList<Map<String, String>>() else batch(emptyList(), emptyList()))
            return
        }
        val picked = data.clipData
        val uris = if (picked != null) {
            (0 until picked.itemCount).map { picked.getItemAt(it).uri }
        } else {
            listOfNotNull(data.data)
        }.filter { it.scheme == "content" }
        if (scan && uris.isNotEmpty()) {
            prepareScanPhoto(activity, uris.first(), result)
        } else if (scan) {
            result.success(emptyList<Map<String, String>>())
        } else {
            stage(uris, result)
        }
    }

    private fun batch(files: List<Map<String, String>>, skipped: List<String>) =
        mapOf("files" to files, "skipped" to skipped)

    private fun stage(uris: List<Uri>, result: MethodChannel.Result) {
        Thread {
            val files = mutableListOf<Map<String, String>>()
            val skipped = MutableList((uris.size - 16).coerceAtLeast(0)) { "selection_count" }
            var total = 0L
            for (uri in uris.take(16)) {
                var file: File? = null
                try {
                    val resolver = activity.contentResolver
                    val mime = resolver.getType(uri)
                    val pdf = mime == "application/pdf"
                    if (!pdf && mime !in setOf("image/jpeg", "image/png", "image/webp")) {
                        throw AttachmentLimit("unsupported")
                    }
                    val maximum = (if (pdf) 100L else 18L) * 1024 * 1024
                    val available = StatFs(activity.cacheDir.path).availableBytes
                    fun check(size: Long) {
                        if (size > maximum) throw AttachmentLimit(if (pdf) "pdf_large" else "photo_large")
                        if (total + size > 200L * 1024 * 1024) throw AttachmentLimit("selection_large")
                        if (size > available) throw AttachmentLimit("device_full")
                    }
                    var name = if (pdf) "Documento.pdf" else "Foto"
                    resolver.query(
                        uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null
                    )?.use { cursor ->
                        if (cursor.moveToFirst()) {
                            val nameColumn = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                            val sizeColumn = cursor.getColumnIndex(OpenableColumns.SIZE)
                            if (nameColumn >= 0) name = cursor.getString(nameColumn) ?: name
                            if (sizeColumn >= 0 && !cursor.isNull(sizeColumn)) check(cursor.getLong(sizeColumn))
                        }
                    }
                    val output = File.createTempFile("planner-share-", if (pdf) ".pdf" else ".image", activity.cacheDir)
                    file = output
                    val input = resolver.openInputStream(uri) ?: throw IOException()
                    val size = input.use { source ->
                        output.outputStream().use { target ->
                            copyWithLimit(source, target, checkSize = ::check)
                        }
                    }
                    if (size == 0L) throw AttachmentLimit("empty")
                    total += size
                    files.add(mapOf(
                        "path" to output.absolutePath,
                        "name" to name,
                        "kind" to if (pdf) "pdf" else "photo"
                    ))
                } catch (error: Exception) {
                    file?.delete()
                    skipped.add(when {
                        error is AttachmentLimit -> error.code
                        error.cause is ErrnoException &&
                            (error.cause as ErrnoException).errno == OsConstants.ENOSPC -> "device_full"
                        else -> "unreadable"
                    })
                }
            }
            activity.runOnUiThread { result.success(batch(files, skipped)) }
        }.start()
    }

    private class AttachmentLimit(val code: String) : IOException()
}
