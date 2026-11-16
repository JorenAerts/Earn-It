package be.gloop.core

import be.gloop.core.coach.CoachIntensity
import be.gloop.core.coach.CoachMood
import be.gloop.core.coach.SlimeEyes
import be.gloop.core.coach.SlimeLook
import be.gloop.core.coach.SlimeMouth
import be.gloop.core.legal.LegalDocument
import be.gloop.core.legal.LegalDocumentKind
import be.gloop.core.model.AlarmSound
import be.gloop.core.model.MissionConfig
import be.gloop.core.model.MissionDifficulty
import be.gloop.core.model.MissionKind
import be.gloop.core.model.SoundChoice
import be.gloop.core.onboarding.AlarmReaction
import be.gloop.core.onboarding.GetUpTime
import be.gloop.core.onboarding.MorningGoal
import be.gloop.core.onboarding.MorningStruggle
import be.gloop.core.onboarding.OnboardingAnswers
import be.gloop.core.onboarding.OnboardingContext
import be.gloop.core.onboarding.OnboardingFlow
import be.gloop.core.onboarding.OnboardingPersonalization
import be.gloop.core.onboarding.OnboardingPersonalization.Line
import be.gloop.core.onboarding.OnboardingProgress
import be.gloop.core.onboarding.OnboardingStep
import be.gloop.core.onboarding.SocialProof
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Same cases as iOS `OnboardingTests`, plus Android's billing flag. */
class OnboardingFlowTest {
    private val full = OnboardingContext(accountsAvailable = true, isSignedIn = false, isPro = false)

    @Test fun walksAllStepsInOrder() {
        val seen = generateSequence(OnboardingStep.WELCOME) { OnboardingFlow.next(it, full) }.toList()
        assertEquals(OnboardingStep.entries, seen)
        assertTrue(seen.indexOf(OnboardingStep.BUILDING) > seen.indexOf(OnboardingStep.SOUND))
    }

    @Test fun accountSkippedWhenUnavailableOrSignedIn() {
        assertEquals(OnboardingStep.BUILDING, OnboardingFlow.next(OnboardingStep.INVITE_FRIEND, full.copy(accountsAvailable = false)))
        assertEquals(OnboardingStep.BUILDING, OnboardingFlow.next(OnboardingStep.INVITE_FRIEND, full.copy(isSignedIn = true)))
    }

    @Test fun paywallSkippedForPro() {
        val pro = full.copy(isPro = true)
        assertNull(OnboardingFlow.next(OnboardingStep.SUMMARY, pro))
        assertFalse(OnboardingStep.PAYWALL in OnboardingFlow.visibleSteps(pro))
    }

    @Test fun inviteSkippedOnceUnlocked() {
        val unlocked = full.copy(bonusSoundUnlocked = true)
        assertEquals(OnboardingStep.ACCOUNT, OnboardingFlow.next(OnboardingStep.SOUND, unlocked))
        assertEquals(OnboardingStep.SOUND, OnboardingFlow.previous(OnboardingStep.ACCOUNT, unlocked))
    }

    @Test fun androidWithoutBillingOrAccounts() {
        val android = OnboardingContext(accountsAvailable = false, isSignedIn = false, isPro = false, billingAvailable = false)
        assertEquals(OnboardingStep.BUILDING, OnboardingFlow.next(OnboardingStep.SOUND, android))
        assertNull(OnboardingFlow.next(OnboardingStep.SUMMARY, android))
        assertEquals(17, OnboardingFlow.visibleSteps(android).size)
        assertEquals(1.0, OnboardingFlow.fraction(OnboardingStep.SUMMARY, android), 0.0)
    }

