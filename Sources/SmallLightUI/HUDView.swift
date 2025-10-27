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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
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

            ForEach(viewModel.history) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.path)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(2)
                        .truncationMode(.middle)
                    if let message = entry.message {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Button(UILocalized.string("hud.copy")) {
                        copyHandler(entry)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.init("c"), modifiers: [.command])
                }
                .padding(8)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .cornerRadius(16)
        .shadow(radius: 24, y: 8)
        .frame(maxWidth: 480)
    }
}
