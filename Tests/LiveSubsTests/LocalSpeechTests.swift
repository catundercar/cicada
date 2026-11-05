import Foundation
import Testing
@testable import LiveSubs

@Suite struct LocalSpeechTests {
    /// A WAV header as a streaming server writes it: the lengths unknown (0xFFFFFFFF).
    private func header(rate: Int, channels: Int = 1, bits: Int = 16, extra: Bool = false) -> Data {
        func le(_ v: Int, _ n: Int) -> [UInt8] { (0..<n).map { UInt8((v >> (8 * $0)) & 0xFF) } }
        var b = Array("RIFF".utf8) + le(0xFFFF_FFFF, 4) + Array("WAVE".utf8)
        b += Array("fmt ".utf8) + le(16, 4) + le(1, 2) + le(channels, 2) + le(rate, 4)
            + le(rate * channels * bits / 8, 4) + le(channels * bits / 8, 2) + le(bits, 2)
        if extra { b += Array("LIST".utf8) + le(3, 4) + [1, 2, 3, 0] }  // odd size, padded
        b += Array("data".utf8) + le(0xFFFF_FFFF, 4)
        return Data(b)
    }

    private func samples(_ values: [Int16]) -> Data {
        values.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    @Test func requestUsesAVoiceOrTheBareReferenceClip() {
        let voice = LocalSpeech.body(model: "Ming-3.0-tts-0.5B-bf16", text: "hi", voice: "UK_Charlotte", reference: nil, language: nil)
        #expect(voice["model"] as? String == "Ming-3.0-tts-0.5B-bf16")
        #expect(voice["voice"] as? String == "UK_Charlotte")
        #expect(voice["response_format"] as? String == "wav" && voice["stream"] as? Bool == true)
        #expect(voice["language"] == nil && voice["ref_audio"] == nil)

        let clone = LocalSpeech.body(model: "m", text: "hi", voice: "UK_Charlotte",
                                     reference: ("data:audio/wav;base64,UklGRg==", "what I said"), language: "ja")
        #expect(clone["ref_audio"] as? String == "UklGRg==")
        #expect(clone["ref_text"] as? String == "what I said")
        #expect(clone["voice"] == nil)
        #expect(clone["language"] as? String == "ja")
    }

    @Test func wavStreamReadsTheHeaderAcrossPiecesThenPassesSamples() throws {
        let audio = samples([1, -2, 300, -400, 5])
        let all = header(rate: 44_100, extra: true) + audio
        var wav = WAVStream()
        var out = Data()
        // One byte at a time: the header, an odd chunk and half a sample all straddle feeds.
        for byte in all { out += try wav.feed(Data([byte])) }
        #expect(wav.sampleRate == 44_100)
        #expect(out == audio)

        var whole = WAVStream()
        #expect(try whole.feed(header(rate: 24_000) + audio.prefix(3)) == audio.prefix(2))
        #expect(try whole.feed(audio.dropFirst(3)) == audio.dropFirst(2))
    }

    @Test func writtenWAVReadsBack() throws {
        let audio = samples([7, -7, 1_000])
        var wav = WAVStream()
        #expect(try wav.feed(LocalSpeech.wav(audio, rate: 24_000)) == audio)
        #expect(wav.sampleRate == 24_000)
    }

    @Test func wavStreamRefusesWhatItCantPlay() {
        var json = WAVStream()
        #expect(throws: WAVStream.Failure.self) { try json.feed(Data(#"{"error":{"message":"nope"}}"#.utf8)) }
        var stereo = WAVStream()
        #expect(throws: WAVStream.Failure.self) { try stereo.feed(header(rate: 44_100, channels: 2)) }
    }

    @Test func resamplerKeepsLengthAndPitchAcrossChunks() throws {
        // One second of 1 kHz at 44.1 kHz, fed in uneven chunks, comes out as about one second at 24 kHz.
        let tone = (0..<44_100).map { Int16(12_000 * sin(2 * Double.pi * 1_000 * Double($0) / 44_100)) }
        let input = samples(tone)
        let r = try #require(PCMResampler(from: 44_100, to: 24_000))
        var out = Data()
        var at = 0
        for size in [1_000, 7_777, 8_820, 30_000] + Array(repeating: 8_820, count: 10) where at < input.count {
            let end = min(input.count, at + size * 2)
            out += r.convert(input.subdata(in: at..<end))
            at = end
        }
        out += r.convert(Data(), last: true)
        let result = out.withUnsafeBytes { Array($0.bindMemory(to: Int16.self)) }
        #expect(abs(result.count - 24_000) < 100)
        // Pitch: a 1 kHz tone crosses zero ~2000 times a second.
        let crossings = zip(result, result.dropFirst()).filter { ($0 < 0) != ($1 < 0) }.count
        #expect(abs(crossings - 2_000) < 20)
        // Loudness survives (no silence or clipping from the joins).
        let peak = result.dropFirst(500).dropLast(500).map { abs(Int($0)) }.max() ?? 0
        #expect(peak > 10_000 && peak < 14_000)

        let same = try #require(PCMResampler(from: 24_000, to: 24_000))
        #expect(same.convert(input) == input)
    }
}