    @Test fun backNavigation() {
        assertNull(OnboardingFlow.previous(OnboardingStep.WELCOME, full))
        assertEquals(OnboardingStep.WELCOME, OnboardingFlow.previous(OnboardingStep.NAME, full))
        assertNull(OnboardingFlow.previous(OnboardingStep.BUILDING, full))
        assertNull(OnboardingFlow.previous(OnboardingStep.SUMMARY, full))
        assertEquals(OnboardingStep.SUMMARY, OnboardingFlow.previous(OnboardingStep.PAYWALL, full))
        for (step in OnboardingStep.entries.filter { it !in setOf(OnboardingStep.WELCOME, OnboardingStep.BUILDING, OnboardingStep.SUMMARY) }) {
            val prev = OnboardingFlow.previous(step, full) ?: continue
            if (prev != OnboardingStep.BUILDING) assertEquals(step, OnboardingFlow.next(prev, full))
        }
    }

    @Test fun progressFraction() {
        assertEquals(0.0, OnboardingFlow.fraction(OnboardingStep.WELCOME, full), 0.0)
        assertEquals(1.0, OnboardingFlow.fraction(OnboardingStep.PAYWALL, full), 0.0)
        assertTrue(OnboardingFlow.fraction(OnboardingStep.MISSION, full) > OnboardingFlow.fraction(OnboardingStep.GOAL, full))
    }

    @Test fun oldStepNamesStillLoad() {
        mapOf("howItWorks" to OnboardingStep.WHY_IT_WORKS, "goals" to OnboardingStep.STRUGGLES, "firstAlarm" to OnboardingStep.MISSION,
            "permissions" to OnboardingStep.PERMISSIONS, "nonsense" to OnboardingStep.WELCOME)
            .forEach { (old, new) -> assertEquals(new, OnboardingStep.fromRaw(old)) }
    }
}

class OnboardingAnswersTest {
    @Test fun firstAlarmUsesAnswers() {
        val answers = OnboardingAnswers(hour = 6, minute = 45, weekdays = setOf(2, 4), getUpTime = GetUpTime.OVER_HOUR,
            missions = listOf(MissionConfig(kind = MissionKind.MATH, difficulty = MissionDifficulty.HARD, target = 5)),
            sound = SoundChoice.of(AlarmSound.REVEILLE))
        val plan = answers.firstAlarm("Wake up")
        assertTrue(plan.hour == 6 && plan.minute == 45 && plan.weekdays == setOf(2, 4) && plan.isEnabled)
        assertEquals(MissionDifficulty.HARD, plan.missions.single().difficulty); assertEquals(5, plan.missions.single().target)
        assertEquals(AlarmSound.REVEILLE, plan.sound.builtIn)
        assertEquals(1, plan.reArmMinutes)
        assertEquals("Wake up", plan.label)
        assertTrue(plan.isReady)
    }

    @Test fun lockedMissionBecomesMathAndLockedSoundClassic() {
        val answers = OnboardingAnswers(missions = listOf(MissionConfig(kind = MissionKind.SHAKE, target = 40)), sound = SoundChoice.of(AlarmSound.CHIME))
        val free = answers.firstAlarm("x", missionLocked = { it != MissionKind.MATH }, soundLocked = { it != AlarmSound.CLASSIC })
        assertEquals(listOf(MissionKind.MATH), free.missions.map { it.kind }); assertEquals(AlarmSound.CLASSIC, free.sound.builtIn)
        assertEquals(listOf(MissionKind.SHAKE), answers.firstAlarm("x").missions.map { it.kind })
        assertTrue(answers.soundNeedsPaywall { it != AlarmSound.CLASSIC })
        assertFalse(answers.copy(sound = SoundChoice.of(AlarmSound.RISE_AND_CONQUER)).soundNeedsPaywall { it != AlarmSound.CLASSIC })
    }

