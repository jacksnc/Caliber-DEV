import SwiftUI

@main
struct Caliber__DEV_App: App {
    @StateObject private var runtime = FoundationRuntime()
    var body: some Scene {
        WindowGroup { FoundationRootView().environmentObject(runtime) }
    }
}
