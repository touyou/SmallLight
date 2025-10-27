import Combine
import Foundation
import SmallLightDomain
import SmallLightServices
import SmallLightUI

@MainActor
public final class AppCoordinator: ObservableObject {
    private let viewModel: AppViewModel
    private let hotKeyManager: HotKeyManaging
    private let chord: HotKeyChord
    private var timer: Timer?
    @Published private(set) var isArmed: Bool = false
    private let cursorController: CursorVisualControlling
    private var cancellables: Set<AnyCancellable> = []
    private let notificationController: NotificationController
    private var lastConfirmationPath: String?
    private var lastCompletionPath: String?
    private let undoManager: UndoStagingManaging
    private let preferences: PreferencesStoring
    private var currentChord: HotKeyChord
    private var bindingsConfigured = false

    init(
        viewModel: AppViewModel,
        hotKeyManager: HotKeyManaging,
        chord: HotKeyChord,
        cursorController: CursorVisualControlling = CursorVisualController(),
        notificationController: NotificationController = NotificationController(),
        undoManager: UndoStagingManaging,
        preferences: PreferencesStoring
    ) {
        self.viewModel = viewModel
        self.hotKeyManager = hotKeyManager
        self.chord = chord
        self.cursorController = cursorController
        self.notificationController = notificationController
        self.undoManager = undoManager
        self.preferences = preferences
        self.currentChord = chord
        self.notificationController.delegate = self
    }

    public func start() {
        guard !isArmed else { return }
        configureBindingsIfNeeded()
        isArmed = true
        currentChord = preferences.preferredHotKey
        do {
            try hotKeyManager.register(chord: currentChord)
        } catch {
            NSLog("[SmallLight] Failed to register hot key: \(error.localizedDescription)")
        }
        cursorController.update(listening: viewModel.isListening)
        notificationController.start()
        startTimerIfNeeded()
        viewModel.setMonitoringActive(true)
    }

    public func stop() {
        guard isArmed else { return }
        isArmed = false
        timer?.invalidate()
        timer = nil
        hotKeyManager.unregister()
        cursorController.reset()
        lastConfirmationPath = nil
        lastCompletionPath = nil
        viewModel.setMonitoringActive(false)
    }

    private func startTimerIfNeeded() {
        guard timer == nil else { return }
        let newTimer = Timer(timeInterval: 0.25, repeats: true) { [weak viewModel] _ in
            guard let viewModel else { return }
            Task { @MainActor in
                viewModel.refreshState()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func bindViewModel() {
        viewModel.$isListening
            .removeDuplicates()
            .sink { [weak self] listening in
                guard let self else { return }
                self.cursorController.update(listening: listening)
            }
            .store(in: &cancellables)

        viewModel.$pendingDecision
            .sink { [weak self] decision in
                guard let self else { return }
                guard let decision = decision, decision.requiresConfirmation else {
                    self.lastConfirmationPath = nil
                    return
                }
                let path = decision.item.url.path
                if self.lastConfirmationPath != path {
                    self.notificationController.presentConfirmation(for: decision)
                    self.lastConfirmationPath = path
                }
            }
            .store(in: &cancellables)

        viewModel.$lastAction
            .compactMap { $0 }
            .sink { [weak self] completed in
                guard let self else { return }
                let path = completed.item.url.path
                if self.lastCompletionPath != path {
                    self.notificationController.presentCompletion(for: completed.action, item: completed.item, destination: completed.destination)
                    self.lastCompletionPath = path
                }
            }
            .store(in: &cancellables)
    }

    private func bindPreferences() {
        let cancellable = preferences.observeChanges { [weak self] in
            self?.applyPreferences()
        }
        cancellables.insert(cancellable)
        applyPreferences()
    }

    public func toggleArmed() {
        if isArmed {
            stop()
        } else {
            start()
        }
    }

    private func configureBindingsIfNeeded() {
        guard !bindingsConfigured else { return }
        bindViewModel()
        bindPreferences()
        bindingsConfigured = true
    }

    private func applyPreferences() {
        let retention = preferences.undoRetentionInterval
        undoManager.updateRetentionInterval(retention)

        let newChord = preferences.preferredHotKey
        guard newChord != currentChord else { return }
        currentChord = newChord
        guard isArmed else { return }
        hotKeyManager.unregister()
        do {
            try hotKeyManager.register(chord: newChord)
        } catch {
            NSLog("[SmallLight] Failed to update hotkey preference: \(error.localizedDescription)")
        }
    }
}

public extension AppCoordinator {
    static func preview(viewModel: AppViewModel) -> AppCoordinator {
        let hotKeyManager = PreviewHotKeyManager()
        let preferences = PreferencesStore.shared
        let undoManager = FileUndoStagingManager()
        return AppCoordinator(
            viewModel: viewModel,
            hotKeyManager: hotKeyManager,
            chord: .defaultActionChord,
            undoManager: undoManager,
            preferences: preferences
        )
    }
}

extension AppCoordinator: NotificationControllerDelegate {
    func handleConfirmationRequest(forPath path: String) {
        guard let decision = viewModel.pendingDecision, decision.item.url.path == path else { return }
        viewModel.confirmPendingAction()
        viewModel.performPendingAction()
    }

    func handleUndoRequest(forPath path: String) {
        guard let lastAction = viewModel.lastAction, lastAction.item.url.path == path else { return }
        viewModel.undoLastAction()
    }
}

private final class PreviewHotKeyManager: HotKeyManaging {
    func register(chord: HotKeyChord) throws {}
    func unregister() {}
}
