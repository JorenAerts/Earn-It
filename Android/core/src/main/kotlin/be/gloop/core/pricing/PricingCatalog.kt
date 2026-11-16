package be.gloop.core.pricing

import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonUnquotedLiteral
import kotlinx.serialization.json.JsonEncoder
import kotlinx.serialization.json.jsonPrimitive
import java.math.BigDecimal

/** One purchasable plan from `Shared/Config/Pricing.json` (port of iOS `PricedProduct`). */
@Serializable
data class PricedProduct(
    val key: String,
    /** Store product id (`be.gloop.app.pro.*`). */
    val id: String,
    val type: Kind,
    /** ISO 8601 period ("P1W", "P1M", "P3M", "P1Y"); null for lifetime. */
    val period: String? = null,
    /** Reference price. The app shows the store's localized price; this one is a fallback. */
    @Serializable(with = DecimalSerializer::class) val price: BigDecimal,
    val enabled: Boolean,
    val badge: String? = null,
    val title: String,
) {
    @Serializable
    enum class Kind {
        @SerialName("subscription") SUBSCRIPTION,
        @SerialName("lifetime") LIFETIME,
    }

    val isSubscription: Boolean get() = type == Kind.SUBSCRIPTION
}

/**
 * `Shared/Config/Pricing.json`, the single place to change plans and prices for both apps
 * (port of iOS `PricingCatalog`).
 */
@Serializable
data class PricingCatalog(
    val currency: String,
    val trialDays: Int,
    val subscriptionGroup: String,
    val defaultSelection: String,
    private val products: List<PricedProduct>,
) {
    /** Enabled plans, in file order (the order shown on the paywall). */
    val plans: List<PricedProduct> get() = products.filter { it.enabled }

    val productIds: List<String> get() = plans.map { it.id }

    fun plan(id: String): PricedProduct? = plans.firstOrNull { it.id == id }

    /** The preselected plan: `defaultSelection` if enabled, else the first plan. */
    val defaultPlan: PricedProduct? get() = plans.firstOrNull { it.key == defaultSelection } ?: plans.firstOrNull()

    companion object {
        private val json = Json { ignoreUnknownKeys = true }

        fun decode(text: String): PricingCatalog = json.decodeFromString(serializer(), text)
    }
}

/** Keeps prices exact (29.99 stays 29.99, no binary floating point). */
internal object DecimalSerializer : KSerializer<BigDecimal> {
    override val descriptor = PrimitiveSerialDescriptor("BigDecimal", PrimitiveKind.STRING)

    override fun deserialize(decoder: Decoder): BigDecimal =
        if (decoder is JsonDecoder) BigDecimal(decoder.decodeJsonElement().jsonPrimitive.content)
        else BigDecimal(decoder.decodeString())

    override fun serialize(encoder: Encoder, value: BigDecimal) {
        if (encoder is JsonEncoder) encoder.encodeJsonElement(JsonUnquotedLiteral(value.toPlainString()))
        else encoder.encodeString(value.toPlainString())
    }
}
