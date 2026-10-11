import CaliberCharts
import CaliberCore
import SwiftUI

/// Existing logging screens stay live while Foundation adds Today and settings.
struct RootTabView: View {
  @EnvironmentObject private var runtime: FoundationRuntime
  @State private var selection = "today"
  var body: some View {
    Group {
      if runtime.isDemoMode, let dataset = runtime.demo {
        NavigationStack {
          DemoDashboard(dataset: dataset, hidesNumbers: runtime.settings.hideNumbers)
        }
        .safeAreaInset(edge: .bottom) {
          // A full-width control gives large text room to grow and stays reachable while scrolling.
          Button {
            runtime.isDemoMode = false
          } label: {
            Text("Exit Demo").font(.body)
              .fixedSize(horizontal: false, vertical: true)
              .frame(maxWidth: .infinity, minHeight: 48)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain).foregroundStyle(.tint)
          .accessibilityIdentifier("exitDemo")
          .padding(.horizontal).padding(.vertical, 8)
          .background(.bar)
        }
      } else if runtime.settings.hideNumbers {
        NumberFreeHomeView()
      } else {
        TabView(selection: $selection) {
          TodayFoundationView().tabItem { Label("Today", systemImage: "sun.max") }.tag("today")
          DiaryView().tabItem { Label("Diary", systemImage: "fork.knife") }.tag("diary")
          FoodLibraryView().tabItem { Label("Food Library", systemImage: "books.vertical") }.tag(
            "library")
          ProgressDashboardView().tabItem {
            Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
          }.tag("progress")
          NavigationStack { FoundationSettingsView() }.tabItem {
            Label("Settings", systemImage: "gearshape")
          }.tag("settings")
        }
      }
    }
  }
}
