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
        .frame(minWidth: 760, minHeight: 560)
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

                    Button("Use Whisper Turbo") {
                        viewModel.chooseCurrentBuildFallbackModel()
                    }
                    .controlSize(.large)
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
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                HStack(spacing: 12) {
                    AppIconMark()
                        .frame(width: 46, height: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NeelSpeak")
                            .font(.system(size: 28, weight: .bold))
                        Text("Hold Option to dictate.")
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                StatusBadge(state: viewModel.state)
            }

            HStack(alignment: .top, spacing: 18) {
                DictationCard(viewModel: viewModel)
                    .frame(maxWidth: .infinity, minHeight: 330)
                RuntimeCard(viewModel: viewModel)
                    .frame(width: 260)
                    .frame(minHeight: 330)
            }

            OverlayThemePicker(store: viewModel.themeStore)

            TranscriptPanel(entries: viewModel.recentTranscripts)
                .frame(minHeight: 126)
        }
        .padding(28)
    }
}

private struct OverlayThemePicker: View {
    @ObservedObject var store: OverlayThemeStore

    private let columns = [GridItem(.adaptive(minimum: 132), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Pill appearance", systemImage: "paintpalette.fill")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Text(store.theme.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(OverlayThemeCatalog.all) { theme in
                    OverlayThemeSwatch(
                        theme: theme,
                        selected: store.selectedID == theme.id,
                        action: { store.selectedID = theme.id }
                    )
                }
            }
        }
        .padding(18)
        .cardBackground()
    }
}

private struct OverlayThemeSwatch: View {
    let theme: OverlayTheme
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    Capsule()
                        .fill(theme.fill)
                    Capsule()
                        .strokeBorder(
                            AngularGradient(
                                colors: theme.borderColors + [theme.borderColors.first ?? .white],
                                center: .center
                            ),
                            lineWidth: 2
                        )
                }
                .frame(height: 30)

                Text(theme.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 1.4)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct DictationCard: View {
    @ObservedObject var viewModel: VoiceTyperViewModel
    @State private var isHolding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Dictation", systemImage: "keyboard")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(viewModel.state.title)
                .font(.system(size: 30, weight: .bold))

            Text(viewModel.state.detail)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            HStack {
                Spacer()
                RecordButton(viewModel: viewModel, isHolding: $isHolding)
                Spacer()
            }

            Spacer()
        }
        .padding(22)
        .cardBackground()
    }
}

private struct RuntimeCard: View {
    @ObservedObject var viewModel: VoiceTyperViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Status")
                .font(.system(size: 20, weight: .bold))

            CompactInfoRow(title: "Microphone", value: viewModel.microphoneLabel, icon: "mic.fill", good: viewModel.microphoneStatus == .authorized)
            CompactInfoRow(title: "Accessibility", value: viewModel.accessibilityLabel, icon: "command", good: viewModel.accessibilityTrusted)
            CompactInfoRow(title: "Model", value: viewModel.selectedModel.displayName, icon: "cpu", good: viewModel.modelReady)

            Spacer()

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

private struct RecordButton: View {
    @ObservedObject var viewModel: VoiceTyperViewModel
    @Binding var isHolding: Bool

    private var disabled: Bool {
        !viewModel.canStartRecording && !viewModel.isRecording
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(viewModel.state.accentColor.opacity(0.12))
                .frame(width: 162, height: 162)

            Circle()
                .fill(viewModel.state.accentColor)
                .frame(width: 118, height: 118)
                .shadow(color: viewModel.state.accentColor.opacity(0.24), radius: 14, x: 0, y: 8)

            VStack(spacing: 8) {
                Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 34, weight: .bold))
                Text(viewModel.isRecording ? "Release" : "Hold")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(.white)
        }
        .opacity(disabled ? 0.45 : 1)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !disabled, !isHolding else { return }
                    isHolding = true
                    viewModel.beginDictation()
                }
                .onEnded { _ in
                    guard isHolding else { return }
                    isHolding = false
                    viewModel.endDictation()
                }
        )
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
        case .error:
            return .orange
        }
    }
}
