package be.gloop.app.alarm

import android.content.Context
import android.util.Log
import be.gloop.app.data.AlarmStore
import be.gloop.core.alarm.RingPolicy
import be.gloop.core.model.AlarmPlan
import be.gloop.core.model.SessionState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * The Android wake-up loop (counterpart of iOS `AlarmCoordinator`): schedule → ring → mission →
 * silence. Rules live in `:core` (`RingPolicy`); this class only does the platform work.
 */
class AlarmController(
    private val context: Context,
    private val store: AlarmStore,
    private val scheduler: AlarmScheduler,
    private val now: () -> Long = System::currentTimeMillis,
) {
    private val _plans = MutableStateFlow(store.loadPlans())
    val plans: StateFlow<List<AlarmPlan>> = _plans.asStateFlow()

    private val _session = MutableStateFlow(store.loadSession())
    val session: StateFlow<SessionState?> = _session.asStateFlow()

    /** Finished cycles, newest last. */
    private val _dayLog = MutableStateFlow(store.loadDayLog())
    val dayLog: StateFlow<List<SessionState>> = _dayLog.asStateFlow()

    /** The app should show the mission right now (iOS `needsMission`). */
    val needsMission: Boolean get() = RingPolicy.currentSession(_session.value, now()).awaitingMission

    /** The alarm whose cycle is running: its missions and sound apply. */
    val activePlan: AlarmPlan? get() = plan(_session.value?.planID) ?: _plans.value.firstOrNull()

    fun plan(id: String?): AlarmPlan? = _plans.value.firstOrNull { it.id == id }

    /** Soonest upcoming ring across all enabled alarms. */
    fun nextAlarm(): Pair<AlarmPlan, Long>? = _plans.value.filter { it.isEnabled }
        .mapNotNull { p -> p.nextFireTime(now())?.let { p to it } }
        .minByOrNull { it.second }

    // MARK: Alarms (CRUD)

    fun save(plan: AlarmPlan) {
        val list = _plans.value.toMutableList()
        val index = list.indexOfFirst { it.id == plan.id }
        if (index >= 0) list[index] = plan else list += plan
        persistPlans(list)
        schedule(plan)
    }

    fun setEnabled(id: String, enabled: Boolean) {
        plan(id)?.let { save(it.copy(isEnabled = enabled)) }
    }

    fun delete(id: String) {
        scheduler.cancel(id)
        scheduler.cancel(id, AlarmScheduler.Kind.TEST)
        persistPlans(_plans.value.filterNot { it.id == id })
    }

    fun testRing(id: String, inSeconds: Int = 10) {
        scheduler.schedule(id, now() + inSeconds * 1000L, AlarmScheduler.Kind.TEST)
    }

    fun rescheduleAll() = _plans.value.forEach(::schedule)

    private fun schedule(plan: AlarmPlan) {
        scheduler.cancel(plan.id)
        if (!plan.isEnabled) return
        plan.nextFireTime(now())?.let { scheduler.schedule(plan.id, it) }
    }

    // MARK: Ringing loop

    /** An alarm went off (receiver). Starts a ring cycle unless one is already running. */
    fun alarmFired(planId: String, kind: AlarmScheduler.Kind) {
        reloadSession()
        val plan = plan(planId) ?: return
        if (kind == AlarmScheduler.Kind.MAIN) {
            when (val next = RingPolicy.afterRing(plan, now())) {
                is RingPolicy.AfterRing.Next -> scheduler.schedule(plan.id, next.atMillis)
                RingPolicy.AfterRing.Disable -> persistPlans(_plans.value.map { if (it.id == plan.id) it.copy(isEnabled = false) else it })
            }
        }
        val current = RingPolicy.currentSession(_session.value, now(), newRing = kind != AlarmScheduler.Kind.RESUME)
        if (current.awaitingMission) {
            // Already ringing for an earlier alarm (or resuming after a reboot): keep that cycle.
            val owner = plan(current.planID) ?: plan
            if (RingPolicy.isFailSafeDue(current.firstEndedAt!!, now(), owner)) failSafe() else RingService.start(context)
            return
        }
        if (kind == AlarmScheduler.Kind.RESUME) return
        val started = current.copy(firstEndedAt = now(), planID = plan.id)
        persistSession(started)
        scheduler.scheduleFailSafe(RingPolicy.failSafeAt(now(), plan))
        Log.i(TAG, "ring started plan=${plan.id} kind=$kind")
        RingService.start(context)
    }

    /** Every mission done: silence, log the day. Returns the finished cycle. */
    fun missionSucceeded(): SessionState? {
        reloadSession()
        val s = RingPolicy.currentSession(_session.value, now())
        if (!s.awaitingMission) return null
        val plan = plan(s.planID)
        val reRings = if (plan != null) RingPolicy.reRings(s.firstEndedAt!!, now(), plan) else 0
        val done = s.copy(missionCompletedAt = now(), reArmCount = reRings)
        finish(done)
        Log.i(TAG, "mission succeeded, re-rings=$reRings")
        return done
    }

    /** Rang too long without the mission: stop for good (the day doesn't count toward the streak). */
    fun failSafe() {
        reloadSession()
        val s = RingPolicy.currentSession(_session.value, now())
        if (!s.awaitingMission) return
        val plan = plan(s.planID)
        finish(s.copy(failSafeTriggered = true, reArmCount = plan?.maxReArms ?: s.reArmCount))
        Log.i(TAG, "fail-safe triggered")
    }

    /** After reboot / time change / update: alarms back, and ringing again if a mission was pending. */
    fun restoreAfterRestart() {
        reloadSession()
        rescheduleAll()
        val s = _session.value ?: return
        if (!RingPolicy.currentSession(s, now()).awaitingMission) return
        val plan = plan(s.planID) ?: return
        val rangAt = s.firstEndedAt ?: return
        if (RingPolicy.isFailSafeDue(rangAt, now(), plan)) { failSafe(); return }
        scheduler.scheduleFailSafe(RingPolicy.failSafeAt(rangAt, plan))
        // A media foreground service may not start from BOOT_COMPLETED (Android 15+), but it may
        // from an exact alarm: ring again in a moment through the alarm path.
        scheduler.schedule(plan.id, now() + 2_000, AlarmScheduler.Kind.RESUME)
    }

    private fun finish(s: SessionState) {
        persistSession(s)
        store.appendDayLog(s)
        _dayLog.value = store.loadDayLog()
        scheduler.cancelFailSafe()
        RingService.stop(context)
    }

    /** Receivers and the service run in the same process, but re-read in case of a cold start. */
    fun reloadSession() { _session.value = store.loadSession() }

    private fun persistPlans(list: List<AlarmPlan>) { store.savePlans(list); _plans.value = list }
    private fun persistSession(s: SessionState) { store.saveSession(s); _session.value = s }

    private companion object { const val TAG = "GloopAlarm" }
}
