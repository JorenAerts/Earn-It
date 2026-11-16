package be.gloop.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import be.gloop.app.camera.ReferenceStore
import be.gloop.app.mission.MissionActivity
import be.gloop.app.ui.EditorScreen
import be.gloop.app.ui.GloopTheme
import be.gloop.app.ui.HomeScreen
import be.gloop.core.model.AlarmPlan

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val controller = GloopApplication.controller(this)
        setContent {
            GloopTheme {
                Surface(Modifier.fillMaxSize()) {
                    // null = Home; Editing(plan == null) = new alarm.
                    var editing by remember { mutableStateOf<Editing?>(null) }
                    when (val e = editing) {
                        null -> HomeScreen(controller, onEdit = { editing = Editing(it) })
                        else -> EditorScreen(e.plan, onSave = {
                            controller.save(it)
                            editing = null
                            ReferenceStore(this@MainActivity).prune(controller.plans.value.flatMap { p -> p.missions.mapNotNull { m -> m.payload } }.toSet())
                        }, onCancel = { editing = null })
                    }
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // Like iOS: while a mission is due, the app opens straight into it.
        val controller = GloopApplication.controller(this)
        controller.reloadSession()
        if (controller.needsMission) startActivity(Intent(this, MissionActivity::class.java))
    }

    private data class Editing(val plan: AlarmPlan?)
}
