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
            PrismKitDemoScreen()
                .tabItem { Label("Demo", systemImage: "rectangle.dashed") }
        }
    }
}
