package be.gloop.app.onboarding

import android.content.Context
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import be.gloop.app.R
import be.gloop.app.alarm.AlarmController
import be.gloop.core.coach.CoachIntensity
import be.gloop.core.onboarding.AgeRange
import be.gloop.core.onboarding.AlarmReaction
import be.gloop.core.onboarding.GetUpTime
import be.gloop.core.onboarding.HeardFrom
import be.gloop.core.onboarding.MorningGoal
import be.gloop.core.onboarding.OnboardingContext
import be.gloop.core.onboarding.OnboardingFlow
import be.gloop.core.onboarding.OnboardingPersonalization
import be.gloop.core.onboarding.OnboardingProgress
import be.gloop.core.onboarding.OnboardingStep

/** `gloop.onboarding` in SharedPreferences (iOS `OnboardingStore`). */
class OnboardingStore(context: Context) {
    private val prefs = context.getSharedPreferences("gloop", Context.MODE_PRIVATE)

    fun load(): OnboardingProgress = OnboardingProgress.decode(prefs.getString(KEY, null)) ?: OnboardingProgress()
    fun save(progress: OnboardingProgress) = prefs.edit().putString(KEY, progress.encode()).apply()

    /** Installs from before onboarding already have alarms: don't make them onboard (iOS legacy flag). */
    fun needsOnboarding(hasAlarms: Boolean): Boolean {
        val progress = load()
        if (progress.completed) return false
        if (hasAlarms && prefs.getString(KEY, null) == null) { save(progress.copy(completed = true)); return false }
        return true
    }

    /** Debug: run onboarding again (answers kept, so replaying updates the same alarm). */
    fun reset() = save(load().copy(completed = false, step = OnboardingStep.WELCOME))

    companion object { private const val KEY = "gloop.onboarding" }
}

/** Android today: no accounts, no billing yet; those steps return with phases 3–4. */
private val ANDROID_CONTEXT = OnboardingContext(accountsAvailable = false, isSignedIn = false, isPro = false, billingAvailable = false)

