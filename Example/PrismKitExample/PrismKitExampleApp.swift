import SwiftUI
import PrismKit

@main
struct PrismKitExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            PlaygroundScreen()
                .tabItem { Label("Shop", systemImage: "bag") }
            AdaptiveScreen()
                .tabItem { Label("Adaptive", systemImage: "textformat.size") }
            PrismKitDemoScreen()
                .tabItem { Label("Demo", systemImage: "rectangle.dashed") }
        }
    }
}
