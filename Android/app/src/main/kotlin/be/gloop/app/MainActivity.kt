package be.gloop.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import be.gloop.app.ui.GloopTheme
import be.gloop.core.pricing.PricingCatalog

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            GloopTheme {
                Surface(Modifier.fillMaxSize()) { FoundationScreen() }
            }
        }
    }
}

/** Placeholder until the real screens are ported: proves Shared/Config → :core → UI works. */
@Composable
private fun FoundationScreen() {
    val context = LocalContext.current
    val catalog: PricingCatalog = remember { SharedContent.pricing(context) }
    Column(
        Modifier.fillMaxSize().safeDrawingPadding().padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("Gloop", style = MaterialTheme.typography.displaySmall, fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary)
        Text("Android foundation. Plans read from Shared/Config/Pricing.json:",
            style = MaterialTheme.typography.bodyMedium)
        Spacer(Modifier.height(4.dp))
        for (plan in catalog.plans) {
            Card(Modifier.fillMaxWidth()) {
                Row(Modifier.fillMaxWidth().padding(16.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(plan.title + (if (plan.key == catalog.defaultSelection) "  ★" else ""), fontWeight = FontWeight.SemiBold)
                    Text("€" + plan.price.toPlainString())
                }
            }
        }
        Text("${catalog.trialDays}-day free trial", style = MaterialTheme.typography.bodySmall)
    }
}
