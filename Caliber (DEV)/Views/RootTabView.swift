import CaliberCharts
import CaliberCore
import HeliosDesign
import SwiftUI

/// Five primary tabs keep the most common one-handed actions directly reachable.
struct RootTabView: View {
  @EnvironmentObject private var runtime: FoundationRuntime
  @Environment(\.heliosTheme) private var theme
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
          TrainHomeView().tabItem {
            Label("Train", systemImage: "figure.strengthtraining.traditional")
          }.tag("train")
          ProgressDashboardView().tabItem {
            Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
          }.tag("progress")
          ProfileView().tabItem { Label("Profile", systemImage: "person.crop.circle") }
            .tag("profile")
        }
        .tint(theme.palette.accent.base.color)
      }
    }
  }
}
