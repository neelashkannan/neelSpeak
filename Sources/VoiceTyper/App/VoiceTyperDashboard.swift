import AVFoundation
import SwiftUI

struct VoiceTyperDashboard: View {
    @ObservedObject var viewModel: VoiceTyperViewModel

    var body: some View {
        Group {
            if viewModel.needsSetup {
                SetupFlowView(viewModel: viewModel)
            } else {
                ControlCenterView(viewModel: viewModel)
            }
        }
        .frame(minWidth: 720, minHeight: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { viewModel.refreshPermissions() }
    }
}

private struct SetupFlowView: View {
    @ObservedObject var viewModel: VoiceTyperViewModel

    var body: some View {
        HStack(spacing: 0) {
            SetupSidebar(viewModel: viewModel)
                .frame(width: 250)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SetupHeader()
                    PermissionSetupSection(viewModel: viewModel)
                    ModelSetupSection(viewModel: viewModel)
                    FinishSetupSection(viewModel: viewModel)
                }
                .padding(32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct SetupSidebar: View {
    @ObservedObject var viewModel: VoiceTyperViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 12) {
                AppIconMark()
                    .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text("NeelSpeak")
                        .font(.system(size: 20, weight: .bold))
                    Text("Voice typing")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                SetupStepRow(
                    number: "1",
                    title: "Permissions",
                    complete: viewModel.microphoneStatus == .authorized && viewModel.accessibilityTrusted
                )
                SetupStepRow(number: "2", title: "Speech model", complete: viewModel.modelReady)
                SetupStepRow(number: "3", title: "Run in background", complete: viewModel.setupComplete)
            }

            Spacer()

            Text("Shortcut: Option")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(22)
        .background(Color.secondary.opacity(0.06))
    }
}

private struct SetupHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Set up NeelSpeak")
                .font(.system(size: 34, weight: .bold))
            Text("Grant permissions, download a speech model, then NeelSpeak will stay in the menu bar until you need it.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PermissionSetupSection: View {
    @ObservedObject var viewModel: VoiceTyperViewModel

    var body: some View {
        SetupSection(title: "Permissions", subtitle: "NeelSpeak needs the microphone to listen and Accessibility to receive the global shortcut and paste text.") {
            VStack(spacing: 10) {
                SetupActionRow(
                    icon: "mic.fill",
                    title: "Microphone",
                    value: viewModel.microphoneLabel,
                    complete: viewModel.microphoneStatus == .authorized,
                    buttonTitle: viewModel.microphoneStatus == .authorized ? "Allowed" : "Allow",
                    action: viewModel.requestMicrophonePermission
                )

                SetupActionRow(
                    icon: "command",
                    title: "Accessibility",
                    value: viewModel.accessibilityLabel,
                    complete: viewModel.accessibilityTrusted,
                    buttonTitle: viewModel.accessibilityTrusted ? "Allowed" : "Open Settings",
                    action: viewModel.openAccessibilitySettings
                )

                Button {
                    viewModel.refreshPermissions()
                } label: {
                    Label("Refresh permission status", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

private struct ModelSetupSection: View {
    @ObservedObject var viewModel: VoiceTyperViewModel

    var body: some View {
        SetupSection(title: "Speech model", subtitle: "Pick what NeelSpeak should use. Installed models are used in place; other models download only when you press the button.") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(SpeechModelCatalog.all) { model in
                    ModelChoiceRow(
                        model: model,
                        selected: viewModel.selectedModelID == model.id,
                        action: { viewModel.selectedModelID = model.id }
                    )
                }

                if let message = viewModel.setupMessage {
                    Label(message, systemImage: "info.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let progress = viewModel.modelProgress {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                        Text("Downloading \(Int(progress * 100))%")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        viewModel.prepareSelectedModel()
                    } label: {
                        Label(modelActionTitle, systemImage: modelActionIcon)
                            .frame(minWidth: 190)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(viewModel.modelReady)
                }
            }
        }
    }

    private var modelActionTitle: String {
        if viewModel.modelReady { return "Model ready" }
        if viewModel.selectedModel.runtime == .fluidAudioParakeet {
            return viewModel.selectedModel.isInstalled ? "Use Parakeet" : "Download Parakeet"
        }
        if viewModel.selectedModel.localFolderURL != nil { return "Use installed model" }
        return "Download selected model"
    }

    private var modelActionIcon: String {
        if viewModel.selectedModel.runtime == .fluidAudioParakeet && viewModel.selectedModel.isInstalled {
            return "bolt.circle.fill"
        }
        return viewModel.selectedModel.localFolderURL == nil ? "arrow.down.circle.fill" : "checkmark.circle.fill"
    }
}

private struct FinishSetupSection: View {
    @ObservedObject var viewModel: VoiceTyperViewModel

    var body: some View {
        SetupSection(title: "Ready to run", subtitle: "Once setup is complete, NeelSpeak hides to the background and keeps listening for the shortcut.") {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.state.title)
                        .font(.system(size: 16, weight: .bold))
                    Text(viewModel.state.detail)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button {
                    viewModel.finishSetupAndRunInBackground()
                } label: {
                    Label("Finish and run in background", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!(viewModel.microphoneStatus == .authorized && viewModel.accessibilityTrusted && viewModel.modelReady))
            }
        }
    }
}

private struct ControlCenterView: View {
    @ObservedObject var viewModel: VoiceTyperViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    HStack(spacing: 12) {
                        AppIconMark()
                            .frame(width: 42, height: 42)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("NeelSpeak")
                                .font(.system(size: 26, weight: .bold))
                            Text("Menu-bar voice typing. Hold Option anywhere to dictate.")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    StatusBadge(state: viewModel.state)
                }

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                        ShortcutCard(viewModel: viewModel)
                        CleanupCard(viewModel: viewModel)
                        TranscriptPanel(entries: viewModel.recentTranscripts)
                            .frame(minHeight: 118)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 16) {
                        RuntimeCard(viewModel: viewModel)
                        OverlayThemePicker(store: viewModel.themeStore)
                    }
                    .frame(width: 260)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

private struct OverlayThemePicker: View {
    @ObservedObject var store: OverlayThemeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Pill appearance", systemImage: "paintpalette.fill")
                .font(.system(size: 16, weight: .bold))

            HStack(spacing: 10) {
                OverlayThemePreview(theme: store.theme)
                    .frame(width: 74, height: 30)

                Picker("Pill color", selection: $store.selectedID) {
                    ForEach(OverlayThemeCatalog.all) { theme in
                        Text(theme.name).tag(theme.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }

            Text("Changes only the floating pill shown while you dictate.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .cardBackground()
    }
}

private struct OverlayThemePreview: View {
    let theme: OverlayTheme

    var body: some View {
        Capsule()
            .fill(theme.fill)
            .overlay(
                Capsule()
                    .strokeBorder(
                        AngularGradient(
                            colors: theme.borderColors + [theme.borderColors.first ?? .white],
                            center: .center
                        ),
                        lineWidth: 2
                    )
            )
    }
}

private struct ShortcutCard: View {
    @ObservedObject var viewModel: VoiceTyperViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Global shortcut", systemImage: "keyboard")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text("Hold Option anywhere")
                        .font(.system(size: 26, weight: .bold))

                    Text("NeelSpeak stays out of the way and types into the app you are already using.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(viewModel.state.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(viewModel.state.accentColor)
                    Text(viewModel.state.detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                }
                .frame(maxWidth: 190, alignment: .trailing)
            }

            HStack(spacing: 8) {
                ShortcutStep(title: "Hold", value: "Option", symbol: "option")
                ShortcutStep(title: "Speak", value: "Anywhere", symbol: "text.bubble")
                ShortcutStep(title: "Release", value: "Types text", symbol: "text.cursor")
            }
        }
        .padding(18)
        .cardBackground()
    }
}

private struct ShortcutStep: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 18)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                Text(value)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct RuntimeCard: View {
    @ObservedObject var viewModel: VoiceTyperViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("System status")
                .font(.system(size: 20, weight: .bold))

            CompactInfoRow(title: "Accessibility", value: viewModel.accessibilityLabel, icon: "command", good: viewModel.accessibilityTrusted)
            CompactInfoRow(title: "Model", value: viewModel.selectedModel.displayName, icon: "cpu", good: viewModel.modelReady)

            Button {
                viewModel.finishSetupAndRunInBackground()
            } label: {
                Label("Run in Background", systemImage: "menubar.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
        }
        .padding(18)
        .cardBackground()
    }
}

private struct CleanupCard: View {
    @ObservedObject var viewModel: VoiceTyperViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Speech cleanup", systemImage: "wand.and.stars")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Text(viewModel.cleanupStatusLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Text("After each dictation, a local AI model strips fillers (um, uh, like), stutters, repetitions, and course corrections.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text("Mode")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Picker("Mode", selection: $viewModel.cleanupMode) {
                    ForEach(CleanupMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                if viewModel.cleanupMode != .off {
                    Text(viewModel.cleanupMode.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Engine")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Picker("Engine", selection: $viewModel.cleanupEngine) {
                    ForEach(CleanupEngine.allCases) { engine in
                        Text(engine.displayName).tag(engine)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(viewModel.cleanupMode == .off)
                Text(viewModel.cleanupEngine.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if case .failed(let msg) = viewModel.cleanupState {
                Label(msg.prefix(160).description, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if case .unsupported(let msg) = viewModel.cleanupState {
                Label(msg, systemImage: "info.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            switch viewModel.cleanupEngine {
            case .openAICompatible:
                OpenAICompatConfigView(viewModel: viewModel)
            case .anthropic:
                AnthropicConfigView(viewModel: viewModel)
            case .githubCopilot:
                CopilotConfigView(viewModel: viewModel)
            case .foundationModels:
                HStack {
                    Button {
                        viewModel.loadCleanupModelNow()
                    } label: {
                        Label(viewModel.cleanupActionLabel, systemImage: "arrow.down.circle.fill")
                    }
                    .disabled(!viewModel.cleanupCanLoad)
                    Spacer()
                }
            }
        }
        .padding(18)
        .cardBackground()
    }
}

private struct OpenAICompatConfigView: View {
    @ObservedObject var viewModel: VoiceTyperViewModel
    @State private var showKey = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Preset")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .leading)
                Menu {
                    ForEach(OpenAICompatPreset.all) { preset in
                        Button(preset.displayName) {
                            viewModel.applyOpenAIPreset(preset)
                        }
                    }
                } label: {
                    HStack {
                        Text(currentPresetName)
                        Image(systemName: "chevron.down")
                    }
                    .font(.system(size: 12))
                }
                .menuStyle(.borderlessButton)
                Spacer()
            }

            labelledField("Base URL", text: $viewModel.cloudOpenAIBaseURL, placeholder: "https://api.openai.com/v1")
            labelledField("Model", text: $viewModel.cloudOpenAIModel, placeholder: "gpt-4o-mini")
            keyField("API Key", text: $viewModel.cloudOpenAIKey, hint: currentPresetHint)
        }
        .padding(.top, 4)
    }

    private var currentPresetName: String {
        OpenAICompatPreset.all.first(where: { $0.baseURL == viewModel.cloudOpenAIBaseURL })?.displayName ?? "Custom"
    }

    private var currentPresetHint: String {
        OpenAICompatPreset.all.first(where: { $0.baseURL == viewModel.cloudOpenAIBaseURL })?.apiKeyHint
            ?? "API key for your provider"
    }

    @ViewBuilder
    private func labelledField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
        }
    }

    @ViewBuilder
    private func keyField(_ label: String, text: Binding<String>, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .leading)
                if showKey {
                    TextField("paste key here", text: text)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                } else {
                    SecureField("paste key here", text: text)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                }
                Button {
                    showKey.toggle()
                } label: {
                    Image(systemName: showKey ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
            }
            if !hint.isEmpty {
                Text(hint)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 78)
            }
        }
    }
}

private struct CopilotConfigView: View {
    @ObservedObject var viewModel: VoiceTyperViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let code = viewModel.copilotDeviceCode {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Open the GitHub page below and enter this code:")
                        .font(.system(size: 12))
                    Text(code.userCode)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .textSelection(.enabled)
                    HStack(spacing: 8) {
                        Button {
                            if let url = URL(string: code.verificationURL) {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Label("Open github.com/login/device", systemImage: "arrow.up.right.square")
                        }
                        Button("Cancel") {
                            viewModel.signOutOfCopilot()
                        }
                    }
                    Text("Waiting for you to authorize in the browser…")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            } else if !viewModel.cloudCopilotOAuthToken.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Signed in to GitHub Copilot")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Button("Sign out") {
                        viewModel.signOutOfCopilot()
                    }
                    .controlSize(.small)
                }
            } else {
                Button {
                    viewModel.startCopilotSignIn()
                } label: {
                    Label("Sign in with GitHub Copilot", systemImage: "person.crop.circle.badge.checkmark")
                }
                .disabled(viewModel.copilotAuthInProgress)
            }

            if !viewModel.cloudCopilotOAuthToken.isEmpty {
                HStack(spacing: 8) {
                    Text("Model")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .leading)
                    if viewModel.copilotAvailableModels.isEmpty {
                        if viewModel.copilotModelsLoading {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading models…")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("No models loaded")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            viewModel.refreshCopilotModels()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .disabled(viewModel.copilotModelsLoading)
                    } else {
                        Picker("", selection: $viewModel.cloudCopilotModel) {
                            ForEach(viewModel.copilotAvailableModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .font(.system(size: 12))
                        Spacer()
                        Button {
                            viewModel.refreshCopilotModels()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .disabled(viewModel.copilotModelsLoading)
                    }
                }
                if !viewModel.copilotAvailableModels.isEmpty {
                    Text("\(viewModel.copilotAvailableModels.count) chat models available from your Copilot subscription")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 78)
                }
            }

            if let err = viewModel.copilotAuthError {
                Label(err.prefix(200).description, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.top, 4)
    }
}

private struct AnthropicConfigView: View {
    @ObservedObject var viewModel: VoiceTyperViewModel
    @State private var showKey = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Model")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .leading)
                TextField("claude-haiku-4-5", text: $viewModel.cloudAnthropicModel)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("API Key")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .leading)
                    if showKey {
                        TextField("paste key here", text: $viewModel.cloudAnthropicKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                    } else {
                        SecureField("paste key here", text: $viewModel.cloudAnthropicKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                    }
                    Button {
                        showKey.toggle()
                    } label: {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }
                Text("sk-ant-... from console.anthropic.com")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 78)
            }
        }
        .padding(.top, 4)
    }
}

private struct TranscriptPanel: View {
    let entries: [VoiceTyperViewModel.TranscriptEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Recent text", systemImage: "text.quote")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Text("\(entries.count) saved")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            if entries.isEmpty {
                Text("Your last dictations will appear here.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(entries) { entry in
                            TranscriptCard(entry: entry)
                        }
                    }
                }
            }
        }
        .padding(18)
        .cardBackground()
    }
}

