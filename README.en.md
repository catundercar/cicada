<p align="center">
  <img src="docs/icon.png" width="128" height="128" alt="Cicada icon">
</p>

<h1 align="center">Cicada · 知了</h1>

<p align="center">
  Every call. Every stream. No language barrier.<br>
  Live meeting notes, bilingual transcripts, subtitles and interpreting for anything your Mac plays.
</p>

<p align="center">
  <a href="https://cicada.indaloop.app"><img src="https://img.shields.io/badge/Website-cicada.indaloop.app-E8552B?style=for-the-badge" alt="Website: cicada.indaloop.app" height="36"></a>
  &nbsp;
  <a href="https://github.com/wquguru/cicada/releases/latest"><img src="https://img.shields.io/badge/Download-macOS-15171C?style=for-the-badge&logo=apple&logoColor=white" alt="Download for macOS" height="36"></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-26%2B-black" alt="macOS 26+">
  <img src="https://img.shields.io/badge/Apple%20silicon-only-black" alt="Apple silicon">
  <img src="https://img.shields.io/badge/Swift-5-orange" alt="Swift 5">
  <img src="https://img.shields.io/badge/license-Apache--2.0-blue" alt="Apache-2.0">
</p>

<p align="center"><a href="README.md">简体中文</a> · <a href="README.en.md">English</a></p>

Cicada works with whatever is playing on your Mac, from Zoom, Teams, and Feishu calls to X Spaces, Discord stages, and YouTube livestreams. By listening directly to system audio, it gives you live bilingual subtitles and structured meeting notes without sending bots into the call or asking anyone else to install a thing. And when you need to jump in, just hold the right `⌥` key to speak and broadcast your translated voice straight into the meeting.

<p align="center">
  <img src="docs/demo.gif" width="800" alt="A Bloomberg English livestream on YouTube with Cicada's live Chinese notes, topics, and fishbone diagram on the right and bilingual subtitles at the bottom">
</p>

## Features

### Live notes and bilingual transcript

While the meeting runs, the notes window organizes a summary, topics and key points, conclusions, to-dos, a fishbone diagram, and a glossary of names and terms, and every conclusion or to-do clicks straight back to the supporting lines in the bilingual transcript. Cicada unifies names and terms across the notes and remembers misrecognized spellings, so `⌘F` searches both the canonical spelling and the variants.

### Live subtitles and language detection

Cicada detects the spoken language on device within seconds and translates into your system language, and pressing `⌃⌥S` switches between the notes window, a compact subtitle bar, and hidden. The subtitle bar appears only when someone speaks and turns see-through under your pointer so you can click right through it.

### Speak back in their language

Hold the right `⌥` key and speak so the room hears your translated voice through BlackHole 2ch, a virtual microphone you can install from the app with one click and that Cicada switches to automatically while interpreting is on. With Ling as the AI service and its key set, the other side hears natural Ming voices or a clone of your own voice from an 8 to 30 second sample; otherwise it uses macOS system voices.

<p align="center">
  <img src="docs/interpreting.png" width="640" alt="Interpreting settings showing the right Option talk key, target language, Ming voice previews, and macOS voices">
</p>

### Meeting records

