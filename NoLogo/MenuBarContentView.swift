import SwiftUI
import AppKit

struct MenuBarContentView: View {
    let model: LogoLightModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            ContentView(model: model, isMenuBar: true)
            Divider()
            HStack(spacing: 12) {
                Button {
                    openWindow(id: "main")
                    NSApplication.shared.activate()
                } label: {
                    Text("Open App").frame(maxWidth: .infinity, minHeight: 28)
                }
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Text("Quit").frame(maxWidth: .infinity, minHeight: 28)
                }
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 340)
    }
}
