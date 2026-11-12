import AppKit
import DimmelaCore
import SwiftUI

/// The welcome tour, after dimmela.app: what Dimmela does, the permissions and the download before
/// the first Dictation (each ticked as soon as it is done), a real Dictation tried right in the
/// window, the Modes, and the small things. Shown on the first launch and until Done; the menu
/// opens it again.
struct WelcomeView: View {
    static let windowID = "welcome"

    /// Until Done is clicked once. In Debug builds `-showWelcome YES` shows it anyway.
    static var isNeededAtLaunch: Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "showWelcome") { return true }
        #endif
        return !UserDefaults.standard.bool(forKey: AppSettings.onboardingDoneKey)
    }

    enum Page: Int, CaseIterable {
        case hello, setup, tryIt, modes, details
    }

    /// The hello page; in Debug builds `-welcomePage 2` opens another, to check its look.
    private static var firstPage: Page {
        #if DEBUG
        if let page = Page(rawValue: UserDefaults.standard.integer(forKey: "welcomePage")) { return page }
        #endif
        return .hello
    }

    let model: AppModel
    @State private var page: Page = Self.firstPage
    /// Which way the pages slide: forward from the right, back from the left.
    @State private var isGoingForward = true
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppSettings.onboardingDoneKey) private var isDone = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                content
                    .id(page)
                    .transition(transition)
            }
            // Not clipped: the hero's green goes on under the hidden title bar.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
        }
        .frame(width: 680, height: 600)
        .background(.background)
        // No Dock icon: without activating, the window would open behind the others.
        .onAppear { NSApplication.shared.activate() }
        // Back from System Settings, where a permission may have just been granted.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await model.refreshPermissions() }
        }
    }

    @ViewBuilder private var content: some View {
        switch page {
        case .hello: HelloPage()
        case .setup: SetupPage(model: model)
        case .tryIt: TryItPage(model: model)
        case .modes: ModesPage()
        case .details: DetailsPage()
        }
    }

    private var transition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: isGoingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: isGoingForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    private var footer: some View {
        HStack {
            Button("Back") { go(to: page.rawValue - 1) }
                .opacity(page == .hello ? 0 : 1)
                .disabled(page == .hello)
            Spacer()
            HStack(spacing: 6) {
                ForEach(Page.allCases, id: \.self) { each in
                    Capsule()
                        .fill(each == page ? Brand.accent : Color.secondary.opacity(0.3))
                        .frame(width: each == page ? 18 : 6, height: 6)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(Text("Page \(page.rawValue + 1) of \(Page.allCases.count)"))
            Spacer()
            nextButton
        }
        .controlSize(.large)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    @ViewBuilder private var nextButton: some View {
        let button = Button(page == .details ? "Start Dictating" : page == .hello ? "Get Started" : "Continue") {
            if page == .details {
                isDone = true
                dismissWindow(id: Self.windowID)
            } else {
                go(to: page.rawValue + 1)
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(Brand.accent)
        // While trying a Dictation, Return belongs to the text box.
        if page == .tryIt {
            button
        } else {
            button.keyboardShortcut(.defaultAction)
        }
    }

    private func go(to index: Int) {
        guard let next = Page(rawValue: index) else { return }
        isGoingForward = index > page.rawValue
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.5, bounce: 0.12)) { page = next }
    }
}

// MARK: - Pages

/// dimmela.app's hero: "Just say it."
private struct HelloPage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            HeroBackground().ignoresSafeArea()
            VStack(spacing: 22) {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 112, height: 112)
                    .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
                    .accessibilityHidden(true)
                Text("Just say it.")
                    .font(.system(size: 64, weight: .bold))
                    .tracking(-2.6)
                    .foregroundStyle(Brand.ink)
                // The keys press themselves now and then, as on the site; still with Reduce Motion.
                PhaseAnimator([false, true, true, false], trigger: reduceMotion) { isPressed in
                    ShortcutKeys(isPressed: isPressed && !reduceMotion, scale: 1.15)
                } animation: { isPressed in
                    isPressed ? .spring(duration: 0.25, bounce: 0.3).delay(1.2) : .spring(duration: 0.3).delay(0.6)
                }
                Text("Hold fn space, speak, let go.\nDimmela types it wherever your cursor is.")
                    .font(.title2.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Brand.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Dimmela /ˈdim.me.la/ · Italian for “tell it to me.”")
                    .font(.callout)
                    .foregroundStyle(Brand.inkSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.3)))
                    .padding(.top, 6)
            }
            .padding(32)
        }
    }
}

