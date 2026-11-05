import AVFoundation
import Foundation

// MARK: - Catalog

/// A voice the room can hear: one of Ming's (with Ling as the AI service and its key), a voice installed on this Mac,
/// or the user's own voice cloned from a recording.
struct VoiceOption: Identifiable, Equatable {
    enum Kind: Equatable {
        case ming(String)
        case system(String)
        case clone
    }
    /// Stored in settings: "ming:US_Emma", "system:<AVSpeechSynthesisVoice identifier>", "clone".
    let id: String
    let name: String
    let tags: [String]
    let kind: Kind

    var needsKey: Bool { if case .system = kind { return false } else { return true } }
}

/// Which voices to offer for each language the room may hear. Ming's are hand-picked natural ones
/// (two women, two men where it has them); for languages it has no native voice for, Emma and
/// George speak it with `language_id`. The Mac's own best female and male voices follow, so there is
/// always something without a key.
enum VoiceCatalog {
    /// Tabs in settings: (key, title). The key is the translation code without region ("zh" for zh-CN / zh-TW).
    static let languages: [(key: String, title: String)] = [
        ("en", "English"), ("zh", "中文"), ("ja", "日本語"), ("ko", "한국어"),
        ("es", "Español"), ("fr", "Français"), ("de", "Deutsch"), ("pt", "Português"),
    ]

    static func key(for code: String) -> String {
        let base = String(code.prefix(while: { $0 != "-" }))
        return base.isEmpty ? "en" : base
    }

    /// Ming's `language_id` for languages that need it (zh and en work without).
    static func mingLanguage(for code: String) -> String? {
        let k = key(for: code)
        return ["ja", "ko", "de", "fr", "es"].contains(k) ? k : nil
    }

    static func ming(for language: String) -> [VoiceOption] {
        func v(_ voice: String, _ name: String, _ tags: [String]) -> VoiceOption {
            VoiceOption(id: "ming:\(voice)", name: name, tags: tags, kind: .ming(voice))
        }
        switch key(for: language) {
        case "en":
            return [v("US_Emma", "Emma", [L("女"), L("美式"), L("自然对话")]), v("UK_George", "George", [L("男"), L("英式"), L("稳重")]),
                    v("UK_Charlotte", "Charlotte", [L("女"), L("英式"), L("平稳")])]
        case "zh":
            return [v("灵小雅", "小雅", [L("女"), L("清亮"), L("播报")]), v("灵小棠", "小棠", [L("女"), L("温和"), L("沉稳")]),
                    v("灵小锋", "小锋", [L("男"), L("温暖"), L("亲切")]), v("灵卓然", "卓然", [L("男"), L("沉着"), L("清楚")])]
        case "ja", "ko", "de", "fr", "es":
            return [v("US_Emma", "Emma", [L("女"), "Ming"]), v("UK_George", "George", [L("男"), "Ming"])]
        default:
            return []
        }
    }