    @Test fun suggestionsAndFallbacks() {
        assertEquals(listOf(MissionKind.MATH), OnboardingAnswers().suggestedMissions)
        val lazy = OnboardingAnswers(struggles = setOf(MorningStruggle.STAY_IN_BED))
        assertEquals(MissionKind.SHAKE, lazy.suggestedMission)
        assertEquals(listOf(MissionKind.SHAKE), lazy.firstAlarm("x").missions.map { it.kind })
        assertEquals(listOf(MissionKind.MATH, MissionKind.SHAKE),
            OnboardingAnswers(struggles = setOf(MorningStruggle.NO_ENERGY, MorningStruggle.SNOOZE)).suggestedMissions)
        // Unregistered scan → Math.
        assertEquals(listOf(MissionKind.MATH), OnboardingAnswers(missions = listOf(MissionConfig(kind = MissionKind.QR))).firstAlarm("x").missions.map { it.kind })
        assertEquals("ID-1", OnboardingAnswers(createdPlanID = "ID-1").firstAlarm("x").id)
    }

    @Test fun progressRoundTripsAndOldProgressDecodes() {
        val p = OnboardingProgress(OnboardingStep.SOUND, OnboardingAnswers(name = "Joren", struggles = setOf(MorningStruggle.SNOOZE),
            missions = listOf(MissionConfig(kind = MissionKind.QUIZ)), createdPlanID = "A"), completed = false)
        assertEquals(p, OnboardingProgress.decode(p.encode()))
        val old = OnboardingProgress.decode("""{"step":"goals","answers":{"hour":6,"minute":15,"weekdays":[2,3],"struggles":["snooze","fallBackAsleep","gone"]},"completed":false}""")!!
        assertEquals(OnboardingStep.STRUGGLES, old.step)
        assertEquals(setOf(MorningStruggle.SNOOZE, MorningStruggle.FALL_BACK_ASLEEP), old.answers.struggles)
        assertTrue(old.answers.hour == 6 && old.answers.minute == 15 && old.answers.weekdays == setOf(2, 3))
        assertTrue(old.answers.name.isEmpty() && old.answers.missions == null && old.answers.sound.builtIn == AlarmSound.CLASSIC)
        assertNull(OnboardingProgress.decode("nope"))
    }
}

class OnboardingPersonalizationTest {
    @Test fun toneAndReRing() {
        assertEquals(CoachIntensity.GENTLE, OnboardingPersonalization.suggestedTone(AlarmReaction.IM_UP))
        assertEquals(CoachIntensity.TOUGH_LOVE, OnboardingPersonalization.suggestedTone(AlarmReaction.FIVE_MORE))
        assertEquals(CoachIntensity.SAVAGE, OnboardingPersonalization.suggestedTone(AlarmReaction.WHY_SO_EARLY))
        assertEquals(CoachIntensity.TOUGH_LOVE, OnboardingPersonalization.suggestedTone(null))
        assertEquals(listOf(3, 2, 2, 1, 2), listOf(GetUpTime.UNDER_10, GetUpTime.TEN_TO_30, GetUpTime.THIRTY_TO_60, GetUpTime.OVER_HOUR, null)
            .map { OnboardingPersonalization.reArmMinutes(it) })
    }

    @Test fun hoursBack() {
        val weekdays = (2..6).toSet()
        assertEquals(1.5, OnboardingPersonalization.hoursBackPerWeek(GetUpTime.TEN_TO_30, weekdays)!!, 0.0)
        assertEquals(8.5, OnboardingPersonalization.hoursBackPerWeek(GetUpTime.OVER_HOUR, (1..7).toSet())!!, 0.0)
        assertNull(OnboardingPersonalization.hoursBackPerWeek(GetUpTime.UNDER_10, weekdays))
        assertNull(OnboardingPersonalization.hoursBackPerWeek(null, weekdays))
        assertEquals("1½" to true, OnboardingPersonalization.hoursBackNumber(1.5))
        assertEquals("1" to false, OnboardingPersonalization.hoursBackNumber(1.0))
    }