/// The permissions and the speech model, ticked as they are done.
private struct SetupPage: View {
    let model: AppModel

    var body: some View {
        VStack(spacing: 22) {
            PageHead(
                eyebrow: "Before the first Dictation",
                title: "Three permissions and a model.",
                subtitle: "Your voice is transcribed on this Mac. Nothing here is sent anywhere."
            )
            VStack(spacing: 10) {
                SetupCard(
                    systemImage: "mic.fill", title: "Microphone",
                    text: "To hear you. It is on only while you dictate.",
                    isDone: model.microphonePermission == .authorized
                ) {
                    switch model.microphonePermission {
                    case .notDetermined:
                        WindowButton("Allow") { await model.requestMicrophone() }
                    case .denied, .restricted:
                        Button("Open System Settings") { model.openMicrophoneSettings() }
                    default:
                        EmptyView()
                    }
                }
                SetupCard(
                    systemImage: "accessibility", title: "Accessibility",
                    text: "To see fn space in every app and to paste the text. Turn Dimmela on in the list.",
                    isDone: model.accessibilityGranted
                ) {
                    HStack {
                        Button("Allow") { model.requestAccessibility() }
                        Button("Open System Settings") { model.openAccessibilitySettings() }
                    }
                }
                SetupCard(
                    systemImage: "bell.badge.fill", title: "Notifications",
                    text: "To tell you when something goes wrong, for example when the Transcript was pasted because Post-processing failed.",
                    isDone: model.notificationsAllowed
                ) {
                    HStack {
                        WindowButton("Allow") { await model.requestNotifications() }
                        Button("Open System Settings") { model.openNotificationSettings() }
                    }
                }
                SetupCard(
                    systemImage: "waveform", title: "Speech model",
                    text: nil, isDone: model.speechModel.state == .ready
                ) {
                    EmptyView()
                } detail: {
                    SpeechModelStatus(model: model.speechModel)
                }
            }
            .frame(maxWidth: 560)
        }
        .padding(28)
    }
}

/// A Dictation tried right here: the keys light up while recording, and the text lands in the box.
private struct TryItPage: View {
    let model: AppModel
    @State private var text = ""
    @FocusState private var isFocused: Bool

    private var phase: DictationController.Phase { model.controller.phase }

    var body: some View {
        VStack(spacing: 18) {
            PageHead(
                eyebrow: "Try it here",
                title: "Hold fn space. Talk.",
                subtitle: "Let go, and the text lands in the box below, as it will in any app."
            )
            VStack(spacing: 12) {
                ShortcutKeys(isPressed: phase == .recording)
                HStack(spacing: 8) {
                    switch phase {
                    case .recording:
                        LevelBars(level: model.controller.level, color: Brand.accent)
                        Text("Listening… let go to paste.")
                    case .processing:
                        ProgressView().controlSize(.small)
                        Text("Transcribing…")
                    case .idle:
                        if let missing {
                            Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
                            Text(missing)
                        } else if text.isEmpty {
                            Text("Hold fn space and say something.")
                        } else {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Brand.accent)
                            Text("It works. Try a longer one: tap fn space to talk hands-free.")
                        }
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(height: 22)
            }
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.system(size: 15))
                    .scrollContentBackground(.hidden)
                    .focused($isFocused)
                    .padding(10)
                if text.isEmpty {
                    Text("Your Dictations land here.")
                        .font(.system(size: 15))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: 560, minHeight: 110, maxHeight: 130)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.background.secondary))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isFocused ? Brand.accent.opacity(0.6) : .secondary.opacity(0.2))
            )
            HStack(alignment: .top, spacing: 10) {
                Tip(key: "Hold", text: "For a quick thought. Let go and it's pasted.")
                Tip(key: "Tap", text: "Lock: talk hands-free, tap again to finish.")
                Tip(key: "esc", text: "Changed your mind? Nothing is pasted.")
            }
            .frame(maxWidth: 560)
        }
        .padding(28)
        .onAppear { isFocused = true }
    }

    /// What is still missing before a Dictation can work.
    private var missing: String? {
        if model.microphonePermission != .authorized { return "Allow the microphone first, in the previous step." }
        if !model.accessibilityGranted { return "Allow Accessibility first, in the previous step." }
        if model.speechModel.state != .ready { return "Wait for the speech model, in the previous step." }
        return nil
    }
}

