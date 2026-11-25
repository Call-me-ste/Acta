package com.callmeste.planner

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.IOException
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class BoundedFileCopyTest {
    @Test
    fun exactLimitCopiesEverythingWithoutADeclaredSize() {
        val bytes = ByteArray(70_000) { it.toByte() }
        val target = ByteArrayOutputStream()
        val copied = copyWithLimit(ByteArrayInputStream(bytes), target) { size ->
            if (size > bytes.size) throw IOException()
        }
        assertEquals(bytes.size.toLong(), copied)
        assertArrayEquals(bytes, target.toByteArray())
    }

    @Test
    fun exceedingTheLimitByOneByteDoesNotWriteTheExcess() {
        val target = ByteArrayOutputStream()
        assertThrows(IOException::class.java) {
            copyWithLimit(ByteArrayInputStream(ByteArray(65_537)), target) { size ->
                if (size > 65_536) throw IOException()
            }
        }
        assertEquals(65_536, target.size())
    }

    @Test
    fun cancellingBetweenBlocksStopsCopying() {
        val target = ByteArrayOutputStream()
        val copied = copyWithLimit(
            ByteArrayInputStream(ByteArray(80_000)), target,
            cancelled = { target.size() > 0 },
        ) {}
        assertEquals(65_536L, copied)
        assertEquals(65_536, target.size())
    }
}
