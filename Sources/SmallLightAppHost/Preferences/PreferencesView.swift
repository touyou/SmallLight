import AppKit
import Combine
import SmallLightDomain
import SwiftUI

@MainActor
final class PreferencesViewModel: ObservableObject {
    @Published var undoRetentionDays: Double
    @Published var launchAtLogin: Bool
    @Published var assetPath: String
    @Published var selectedHotKey: HotKeyPreset

    private let store: PreferencesStoring
    private var cancellables: Set<AnyCancellable> = []
    private var isUpdatingFromStore = false
    private let launchAgentManager: LaunchAgentManaging

    private static let day: TimeInterval = 60 * 60 * 24

    init(store: PreferencesStoring, launchAgentManager: LaunchAgentManaging) {
        self.store = store
        self.launchAgentManager = launchAgentManager
        undoRetentionDays = max(1, store.undoRetentionInterval / Self.day)
        launchAtLogin = store.launchAtLogin
        assetPath = store.assetPackPath ?? ""
        selectedHotKey = HotKeyPreset(from: store.preferredHotKey)

        store.observeChanges { [weak self] in
            self?.refreshFromStore()
        }
        .store(in: &cancellables)
    }

    func refreshFromStore() {
        isUpdatingFromStore = true
        undoRetentionDays = max(1, store.undoRetentionInterval / Self.day)
        launchAtLogin = store.launchAtLogin
        assetPath = store.assetPackPath ?? ""
        selectedHotKey = HotKeyPreset(from: store.preferredHotKey)
        isUpdatingFromStore = false
    }

    func onUndoRetentionChanged() {
        guard !isUpdatingFromStore else { return }
        store.undoRetentionInterval = undoRetentionDays * Self.day
    }

    func onLaunchAtLoginChanged() {
        guard !isUpdatingFromStore else { return }
        store.launchAtLogin = launchAtLogin
        do {
            try launchAgentManager.setEnabled(launchAtLogin)
        } catch {
            NSLog("[SmallLight] Failed to update launch-at-login preference: \(error.localizedDescription)")
        }
    }

    func onAssetPathChanged() {
        guard !isUpdatingFromStore else { return }
        store.assetPackPath = assetPath.isEmpty ? nil : assetPath
    }

    func onHotKeyChanged() {
        guard !isUpdatingFromStore else { return }
        store.preferredHotKey = selectedHotKey.chord
    }

    func chooseAssetDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            assetPath = url.path
            onAssetPathChanged()
        }
    }

    func revealLogs() {
        let logsURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("SmallLight/logs", isDirectory: true)
        guard let logsURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([logsURL])
    }
}

struct SettingsView: View {
    @StateObject private var viewModel: PreferencesViewModel

    init(viewModel: PreferencesViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Form {
            Section(LocalizedStringKey("preferences.undo.section")) {
                VStack(alignment: .leading) {
                    Slider(value: $viewModel.undoRetentionDays, in: 1 ... 30, step: 1) { Text(LocalizedStringKey("preferences.undo.slider")) }
                        .onChange(of: viewModel.undoRetentionDays) { _ in viewModel.onUndoRetentionChanged() }
                    Text(String(format: NSLocalizedString("preferences.undo.caption", bundle: .main, comment: ""), Int(viewModel.undoRetentionDays)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section(LocalizedStringKey("preferences.appearance.section")) {
                HStack {
                    TextField(LocalizedStringKey("preferences.assets.placeholder"), text: $viewModel.assetPath)
                        .onSubmit { viewModel.onAssetPathChanged() }
                    Button(LocalizedStringKey("preferences.assets.choose")) {
                        viewModel.chooseAssetDirectory()
                    }
                }
                Text(LocalizedStringKey("preferences.assets.hint"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(LocalizedStringKey("preferences.hotkey.section")) {
                Picker("Shortcut", selection: $viewModel.selectedHotKey) {
                    ForEach(HotKeyPreset.allCases) { preset in
                        Text(preset.localizedName).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: viewModel.selectedHotKey) { _ in viewModel.onHotKeyChanged() }
            }

            Section(LocalizedStringKey("preferences.general.section")) {
                Toggle(LocalizedStringKey("preferences.launch.label"), isOn: $viewModel.launchAtLogin)
                    .onChange(of: viewModel.launchAtLogin) { _ in viewModel.onLaunchAtLoginChanged() }
                Button(LocalizedStringKey("preferences.reveal.logs")) {
                    viewModel.revealLogs()
                }
            }
        }
        .padding()
        .frame(minWidth: 420, minHeight: 320)
        .navigationTitle(LocalizedStringKey("preferences.window.title"))
    }
}

enum HotKeyPreset: String, CaseIterable, Identifiable {
    case controlOptionL
    case optionShiftSpace
    case commandOptionSpace

    var id: String { rawValue }

    var chord: HotKeyChord {
        switch self {
        case .controlOptionL:
            return HotKeyChord(keyCode: 37, modifiers: [.control, .option])
        case .optionShiftSpace:
            return HotKeyChord(keyCode: 49, modifiers: [.option, .shift])
        case .commandOptionSpace:
            return HotKeyChord(keyCode: 49, modifiers: [.command, .option])
        }
    }

    var localizedName: String {
        switch self {
        case .controlOptionL:
            return NSLocalizedString("hotkey.controlOptionL", bundle: .main, comment: "")
        case .optionShiftSpace:
            return NSLocalizedString("hotkey.optionShiftSpace", bundle: .main, comment: "")
        case .commandOptionSpace:
            return NSLocalizedString("hotkey.commandOptionSpace", bundle: .main, comment: "")
        }
    }

    init(from chord: HotKeyChord) {
        for preset in HotKeyPreset.allCases where preset.chord == chord {
            self = preset
            return
        }
        self = .controlOptionL
    }
}
