package com.callmeste.planner.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Le cose dei widget che si possono provare senza telefono: date, etichette e
 * chiavi del mese. La geometria delle griglie è affidata ai layout e alla prova
 * sul launcher; qui si bloccano i calcoli che, se sbagliati, darebbero un widget
 * silenziosamente sbagliato (un mese «2026-00», un countdown di un giorno).
 */
class WidgetMeseTest {

    @Test
    fun `il countdown conta i giorni in UTC, anche attraverso l'ora legale`() {
        assertEquals(2, WidgetKit.giorniTra("2026-10-24", "2026-10-26"))
        assertEquals(0, WidgetKit.giorniTra("2026-10-26", "2026-10-26"))
        assertEquals(-1, WidgetKit.giorniTra("2026-10-26", "2026-10-25"))
        // 25 ottobre 2026 è il cambio d'ora in Italia: in UTC restano 2 giorni.
        assertEquals(2, WidgetKit.giorniTra("2026-10-24", "2026-10-26"))
    }

    @Test
    fun `oggi e domani hanno un'etichetta vera`() {
        assertEquals("Oggi", WidgetKit.etichettaData("2026-10-26", "2026-10-26"))
        assertEquals("Domani", WidgetKit.etichettaData("2026-10-27", "2026-10-26"))
        assertEquals("28 ott", WidgetKit.etichettaData("2026-10-28", "2026-10-26"))
        assertTrue(WidgetKit.etichettaGiorno("2026-10-26").contains("26"))
    }

    @Test
    fun `la freccia attraversa l'anno`() {
        assertEquals("2025-12", WidgetPayload.spostaMese("2026-01", -1))
        assertEquals("2027-01", WidgetPayload.spostaMese("2026-12", 1))
        assertEquals("2026-09", WidgetPayload.spostaMese("2026-09", 0))
    }

    @Test
    fun `una chiave malformata non fa saltare il widget`() {
        assertEquals("storto", WidgetPayload.spostaMese("storto", 1))
        assertEquals("2026-xx", WidgetPayload.spostaMese("2026-xx", 1))
    }

    @Test
    fun `la data e l'anno-mese si ricavano l'uno dall'altro`() {
        assertEquals("2026-09", WidgetPayload.annoMese("2026-09-24"))
        assertEquals("2026-09-01", WidgetPayload.primoDelMese("2026-09"))
    }

    @Test
    fun `l'etichetta del mese e' in italiano`() {
        assertEquals("settembre 2026", WidgetPayload.etichettaMese("2026-09"))
        assertEquals("gennaio 2027", WidgetPayload.etichettaMese("2027-01"))
    }

    @Test
    fun `il mese sa la propria chiave`() {
        val mese = WidgetMese(
            anno = 2026,
            mese = 9,
            etichetta = "settembre 2026",
            settimane = 5,
            giorni = emptyList(),
        )
        assertEquals("2026-09", mese.annoMese)
    }

    @Test
    fun `il piu' N e' la differenza vera, non zero per caso`() {
        val anteprime = listOf(
            WidgetMeseAnteprima("a", "#111111", "#222222"),
            WidgetMeseAnteprima("b", "#333333", "#444444"),
        )
        val giorno = WidgetMeseGiorno(
            data = "2026-09-24",
            giorno = 24,
            fuoriMese = false,
            eventi = 5,
            anteprime = anteprime,
            oggi = true,
        )
        assertEquals(3, giorno.altre)

        val vuoto = giorno.copy(eventi = 0, anteprime = emptyList())
        assertEquals(0, vuoto.altre)
    }
}