Every session saves its bilingual transcript, notes, and audio recording on your Mac, and turning on experimental speaker identification separates voices on the other side and fills in their names when an AI service is connected. Cicada ends the session and trims the silent tail when the call hangs up or after 10 minutes of silence, and you can generate notes later or export to Markdown, Word, or SRT subtitles. Right now "you" in the transcript covers only what you say while holding the talk key; recording what you say directly into the meeting is on the [roadmap](#roadmap).

<p align="center">
  <img src="docs/records.png" width="640" alt="Meeting records window showing identified speakers and a line-by-line English and Chinese transcript">
</p>

## Privacy & Permissions

Audio capture, language detection, speech recognition (Apple SpeechAnalyzer), and meeting recordings all stay on your Mac. The only data that leaves your device is the recognized text sent for translation and meeting notes, plus the short audio clips you speak while holding the talk key when using Ling. Without an AI service, subtitles, translation (via Google with Apple on-device fallback), meeting records, and push-to-talk interpreting all work. Live meeting notes, sharper sentence translation, and speaker names need an AI service: Ling (Ant Group's model service) by default, or DeepSeek, Qwen, Kimi, Zhipu GLM, OpenAI, OpenRouter, a local Ollama, or any OpenAI-compatible address (see [below](#ai-service)). One-step voice translation, Ming voices, and voice cloning come only with Ling. With Ling an hour of live notes costs roughly ¥0.15 to ¥1 at current pricing, and Ling gives ¥10 of credit every month, enough for about 10 to 50 hours of meetings; other services bill at their own prices, and Ollama is free.

Cicada asks for a permission only when you use the feature that needs it, and everything else keeps working if you decline.

| Permission | What it's for | When it's asked | Without it |
|---|---|---|---|
| System audio recording (Screen & System Audio Recording) | Hearing what your Mac plays, for subtitles. Never records the screen or its own sound | Onboarding step 1, or the first time it listens | No subtitles or notes |
| Microphone | Recording only while you hold the talk key, for speak-back | When you turn on speak-back | No speak-back |
| Input Monitoring | Only to tell whether the right `⌥` was pressed on its own (listen-only; nothing is blocked or logged) | The first time you talk with right `⌥` | Pick a `⌃`/`⌘` combination in Settings instead; it needs no permission |
| Administrator password | Installing the BlackHole 2ch virtual microphone and restarting the system audio service | When you click Install in onboarding or Settings, once | The room can't hear your translation; everything else works |

- **Network and virtual microphone**. Cicada only connects to Google Translate (`translate.googleapis.com`), the AI service you choose (Ling / Ming at `api.ant-ling.com` by default), the official BlackHole download, and GitHub once a day for update checks. BlackHole is downloaded from the official Apple-notarized package and verified against a hardcoded SHA-256 checksum before installing.
- **No analytics or servers of our own**. There is no analytics, no tracking, and no backend server. Diagnostics only log timings and counts locally in the meeting folder.
- **Local storage**. Meetings, recordings, and notes live in `~/Library/Application Support/LiveSubs`. Your AI service keys and voice sample are readable only by your user account, excluded from Time Machine backups, and never written to logs or exports.
- **Private notes window**. Hidden from screen sharing, screen recording, and screenshots, unless you turn on the option to show it during screen sharing to record a demo.

## Models

Without an AI service, everything runs on Apple's on-device models plus Google Translate. With one, the chosen service's model handles the tasks below and falls back automatically if a request fails; the two Ming rows need Ling.

| Feature | With an AI service (Ling by default) | Without / fallback |
|---|---|---|
| Speech recognition and language detection | Apple `SpeechAnalyzer` / `SpeechTranscriber` (on device) | same |
| Translating finished sentences | The chosen service's model, Ling `Ling-3.1-flash` by default (change service or model in Settings › AI Service) | Google Translate → Apple `Translation` (on device) |
| Translating the sentence still being spoken | Google Translate (saves the AI service's rate limit) | Apple `Translation` (on device) |
| Live notes, the final version, speaker names | Same as above | not available |
| Checking the key | The chosen model (`Ling-3.0-tiny` for Ling), one token | — |
| Interpreting: hearing and translating what you say | With Ling: Ming `Ming-3.0-audio-flash`, one step; other services use the right column | Apple on-device transcript, then the translation chain above |
| Interpreting: the voice the room hears, voice cloning | With Ling: Ming `Ming-3.0-tts-0.5B`; other services use the right column | macOS system voices (`AVSpeechSynthesizer`); no cloning |
| Speaker identification (说话人识别, experimental, off by default) | WeSpeaker ResNet34-LM voiceprints, bundled, on device (Core ML) | same |

<a id="ai-service"></a>
## Setting up the AI service

1. In Cicada, open **Settings › AI Service** (or step 3 of onboarding) and pick a **Service**: Ling (default), DeepSeek, Qwen, Kimi, Zhipu GLM, OpenAI, OpenRouter, Ollama, or **Custom**.
2. Create an API key on that service and copy it. For Ling: sign up or log in on the [Ling open platform](https://chat.ant-ling.com/platform/api), click **创建令牌** (create token), and copy the key that starts with `sk-`.
3. Paste the key and click **Save and check** (or paste it in the prompt at the top of the notes window). A one-token request confirms the key and model work. Each service keeps its own key, so switching back needs no new one.
4. Optionally change the model on the same page: `Ling-3.1-flash` or `Ling-3.0-flash` for Ling, any model the service offers for the others (after a check, the menu lists the service's own models).
5. A local [Ollama](https://ollama.com/download) needs no key: install it, pull a model such as `qwen2.5:7b`, and click **Check Connection**. **Custom** takes any OpenAI-compatible address ([oMLX](https://github.com/jundot/omlx), LM Studio, vLLM, a relay…), with an optional key; Cicada asks local models not to think, so a sentence translation doesn't wait on reasoning.
6. Pick the Ming voice for each language under **Settings › Interpreting** (Ling only). To remove a key, click **Remove** on the same page.

## Requirements & Installation

Requires **macOS 26 or later** on **Apple silicon**. The UI is available in English, Chinese, Japanese, and Korean, following your macOS language or set per app in **System Settings › General › Language & Region**.

Download `Cicada-<version>-macOS-AppleSilicon.dmg` from [Releases](https://github.com/wquguru/cicada/releases/latest) or [the website](https://cicada.indaloop.app), open it, and drag **Cicada** into **Applications**. Builds are ad-hoc signed and not notarized yet (see [roadmap](#roadmap)), so if macOS blocks the first launch, open **System Settings › Privacy & Security** and click **Open Anyway**. Each release includes `checksums.txt`, which you can verify with `shasum -a 256 Cicada-*.dmg`. For questions, reach out to the author [@wquguru](https://x.com/wquguru) on X.

The first-launch guide asks for one permission, plays a short two-person sample meeting so you can see live subtitles right away, helps you connect an AI service (or skip it for now), and sets up the virtual microphone if you want interpreting. Later updates show as an orange dot on the menu bar icon and install in one click without losing your permissions.

<p align="center">
  <img src="docs/onboarding.png" width="640" alt="Onboarding step 2 playing a two-person sample meeting with live bilingual subtitles">
</p>

## Roadmap

In rough order; tell us what you need in Issues.

- **Recording what you say**, listening to your microphone during meetings with echo cancellation so your own proposals and to-dos are included in the transcript and notes.
- **Older macOS support (targeting macOS 14.4+)**, falling back to earlier system speech recognition and translation APIs on older versions.
- **Developer ID signing and notarization**, removing the "Open Anyway" prompt on first launch and storing the AI key in the macOS Keychain.
- **Speaker recognition**, building on today's experimental speaker identification to remember frequent meeting participants by voice on your Mac, so they're named in the next meeting too.
- **Local notes without an API key** using Apple's on-device model on supported Macs, plus **custom AI providers** for any OpenAI-compatible endpoint.
- **Windows and Android**, sharing the same notes and meeting-record formats (iPhone and iPad are not planned due to iOS audio capture restrictions).

See [docs/ROADMAP.md](docs/ROADMAP.md) for details and trade-offs on each item.

## Uninstall

Quit Cicada and drag it from **Applications** to the Trash. To remove all saved transcripts, notes, and audio recordings, delete `~/Library/Application Support/LiveSubs`. To clear preferences, run:

```bash
defaults delete com.wquguru.cicada
```

## Development

Building from source requires Xcode Command Line Tools (`xcode-select --install`). Cicada has no third-party dependencies and builds directly against macOS system frameworks.

```bash
scripts/build.sh            # dev build → build/Cicada.app ("Cicada Dev", runs beside the installed app)
open build/Cicada.app
scripts/package.sh          # release DMG + zip + checksums
```

See [AGENTS.md](AGENTS.md) for architecture details and release workflows. The website source lives in `site/` and is generated by `scripts/site.py`. Release history is in [CHANGELOG.md](CHANGELOG.md) and on the website at [cicada.indaloop.app/changelog](https://cicada.indaloop.app/changelog/).

## License

[Apache-2.0](LICENSE). The BlackHole 2ch virtual audio driver is licensed under the GPL; Cicada does not bundle it and downloads the official release on demand when you choose to install it. The bundled voiceprint model is [WeSpeaker](https://github.com/wenet-e2e/wespeaker)'s ResNet34-LM trained on VoxCeleb, licensed CC BY 4.0, converted to Core ML by `scripts/convert-voiceprint.py`.