private struct Tip: View {
    let key: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(key).font(.callout.weight(.semibold))
            Text(text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

/// shift and the digits, the built-in Modes, where Post-processing goes and the Default Mode.
private struct ModesPage: View {
    @AppStorage(AppSettings.enabledModesKey) private var enabled = ""
    @AppStorage(AppSettings.defaultModeKey) private var defaultModeID = ""
    @AppStorage(AppSettings.providerProfilesKey) private var profiles = ProviderProfiles()
    @Environment(\.openSettings) private var openSettings

    private var modes: [Mode] { AppSettings.lines(of: enabled).map(Mode.init(id:)) }

    var body: some View {
        VStack(spacing: 22) {
            PageHead(
                eyebrow: "Modes",
                title: "Want it rewritten? Pick a Mode.",
                subtitle: "While you talk, press shift for the list and a digit to choose. Clean tidies up what you said; Markdown also makes the lists and tables you ask for."
            )
            HStack(alignment: .center, spacing: 28) {
                VStack(spacing: 10) {
                    HStack(spacing: 6) {
                        KeyCap(label: "⇧ shift", scale: 0.85)
                        KeyCap(label: "1", scale: 0.85)
                        KeyCap(label: "2", scale: 0.85)
                    }
                    ModePreview(modes: Array(modes.prefix(4)), selected: modes.first { $0.id == defaultModeID })
                }
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Start every Dictation with", selection: $defaultModeID) {
                        Text("The Transcript alone").tag("")
                        ForEach(modes) { Text($0.name).tag($0.id) }
                    }
                    .fixedSize()
                    Text(providerLine)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Set Up Post-processing…") {
                        SettingsTab.select(.postProcessing)
                        NSApplication.shared.activate()
                        openSettings()
                    }
                }
                .frame(width: 290, alignment: .leading)
            }
        }
        .padding(28)
    }

    private var providerLine: String {
        let options = "A provider key (OpenRouter, a model on this Mac) or a coding agent you already pay for (Claude Code, Codex, Copilot, OpenCode, Pi), in Settings › Post-processing."
        guard let profile = profiles.selected else { return "Modes need an LLM. " + options }
        return "Modes go to \(profile.displayName) now. Only the text is sent. " + options
    }
}

/// The overlay's Mode list as it looks while dictating.
private struct ModePreview: View {
    let modes: [Mode]
    let selected: Mode?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            row(digit: 0, name: "Transcript", isSelected: selected == nil)
            ForEach(Array(modes.enumerated()), id: \.offset) { index, mode in
                row(digit: index + 1, name: mode.name, isSelected: mode == selected)
            }
        }
        .padding(6)
        .frame(width: 220)
        .background(RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.82)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.12)))
        .environment(\.colorScheme, .dark)
        .accessibilityHidden(true)
    }

    private func row(digit: Int, name: String, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Text(verbatim: "\(digit)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 14)
            Text(name).font(.system(size: 13)).foregroundStyle(.white).lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 7).fill(isSelected ? .white.opacity(0.18) : .clear))
    }
}