private struct TranscriptCard: View {
    let entry: VoiceTyperViewModel.TranscriptEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.date.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(entry.text)
                .font(.system(size: 13))
                .lineLimit(3)
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(width: 220, height: 82, alignment: .topLeading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SetupSection<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content
        }
        .padding(18)
        .cardBackground()
    }
}

private struct SetupActionRow: View {
    let icon: String
    let title: String
    let value: String
    let complete: Bool
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(complete ? .green : .orange)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(value)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(buttonTitle, action: action)
                .disabled(complete)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ModelChoiceRow: View {
    let model: SpeechModelOption
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(selected ? .blue : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(model.displayName)
                            .font(.system(size: 14, weight: .bold))
                        Text(model.badge)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(model.isSupportedInCurrentBuild ? .green : .orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background((model.isSupportedInCurrentBuild ? Color.green : Color.orange).opacity(0.12), in: Capsule())
                    }
                    Text(modelSubtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(12)
        .background(selected ? Color.blue.opacity(0.10) : Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(selected ? Color.blue.opacity(0.45) : Color.clear, lineWidth: 1)
        )
    }

    private var modelSubtitle: String {
        if model.runtime == .fluidAudioParakeet {
            if model.isInstalled {
                return "Downloaded in NeelSpeak's model folder. Uses FluidAudio's local Parakeet runtime."
            }
            return "Downloads to NeelSpeak's model folder and runs locally with FluidAudio."
        }
        if let url = model.localFolderURL {
            return "Installed at \(url.lastPathComponent). NeelSpeak will load this local model."
        }
        return model.subtitle
    }
}

private struct SetupStepRow: View {
    let number: String
    let title: String
    let complete: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(complete ? Color.green : Color.secondary.opacity(0.18))
                Text(complete ? "" : number)
                    .font(.system(size: 12, weight: .bold))
                if complete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 24, height: 24)

            Text(title)
                .font(.system(size: 14, weight: .semibold))
        }
    }
}

private struct CompactInfoRow: View {
    let title: String
    let value: String
    let icon: String
    let good: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(good ? .green : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(value)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct StatusBadge: View {
    let state: DictationCoordinator.State

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: state.symbolName)
            Text(state.title)
                .lineLimit(1)
        }
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(state.accentColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(state.accentColor.opacity(0.12), in: Capsule())
    }
}

private struct AppIconMark: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.gradient)
            HStack(alignment: .bottom, spacing: 3) {
                ForEach([16, 28, 22, 34, 19], id: \.self) { height in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white)
                        .frame(width: 4, height: CGFloat(height))
                }
            }
            .padding(.bottom, 9)
        }
    }
}

private extension View {
    func cardBackground() -> some View {
        background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
            )
    }
}

private extension DictationCoordinator.State {
    var accentColor: Color {
        switch self {
        case .setupRequired:
            return .orange
        case .downloadingModel:
            return .blue
        case .warming:
            return .blue
        case .idle:
            return .green
        case .recording:
            return .red
        case .transcribing:
            return .indigo
        case .cleaning:
            return .purple
        case .error:
            return .orange
        }
    }
}
