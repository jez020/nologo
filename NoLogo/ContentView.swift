import SwiftUI
import AppKit

struct ContentView: View {
    var model: LogoLightModel = .shared
    var isMenuBar = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openSettings) private var openSettings
    @State private var errorMessage = ""
    @State private var showsError = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)
            Image(systemName: model.isEnabled == true ? "lightbulb.fill" : "lightbulb")
                .font(.largeTitle)
                .foregroundStyle(model.isEnabled == true ? Color.accentColor : Color.secondary)
                .accessibilityHidden(true)

            Text("NoLogo")
                .font(.title2.bold())

            Button {
                Task {
                    do { try await model.primaryAction() }
                    catch {
                        errorMessage = error.localizedDescription
                        showsError = true
                    }
                }
            } label: {
                Text(model.buttonTitle)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.isBusy || !model.supported)

            if model.isBusy {
                ProgressView().controlSize(.small)
            }

            Text(model.status)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)

            Button {
                // A menu bar popover can be opened while another app is active.
                // Activate this app before presenting its Settings scene.
                NSApplication.shared.activate()
                Task { @MainActor in
                    await Task.yield()
                    openSettings()
                    NSApplication.shared.activate()
                }
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(28)
        .frame(width: 340, height: isMenuBar ? 400 : 480)
        .controlSize(.extraLarge)
        .task { await model.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await model.refresh() }
            }
        }
        .alert("NoLogo", isPresented: $showsError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
}

#Preview {
    ContentView(model: LogoLightModel())
}
