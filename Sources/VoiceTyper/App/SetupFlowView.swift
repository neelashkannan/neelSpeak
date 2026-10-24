import SwiftUI

/// First-run onboarding: welcome → permissions → speech model → try it.
struct SetupFlowView: View {
    enum Step: Int, CaseIterable {
        case welcome, permissions, model, tryIt

        var title: String {
            switch self {
            case .welcome: return "Welcome"
            case .permissions: return "Permissions"
            case .model: return "Speech model"
            case .tryIt: return "Try it"
            }
        }
    }

    @ObservedObject var viewModel: VoiceTyperViewModel
    @State private var step: Step
    @State private var launchAtLogin = true

    init(viewModel: VoiceTyperViewModel, initialStep: Step = .welcome) {
        self.viewModel = viewModel
        _step = State(initialValue: initialStep)
    }

    var body: some View {
        VStack(spacing: 0) {
            StepIndicator(current: step)
                .padding(.top, 40)
                .padding(.bottom, 8)

            ScrollView {
                Group {
                    switch step {
                    case .welcome:
                        WelcomeStep(trigger: viewModel.hotkeyTrigger)
                    case .permissions:
                        PermissionsStep(viewModel: viewModel)
                    case .model:
                        ModelStep(viewModel: viewModel)
                    case .tryIt:
                        TryItStep(viewModel: viewModel, launchAtLogin: $launchAtLogin)
                    }
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 40)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }

            Divider()
            HStack {
                if step != .welcome {
                    Button("Back") { go(to: step.rawValue - 1) }
                        .keyboardShortcut(.cancelAction)
                }
                Spacer()
                if step == .tryIt {
                    Button("Finish Setup") { finish() }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                } else {
                    Button(step == .welcome ? "Get Started" : "Continue") { go(to: step.rawValue + 1) }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!canContinue)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: step) { _, newStep in
            if newStep == .model, !viewModel.modelReady, viewModel.modelProgress == nil, viewModel.selectedModel.isInstalled {
                // Already downloaded: load it straight away.
                viewModel.prepareSelectedModel()
            }
        }
    }

    private var canContinue: Bool {
        switch step {
        case .welcome: return true
        case .permissions: return viewModel.permissionsGranted
        case .model: return viewModel.modelReady
        case .tryIt: return true
        }
    }

    private func go(to rawValue: Int) {
        guard let next = Step(rawValue: rawValue) else { return }
        withAnimation(.easeInOut(duration: 0.25)) { step = next }
    }

    private func finish() {
        if launchAtLogin != viewModel.launchAtLoginEnabled {
            viewModel.setLaunchAtLogin(launchAtLogin)
        }
        viewModel.finishSetupAndRunInBackground()
    }
}

private struct StepIndicator: View {
    let current: SetupFlowView.Step

