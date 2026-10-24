import AVFoundation
import SwiftUI

struct VoiceTyperDashboard: View {
    @ObservedObject var viewModel: VoiceTyperViewModel
    @ObservedObject var navigation: DashboardNavigation

    var body: some View {
        Group {
            if viewModel.setupComplete {
                MainView(viewModel: viewModel, navigation: navigation)
            } else {
                SetupFlowView(viewModel: viewModel)
            }
        }
        .frame(minWidth: 760, minHeight: 540)
        .onAppear { viewModel.refreshPermissions() }
    }
}

private struct MainView: View {
    @ObservedObject var viewModel: VoiceTyperViewModel
    @ObservedObject var navigation: DashboardNavigation

    var body: some View {
        NavigationSplitView {
            List(DashboardSection.allCases, selection: $navigation.section) { section in
                Label(section.title, systemImage: section.symbol)
                    .badge(badge(for: section))
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
            .safeAreaInset(edge: .bottom) {
                SidebarStatus(viewModel: viewModel)
                    .padding(12)
            }
        } detail: {
            Group {
                switch navigation.section ?? .general {
                case .general: GeneralPane(viewModel: viewModel)
                case .cleanup: CleanupPane(viewModel: viewModel)
                case .appearance: AppearancePane(store: viewModel.themeStore)
                case .history: HistoryPane(viewModel: viewModel)
                case .about: AboutPane(viewModel: viewModel)
                }
            }
            .navigationTitle((navigation.section ?? .general).title)
        }
    }

    private func badge(for section: DashboardSection) -> Text? {
        switch section {
        case .general:
            return viewModel.permissionsGranted ? nil : Text("!")
        case .cleanup:
            return viewModel.cleanupProblem == nil ? nil : Text("!")
        default:
            return nil
        }
    }
}

private struct SidebarStatus: View {
    @ObservedObject var viewModel: VoiceTyperViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            StateBadge(state: viewModel.state)
            if case .idle = viewModel.state {
                HStack(spacing: 5) {
                    Text("Hold")
                    KeyCap(label: viewModel.hotkeyTrigger.keyCapLabel)
                    Text("to talk")
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - General

private struct GeneralPane: View {
    @ObservedObject var viewModel: VoiceTyperViewModel

    var body: some View {
        Form {
            Section {
                StatusHero(viewModel: viewModel)
            }

            Section {
                Picker("Dictation key", selection: $viewModel.hotkeyTrigger) {
                    ForEach(HotkeyTrigger.allCases) { trigger in
                        Text(trigger.displayName).tag(trigger)
                    }
                }
                Toggle("Play a sound when dictation starts and stops", isOn: $viewModel.soundsEnabled)
            } header: {
                Text("Dictation")
            } footer: {
                FootnoteText("Hold the key, speak, then let go to paste. Press Escape or any other key while holding to cancel.")
            }

            Section("Startup") {
                Toggle("Open NeelSpeak at login", isOn: Binding(
                    get: { viewModel.launchAtLoginEnabled || viewModel.launchAtLoginNeedsApproval },
                    set: { viewModel.setLaunchAtLogin($0) }
                ))
                if viewModel.launchAtLoginNeedsApproval {
                    HStack {
                        FootnoteText("macOS needs you to approve NeelSpeak in Login Items.")
                        Spacer()
                        Button("Open Login Items") { viewModel.openLoginItemsSettings() }
                    }
                }
                if let error = viewModel.launchAtLoginError {
                    IssueLabel(message: error)
                }
            }

            Section {
                PermissionRow(
                    symbol: "mic.fill",
                    title: "Microphone",
                    detail: viewModel.microphoneLabel,
                    granted: viewModel.microphoneStatus == .authorized,
                    actionTitle: viewModel.microphoneStatus == .notDetermined ? "Allow" : "Open Settings",
                    action: viewModel.requestMicrophonePermission
                )
                PermissionRow(
                    symbol: "accessibility",
                    title: "Accessibility",
                    detail: viewModel.accessibilityLabel,
                    granted: viewModel.accessibilityTrusted,
                    actionTitle: "Open Settings",
                    action: viewModel.requestAccessibilityPermission
                )
            } header: {
                Text("Permissions")
            }

            Section {
                Toggle("Check for updates automatically", isOn: $viewModel.checkForUpdatesAutomatically)
                HStack {
                    updateStatusText
                    Spacer()
                    if viewModel.availableUpdate != nil {
                        Button("Download") { viewModel.openUpdatePage() }
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button("Check Now") { viewModel.checkForUpdates(userInitiated: true) }
                            .disabled(viewModel.updateStatus == .checking)
                    }
                }
            } header: {
                Text("Updates")
            } footer: {
                FootnoteText("Checks the NeelSpeak releases page on GitHub. No personal data is sent.")
            }

            Section("Privacy") {
                LabeledContent("Speech recognition") {
                    Text("On this Mac")
                }
                LabeledContent("AI cleanup") {
                    Text(cleanupPrivacy)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Speech model") {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([SpeechModelCatalog.parakeetModelURL()])
                    }
                    .disabled(!viewModel.selectedModel.isInstalled)
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var updateStatusText: some View {
        switch viewModel.updateStatus {
        case .idle:
            Text("NeelSpeak \(UpdateChecker.currentVersion)")
        case .checking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Checking…")
            }
        case .upToDate:
            Label("NeelSpeak \(UpdateChecker.currentVersion) is up to date", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .available(let release):
            Label("NeelSpeak \(release.version) is available", systemImage: "arrow.down.circle.fill")
                .foregroundStyle(Color.accentColor)
        case .failed:
            Label("Couldn't reach GitHub", systemImage: "wifi.exclamationmark")
                .foregroundStyle(.secondary)
        }
    }

    private var cleanupPrivacy: String {
        if viewModel.cleanupMode == .off { return "Off" }
        return viewModel.cleanupEngine.isCloud
            ? "Text is sent to \(viewModel.cleanupEngine.displayName)"
            : "On this Mac"
    }
}

private struct StatusHero: View {
    @ObservedObject var viewModel: VoiceTyperViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(viewModel.state.accentColor.opacity(0.14))
                Image(systemName: viewModel.state.symbolName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(viewModel.state.accentColor)
                    .symbolEffect(.pulse, options: .repeating, isActive: viewModel.isRecording)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.state.title)
                    .font(.system(size: 17, weight: .semibold))
                Text(viewModel.state.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let progress = viewModel.modelProgress {
                    ProgressView(value: progress)
                        .frame(maxWidth: 260)
                }
            }

            Spacer(minLength: 12)

            switch viewModel.state {
            case .idle, .recording, .transcribing, .cleaning:
                KeyCap(label: viewModel.hotkeyTrigger.keyCapLabel, large: true)
            case .setupRequired, .error:
                Button("Retry") { viewModel.retrySetup() }
            case .downloadingModel, .warming:
                EmptyView()
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Cleanup

private struct CleanupPane: View {
    @ObservedObject var viewModel: VoiceTyperViewModel
    @State private var sample = "um so I I think we should uh meet at at three, no wait, four tomorrow"

    var body: some View {
        Form {
            Section {
                Picker("Cleanup", selection: $viewModel.cleanupMode) {
                    ForEach(CleanupMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            } footer: {
                FootnoteText(viewModel.cleanupMode.subtitle)
            }

            Section {
                ForEach(CleanupEngine.allCases) { engine in
                    EngineRow(engine: engine, selected: viewModel.cleanupEngine == engine) {
                        viewModel.cleanupEngine = engine
                    }
                }
            } header: {
                Text("Engine")
            } footer: {
                if viewModel.cleanupMode == .off {
                    FootnoteText("Choose Conservative or Aggressive above to turn cleanup on.")
                }
            }
            .disabled(viewModel.cleanupMode == .off)

            if viewModel.cleanupMode != .off {
                Section {
                    switch viewModel.cleanupEngine {
                    case .foundationModels:
                        LabeledContent("Apple Intelligence") {
                            Button("Check Availability") { viewModel.loadCleanupModelNow() }
                                .disabled(!viewModel.cleanupCanLoad)
                        }
                    case .githubCopilot:
                        CopilotConfigView(viewModel: viewModel)
                    case .openAICompatible:
                        OpenAICompatConfigView(viewModel: viewModel)
                    case .anthropic:
                        AnthropicConfigView(viewModel: viewModel)
                    }
                    LabeledContent("Status") {
                        HStack(spacing: 6) {
                            if case .loading = viewModel.cleanupState {
                                ProgressView().controlSize(.small)
                            }
                            Text(viewModel.cleanupStatusLabel)
                                .foregroundStyle(viewModel.cleanupProblem == nil ? Color.secondary : Color.orange)
                        }
                    }
                    if let problem = viewModel.cleanupProblem {
                        IssueLabel(message: problem)
                    }
                } header: {
                    Text(viewModel.cleanupEngine.displayName)
                } footer: {
                    if viewModel.cleanupEngine.isCloud {
                        FootnoteText("Keys are stored in your login keychain. If cleanup fails, NeelSpeak pastes your words as transcribed.")
                    }
                }

                Section {
                    TextField("Sample", text: $sample, axis: .vertical)
                        .lineLimit(2...4)
                    HStack(alignment: .top) {
                        if viewModel.cleanupTestRunning {
                            ProgressView().controlSize(.small)
                        } else if let result = viewModel.cleanupTestResult {
                            if let issue = result.issue {
                                IssueLabel(message: issue)
                            } else {
                                Text(result.text)
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        } else {
                            FootnoteText("Runs your current settings on the sample.")
                        }
                        Spacer()
                        Button("Clean Up") { viewModel.testCleanup(sample) }
                            .disabled(viewModel.cleanupTestRunning || sample.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Try it")
                }
            }

            if let error = viewModel.credentialStoreError {
                Section {
                    IssueLabel(message: "Couldn't save to the keychain: \(error)")
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct EngineRow: View {
    let engine: CleanupEngine
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(engine.displayName)
                            .font(.system(size: 13, weight: .semibold))
                        Text(engine.isCloud ? "Cloud" : "On device")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(engine.isCloud ? Color.secondary : Color.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background((engine.isCloud ? Color.secondary : Color.green).opacity(0.12), in: Capsule())
                    }
                    Text(engine.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

/// API key field with a reveal toggle.
private struct SecretField: View {
    let title: String
    @Binding var text: String
    let prompt: String
    @State private var revealed = false

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 6) {
                Group {
                    if revealed {
                        TextField(title, text: $text, prompt: Text(prompt))
                    } else {
                        SecureField(title, text: $text, prompt: Text(prompt))
                    }
                }
                .labelsHidden()
                .font(.system(size: 12, design: .monospaced))
                Button {
                    revealed.toggle()
                } label: {
                    Image(systemName: revealed ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(revealed ? "Hide key" : "Show key")
            }
        }
    }
}

private struct OpenAICompatConfigView: View {
    @ObservedObject var viewModel: VoiceTyperViewModel

    var body: some View {
        Picker("Provider", selection: Binding(
            get: { currentPreset.id },
            set: { id in
                if let preset = OpenAICompatPreset.all.first(where: { $0.id == id }) {
                    viewModel.applyOpenAIPreset(preset)
                }
            }
        )) {
            ForEach(OpenAICompatPreset.all) { preset in
                Text(preset.displayName).tag(preset.id)
            }
        }
        TextField("Base URL", text: $viewModel.cloudOpenAIBaseURL, prompt: Text("https://api.openai.com/v1"))
        TextField("Model", text: $viewModel.cloudOpenAIModel, prompt: Text(currentPreset.defaultModel.isEmpty ? "model-name" : currentPreset.defaultModel))
        SecretField(title: "API key", text: $viewModel.cloudOpenAIKey, prompt: "Paste key")
        if !currentPreset.apiKeyHint.isEmpty {
            FootnoteText(currentPreset.apiKeyHint)
        }
    }

    private var currentPreset: OpenAICompatPreset {
        OpenAICompatPreset.all.first { $0.id != "custom" && $0.baseURL == viewModel.cloudOpenAIBaseURL } ?? .custom
    }
}

private struct AnthropicConfigView: View {
    @ObservedObject var viewModel: VoiceTyperViewModel

    var body: some View {
        TextField("Model", text: $viewModel.cloudAnthropicModel, prompt: Text(LLMTranscriptCleaner.CloudConfig.defaultAnthropicModel))
        SecretField(title: "API key", text: $viewModel.cloudAnthropicKey, prompt: "sk-ant-…")
        FootnoteText("Create a key at console.anthropic.com.")
    }
}

private struct CopilotConfigView: View {
    @ObservedObject var viewModel: VoiceTyperViewModel

    var body: some View {
        if let code = viewModel.copilotDeviceCode {
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter this code on the GitHub page that opened:")
                    .font(.system(size: 12))
                HStack(spacing: 12) {
                    Text(code.userCode)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .textSelection(.enabled)
                    Button {
                        TextInjector.copyToClipboard(code.userCode)
                    } label: {
                        Label("Copy Code", systemImage: "doc.on.doc")
                    }
                }
                HStack(spacing: 8) {
                    Button("Open GitHub") {
                        if let url = URL(string: code.verificationURL) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    Button("Cancel") { viewModel.cancelCopilotSignIn() }
                    ProgressView().controlSize(.small)
                    Text("Waiting for you to authorise…")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        } else if !viewModel.cloudCopilotOAuthToken.isEmpty {
            LabeledContent("Account") {
                HStack(spacing: 8) {
                    Label("Signed in", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Button("Sign Out") { viewModel.signOutOfCopilot() }
                }
            }
            LabeledContent("Model") {
                HStack(spacing: 6) {
                    if viewModel.copilotAvailableModels.isEmpty {
                        Text(viewModel.copilotModelsLoading ? "Loading models…" : viewModel.cloudCopilotModel)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Model", selection: $viewModel.cloudCopilotModel) {
                            ForEach(viewModel.copilotAvailableModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                    Button {
                        viewModel.refreshCopilotModels()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .disabled(viewModel.copilotModelsLoading)
                    .accessibilityLabel("Refresh models")
                }
            }
        } else {
            LabeledContent("Account") {
                Button {
                    viewModel.startCopilotSignIn()
                } label: {
                    Label("Sign in with GitHub", systemImage: "person.crop.circle.badge.checkmark")
                }
                .disabled(viewModel.copilotAuthInProgress)
            }
            FootnoteText("Needs an active GitHub Copilot subscription.")
        }

        if let err = viewModel.copilotAuthError {
            IssueLabel(message: String(err.prefix(200)))
        }
    }
}

// MARK: - Appearance

private struct AppearancePane: View {
    @ObservedObject var store: OverlayThemeStore

    private let columns = [GridItem(.adaptive(minimum: 132), spacing: 12)]

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    PillSwatch(theme: store.theme, width: 220, height: 44)
                        .animation(.easeInOut(duration: 0.2), value: store.selectedID)
                    Spacer()
                }
                .padding(.vertical, 12)
            } header: {
                Text("Dictation pill")
            } footer: {
                FootnoteText("The pill appears at the top of the screen you're working on while you dictate.")
            }

            Section("Colours") {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(OverlayThemeCatalog.all) { theme in
                        Button {
                            store.selectedID = theme.id
                        } label: {
                            VStack(spacing: 8) {
                                PillSwatch(theme: theme, width: 84, height: 30)
                                Text(theme.name)
                                    .font(.system(size: 11, weight: store.selectedID == theme.id ? .semibold : .regular))
                                    .lineLimit(1)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(store.selectedID == theme.id ? Color.accentColor.opacity(0.12) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(store.selectedID == theme.id ? Color.accentColor : Color.secondary.opacity(0.15))
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(theme.name)
                        .accessibilityAddTraits(store.selectedID == theme.id ? [.isSelected] : [])
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - History

private struct HistoryPane: View {
    @ObservedObject var viewModel: VoiceTyperViewModel
    @State private var query = ""
    @State private var confirmClear = false

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.history.isEmpty {
                ContentUnavailableView {
                    Label("No dictations yet", systemImage: "waveform")
                } description: {
                    Text("Hold \(viewModel.hotkeyTrigger.keyCapLabel) in any app and speak. Your dictations show up here.")
                }
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List {
                    ForEach(groupedByDay, id: \.day) { group in
                        Section(group.day) {
                            ForEach(group.entries) { entry in
                                HistoryRow(entry: entry, viewModel: viewModel)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }

            Divider()
            HStack {
                Toggle("Keep history on this Mac", isOn: $viewModel.keepHistory)
                    .toggleStyle(.checkbox)
                Spacer()
                Text(viewModel.history.isEmpty ? "" : "\(viewModel.history.count) dictations")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Button("Clear History…", role: .destructive) { confirmClear = true }
                    .disabled(viewModel.history.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .searchable(text: $query, placement: .toolbar, prompt: "Search dictations")
        .confirmationDialog("Clear all dictation history?", isPresented: $confirmClear) {
            Button("Clear History", role: .destructive) { viewModel.clearHistory() }
        } message: {
            Text("This removes every saved dictation from this Mac.")
        }
    }

    private var filtered: [TranscriptEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return viewModel.history }
        return viewModel.history.filter { $0.text.localizedCaseInsensitiveContains(trimmed) }
    }

    private var groupedByDay: [(day: String, entries: [TranscriptEntry])] {
        var groups: [(day: String, entries: [TranscriptEntry])] = []
        for entry in filtered {
            let day = Self.dayLabel(for: entry.date)
            if groups.last?.day == day {
                groups[groups.count - 1].entries.append(entry)
            } else {
                groups.append((day, [entry]))
            }
        }
        return groups
    }

    private static func dayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct HistoryRow: View {
    let entry: TranscriptEntry
    @ObservedObject var viewModel: VoiceTyperViewModel
    @State private var hovering = false
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.text)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Text(entry.date.formatted(date: .omitted, time: .shortened))
                    Text("·")
                    Text(Duration.seconds(entry.duration).formatted(.units(allowed: [.minutes, .seconds], width: .narrow)))
                    if entry.rawText != nil {
                        Text("·")
                        Label("Cleaned", systemImage: "wand.and.stars")
                            .labelStyle(.titleAndIcon)
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button {
                viewModel.copy(entry)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .opacity(hovering || copied ? 1 : 0)
            .accessibilityLabel("Copy dictation")
        }
        .padding(.vertical, 4)
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Copy") { viewModel.copy(entry) }
            if let raw = entry.rawText {
                Button("Copy Original Transcript") { TextInjector.copyToClipboard(raw) }
            }
            Divider()
            Button("Delete", role: .destructive) { viewModel.delete(entry) }
        }
    }
}

// MARK: - About

private struct AboutPane: View {
    @ObservedObject var viewModel: VoiceTyperViewModel

    private static let repository = URL(string: "https://github.com/neelashkannan/neelSpeak")!

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            AppIconMark()
                .frame(width: 112, height: 112)
            VStack(spacing: 4) {
                Text("NeelSpeak")
                    .font(.system(size: 26, weight: .bold))
                Text("Version \(viewModel.appVersion)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Text("Hold a key, speak, and your words appear wherever you're typing.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                Link("GitHub", destination: Self.repository)
                Text("·").foregroundStyle(.tertiary)
                Link("Release Notes", destination: UpdateChecker.releasesPage)
                Text("·").foregroundStyle(.tertiary)
                Link("Report an Issue", destination: Self.repository.appendingPathComponent("issues"))
            }
            .font(.system(size: 12))
            Spacer()
            Text("Speech recognition by NVIDIA Parakeet TDT v3 via FluidAudio. Free and open source under the MIT License.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 20)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