    /// The Mac's best installed female and male voice for the language (no novelty voices).
    static func system(for language: String) -> [VoiceOption] {
        let k = key(for: language)
        let prefix = language.hasPrefix("zh-TW") ? "zh-TW" : k == "zh" ? "zh-CN" : k
        let all = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix(prefix) && !$0.voiceTraits.contains(.isNoveltyVoice)
                && !$0.voiceTraits.contains(.isPersonalVoice)
        }
        var out: [VoiceOption] = []
        for gender in [AVSpeechSynthesisVoiceGender.female, .male] {
            guard let best = all.filter({ $0.gender == gender }).max(by: { $0.quality.rawValue < $1.quality.rawValue }) else { continue }
            let quality = best.quality == .premium ? L("高品质") : best.quality == .enhanced ? L("增强") : L("标准")
            out.append(VoiceOption(id: "system:\(best.identifier)", name: best.name,
                                   tags: [gender == .female ? L("女") : L("男"), L("本机"), quality], kind: .system(best.identifier)))
        }
        return out
    }

    static func options(for language: String) -> [VoiceOption] { ming(for: language) + system(for: language) }

    /// What a language uses until the user picks: Ming's first voice with a key, else the Mac's.
    static func defaultID(for language: String, hasKey: Bool) -> String? {
        (hasKey ? ming(for: language).first : nil)?.id ?? system(for: language).first?.id
    }

    static let cloneOption = VoiceOption(id: "clone", name: L("我自己的声音"), tags: [], kind: .clone)

    /// A short line to try a voice with, in the language it will speak.
    static func sample(for language: String) -> String {
        switch key(for: language) {
        case "zh": "谢谢大家。我们来看一下上线时间表，并确定谁负责麦克风测试。"
        case "ja": "皆さん、ありがとうございます。発売スケジュールを確認しましょう。"
        case "ko": "감사합니다. 출시 일정을 함께 확인해 보겠습니다."
        case "es": "Gracias a todos. Revisemos el calendario de lanzamiento."
        case "fr": "Merci à tous. Regardons ensemble le calendrier de lancement."
        case "de": "Danke an alle. Schauen wir uns den Zeitplan für den Start an."
        case "pt": "Obrigado a todos. Vamos ver o cronograma de lançamento."
        default: "Thanks everyone. Let's look at the launch timeline and decide who owns the microphone tests."
        }
    }
}

// MARK: - The user's own voice

/// The recording Ming clones the user's voice from: `voice/reference.wav` (16 kHz mono, ≤ 30 s) and
/// `voice/reference.txt` (what it says, as transcribed on this Mac) under Application Support. Never
/// leaves the Mac except inside a speech request to Ling.
enum VoiceReference {
    static var folder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(DevBuild.supportFolder).appendingPathComponent("voice")
    }
    static var audioURL: URL { folder.appendingPathComponent("reference.wav") }
    static var textURL: URL { folder.appendingPathComponent("reference.txt") }

    static var exists: Bool {
        FileManager.default.fileExists(atPath: audioURL.path) && !(text ?? "").isEmpty
    }
    static var text: String? { try? String(contentsOf: textURL, encoding: .utf8) }

    static var duration: Double {
        guard let f = try? AVAudioFile(forReading: audioURL) else { return 0 }
        return Double(f.length) / f.fileFormat.sampleRate
    }

    /// What Ming needs: the clip as a data URI and its transcript.
    static func reference() -> (audio: String, text: String)? {
        guard let data = try? Data(contentsOf: audioURL), let text, !text.isEmpty else { return nil }
        return ("data:audio/wav;base64," + data.base64EncodedString(), text)
    }

    static func save(wav: URL, text: String) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path)
        if fm.fileExists(atPath: audioURL.path) { try fm.removeItem(at: audioURL) }
        try fm.copyItem(at: wav, to: audioURL)
        try Data(text.utf8).write(to: textURL)
        for url in [audioURL, textURL] {
            try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            var u = url
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? u.setResourceValues(values)
        }
    }

    static func remove() {
        try? FileManager.default.removeItem(at: folder)
    }

    /// The passage to read, in the user's own language.
    static func passage(for locale: String) -> String {
        switch VoiceCatalog.key(for: locale) {
        case "zh": "大家好，我是这次会议的主持人。今天我们主要讨论新产品的上线计划，包括时间安排、测试范围和市场推广。请大家先看一下屏幕上的议程。"
        case "ja": "皆さん、こんにちは。今日の会議では、新製品の発売計画について話し合います。スケジュール、テストの範囲、そしてマーケティングについて順番に確認しましょう。"
        default: "Hello everyone, thanks for joining. Today we'll walk through the launch plan for the new product: the schedule, what we still need to test, and how we'll tell people about it. Let's start with the agenda on the screen."
        }
    }
}

