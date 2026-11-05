import AppKit
import SwiftUI

/// Settings › AI 服务: the one AI service the whole app uses (Ling, another OpenAI-compatible service
/// or the user's own address), its key and model, and what uses it.
struct AISettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var ai: AIClient
    @ObservedObject var settings: AppSettings
    @State private var draft = ""
    @State private var editing = false
    @State private var baseDraft = ""
    @State private var modelDraft = ""
    @State private var speechDraft = ""

    private var provider: AIProvider { settings.aiEndpoint.provider }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            keyCard
            Text("用在哪里").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.secondary)
                .padding(.top, 4)
            SettingsCard {
                usageRow(L("实时纪要"), tag: ai.usable ? L("用 \(ai.serviceName)") : L("需要 key"), on: ai.usable,
                         note: ai.usable ? L("会中每 45 秒更新") : L("填好 key 后可用"))
                usageRow(L("翻译"), tag: ai.usable ? L("用 \(ai.serviceName)") : "Google", on: ai.usable,
                         note: ai.usable ? L("整句用 \(ai.serviceName)；不行时换 Google、本机") : L("没有 key 时照常可用"))
                usageRow(L("语音识别"), tag: L("本机"), on: false, note: L("更快，不花钱"))
                SettingsRow(title: L("同声传译的声音"), detail: voiceNote, divider: false) {
                    SoftButton(L("去选声音")) { model.settingsSection = .speak }
                }
            }
            SettingsCard {
                modelRow
                if provider.isCustom { speechRow }
            }
            Text(costNote).font(.system(size: 12)).foregroundStyle(Palette.tertiary)
        }
        .onAppear {
            baseDraft = settings.aiBaseURL
            modelDraft = settings.aiModel
            speechDraft = settings.aiSpeechModel
        }
    }

    private var voiceNote: String {
        if ai.voiceUsable { return L("Ming 的声音或你自己的声音") }
        if provider.ming { return L("没有 key 时用本机声音") }
        return provider.isCustom ? L("填了语音模型就用 Ming 的声音，现用本机声音") : L("Ming 声音只随 Ling 提供，现用本机声音")
    }

    private var costNote: String {
        if provider.ming {
            return L("一小时会议约 ¥0.15–1（目前优惠价）。发出去的只有文字（用你自己的声音时还有那段录音），语音识别留在本机。")
        }
        if provider.isLocal { return L("全部在这台 Mac 上运行，不花钱；语音识别也留在本机。") }
        if provider.isCustom {
            return ai.speechModel == nil ? L("费用按这个服务的价格计算。发出去的只有文字，语音识别留在本机。")
                : L("费用按这个服务的价格计算。发出去的只有文字（用你自己的声音时还有那段录音），语音识别留在本机。")
        }
        return L("按 \(provider.name) 的价格计费。发出去的只有文字，语音识别留在本机。")
    }

    // MARK: Service and key

    private var keyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle().fill(statusColor).frame(width: 8, height: 8)
                Text(statusTitle).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
                if let detail = statusDetail {
                    Text(detail).font(.system(size: 12)).foregroundStyle(Palette.tertiary).lineLimit(1)
                }
                Spacer()
            }
            HStack(spacing: 8) {
                Text("服务").font(.system(size: 13)).foregroundStyle(Palette.secondary)
                PillMenu(value: provider.name, options: AIProvider.all.map { ($0.id, $0.name) }, fill: .white) { id in
                    editing = false
                    draft = ""
                    model.setAIProvider(id)
                    modelDraft = settings.aiModel
                }
                Spacer()
            }
            if provider.isCustom { baseField }
            keyArea
            HStack(spacing: 6) {
                Image(systemName: "lock").font(.system(size: 11)).foregroundStyle(Palette.tertiary)
                Text(ai.host.isEmpty ? L("只存在这台 Mac 上，只有你的账户能读")
                     : provider.isCustom ? L("只保存在这台 Mac 上，只发给 \(ai.host)")
                     : L("只存在这台 Mac 上（只有你的账户能读），只发给 \(provider.name)（\(ai.host)）"))
                    .font(.system(size: 11)).foregroundStyle(Palette.tertiary)
                Spacer()
                if ai.savedKey != nil && !editing {
                    Button("移除") { ai.removeKey() }
                        .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Palette.secondary)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.961, green: 0.965, blue: 0.973)))
    }

    /// 自定义: any OpenAI-compatible address (LM Studio, vLLM, a relay…), applied on Return.
    private var baseField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField("https://…/v1", text: $baseDraft)
                    .textFieldStyle(.plain).font(.system(size: 13, design: .monospaced))
                    .padding(.horizontal, 12).frame(height: 36)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 1))
                    .onSubmit(applyBase)
                if baseDraft != settings.aiBaseURL { SoftButton(L("保存地址"), dark: true, action: applyBase) }
            }
            Text("任何兼容 OpenAI 接口的地址，如 LM Studio、vLLM 或中转服务")
                .font(.system(size: 11)).foregroundStyle(Palette.tertiary)
        }
    }

    @ViewBuilder private var keyArea: some View {
        if let key = ai.savedKey, !editing {
            HStack(spacing: 8) {
                Text(AIKey.masked(key)).font(.system(size: 13, design: .monospaced)).foregroundStyle(Palette.ink)
                    .padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 1))
                SoftButton(L("更换")) { draft = ""; editing = true }
                if case .unreachable = ai.keyState {
                    SoftButton(L("重试")) { Task { await ai.check() } }
                }
            }
        } else if !provider.needsKey && !editing {
            // Local and self-hosted services usually take no key: checking the connection is enough.
            HStack(spacing: 8) {
                Text(provider.isLocal ? L("本机服务不需要 key") : L("服务不要求 key 时可以不填"))
                    .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                Spacer()
                SoftButton(L("填 key"), onGrey: true) { draft = ""; editing = true }
                SoftButton(L("检查连接"), dark: true) { Task { await ai.check() } }.disabled(!ai.hasKey)
            }
            keyPageLink
        } else {
            if ai.savedKey == nil {
                Text(provider.ming ? L("在 Ling 开放平台点“创建令牌”，复制以 sk- 开头的那串。")
                                   : L("在 \(ai.serviceName) 的控制台创建 API key，复制回来粘贴。"))
                    .font(.system(size: 12)).foregroundStyle(Palette.secondary)
            }
            HStack(spacing: 8) {
                SecureField("sk-…", text: $draft)
                    .textFieldStyle(.plain).font(.system(size: 13, design: .monospaced))
                    .padding(.horizontal, 12).frame(height: 36)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.ink.opacity(0.6), lineWidth: 1))
                    .onSubmit(save)
                SoftButton(L("保存并检查"), dark: true, action: save)
                if editing { SoftButton(L("取消")) { editing = false } }
            }
            keyPageLink
        }
    }

    @ViewBuilder private var keyPageLink: some View {
        if let page = provider.keyPage, let url = URL(string: page) {
            Button(provider.ming ? L("打开 Ling 开放平台 ↗")
                   : provider.isLocal ? L("下载 \(provider.name) ↗") : L("去 \(provider.name) 创建 key ↗")) {
                NSWorkspace.shared.open(url)
            }
            .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Palette.secondary)
        }
    }

    private func save() {
        let k = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !k.isEmpty else { return }
        draft = ""
        editing = false
        Task { await ai.setKey(k) }
    }

    private func applyBase() {
        let s = baseDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        baseDraft = s
        guard s != settings.aiBaseURL else { return }
        settings.aiBaseURL = s
        Task { await ai.reconfigure() }
    }

    // MARK: Model

    /// Ling's two models as a menu; any other service takes whatever model it serves, with its
    /// own list (after a check) and the usual ones as suggestions.
    @ViewBuilder private var modelRow: some View {
        if provider.ming {
            SettingsRow(title: L("模型"), detail: L("3.1 更准；3.0 更快、更省"), divider: false) {
                PillMenu(value: settings.aiModel, options: provider.models.map { ($0, $0) }) { pickModel($0) }
            }
        } else {
            SettingsRow(title: L("模型"), detail: L("填服务支持的任意模型，回车生效"), divider: provider.isCustom) {
                HStack(spacing: 6) {
                    TextField(provider.models.first ?? "model", text: $modelDraft)
                        .textFieldStyle(.plain).font(.system(size: 12, design: .monospaced))
                        .padding(.horizontal, 10).frame(width: 210, height: 28)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Palette.ground))
                        .onSubmit { pickModel(modelDraft) }
                    if !suggestions.isEmpty {
                        Menu {
                            ForEach(suggestions, id: \.self) { m in Button(m) { pickModel(m) } }
                        } label: {
                            Image(systemName: "chevron.up.chevron.down").font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Palette.secondary)
                                .frame(width: 28, height: 28)
                                .background(RoundedRectangle(cornerRadius: 7).fill(Palette.ground))
                                .contentShape(Rectangle())
                        }
                        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
                        .accessibilityLabel(L("选择模型"))
                    }
                }
            }
            .onChange(of: provider.id) { modelDraft = settings.aiModel }
        }
    }

    /// 自定义 only: a Ming-3.0 TTS model on the same server (oMLX, mlx-audio) speaks Ming's voices
    /// and the cloned voice; empty leaves the Mac's voices.
    private var speechRow: some View {
        SettingsRow(title: L("语音模型"), detail: L("可不填；填服务上的 Ming-3.0 语音模型，同传就用 Ming 的声音"), divider: false) {
            HStack(spacing: 6) {
                TextField("Ming-3.0-tts-0.5B-bf16", text: $speechDraft)
                    .textFieldStyle(.plain).font(.system(size: 12, design: .monospaced))
                    .padding(.horizontal, 10).frame(width: 210, height: 28)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Palette.ground))
                    .onSubmit { pickSpeech(speechDraft) }
                if !speechSuggestions.isEmpty {
                    Menu {
                        ForEach(speechSuggestions, id: \.self) { m in Button(m) { pickSpeech(m) } }
                    } label: {
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Palette.secondary)
                            .frame(width: 28, height: 28)
                            .background(RoundedRectangle(cornerRadius: 7).fill(Palette.ground))
                            .contentShape(Rectangle())
                    }
                    .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
                    .accessibilityLabel(L("选择语音模型"))
                }
            }
        }
    }

    /// What the server lists that looks like Ming's speech model.
    private var speechSuggestions: [String] {
        ai.listedModels.filter { $0.localizedCaseInsensitiveContains("ming") && $0.localizedCaseInsensitiveContains("tts") }
    }

    private func pickSpeech(_ raw: String) {
        let m = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        speechDraft = m
        settings.aiSpeechModel = m
    }

    private var suggestions: [String] {
        var seen = Set<String>()
        return (provider.models + ai.listedModels).filter { seen.insert($0).inserted }
    }

    private func pickModel(_ raw: String) {
        let m = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !m.isEmpty else { modelDraft = settings.aiModel; return }
        modelDraft = m
        guard m != settings.aiModel else { return }
        settings.aiModel = m
        Task { await ai.reconfigure() }
    }

    // MARK: Status

    private var statusColor: Color {
        switch ai.keyState {
        case .ok: Palette.ok
        case .invalid, .unreachable: Palette.error
        case .checking, .unchecked: Palette.accent
        case .none: Color(white: 0.75)
        }
    }

    private var statusTitle: String {
        switch ai.keyState {
        case .none:
            if ai.baseURL == nil { L("还没填服务地址") } else if ai.model.isEmpty { L("还没填模型") } else { L("还没填 API key") }
        case .unchecked, .checking: L("正在检查…")
        case .ok: L("已连接")
        case .invalid: L("这个 key 用不了")
        case .unreachable: L("暂时连不上")
        }
    }

    private var statusDetail: String? {
        switch ai.keyState {
        case .ok(let s): L("\(settings.aiModel) · 响应约 \(String(format: "%.1f", s)) 秒")
        case .invalid: L("\(ai.serviceName) 提示此 key 无效，请检查是否复制完整，或重新创建一个")
        case .unreachable(let why): why
        case .none: L("不填 key 时，字幕和翻译仍可正常使用")
        default: nil
        }
    }

    private func usageRow(_ title: String, tag: String, on: Bool, note: String, divider: Bool = true) -> some View {
        SettingsRow(title: title, detail: note, divider: divider) {
            Text(tag).font(.system(size: 11, weight: .semibold))
                .foregroundStyle(on ? Palette.ok : Palette.secondary)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 6).fill(on ? Palette.okPale : Palette.fill))
        }
    }
}
