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
    private let timerQueue = DispatchQueue(label: "io.smalllight.action-loop", qos: .userInteractive)
    private var timer: DispatchSourceTimer?
    private var isRunning = false
    private let cursorController: CursorVisualControlling
    private var cancellables: Set<AnyCancellable> = []
    private let notificationController: NotificationController
    private var lastConfirmationPath: String?
    private var lastCompletionPath: String?
    private let undoManager: UndoStagingManaging
    private let preferences: PreferencesStoring
    private var currentChord: HotKeyChord

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
        guard !isRunning else { return }
        isRunning = true
        do {
            try hotKeyManager.register(chord: chord)
        } catch {
            NSLog("[SmallLight] Failed to register hot key: \(error.localizedDescription)")
        }
        bindViewModel()
        cursorController.update(listening: viewModel.isListening)
        notificationController.start()
        startTimerIfNeeded()
        bindPreferences()
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        timer?.cancel()
        timer = nil
        hotKeyManager.unregister()
        cancellables.removeAll()
        cursorController.reset()
        lastConfirmationPath = nil
        lastCompletionPath = nil
    }

    private func startTimerIfNeeded() {
        guard timer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(250))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.viewModel.refreshState()
            }
        }
        timer.resume()
        self.timer = timer
    }

    private func bindViewModel() {
        cancellables.removeAll()
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
        preferences.preferencesDidChange
            .sink { [weak self] in
                self?.applyPreferences()
            }
            .store(in: &cancellables)
        applyPreferences()
    }

    private func applyPreferences() {
        let retention = preferences.undoRetentionInterval
        undoManager.updateRetentionInterval(retention)

        let newChord = preferences.preferredHotKey
        guard newChord != currentChord else { return }
        hotKeyManager.unregister()
        do {
            try hotKeyManager.register(chord: newChord)
            currentChord = newChord
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
