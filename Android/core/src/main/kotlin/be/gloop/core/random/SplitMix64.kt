package be.gloop.core.random

/**
 * Deterministic generator, bit-for-bit the same as the iOS `SplitMix64`, plus Swift's bounded-random
 * and shuffle algorithms. Same seed → same math problems, same tip order on both platforms.
 */
class SplitMix64(seed: Long) {
    private var state: Long = seed

    fun next(): Long {
        state += -0x61c8864680b583ebL // 0x9E3779B97F4A7C15
        var z = state
        z = (z xor (z ushr 30)) * -0x40a7b892e31b1a47L // 0xBF58476D1CE4E5B9
        z = (z xor (z ushr 27)) * -0x6b2fb644ecceee15L // 0x94D049BB133111EB
        return z xor (z ushr 31)
    }

    /** Swift `next(upperBound:)` (Lemire's multiply-shift with rejection), as unsigned 64-bit. */
    fun next(upperBound: Long): Long {
        require(upperBound != 0L)
        var random = next()
        var high = unsignedMultiplyHigh(random, upperBound)
        var low = random * upperBound
        if (java.lang.Long.compareUnsigned(low, upperBound) < 0) {
            val t = java.lang.Long.remainderUnsigned(-upperBound, upperBound)
            while (java.lang.Long.compareUnsigned(low, t) < 0) {
                random = next()
                high = unsignedMultiplyHigh(random, upperBound)
                low = random * upperBound
            }
        }
        return high
    }

    /** Swift `Int.random(in: range, using:)`. */
    fun nextInt(range: IntRange): Int {
        val delta = range.last.toLong() - range.first.toLong()
        return (range.first + next(delta + 1)).toInt()
    }

    private fun unsignedMultiplyHigh(a: Long, b: Long): Long {
        // Math.unsignedMultiplyHigh needs API 35; compute from 32-bit halves.
        val aLo = a and 0xFFFFFFFFL; val aHi = a ushr 32
        val bLo = b and 0xFFFFFFFFL; val bHi = b ushr 32
        val loLo = aLo * bLo
        val hiLo = aHi * bLo
        val loHi = aLo * bHi
        val hiHi = aHi * bHi
        val cross = (loLo ushr 32) + (hiLo and 0xFFFFFFFFL) + (loHi and 0xFFFFFFFFL)
        return hiHi + (hiLo ushr 32) + (loHi ushr 32) + (cross ushr 32)
    }
}

/** Swift `shuffled(using:)`: same algorithm, so the same order for the same generator state. */
fun <T> List<T>.shuffledSwift(rng: SplitMix64): List<T> {
    val result = toMutableList()
    var amount = result.size
    var current = 0
    while (amount > 1) {
        val random = rng.next(amount.toLong()).toInt()
        amount -= 1
        val other = current + random
        val tmp = result[current]; result[current] = result[other]; result[other] = tmp
        current += 1
    }
    return result
}