/// dimmela.app's "small things" and its privacy promise.
private struct DetailsPage: View {
    var body: some View {
        VStack(spacing: 20) {
            PageHead(
                eyebrow: "The small things",
                title: "Built for dictating all day.",
                subtitle: "Your voice never leaves your Mac: Parakeet runs on the Neural Engine. Only text is sent, and only to the provider you choose."
            )
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    Tile(systemImage: "character.book.closed", title: "Vocabulary", text: "Names and terms speech recognition gets wrong are fixed, then handed to the LLM too. In Settings › General.")
                    Tile(systemImage: "clock.arrow.circlepath", title: "History", text: "Your last five Dictations, with their audio. Copy Last Dictation is at the top of the menu.")
                }
                GridRow {
                    Tile(systemImage: "text.badge.minus", title: "No more “ehm”", text: "Fillers like “uhm” and “mmh” disappear. Words with meaning, like “cioè”, never do.")
                    Tile(systemImage: "globe", title: "Many languages, no setting", text: "Speak Italian, English and other European languages, and mix them.")
                }
            }
            .frame(maxWidth: 560)
            HStack {
                LaunchAtLoginToggle()
                Spacer()
            }
            .frame(maxWidth: 560)
        }
        .padding(28)
    }
}

// MARK: - Setup pieces

private struct SetupCard<Actions: View, Detail: View>: View {
    let systemImage: String
    let title: String
    let text: String?
    let isDone: Bool
    @ViewBuilder var actions: Actions
    @ViewBuilder var detail: Detail

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isDone ? .white : Brand.accent)
                .frame(width: 30, height: 30)
                .background(Circle().fill(isDone ? AnyShapeStyle(Brand.accent) : AnyShapeStyle(Brand.accent.opacity(0.14))))
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                    if isDone {
                        Label("Done", systemImage: "checkmark.circle.fill")
                            .labelStyle(.iconOnly)
                            .foregroundStyle(Brand.accent)
                            .font(.title3)
                    } else {
                        actions.controlSize(.small)
                    }
                }
                if let text {
                    Text(text).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                detail
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.background.secondary))
        .animation(.spring(duration: 0.35), value: isDone)
    }
}

extension SetupCard where Detail == EmptyView {
    init(systemImage: String, title: String, text: String?, isDone: Bool, @ViewBuilder actions: () -> Actions) {
        self.init(systemImage: systemImage, title: title, text: text, isDone: isDone, actions: actions, detail: { EmptyView() })
    }
}

/// A button whose system prompt brings another app to the front: the window comes back when it
/// is answered (from Takku).
private struct WindowButton: View {
    let title: LocalizedStringKey
    let action: () async -> Void

    init(_ title: LocalizedStringKey, action: @escaping () async -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(title) {
            let window = NSApplication.shared.keyWindow
            Task {
                await action()
                await Self.bringBack(window)
            }
        }
    }

    private static func bringBack(_ window: NSWindow?) async {
        for _ in 0..<480 {
            guard let front = NSWorkspace.shared.frontmostApplication,
                  front != .current,
                  front.activationPolicy != .regular
            else { break }
            try? await Task.sleep(for: .milliseconds(250))
        }
        NSApplication.shared.activate()
        window?.orderFrontRegardless()
        window?.makeKey()
    }
}

/// Where the speech model is: downloading, preparing, ready or failed, with a way to retry.
struct SpeechModelStatus: View {
    let model: SpeechModel

    var body: some View {
        switch model.state {
        case .notLoaded:
            HStack {
                Text("\(model.choice.name), \(model.choice.downloadMB) MB, downloaded once.").foregroundStyle(.secondary)
                Spacer()
                Button("Download") { Task { try? await model.prepare() } }
            }
        case .downloading(let percent):
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: Double(percent), total: 100)
                Text("Downloading \(model.choice.name)… \(percent)%").font(.caption).foregroundStyle(.secondary)
            }
        case .preparing(let firstTime):
            HStack {
                ProgressView().controlSize(.small)
                Text(firstTime
                    ? "Preparing the model for this Mac. It takes a few minutes, only once."
                    : "Loading the model…")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .ready:
            Text("\(model.choice.name) is ready.").foregroundStyle(.secondary)
        case .failed(let detail):
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("The model could not be loaded.")
                    Spacer()
                    Button("Retry") { Task { try? await model.prepare() } }
                }
                Text(detail).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }
    }
}
