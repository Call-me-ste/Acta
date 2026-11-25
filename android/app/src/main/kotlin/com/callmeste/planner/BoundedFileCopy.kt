package com.callmeste.planner

import java.io.InputStream
import java.io.OutputStream

internal fun copyWithLimit(
    source: InputStream,
    target: OutputStream,
    cancelled: () -> Boolean = { false },
    checkSize: (Long) -> Unit,
): Long {
    val buffer = ByteArray(64 * 1024)
    var copied = 0L
    while (!cancelled()) {
        val count = source.read(buffer)
        if (count < 0 || cancelled()) break
        copied += count
        checkSize(copied)
        target.write(buffer, 0, count)
    }
    return copied
}
