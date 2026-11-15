import AVFoundation

enum AudioLevel {
    /// Normalized 0...1 level from RMS, mapped over a -50 dB...0 dB range.
    static func normalizedRMS(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        let samples = UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength))
        let meanSquare = samples.reduce(Float(0)) { $0 + $1 * $1 } / Float(samples.count)
        let decibels = 20 * log10(max(meanSquare.squareRoot(), 1e-7))
        return min(max((decibels + 50) / 50, 0), 1)
    }
}
