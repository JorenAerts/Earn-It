package be.gloop.app

import android.app.Application
import android.content.Context
import be.gloop.app.alarm.AlarmController
import be.gloop.app.alarm.AlarmScheduler
import be.gloop.app.alarm.RingService
import be.gloop.app.data.AlarmStore

/** App entry (like iOS `GloopApp`): one controller shared by screens, receivers and the service. */
class GloopApplication : Application() {
    val controller: AlarmController by lazy { AlarmController(this, AlarmStore(this), AlarmScheduler(this)) }

    override fun onCreate() {
        super.onCreate()
        RingService.createChannel(this)
    }

    companion object {
        fun controller(context: Context): AlarmController =
            (context.applicationContext as GloopApplication).controller
    }
}