/** Full-screen onboarding: questions → guided first alarm → summary (iOS `OnboardingView`). */
@Composable
fun OnboardingScreen(controller: AlarmController, store: OnboardingStore, onFinish: () -> Unit) {
    val context = LocalContext.current
    var progress by remember { mutableStateOf(store.load()) }
    var goingBack by remember { mutableStateOf(false) }
    fun change(p: OnboardingProgress) { progress = p; store.save(p) }
    fun advance() {
        goingBack = false
        val next = OnboardingFlow.next(progress.step, ANDROID_CONTEXT)
        if (next == null) { change(progress.copy(completed = true)); onFinish() } else change(progress.copy(step = next))
    }
    val previous = OnboardingFlow.previous(progress.step, ANDROID_CONTEXT)
    fun back() { previous?.let { goingBack = true; change(progress.copy(step = it)) } }
    BackHandler(enabled = previous != null, onBack = ::back)
    BackHandler(enabled = previous == null) { /* welcome / building / summary: stay */ }

    val answers = progress.answers
    val update: (be.gloop.core.onboarding.OnboardingAnswers) -> Unit = { change(progress.copy(answers = it)) }

    Column(Modifier.fillMaxSize().safeDrawingPadding()) {
        if (!progress.step.isFullScreen) {
            val fraction by animateFloatAsState(OnboardingFlow.fraction(progress.step, ANDROID_CONTEXT).toFloat(), label = "progress")
            Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                val backLabel = stringResource(R.string.ob_back)
                Box(Modifier.size(44.dp).alpha(if (previous != null) 1f else 0f).clip(CircleShape).background(MaterialTheme.colorScheme.surfaceContainerHigh)
                    .clickable(enabled = previous != null, onClick = ::back).semantics { contentDescription = backLabel }, contentAlignment = Alignment.Center) {
                    Text("‹", fontSize = 26.sp, fontWeight = FontWeight.Bold)
                }
                LinearProgressIndicator(progress = { fraction }, Modifier.weight(1f), color = Orange)
                Box(Modifier.size(44.dp))
            }
        }
        AnimatedContent(progress.step, Modifier.fillMaxSize(), label = "step", transitionSpec = {
            val dir = if (goingBack) -1 else 1
            (slideInHorizontally { it * dir } + fadeIn()) togetherWith (slideOutHorizontally { -it * dir } + fadeOut())
        }) { step ->
            when (step) {
                OnboardingStep.WELCOME -> WelcomeStep(::advance)
                OnboardingStep.NAME -> NameStep(answers, update, ::advance)
                OnboardingStep.AGE_RANGE -> SingleChoiceStep(stringResource(R.string.ob_age_title), stringResource(R.string.ob_age_subtitle),
                    AgeRange.entries, answers.ageRange, { it.title }, { it.icon() }, onSelect = { update(answers.copy(ageRange = it)) }, onNext = ::advance)
                OnboardingStep.HEARD_FROM -> SingleChoiceStep(stringResource(R.string.ob_heard_title), null, HeardFrom.entries, answers.heardFrom,
                    { it.label(context) }, { it.icon() }, coachLine(OnboardingStep.HEARD_FROM, answers, context),
                    onSelect = { update(answers.copy(heardFrom = it)) }, onNext = ::advance)
                OnboardingStep.ALARM_REACTION -> SingleChoiceStep(stringResource(R.string.ob_reaction_title), null, AlarmReaction.entries, answers.reaction,
                    { it.label(context) }, { it.icon() }, coachLine(OnboardingStep.ALARM_REACTION, answers, context),
                    onSelect = { update(answers.copy(reaction = it)) }, onNext = ::advance)
                OnboardingStep.WHY_IT_WORKS -> WhyItWorksStep(::advance)
                OnboardingStep.GET_UP_TIME -> SingleChoiceStep(stringResource(R.string.ob_getup_title), null, GetUpTime.entries, answers.getUpTime,
                    { it.label(context) }, { it.icon() }, coachLine(OnboardingStep.GET_UP_TIME, answers, context),
                    onSelect = { update(answers.copy(getUpTime = it)) }, onNext = ::advance)
                OnboardingStep.STRUGGLES -> StrugglesStep(answers, update, ::advance)
                OnboardingStep.GOAL -> SingleChoiceStep(stringResource(R.string.ob_goal_title), null, MorningGoal.entries, answers.goal,
                    { it.label(context) }, { it.icon() }, coachLine(OnboardingStep.GOAL, answers, context),
                    onSelect = { update(answers.copy(goal = it)) }, onNext = ::advance)
                OnboardingStep.WAKE_TIME -> WakeTimeStep(answers, update, ::advance)
                OnboardingStep.COMPARISON -> ComparisonStep(answers, ::advance)
                OnboardingStep.PERMISSIONS -> PermissionsStep(answers, ::advance)
                OnboardingStep.MISSION -> MissionStep(answers, update, ::advance)
                OnboardingStep.MISSION_SETUP -> MissionSetupStep(answers, update, ::advance)
                OnboardingStep.SOUND -> SoundStep(answers, update, ::advance)
                OnboardingStep.BUILDING -> BuildingStep(answers, work = { applyAnswers(context, controller, progress) { change(it) } }, onNext = ::advance)
                OnboardingStep.SUMMARY -> SummaryStep(answers, ::advance)
                // Not on Android yet (skipped by ANDROID_CONTEXT); land safely if old progress points here.
                OnboardingStep.INVITE_FRIEND, OnboardingStep.ACCOUNT, OnboardingStep.PAYWALL -> androidx.compose.runtime.LaunchedEffect(Unit) { advance() }
            }
        }
    }
}

private fun coachLine(step: OnboardingStep, answers: be.gloop.core.onboarding.OnboardingAnswers, context: Context): String? =
    OnboardingPersonalization.coachReaction(step, answers)?.let { context.text(it) }

/** Creates (or, when replaying, updates) the first alarm and stores the personal settings (iOS `applyAnswers`). */
private fun applyAnswers(context: Context, controller: AlarmController, progress: OnboardingProgress, save: (OnboardingProgress) -> Unit) {
    val answers = progress.answers
    val plan = answers.firstAlarm(context.getString(R.string.wake_up_label))
    controller.save(plan)
    save(progress.copy(answers = answers.copy(missions = plan.missions, sound = plan.sound, createdPlanID = plan.id)))
    val tone: CoachIntensity = OnboardingPersonalization.suggestedTone(answers.reaction)
    context.getSharedPreferences("gloop", Context.MODE_PRIVATE).edit()
        .putString("gloop.coach.intensity", tone.rawValue)
        .apply { answers.name.trim().takeIf { it.isNotEmpty() }?.let { putString("gloop.profile.name", it) } }
        .apply()
}
