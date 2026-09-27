import SwiftUI

/// Looks exactly like the launch screen (same logo, size and background), so when iOS hands
/// over to the app nothing jumps. Then the logo gently grows and fades into the bookshelf.
struct SplashView: View {
    var body: some View {
        ZStack {
            Color("LaunchBackground")
                .ignoresSafeArea()
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120)
                .accessibilityLabel("Shelfie")
        }
    }
}

/// Adds the splash on top of the app at launch and removes it after a moment.
struct SplashOverlay: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShowing = true

    func body(content: Content) -> some View {
        content
            .overlay {
                if isShowing {
                    SplashView()
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 1.12)))
                        .zIndex(1)
                }
            }
            .task {
                // Long enough for the 3D room to finish its first frame, short enough to not feel slow.
                try? await Task.sleep(for: .milliseconds(650))
                withAnimation(.easeOut(duration: 0.45)) {
                    isShowing = false
                }
            }
    }
}

extension View {
    func splashOnLaunch() -> some View {
        modifier(SplashOverlay())
    }
}
