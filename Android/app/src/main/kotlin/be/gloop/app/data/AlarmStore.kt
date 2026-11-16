package be.gloop.app.data

import android.content.Context
import be.gloop.core.model.AlarmPlan
import be.gloop.core.model.SessionState
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json

/** Small JSON state in SharedPreferences, same keys as iOS (`gloop.*`). */
class AlarmStore(context: Context) {
    private val prefs = context.getSharedPreferences("gloop", Context.MODE_PRIVATE)
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    private val sessions = ListSerializer(SessionState.serializer())

    fun loadPlans(): List<AlarmPlan> = AlarmPlan.decodeList(prefs.getString(PLANS, null))
    fun savePlans(plans: List<AlarmPlan>) = prefs.edit().putString(PLANS, AlarmPlan.encodeList(plans)).apply()

    fun loadSession(): SessionState? = prefs.getString(SESSION, null)
        ?.let { runCatching { json.decodeFromString(SessionState.serializer(), it) }.getOrNull() }
    fun saveSession(session: SessionState) =
        prefs.edit().putString(SESSION, json.encodeToString(SessionState.serializer(), session)).commit()

    /** Finished ring cycles (mission done or fail-safe), for streaks and later the Progress tab. */
    fun loadDayLog(): List<SessionState> = prefs.getString(DAY_LOG, null)
        ?.let { runCatching { json.decodeFromString(sessions, it) }.getOrNull() }.orEmpty()
    fun appendDayLog(session: SessionState) {
        val log = loadDayLog() + session
        prefs.edit().putString(DAY_LOG, json.encodeToString(sessions, log.takeLast(1000))).apply()
    }

    private companion object {
        const val PLANS = "gloop.plans"
        const val SESSION = "gloop.session"
        const val DAY_LOG = "gloop.daylog"
    }
}
