import SwiftUI

struct AppRootView: View {
    let model: LogoLightModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showsOnboarding = false

    var body: some View {
        ContentView(model: model)
            .task {
                if !hasCompletedOnboarding {
                    showsOnboarding = true
                }
            }
            .sheet(isPresented: $showsOnboarding) {
                OnboardingView(
                    model: model,
                    shortcutLabel: ShortcutSettings.shared.binding.label
                ) {
                    hasCompletedOnboarding = true
                    showsOnboarding = false
                }
                .interactiveDismissDisabled()
            }
    }
}

private enum OnboardingPage: Int {
    case welcome
    case menuBar
    case setup

    var next: OnboardingPage? {
        OnboardingPage(rawValue: rawValue + 1)
    }

    var previous: OnboardingPage? {
        OnboardingPage(rawValue: rawValue - 1)
    }
}

private struct OnboardingView: View {
    let model: LogoLightModel
    let shortcutLabel: String
    let onComplete: () -> Void

    @State private var page: OnboardingPage = .welcome
    @State private var isSettingUp = false
    @State private var errorMessage = ""
    @State private var showsError = false
    @Namespace private var glassNamespace

    var body: some View {
        ZStack {
            OnboardingBackground(page: page)

            VStack(spacing: 24) {
                OnboardingProgress(page: page)

                GlassEffectContainer(spacing: 28) {
                    VStack(spacing: 24) {
                        OnboardingHero(page: page, namespace: glassNamespace)

                        OnboardingPageContent(
                            page: page,
                            shortcutLabel: shortcutLabel
                        )
                        .id(page)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(40)
                    .glassEffect(.regular, in: .rect(cornerRadius: 32))
                }

                OnboardingActions(
                    page: page,
                    isSettingUp: isSettingUp,
                    canSetUp: model.supported && !model.helperInstalled,
                    onBack: moveBack,
                    onNext: moveForward,
                    onFinishLater: onComplete
                )
            }
            .padding(32)
        }
        .frame(width: 700, height: 540)
        .alert("Couldn’t Complete Setup", isPresented: $showsError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func moveBack() {
        guard let previous = page.previous else { return }
        withAnimation(.smooth(duration: 0.45)) {
            page = previous
        }
    }

    private func moveForward() {
        if let next = page.next {
            withAnimation(.smooth(duration: 0.45)) {
                page = next
            }
        } else if model.supported && !model.helperInstalled {
            setUpHelper()
        } else {
            onComplete()
        }
    }

    private func setUpHelper() {
        guard !isSettingUp else { return }
        isSettingUp = true

        Task { @MainActor in
            defer { isSettingUp = false }
            do {
                try await model.primaryAction()
                onComplete()
            } catch {
                errorMessage = error.localizedDescription
                showsError = true
            }
        }
    }
}

private struct OnboardingBackground: View {
    let page: OnboardingPage

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color.indigo.opacity(0.72),
                    Color.blue.opacity(0.45)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(page == .menuBar ? Color.cyan.opacity(0.42) : Color.orange.opacity(0.35))
                .frame(width: 330, height: 330)
                .blur(radius: 80)
                .offset(x: -250, y: -170)

            Circle()
                .fill(page == .setup ? Color.green.opacity(0.38) : Color.purple.opacity(0.4))
                .frame(width: 360, height: 360)
                .blur(radius: 95)
                .offset(x: 260, y: 190)
        }
        .animation(.smooth(duration: 0.7), value: page)
        .ignoresSafeArea()
    }
}

private struct OnboardingProgress: View {
    let page: OnboardingPage

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                ProgressPill(isSelected: page == .welcome)
                ProgressPill(isSelected: page == .menuBar)
                ProgressPill(isSelected: page == .setup)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue("Step \(page.rawValue + 1) of 3")
    }
}

private struct ProgressPill: View {
    let isSelected: Bool

    var body: some View {
        Capsule()
            .fill(isSelected ? Color.white : Color.white.opacity(0.35))
            .frame(width: isSelected ? 34 : 10, height: 10)
            .glassEffect(.clear, in: .capsule)
            .animation(.smooth(duration: 0.35), value: isSelected)
    }
}

private struct OnboardingHero: View {
    let page: OnboardingPage
    let namespace: Namespace.ID

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 58, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .frame(width: 124, height: 124)
            .glassEffect(.regular.tint(tint.opacity(0.34)), in: .circle)
            .glassEffectID("onboarding-hero", in: namespace)
            .contentTransition(.symbolEffect(.replace))
            .accessibilityHidden(true)
    }

    private var symbolName: String {
        switch page {
        case .welcome: "lightbulb.max.fill"
        case .menuBar: "menubar.rectangle"
        case .setup: "checkmark.shield.fill"
        }
    }

    private var tint: Color {
        switch page {
        case .welcome: .orange
        case .menuBar: .cyan
        case .setup: .green
        }
    }
}

private struct OnboardingPageContent: View {
    let page: OnboardingPage
    let shortcutLabel: String

    var body: some View {
        VStack(spacing: 14) {
            Text(title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text(message)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)

            if page == .menuBar {
                HStack(spacing: 12) {
                    OnboardingTip(icon: "cursorarrow.click", text: "Left-click toggles")
                    OnboardingTip(icon: "cursorarrow.rays", text: "Right-click opens options")
                    OnboardingTip(icon: "keyboard", text: shortcutLabel)
                }
                .padding(.top, 8)
            }
        }
    }

    private var title: LocalizedStringResource {
        switch page {
        case .welcome: "Meet NoLogo"
        case .menuBar: "Control It Your Way"
        case .setup: "One Quick Setup"
        }
    }

    private var message: LocalizedStringResource {
        switch page {
        case .welcome:
            "Take control of your Mac’s illuminated logo without reaching for Terminal."
        case .menuBar:
            "Toggle instantly from the menu bar, open quick options with a secondary click, or use your global shortcut."
        case .setup:
            "NoLogo installs a small privileged helper so future changes happen instantly without repeated password prompts."
        }
    }
}

private struct OnboardingTip: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
            Text(text)
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 72)
        .padding(12)
        .glassEffect(.clear, in: .rect(cornerRadius: 18))
    }
}

private struct OnboardingActions: View {
    let page: OnboardingPage
    let isSettingUp: Bool
    let canSetUp: Bool
    let onBack: () -> Void
    let onNext: () -> Void
    let onFinishLater: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if page != .welcome {
                Button("Back", action: onBack)
                    .buttonStyle(.glass)
                    .disabled(isSettingUp)
            }

            Spacer()

            if page == .setup && canSetUp {
                Button("Finish Later", action: onFinishLater)
                    .buttonStyle(.glass)
                    .disabled(isSettingUp)
            }

            Button(action: onNext) {
                if isSettingUp {
                    ProgressView()
                        .controlSize(.small)
                        .frame(minWidth: 110)
                } else {
                    Label(primaryTitle, systemImage: primarySymbol)
                        .frame(minWidth: 110)
                }
            }
            .buttonStyle(.glassProminent)
            .tint(page == .setup ? .green : .accentColor)
            .disabled(isSettingUp)
            .keyboardShortcut(.defaultAction)
        }
    }

    private var primaryTitle: LocalizedStringResource {
        if page != .setup { return "Continue" }
        return canSetUp ? "Set Up & Finish" : "Start Using NoLogo"
    }

    private var primarySymbol: String {
        page == .setup ? "checkmark" : "arrow.right"
    }
}
