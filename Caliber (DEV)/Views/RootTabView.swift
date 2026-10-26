import CaliberCharts
import CaliberCore
import HeliosDesign
import SwiftData
import SwiftUI

/// The brief's primary tabs (§1.2) under a floating glass bar with a detached Quick Log
/// button. The system tab bar is hidden; `TabView` still keeps each tab's navigation state.
struct RootTabView: View {
  @EnvironmentObject private var runtime: FoundationRuntime
  @Environment(\.heliosTheme) private var theme
  @Query(sort: \ProgressEntry.date, order: .reverse) private var progress: [ProgressEntry]
  @State private var selection = CaliberTab.today
  @State private var showsQuickLog = false
  @State private var pendingQuickLog: QuickLogAction?
  @State private var quickLogFood = false
  @State private var quickLogCheckIn = false

  private var tabs: [CaliberTab] { [.today, .train, .fuel, .progress] }

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
          ForEach(tabs) { tab in
            screen(for: tab)
              .clearsCaliberTabBar()
              .toolbar(.hidden, for: .tabBar)
              .tag(tab)
          }
        }
        .overlay(alignment: .bottom) {
          CaliberTabBar(tabs: tabs, selection: $selection) { showsQuickLog = true }
            .ignoresSafeArea(.keyboard)
        }
        .sheet(isPresented: $showsQuickLog, onDismiss: openPendingQuickLog) {
          QuickLogSheet(includesDose: false) { action in
            pendingQuickLog = action
            showsQuickLog = false
          }
        }
        .sheet(isPresented: $quickLogFood) { NavigationStack { FoodSearchView() } }
        .sheet(isPresented: $quickLogCheckIn) {
          ProgressEntryForm(entry: progress.first { Calendar.current.isDateInToday($0.date) })
        }
        .tint(theme.palette.accent.base.color)
      }
    }
  }

  @ViewBuilder private func screen(for tab: CaliberTab) -> some View {
    switch tab {
    case .today: TodayFoundationView()
    case .train: TrainHomeView()
    case .fuel: DiaryView()
    case .stack: EmptyView()
    case .progress: ProgressDashboardView()
    }
  }

  private func openPendingQuickLog() {
    guard let action = pendingQuickLog else { return }
    pendingQuickLog = nil
    switch action {
    case .food: quickLogFood = true
    case .checkIn: quickLogCheckIn = true
    case .workout: selection = .train
    case .dose: break
    }
  }
}
