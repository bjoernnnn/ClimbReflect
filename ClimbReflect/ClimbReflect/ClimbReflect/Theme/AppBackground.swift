import SwiftUI

// DZ-2/E1: Ersatz für `MountainBackground` – ruhige, fast schwarze Fläche statt
// dekorativer Bergsilhouette. Ein sehr weicher Accent-Glow oben, nur auf den
// vier Tab-Root-Views; Detail-Views/Sheets nutzen nur `Theme.bg`.
struct AppBackground: View {
    var body: some View {
        Theme.bg
            .overlay(alignment: .top) {
                RadialGradient(colors: [Theme.accent.opacity(0.07), .clear],
                               center: .top, startRadius: 0, endRadius: 380)
                    .frame(height: 380)
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea()
    }
}

#Preview {
    AppBackground()
}
