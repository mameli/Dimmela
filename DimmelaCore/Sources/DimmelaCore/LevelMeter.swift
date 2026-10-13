/// Turns the microphone's loudness into the overlay's 0...1 level, relative to this microphone:
/// between its background noise and the recent peaks of the voice. A fixed scale left the
/// MacBook's built-in microphone (speech around -53 dB) flat and a headset (-25 dB) lively.
struct LevelMeter {
    /// The quietest recent block: background noise. Follows quieter blocks at once and drifts
    /// up slowly, so the pauses between words keep it in place.
    private var floor: Float?
    /// The loudest recent block: the voice. Follows louder blocks at once and decays slowly.
    private var peak: Float = -200

    /// Below this, digital silence (a microphone starting up) would drag the floor down.
    private static let quietest: Float = -80
    /// Speech is never shown closer to the noise than this, so noise alone stays near zero.
    private static let minimumRange: Float = 15
    /// How far above the noise a block must be to move the bars at all.
    private static let margin: Float = 3

    mutating func level(for decibels: Float) -> Float {
        let decibels = max(decibels, Self.quietest)
        let floor = min(decibels, (floor ?? min(decibels, -55)) + 0.2)
        self.floor = floor
        peak = max(decibels, peak - 0.1, floor + Self.minimumRange)
        let level = (decibels - floor - Self.margin) / (peak - floor - Self.margin)
        return min(max(level, 0), 1)
    }
}
