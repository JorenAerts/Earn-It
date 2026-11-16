package be.gloop.core

import be.gloop.core.pricing.PricingCatalog
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.math.BigDecimal

class PricingCatalogTest {
    private val shipped = PricingCatalog.decode(SharedConfig.text("Pricing.json"))

    @Test fun shippedCatalogHasTheFivePlansInOrder() {
        assertEquals(listOf("weekly", "monthly", "quarterly", "yearly", "lifetime"), shipped.plans.map { it.key })
        assertTrue(shipped.productIds.all { it.startsWith("be.gloop.app.pro.") })
        assertEquals("yearly", shipped.defaultPlan?.key)
        assertEquals(3, shipped.trialDays)
        assertEquals("EUR", shipped.currency)
    }

    @Test fun pricesStayExact() {
        assertEquals(BigDecimal("29.99"), shipped.plan("be.gloop.app.pro.yearly")?.price)
        assertEquals(BigDecimal("59.99"), shipped.plan("be.gloop.app.pro.lifetime")?.price)
    }

    @Test fun lifetimeIsNotASubscription() {
        val lifetime = shipped.plans.single { !it.isSubscription }
        assertEquals("be.gloop.app.pro.lifetime", lifetime.id)
        assertNull(lifetime.period)
    }

    @Test fun disabledPlansAreHiddenAndDefaultFallsBackToTheFirst() {
        val json = """
            {"currency":"EUR","trialDays":0,"subscriptionGroup":"G","defaultSelection":"yearly","products":[
              {"key":"monthly","id":"m","type":"subscription","period":"P1M","price":3.99,"enabled":true,"title":"Monthly"},
              {"key":"yearly","id":"y","type":"subscription","period":"P1Y","price":29.99,"enabled":false,"title":"Yearly"}
            ]}
        """.trimIndent()
        val catalog = PricingCatalog.decode(json)
        assertEquals(listOf("m"), catalog.productIds)
        assertEquals("monthly", catalog.defaultPlan?.key)
        assertNull(catalog.plan("y"))
    }
}