/// Records the microphone for the voice clone: 16 kHz mono into a temporary WAV, with a level for
/// the meter. Stops by itself at 30 s.
@MainActor
final class VoiceRecorder: ObservableObject {
    enum Phase: Equatable { case idle, recording, checking, ready, failed(String) }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var seconds: Double = 0
    @Published private(set) var level: Float = 0
    /// What the recording says (transcribed on this Mac), used as the clone's reference text.
    @Published private(set) var transcript = ""

    static let maxSeconds = 30.0
    static let minSeconds = 8.0

    private let engine = AVAudioEngine()
    private nonisolated(unsafe) var file: AVAudioFile?
    private nonisolated(unsafe) var converter: AVAudioConverter?
    private var timer: Timer?
    private var started = Date()
    private(set) var url = FileManager.default.temporaryDirectory.appendingPathComponent("livesubs-voice-\(UUID().uuidString).wav")
    private let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!
    private var locale = "zh-CN"

    /// `device`: the real mic; the system default may be the virtual mic while speaking is on.
    func start(locale: String, device: OutputDevice?) {
        stopEngine()
        self.locale = locale
        transcript = ""
        try? FileManager.default.removeItem(at: url)
        let input = engine.inputNode
        AudioDevices.pinInput(engine, to: device)
        let inFormat = input.outputFormat(forBus: 0)
        guard inFormat.sampleRate > 0,
              let f = try? AVAudioFile(forWriting: url, settings: format.settings, commonFormat: .pcmFormatInt16, interleaved: true),
              let conv = AVAudioConverter(from: inFormat, to: format) else {
            phase = .failed(L("麦克风没收到声音，请检查麦克风权限"))
            return
        }
        file = f
        converter = conv
        let outFormat = format
        input.installTap(onBus: 0, bufferSize: 4096, format: inFormat) { [weak self] buffer, _ in
            guard let self, let conv = self.converter, let file = self.file else { return }
            let ratio = outFormat.sampleRate / buffer.format.sampleRate
            guard let out = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32) else { return }
            var fed = false
            conv.convert(to: out, error: nil) { _, status in
                if fed { status.pointee = .noDataNow; return nil }
                fed = true
                status.pointee = .haveData
                return buffer
            }
            try? file.write(from: out)
            var peak: Float = 0
            if let ch = buffer.floatChannelData?[0] {
                for i in 0..<Int(buffer.frameLength) { peak = max(peak, abs(ch[i])) }
            }
            Task { @MainActor in self.level = min(1, peak * 2.5) }
        }
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            phase = .failed(L("无法打开麦克风：\(error.localizedDescription)"))
            return
        }
        started = Date()
        seconds = 0
        phase = .recording
        timer?.invalidate()
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.seconds = Date().timeIntervalSince(self.started)
                if self.seconds >= Self.maxSeconds { self.finish() }
            }
        }
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }

    /// Stops recording and transcribes it; `ready` when it is long enough and recognisable.
    func finish() {
        guard phase == .recording else { return }
        stopEngine()
        guard seconds >= Self.minSeconds else {
            phase = .failed(L("录音太短了，请至少朗读 \(Int(Self.minSeconds)) 秒"))
            return
        }
        phase = .checking
        let url = url, locale = locale
        Task {
            let text = await Self.transcribe(url, locale: locale)
            self.transcript = text
            self.phase = text.count >= 6 ? .ready : .failed(L("没听清录音内容，请换个安静的地方再录一次"))
        }
    }

    func cancel() {
        stopEngine()
        phase = .idle
        try? FileManager.default.removeItem(at: url)
    }

    private func stopEngine() {
        timer?.invalidate()
        timer = nil
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        file = nil
        converter = nil
        level = 0
    }

    private static func transcribe(_ url: URL, locale: String) async -> String {
        guard let f = try? AVAudioFile(forReading: url),
              let buf = AVAudioPCMBuffer(pcmFormat: f.processingFormat, frameCapacity: AVAudioFrameCount(f.length)),
              (try? f.read(into: buf)) != nil else { return "" }
        return await LoopbackTest.transcribe([buf], locale: locale)
    }
}