    @Test fun coachUsesTheName() {
        val early = OnboardingAnswers(reaction = AlarmReaction.WHY_SO_EARLY)
        assertEquals(listOf("friend"), OnboardingPersonalization.coachReaction(OnboardingStep.ALARM_REACTION, early)!!.args)
        assertEquals(listOf("Joren"), OnboardingPersonalization.coachReaction(OnboardingStep.ALARM_REACTION, early.copy(name = " Joren "))!!.args)
        assertEquals(listOf("07:00"), OnboardingPersonalization.coachReaction(OnboardingStep.WAKE_TIME, early)!!.args)
        assertEquals(Line.STRUGGLE_SNOOZE, OnboardingPersonalization.coachReaction(OnboardingStep.STRUGGLES,
            OnboardingAnswers(struggles = setOf(MorningStruggle.NO_ENERGY, MorningStruggle.SNOOZE)))!!.line)
        assertNull(OnboardingPersonalization.coachReaction(OnboardingStep.GET_UP_TIME, OnboardingAnswers()))
        assertEquals(Line.GOAL_QUIET, OnboardingPersonalization.goalLine(MorningGoal.QUIET_TIME))
        assertEquals(Line.FINISH_DEFAULT, OnboardingPersonalization.finishLine(MorningGoal.ON_TIME))
    }

    @Test fun socialProofOnlyWhenReal() {
        assertEquals(SocialProof.EMPTY, SocialProof.decode(null))
        val bundled = SocialProof.decode(SharedConfig.text("SocialProof.json"))
        assertTrue(bundled.stats.isEmpty() && bundled.reviews.isEmpty())
        val proof = SocialProof.decode("""{"stats":[{"value":"1K+","label":"mornings"}],"reviews":[{"name":"A","text":"ok","stars":9}]}""")
        assertEquals(1, proof.stats.size); assertTrue(proof.reviews.isEmpty())
    }
}

class SlimeAndLegalTest {
    @Test fun slimeLookPerMood() {
        val proud = SlimeLook.make(0.95, CoachMood.PROUD)
        assertEquals(SlimeEyes.SPARKLY, proud.pose.eyes); assertTrue(proud.pose.sparkle && proud.pose.blush); assertEquals(0, proud.pose.drips)
        val suspicious = SlimeLook.make(0.75, CoachMood.SUSPICIOUS)
        assertEquals(SlimeEyes.SQUINT, suspicious.pose.eyes); assertTrue(suspicious.pose.sweat)
        val sad = SlimeLook.make(0.1, CoachMood.DISAPPOINTED)
        assertEquals(SlimeMouth.FROWN, sad.pose.mouth); assertEquals(3, sad.pose.drips)
        val angry = SlimeLook.make(0.8, CoachMood.ANGRY, anger = 1.0)
        assertTrue(angry.pose.steam); assertEquals(1.0, angry.tremble, 0.0)
    }

    @Test fun legalFillAndParse() {
        assertEquals("Hi Joren, [to be completed].", LegalDocument.fill("Hi {{ name }}, {{city}}.", mapOf("name" to "Joren", "city" to " ")))
        val doc = LegalDocument.parse("# Title\nIntro line\nmore\n\n## Part\n- one\n- two\nafter")
        assertEquals("Title", doc.title)
        assertEquals(listOf(
            LegalDocument.Block.Paragraph("Intro line\nmore"), LegalDocument.Block.Heading("Part"),
            LegalDocument.Block.Bullets(listOf("one", "two")), LegalDocument.Block.Paragraph("after")), doc.blocks)
        assertEquals(mapOf("country" to "België"), LegalDocument.localizedValues(mapOf("country" to "Belgium", "country.nl" to "België"), "nl"))
    }

    @Test fun shippedLegalDocumentsLoad() {
        for (kind in LegalDocumentKind.entries) {
            val en = LegalDocument.load(kind, sharedSource, "en")!!
            assertTrue(en.title.isNotBlank() && en.blocks.isNotEmpty() && !en.isTranslation)
            assertTrue(LegalDocument.load(kind, sharedSource, "nl")!!.isTranslation)
        }
        assertFalse(LegalDocument.load(LegalDocumentKind.PRIVACY, sharedSource, "en")!!.blocks.toString().contains("{{"))
    }
}
