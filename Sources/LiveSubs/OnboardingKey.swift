import AppKit
import SwiftUI

/// Onboarding step 3: connect an AI service, Ling unless the user picks another (any
/// OpenAI-compatible one, or a local Ollama). Notes and the better translation need it, Ming's voices
/// need Ling, but it comes after the sample video, once people have seen what the app does. Skipping
/// is allowed: "先不接" first shows what still works and what waits for a key (the notes window asks
/// again later).
struct OnboardingKeyStep: View {
    @ObservedObject var ai: AIClient
    @ObservedObject var settings: AppSettings
    /// "先不接" was clicked: the card shows what skipping leaves out until 回去接上 or 好，先这样.
    @Binding var skipping: Bool
    @State private var draft = ""
    @State private var clipboardEmpty = false
    @State private var baseDraft = ""
    @State private var modelDraft = ""

    private var provider: AIProvider { settings.aiEndpoint.provider }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("接上 AI，用上完整的知了").font(.system(size: 26, weight: .bold)).foregroundStyle(Palette.ink)
                Text(provider.ming ? L("纪要、更准的翻译和自然的同传语音都靠它，约 1 分钟。") : L("纪要和更准的翻译都靠它，约 1 分钟。"))
                    .font(.system(size: 14)).foregroundStyle(Palette.secondary)
            }
            if case .ok = ai.keyState { connected } else if skipping { withoutKey } else { entry }
            if !skipping && provider.ming {
                HStack(spacing: 10) {
                    Text("Ling 每月赠送 ¥10 额度").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.accentInk)
                        .padding(.horizontal, 9).padding(.vertical, 3)
                        .background(Capsule().fill(Palette.accentPale))
                    Text("约够 10–50 小时会议")
                        .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                }
            }
        }
        .onAppear {
            baseDraft = settings.aiBaseURL
            modelDraft = settings.aiModel
        }
    }

    // MARK: Not connected yet

    private var entry: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text("用哪家 AI").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
                PillMenu(value: provider.name, options: AIProvider.all.map { ($0.id, $0.name) }) { pick($0) }
                Spacer()
                Text("之后可在设置里更换").font(.system(size: 12)).foregroundStyle(Palette.tertiary)
            }
            .padding(.bottom, 16)
            Divider()
            if provider.isCustom { customStep } else { createStep }
            Divider()
            HStack(alignment: .top, spacing: 14) {
                number(2)
                VStack(alignment: .leading, spacing: 10) {
                    Text(provider.ming ? L("复制 sk- 开头的 key，回来粘贴")
                         : provider.needsKey ? L("复制 key，回来粘贴") : L("检查连接（有 key 才填）"))
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                    HStack(spacing: 8) {
                        SecureField(provider.needsKey ? "sk-…" : L("API key（可不填）"), text: $draft)
                            .textFieldStyle(.plain).font(.system(size: 13, design: .monospaced))
                            .padding(.horizontal, 12).frame(height: 36)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.ink.opacity(0.35), lineWidth: 1))
                            .onSubmit { provider.needsKey ? save(draft) : connect() }
                        Button(action: provider.needsKey ? pasteAndCheck : connect) {
                            HStack(spacing: 6) {
                                if provider.needsKey { Image(systemName: "doc.on.clipboard").font(.system(size: 12)) }
                                Text(!provider.needsKey ? L("检查连接") : draft.isEmpty ? L("粘贴并检查") : L("保存并检查"))
                            }
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 14).frame(height: 36)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Palette.ink))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    status
                }
            }
            .padding(.top, 18)
        }
        .padding(22)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line, lineWidth: 1))
    }

    /// Step 1 for a known service: where to get a key (or, for Ollama, the app itself).
    private var createStep: some View {
        HStack(spacing: 14) {
            number(1)
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.ming ? L("在 Ling 开放平台创建 key")
                     : provider.isLocal ? L("在这台 Mac 上运行 \(provider.name)") : L("在 \(provider.name) 创建 API key"))
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                Text(provider.ming ? L("注册或登录后点“创建令牌”")
                     : provider.isLocal ? L("装好后拉取一个模型，如 \(provider.models.first ?? "")") : L("注册或登录后创建一个 key"))
                    .font(.system(size: 12)).foregroundStyle(Palette.tertiary)
            }
            Spacer()
            if let page = provider.keyPage, let url = URL(string: page) {
                Button { NSWorkspace.shared.open(url) } label: {
                    HStack(spacing: 5) {
                        Text(provider.ming ? L("打开 Ling 开放平台")
                             : provider.isLocal ? L("下载 \(provider.name)") : L("打开 \(provider.name)"))
                        Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .semibold))
                    }
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
                    .padding(.horizontal, 14).frame(height: 34)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Palette.fill))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 18)
    }

    /// Step 1 for 自定义: the address and model of any OpenAI-compatible service.
    private var customStep: some View {
        HStack(alignment: .top, spacing: 14) {
            number(1)
            VStack(alignment: .leading, spacing: 10) {
                Text("填写服务地址和模型").font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                field("https://…/v1", text: $baseDraft)
                field(L("模型，如 gpt-4.1-mini"), text: $modelDraft)
                Text("任何兼容 OpenAI 接口的地址，如 LM Studio、vLLM 或中转服务")
                    .font(.system(size: 12)).foregroundStyle(Palette.tertiary)
            }
        }
        .padding(.vertical, 18)
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain).font(.system(size: 13, design: .monospaced))
            .padding(.horizontal, 12).frame(height: 36)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.ink.opacity(0.35), lineWidth: 1))
            .onSubmit(connect)
    }

    @ViewBuilder private var status: some View {
        switch ai.keyState {
        case .checking, .unchecked:
            line(Palette.accent, L("正在检查…"), Palette.secondary)
        case .invalid:
            line(Palette.error, L("这个 key 无效，请检查是否复制完整，或重新创建一个"), Palette.accentInk)
        case .unreachable(let why):
            line(Palette.error, why, Palette.accentInk)
        default:
            if clipboardEmpty {
                line(Palette.error, provider.ming ? L("剪贴板里没有 sk- 开头的 key，先在 Ling 开放平台复制。")
                                                  : L("剪贴板里没有 key，先去 \(provider.name) 复制一个。"), Palette.accentInk)
            } else {
                Label(ai.host.isEmpty ? L("只存在这台 Mac 上，只有你的账户能读") : L("只保存在这台 Mac 上，只发给 \(ai.serviceName)"),
                      systemImage: "lock")
                    .font(.system(size: 12)).foregroundStyle(Palette.tertiary)
            }
        }
    }

    // MARK: Connected

    private var connected: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.ok)
                    .frame(width: 24, height: 24).background(Circle().fill(Palette.okPale))
                Text("已连接").font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                if case .ok(let s) = ai.keyState {
                    Text(L("\(settings.aiModel) · 响应约 \(String(format: "%.1f", s)) 秒"))
                        .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                }
                Spacer()
                if let key = ai.savedKey {
                    Text(AIKey.masked(key)).font(.system(size: 12, design: .monospaced)).foregroundStyle(Palette.secondary)
                }
            }
            Divider()
            Text("现在可以用了").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.secondary)
            HStack(spacing: 10) {
                benefit(L("实时纪要"), L("会中每 45 秒更新"))
                benefit(L("更准的翻译"), L("人名、术语前后一致"))
                if provider.ming { benefit(L("自然人声"), L("同传约 2 秒出声")) }
            }
            Text("开会时，纪要会跟着字幕一起更新。").font(.system(size: 12)).foregroundStyle(Palette.secondary)
        }
        .padding(22)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line, lineWidth: 1))
    }

    // MARK: Skipping

    /// Honest about both sides, so skipping is a choice rather than a dead end.
    private var withoutKey: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("先不接也行，基础功能照常能用").font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
            HStack(alignment: .top, spacing: 10) {
                column(L("现在可用"), [L("实时翻译字幕"), L("双语文字记录"), L("同声传译（系统语音）")],
                       head: Palette.secondary, fill: Palette.ground, check: true)
                column(L("接上 AI 才有"), [L("实时纪要和会后总结"), L("人名、术语前后一致")]
                                           + (provider.ming ? [L("自然人声，约 2 秒出声")] : []),
                       head: Palette.accentInk, fill: Palette.accentPale, check: false)
            }
            Text("随时可在纪要窗口或设置里接上，开完的会也能补出纪要。")
                .font(.system(size: 12)).foregroundStyle(Palette.secondary)
        }
        .padding(22)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line, lineWidth: 1))
    }

    private func column(_ title: String, _ items: [String], head: Color, fill: Color, check: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(head)
            ForEach(items, id: \.self) { item in
                HStack(spacing: 6) {
                    if check { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Palette.ink) }
                    Text(item).font(.system(size: 14)).foregroundStyle(Palette.ink)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(fill))
    }

    // MARK: Pieces

    private func number(_ n: Int) -> some View {
        Text("\(n)").font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.ink)
            .frame(width: 26, height: 26).background(Circle().fill(Palette.fill))
    }

    private func line(_ dot: Color, _ text: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(dot).frame(width: 7, height: 7)
            Text(text).font(.system(size: 12)).foregroundStyle(color).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func benefit(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
            Text(detail).font(.system(size: 12)).foregroundStyle(Palette.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.ground))
    }

    /// Reads the clipboard only when the button is clicked (a deliberate paste, so macOS's paste
    /// privacy prompt, if any, makes sense to the user); a typed key is checked as typed. Ling keys
    /// start with sk-; other services' keys only need to look like one word.
    private func pasteAndCheck() {
        if !draft.isEmpty { save(draft); return }
        let text = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard text.count >= 8, !text.contains(where: \.isWhitespace), !provider.ming || text.hasPrefix("sk-") else {
            clipboardEmpty = true
            return
        }
        save(text)
    }

    private func pick(_ id: String) {
        guard id != settings.aiProvider else { return }
        clipboardEmpty = false
        draft = ""
        settings.aiProvider = id
        modelDraft = settings.aiModel
        Task { await ai.reconfigure() }
    }

    /// A keyless or 自定义 service: apply what was typed, save a key if one was given, and check.
    private func connect() {
        clipboardEmpty = false
        if provider.isCustom {
            settings.aiBaseURL = baseDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            let m = modelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            if !m.isEmpty { settings.aiModel = m }
        }
        let k = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = ""
        Task {
            if !k.isEmpty { await ai.setKey(k) } else { await ai.reconfigure() }
        }
    }

    private func save(_ raw: String) {
        let k = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !k.isEmpty else { return }
        clipboardEmpty = false
        draft = ""
        Task { await ai.setKey(k) }
    }
}

/// Step 3's footer. 继续 waits for a working key; "先不接" turns the card into what skipping leaves out,
/// and only "好，先这样" there moves on without one.
struct OnboardingKeyFooter: View {
    @ObservedObject var ai: AIClient
    @Binding var skipping: Bool
    var next: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            if case .ok = ai.keyState {
                primary(L("继续"), arrow: true, action: next)
            } else if skipping {
                Button { skipping = false } label: {
                    Text("回去接上")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
                        .padding(.horizontal, 20).frame(height: 44)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(white: 0.84), lineWidth: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                primary(L("好，先这样"), arrow: false) { skipping = false; next() }
            } else {
                Button("先不接") { skipping = true }.buttonStyle(.plain).foregroundStyle(Palette.secondary)
                Text("接上后继续")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.secondary)
                    .padding(.horizontal, 24).frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.87)))
            }
        }
    }

    private func primary(_ text: String, arrow: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(text)
                if arrow { Image(systemName: "arrow.right") }
            }
            .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            .padding(.horizontal, 28).frame(height: 44)
            .background(RoundedRectangle(cornerRadius: 12).fill(Palette.ink))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.defaultAction)
    }
}
