import SwiftUI

/// SwiftUI HUD displaying the most recent FinderOverlayDebugger events.
public struct HUDView: View {
    @ObservedObject private var viewModel: HUDViewModel
    private let copyHandler: (HUDEntry) -> Void

    public init(viewModel: HUDViewModel, copyHandler: @escaping (HUDEntry) -> Void) {
        self.viewModel = viewModel
        self.copyHandler = copyHandler
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text(UILocalized.string("hud.title"))
                    .font(.headline)
                Spacer()
                Toggle(isOn: $viewModel.autoCopyEnabled) {
                    Text(UILocalized.string("hud.autocopy"))
                        .font(.caption)
                }
                .toggleStyle(.switch)
                .frame(maxWidth: 160)
            }
            HStack(alignment: .center, spacing: 8) {
                AccessibilityIndicator(isGranted: viewModel.accessibilityGranted)
                Text(viewModel.accessibilityGranted ? UILocalized.string("hud.accessibility.granted") : UILocalized.string("hud.accessibility.denied"))
                    .font(.caption)
                    .foregroundColor(viewModel.accessibilityGranted ? .secondary : .orange)
            }

            if viewModel.history.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(UILocalized.string("hud.empty.title"))
                        .font(.subheadline)
                    Text(UILocalized.string("hud.empty.message"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text(UILocalized.string("hud.history.header"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.history) { entry in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(entry.path)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let message = entry.message {
                                    Text(message)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Button(UILocalized.string("hud.copy")) {
                                    copyHandler(entry)
                                }
                                .buttonStyle(.borderedProminent)
                                .keyboardShortcut(.init("c"), modifiers: [.command])
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 260)
            }
        }
        .padding(18)
        .frame(minWidth: 520, idealWidth: 560, maxWidth: 600)
        .background(.regularMaterial)
        .cornerRadius(16)
        .shadow(radius: 24, y: 12)
    }
}

private struct AccessibilityIndicator: View {
    let isGranted: Bool

    var body: some View {
        Image(systemName: isGranted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
            .foregroundColor(isGranted ? .green : .orange)
    }
}
