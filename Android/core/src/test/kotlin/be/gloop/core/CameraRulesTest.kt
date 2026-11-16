package be.gloop.core

import be.gloop.core.camera.AutoTorch
import be.gloop.core.camera.CameraDarkness
import be.gloop.core.camera.CodeMatcher
import be.gloop.core.camera.ColorMatch
import be.gloop.core.camera.ColorTarget
import be.gloop.core.camera.ConsecutiveHits
import be.gloop.core.camera.Embeddings
import be.gloop.core.camera.MatchRules
import be.gloop.core.camera.SkyPolicy
import be.gloop.core.camera.TorchMode
import be.gloop.core.model.MissionKind
import be.gloop.core.random.SplitMix64
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CameraRulesTest {
    @Test fun consecutiveHitsResetOnMiss() {
        val h = ConsecutiveHits(3)
        h.record(true); h.record(true); h.record(false)
        assertEquals(0, h.streak)
        repeat(3) { h.record(true) }
        assertTrue(h.isComplete); assertEquals(1.0, h.progress, 0.0)
    }

    @Test fun codesMatchTrimmedOnly() {
        assertTrue(CodeMatcher.matches("abc\n", " abc"))
        assertFalse(CodeMatcher.matches("abc", "abd"))
        assertFalse(CodeMatcher.matches("", ""))
        assertTrue(CodeMatcher.newPayload().startsWith("gloop:"))
    }

    @Test fun skyLabels() {
        assertTrue(SkyPolicy.isSkyLabel("Sky")); assertTrue(SkyPolicy.isSkyLabel("Cloud"))
        assertFalse(SkyPolicy.isSkyLabel("Skyscraper")); assertFalse(SkyPolicy.isSkyLabel("Ceiling"))
        assertEquals(0.8f, SkyPolicy.score(listOf("Building" to 0.9f, "Sky" to 0.8f, "Cloud" to 0.6f)))
        assertFalse(SkyPolicy.isSky(SkyPolicy.score(listOf("Room" to 0.9f))))
    }

    @Test fun colorsNeedHueSaturationAndBrightness() {
        val (h, s, b) = ColorMatch.hsb(1.0, 0.0, 0.0)
        assertEquals(0.0, h, 0.01); assertEquals(1.0, s, 0.0); assertEquals(1.0, b, 0.0)
        assertTrue(ColorMatch.matches(355.0, 0.8, 0.8, ColorTarget.RED))   // wraps around red
        assertFalse(ColorMatch.matches(0.0, 0.1, 0.9, ColorTarget.RED))    // pale = grey/white
        assertFalse(ColorMatch.matches(54.0, 0.9, 0.3, ColorTarget.YELLOW)) // too dark for yellow
        val blue = ColorMatch.hsb(0.1, 0.3, 0.9)
        assertTrue(ColorMatch.matches(blue.first, blue.second, blue.third, ColorTarget.BLUE))
        val picked = ColorMatch.targets(3, SplitMix64(1))
        assertEquals(3, picked.toSet().size)
    }

    @Test fun matchThresholdFromSpreadClamped() {
        val rules = MatchRules.ITEM
        assertEquals(rules.minimumThreshold, rules.threshold(emptyList()))
        assertEquals(rules.minimumThreshold, rules.threshold(listOf(0.05f)))
        assertEquals(0.3f * 1.15f, rules.threshold(listOf(0.1f, 0.3f)), 1e-6f)
        assertEquals(rules.maximumThreshold, rules.threshold(listOf(0.9f)))
        assertEquals(1.0, rules.closeness(0.1f, 0.2f), 0.0)
        assertEquals(0.5, rules.closeness(0.3f, 0.2f), 1e-6)
        assertEquals(0.0, rules.closeness(0.5f, 0.2f), 0.0)
    }

    @Test fun cosineDistances() {
        val a = floatArrayOf(1f, 0f); val b = floatArrayOf(0f, 1f); val c = floatArrayOf(2f, 0f)
        assertEquals(0f, Embeddings.cosineDistance(a, c), 1e-6f)
        assertEquals(1f, Embeddings.cosineDistance(a, b), 1e-6f)
        assertEquals(0f, Embeddings.nearest(c, listOf(b, a))!!, 1e-6f)
        assertEquals(listOf(0f, 1f, 1f), Embeddings.pairwise(listOf(a, c, b)).map { Math.round(it).toFloat() })
    }

    @Test fun autoTorchLatchesAfterThreeDarkReadings() {
        val t = AutoTorch()
        assertFalse(t.record(true)); assertFalse(t.record(true)); assertFalse(t.record(false))
        repeat(2) { assertFalse(t.record(true)) }
        assertTrue(t.record(true))
        assertTrue(t.record(false)) // stays on
        assertTrue(CameraDarkness.isDark(iso = 3200, exposureSeconds = 1 / 15.0, meanLuma = 0.3))
        assertFalse(CameraDarkness.isDark(iso = 200, exposureSeconds = 1 / 60.0, meanLuma = 0.4))
        assertTrue(CameraDarkness.isDark(null, null, 0.05))
        assertEquals(listOf(TorchMode.ON, TorchMode.OFF, TorchMode.AUTO), TorchMode.entries.map { it.next })
    }

    @Test fun androidRunsEveryMissionNow() {
        assertEquals(MissionKind.entries.toSet(), MissionKind.availableOnAndroid.toSet())
    }
}
