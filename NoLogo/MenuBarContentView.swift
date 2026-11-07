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
                Button("Open App") {
                    openWindow(id: "main")
                    NSApplication.shared.activate()
                }
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .buttonStyle(.borderless)
            .padding()
        }
        .frame(width: 280)
    }
}