    var body: some View {
        HStack(spacing: 8) {
            ForEach(SetupFlowView.Step.allCases, id: \.self) { step in
                Capsule()
                    .fill(step.rawValue <= current.rawValue ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: step == current ? 28 : 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: current)
        .accessibilityElement()
        .accessibilityLabel("Step \(current.rawValue + 1) of \(SetupFlowView.Step.allCases.count): \(current.title)")
    }
}

private struct StepHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 26, weight: .bold))
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct WelcomeStep: View {
    let trigger: HotkeyTrigger

    var body: some View {
        VStack(spacing: 28) {
            AppIconMark()
                .frame(width: 96, height: 96)
            StepHeader(
                title: "Welcome to NeelSpeak",
                subtitle: "Hold a key, say what you want to write, and let go. Your words appear wherever you're typing."
            )
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(symbol: "keyboard", title: "Works in every app", detail: "Hold \(trigger.keyCapLabel) in Mail, Slack, your editor, anywhere with a text cursor.")
                FeatureRow(symbol: "lock.shield", title: "Private by default", detail: "Speech is transcribed on this Mac. Nothing is uploaded unless you turn on a cloud cleanup engine.")
                FeatureRow(symbol: "wand.and.stars", title: "Optional AI cleanup", detail: "Strip the ums, stutters and false starts before the text lands.")
            }
            .padding(20)
            .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct FeatureRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PermissionsStep: View {
    @ObservedObject var viewModel: VoiceTyperViewModel

    var body: some View {
        VStack(spacing: 24) {
            StepHeader(
                title: "Two permissions",
                subtitle: "NeelSpeak only listens while you hold the dictation key."
            )
            VStack(spacing: 16) {
                PermissionRow(
                    symbol: "mic.fill",
                    title: "Microphone",
                    detail: viewModel.microphoneStatus == .authorized
                        ? "Allowed"
                        : "To hear you while you hold the key.",
                    granted: viewModel.microphoneStatus == .authorized,
                    actionTitle: viewModel.microphoneStatus == .notDetermined ? "Allow" : "Open Settings",
                    action: viewModel.requestMicrophonePermission
                )
                Divider()
                PermissionRow(
                    symbol: "accessibility",
                    title: "Accessibility",
                    detail: viewModel.accessibilityTrusted
                        ? "Allowed"
                        : "To notice the dictation key in other apps and paste your text there. Turn on NeelSpeak in the list that opens.",
                    granted: viewModel.accessibilityTrusted,
                    actionTitle: "Open Settings",
                    action: viewModel.requestAccessibilityPermission
                )
            }
            .padding(20)
            .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if !viewModel.permissionsGranted {
                FootnoteText("This page updates by itself once you've allowed both.", alignment: .center)
            }
        }
    }
}

private struct ModelStep: View {
    @ObservedObject var viewModel: VoiceTyperViewModel

    var body: some View {
        VStack(spacing: 24) {
            StepHeader(
                title: "Download the speech model",
                subtitle: "NVIDIA Parakeet runs entirely on your Mac. It's a one-time download of about 460 MB."
            )

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "cpu")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.selectedModel.displayName)
                            .font(.system(size: 14, weight: .semibold))
                        Text("On-device · 25 European languages · Apple Neural Engine")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if viewModel.modelReady {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.green)
                            .accessibilityLabel("Model ready")
                    }
                }

                if let progress = viewModel.modelProgress {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: progress)
                        Text("Downloading… \(Int(progress * 100))%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                } else if case .warming = viewModel.state {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Loading the model…")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                } else if case .error(let message) = viewModel.state {
                    IssueLabel(message: message)
                }

                if let message = viewModel.setupMessage {
                    IssueLabel(message: message)
                }

                if !viewModel.modelReady, viewModel.modelProgress == nil {
                    Button {
                        viewModel.prepareSelectedModel()
                    } label: {
                        Label(primaryTitle, systemImage: "arrow.down.circle.fill")
                    }
                    .controlSize(.large)
                    .disabled(isWarming)
                }
            }
            .padding(20)
            .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var isWarming: Bool {
        if case .warming = viewModel.state { return true }
        return false
    }

    private var primaryTitle: String {
        if case .error = viewModel.state { return "Try Again" }
        return viewModel.selectedModel.isInstalled ? "Load Model" : "Download"
    }
}

private struct TryItStep: View {
    @ObservedObject var viewModel: VoiceTyperViewModel
    @Binding var launchAtLogin: Bool
    @State private var practiceText = ""
    @State private var latestAtStart: UUID??
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            StepHeader(
                title: "Give it a try",
                subtitle: "Click in the box, hold the key, say a sentence, then let go."
            )

            VStack(alignment: .leading, spacing: 16) {
                Picker("Dictation key", selection: $viewModel.hotkeyTrigger) {
                    ForEach(HotkeyTrigger.allCases) { trigger in
                        Text(trigger.displayName).tag(trigger)
                    }
                }

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $practiceText)
                        .font(.system(size: 14))
                        .focused($fieldFocused)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .frame(height: 96)
                        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.25)))
                        .accessibilityLabel("Practice text")
                    if practiceText.isEmpty {
                        HStack(spacing: 6) {
                            Text("Hold")
                            KeyCap(label: viewModel.hotkeyTrigger.keyCapLabel)
                            Text("and speak…")
                        }
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                    }
                }

                if didDictate {
                    Label("That's it. NeelSpeak will paste wherever your cursor is.", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.green)
                } else {
                    FootnoteText("Pressing any other key while holding cancels, so Option shortcuts keep working.")
                }

                Divider()
                Toggle("Open NeelSpeak when you log in", isOn: $launchAtLogin)
            }
            .padding(20)
            .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            FootnoteText("NeelSpeak lives in the menu bar. Turn on AI cleanup and other options from its menu.", alignment: .center)
        }
        .onAppear {
            latestAtStart = .some(viewModel.history.first?.id)
            fieldFocused = true
        }
    }

    private var didDictate: Bool {
        guard let start = latestAtStart else { return false }
        return viewModel.history.first?.id != start
    }
}
