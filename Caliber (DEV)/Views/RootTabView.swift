import SwiftUI
import CaliberCore
import CaliberCharts

/// Existing logging screens stay live while Foundation adds Today and settings.
struct RootTabView: View {
    @EnvironmentObject private var runtime: FoundationRuntime
    @State private var selection = "today"
    var body: some View {
        Group {
            if runtime.isDemoMode, let dataset = runtime.demo {
                NavigationStack {
                    DemoDashboard(dataset:dataset,hidesNumbers:runtime.settings.hideNumbers)
                        .toolbar { ToolbarItem(placement:.topBarTrailing) { Button("Exit Demo") { runtime.isDemoMode = false }.accessibilityIdentifier("exitDemo") } }
                }
            } else if runtime.settings.hideNumbers {
                NumberFreeHomeView()
            } else {
                TabView(selection:$selection) {
                    TodayFoundationView().tabItem { Label("Today",systemImage:"sun.max") }.tag("today")
                    DiaryView().tabItem { Label("Diary",systemImage:"fork.knife") }.tag("diary")
                    FoodLibraryView().tabItem { Label("Food Library",systemImage:"books.vertical") }.tag("library")
                    ProgressDashboardView().tabItem { Label("Progress",systemImage:"chart.line.uptrend.xyaxis") }.tag("progress")
                    FoundationSettingsView().tabItem { Label("Settings",systemImage:"gearshape") }.tag("settings")
                }
            }
        }
    }
}
