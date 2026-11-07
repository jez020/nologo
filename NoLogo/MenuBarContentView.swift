import SwiftUI
import AppKit

struct MenuBarContentView: View {
    let model: LogoLightModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            ContentView(model: model, isMenuBar: true)
            Divider()
            HStack {
                Button {
                    openWindow(id: "main")
                    NSApplication.shared.activate()
                } label: {
                    Text("Open App").frame(maxWidth: .infinity, minHeight: 44)
                }
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Text("Quit").frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.extraLarge)
            .padding()
        }
        .frame(width: 340)
    }
}
