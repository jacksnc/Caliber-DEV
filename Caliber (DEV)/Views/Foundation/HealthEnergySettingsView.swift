import CaliberCore
import Combine
import SwiftUI

struct HealthEnergySettingsView: View {
  @EnvironmentObject private var energy: HealthEnergyModel
  @Environment(\.locale) private var locale
  @State private var allowance = ""
  @State private var confirmsAllowance = false
  @FocusState private var allowanceFocused: Bool

  var body: some View {
    Form {
      Section("Apple Health Active Energy") {
        Text(
          "Caliber can read today's Active Energy to estimate an optional calorie adjustment. It does not write to Apple Health or add resting energy and workout calories separately."
        )
        Button(energy.readsEnabled ? "Refresh Active Energy" : "Connect Apple Health") {
          Task {
            if energy.readsEnabled { await energy.refresh() } else { await energy.connect() }
          }
        }
        .frame(minHeight: 48)
        .disabled(!energy.isAvailable || energy.isRefreshing)
        .accessibilityIdentifier("connectActiveEnergy")
        if energy.isRefreshing { ProgressView("Refreshing…") }
        if let message = energy.message { Text(message).font(.footnote) }
        if let reading = energy.observation, reading.kilocalories.isFinite,
          reading.kilocalories >= 0
        {
          Text(
            "\(reading.kilocalories.formatted(.number.precision(.fractionLength(0)))) kcal active energy"
          )
          .accessibilityIdentifier("healthActiveEnergy")
          Text("Updated \(reading.refreshedAt, style: .time)").font(.footnote)
        }
      }
      Section("Activity already in your base goal") {
        Text(
          "Your base goal may already include activity. Enter the daily Active Energy allowance you want treated as included. Caliber adds only the amount above this allowance. It cannot infer the correct allowance from your activity label. Review this allowance whenever you change your base goal or activity setting."
        )
        .font(.footnote)
        TextField("Included active calories (kcal)", text: $allowance)
          .keyboardType(.decimalPad).focused($allowanceFocused)
          .accessibilityIdentifier("healthActivityAllowance")
        Toggle(
          "I confirm this activity allowance is already included in my base goal",
          isOn: $confirmsAllowance
        )
        .accessibilityIdentifier("confirmActivityAllowance")
        Button("Save Confirmed Allowance") {
          if let value = NutritionInput.number(allowance, locale: locale) {
            energy.confirmAllowance(value)
            confirmsAllowance = false
          }
        }
        .frame(minHeight: 48)
        .disabled(!confirmsAllowance || NutritionInput.number(allowance, locale: locale) == nil)
        .accessibilityIdentifier("saveActivityAllowance")
        if let saved = energy.confirmedAllowance {
          Text(
            "Confirmed allowance: \(saved.formatted(.number.precision(.fractionLength(0)))) kcal/day"
          )
          .font(.footnote).accessibilityIdentifier("confirmedActivityAllowance")
        }
      }
      Section("Today's adjusted goal") {
        Toggle(
          "Adjust Today's Calorie Goal",
          isOn: Binding(
            get: { energy.adjustsGoal }, set: { energy.setAdjustsGoal($0) })
        )
        .disabled(!energy.readsEnabled || energy.confirmedAllowance == nil)
        .accessibilityIdentifier("adjustGoalFromHealth")
        Text(
          "Adjusted goal = saved base goal + active calories above your confirmed allowance. For example, 2,000 + max(0, 450 − 300) = 2,150 kcal. Macro goals stay as saved. This is an estimate from device data, not a precise measurement of energy needs."
        )
        .font(.footnote)
        Text(
          "Only today is adjusted. Missing, invalid or older-than-15-minute data keeps the base goal. Caliber refreshes while open and when you return. Your saved base goal and past diary days never change."
        )
        .font(.footnote)
        if energy.readsEnabled {
          Button("Disconnect Active Energy", role: .destructive) { energy.disable() }
            .frame(minHeight: 48).accessibilityIdentifier("disconnectActiveEnergy")
          Text(
            "Disconnect stops Caliber reading and clears its in-memory value. You can also revoke read access in Apple Health."
          )
          .font(.footnote)
        }
      }
    }
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") { allowanceFocused = false }.accessibilityIdentifier("healthAllowanceDone")
      }
    }
    .navigationTitle("Apple Health")
    .caliberScreen()
    .onAppear {
      if let value = energy.confirmedAllowance {
        allowance = NutritionInput.format(value, locale: locale)
      }
    }
  }
}

/// Foreground-only refresh; no background polling, Health uploads or widget sharing.
struct HealthEnergyLifecycle: View {
  @EnvironmentObject private var runtime: FoundationRuntime
  @EnvironmentObject private var energy: HealthEnergyModel
  @Environment(\.scenePhase) private var phase
  private let timer = Timer.publish(every: 300, on: .main, in: .common).autoconnect()
  private var allowed: Bool { !runtime.isDemoMode && !runtime.settings.hideNumbers }

  var body: some View {
    Color.clear.frame(width: 0, height: 0).accessibilityHidden(true)
      .task { await refreshIfAllowed() }
      .onChange(of: phase) { _, value in
        if value == .active {
          Task { await refreshIfAllowed() }
        } else if value == .background {
          energy.suppress()
        }
      }
      .onChange(of: allowed) { _, value in
        if value { Task { await refreshIfAllowed() } } else { energy.suppress() }
      }
      .onReceive(timer) { _ in
        if phase == .active { Task { await refreshIfAllowed() } }
      }
      .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
        energy.suppress()
        Task { await refreshIfAllowed() }
      }
      .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
        energy.suppress()
        Task { await refreshIfAllowed() }
      }
  }

  private func refreshIfAllowed() async {
    if allowed { await energy.refresh() } else { energy.suppress() }
  }
}

/// A transparent breakdown; no saved profile is overwritten.
struct HealthEnergyGoalBreakdown: View {
  let base: Double
  @EnvironmentObject private var energy: HealthEnergyModel
  @EnvironmentObject private var runtime: FoundationRuntime
  var body: some View {
    if energy.adjustsGoal {
      TimelineView(.periodic(from: .now, by: 60)) { timeline in
        if let result = energy.goal(base: base, at: timeline.date) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Base goal: \(display(result.base))")
            Text("Health adjustment: +\(display(result.adjustment))")
            Text("Today's goal: \(display(result.total))").bold()
            if result.status != .applied {
              Text("No current adjustment available. Using your base goal.")
            }
          }
          .font(.footnote).fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("healthGoalBreakdown")
        }
      }
    }
  }
  private func display(_ kcal: Double) -> String {
    let unit = runtime.settings.energyUnit
    return
      "\(UnitFormatting.energy(kcal, unit: unit).formatted(.number.precision(.fractionLength(0)))) \(unit.rawValue)"
  }
}
