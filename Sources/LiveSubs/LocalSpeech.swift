import AVFoundation
import Foundation

// MARK: - Ming voices from a 自定义 server

/// Ming-3.0 TTS on a server of the user's own (oMLX, mlx-audio): an OpenAI-style `audio/speech`
/// request, and the WAV it streams back turned into the 24 kHz mono 16-bit PCM chunks that Ling's
/// Ming sends and `SpeakEngine` plays.
enum LocalSpeech {
    /// The rate the speak engine plays (Ling's Ming streams it).
    static let rate = 24_000.0

    /// A built-in voice ("UK_Charlotte", "灵小雅"), or the user's reference clip and its transcript.
    static func body(model: String, text: String, voice: String?, reference: (audio: String, text: String)?,
                     language: String?) -> [String: Any] {
        var body: [String: Any] = ["model": model, "input": text, "response_format": "wav", "stream": true]
        if let reference {
            // Ling takes a data URL; these servers want the bare base64.
            let audio = reference.audio.range(of: "base64,").map { String(reference.audio[$0.upperBound...]) } ?? reference.audio
            body["ref_audio"] = audio
            body["ref_text"] = reference.text
        } else if let voice {
            body["voice"] = voice
        }
        if let language { body["language"] = language }
        return body
    }

    /// 16-bit mono PCM as a WAV file (debug copies of what a voice said).
    static func wav(_ pcm: Data, rate: Int) -> Data {
        func le(_ v: Int, _ n: Int) -> Data { Data((0..<n).map { UInt8((v >> (8 * $0)) & 0xFF) }) }
        var d = Data("RIFF".utf8)
        d += le(36 + pcm.count, 4)
        d += Data("WAVEfmt ".utf8)
        d += le(16, 4) + le(1, 2) + le(1, 2)  // PCM, mono
        d += le(rate, 4) + le(rate * 2, 4) + le(2, 2) + le(16, 2)
        d += Data("data".utf8)
        d += le(pcm.count, 4)
        return d + pcm
    }
}

/// A WAV arriving in pieces: the header first (for the sample rate), then 16-bit mono samples.
/// A streamed header can't know the length, so everything after the `data` chunk's id is audio.
struct WAVStream {
    enum Failure: Error { case notWAV, unsupported }

    private(set) var sampleRate: Double?
    private var buffer = Data()
    private var inData = false

    /// Bytes in; whole samples of the data chunk so far out (nothing until the header has passed).
    mutating func feed(_ bytes: Data) throws -> Data {
        buffer.append(bytes)
        if !inData, try !readHeader() { return Data() }
        let whole = buffer.count & ~1
        let samples = Data(buffer.prefix(whole))
        buffer = Data(buffer.dropFirst(whole))
        return samples
    }

    /// Walks the chunks from the start each time until `data` turns up (the header is ~44 bytes).
    private mutating func readHeader() throws -> Bool {
        let b = [UInt8](buffer)
        guard b.count >= 12 else { return false }
        guard b[0..<4].elementsEqual("RIFF".utf8), b[8..<12].elementsEqual("WAVE".utf8) else { throw Failure.notWAV }
        func u16(_ i: Int) -> Int { Int(b[i]) | Int(b[i + 1]) << 8 }
        func u32(_ i: Int) -> Int { u16(i) | u16(i + 2) << 16 }
        var at = 12
        var rate: Double?
        while b.count >= at + 8 {
            let id = String(decoding: b[at..<at + 4], as: UTF8.self)
            if id == "data" {
                guard let rate else { throw Failure.notWAV }
                sampleRate = rate
                inData = true
                buffer = Data(b[(at + 8)...])
                return true
            }
            let size = u32(at + 4)
            guard b.count >= at + 8 + size else { return false }
            if id == "fmt " {
                // PCM (1) or WAVE_FORMAT_EXTENSIBLE, mono, 16-bit: what Ming writes.
                guard size >= 16, [1, 0xFFFE].contains(u16(at + 8)), u16(at + 10) == 1, u16(at + 22) == 16
                else { throw Failure.unsupported }
                rate = Double(u32(at + 12))
            }
            at += 8 + size + (size & 1)
        }
        return false
    }
}

/// 16-bit mono PCM from one rate to another a chunk at a time. The converter keeps its filter state
/// between chunks, so the joins don't click; `last` flushes what it still holds.
final class PCMResampler {
    private let converter: AVAudioConverter?
    private let input: AVAudioFormat
    private let output: AVAudioFormat

    init?(from: Double, to: Double) {
        guard from > 0, to > 0,
              let i = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: from, channels: 1, interleaved: true),
              let o = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: to, channels: 1, interleaved: true)
        else { return nil }
        input = i
        output = o
        if from == to {
            converter = nil
        } else {
            guard let c = AVAudioConverter(from: i, to: o) else { return nil }
            c.sampleRateConverterQuality = AVAudioQuality.high.rawValue
            converter = c
        }
    }

    func convert(_ pcm: Data, last: Bool = false) -> Data {
        guard let converter else { return pcm }
        let frames = pcm.count / 2
        var source: AVAudioPCMBuffer?
        if frames > 0, let buf = AVAudioPCMBuffer(pcmFormat: input, frameCapacity: AVAudioFrameCount(frames)) {
            buf.frameLength = AVAudioFrameCount(frames)
            pcm.withUnsafeBytes { raw in
                if let base = raw.baseAddress { memcpy(buf.int16ChannelData![0], base, frames * 2) }
            }
            source = buf
        }
        let capacity = AVAudioFrameCount(Double(frames) * output.sampleRate / input.sampleRate) + 1024
        var out = Data()
        var given = false
        while let buf = AVAudioPCMBuffer(pcmFormat: output, frameCapacity: capacity) {
            var error: NSError?
            let status = converter.convert(to: buf, error: &error) { _, state in
                if !given, let source {
                    given = true
                    state.pointee = .haveData
                    return source
                }
                state.pointee = last ? .endOfStream : .noDataNow
                return nil
            }
            if buf.frameLength > 0 {
                out.append(Data(bytes: buf.int16ChannelData![0], count: Int(buf.frameLength) * 2))
            }
            // .haveData: the output filled up and there is more to take.
            guard status == .haveData else { break }
        }
        return out
    }
}
