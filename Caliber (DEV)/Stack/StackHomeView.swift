import Charts
import HeliosDesign
import StackCore
import SwiftData
import SwiftUI

/// The Stack tab: today's doses, the illustrative level and supply (look book "Stack").
/// It opens the module's private store behind the lock gate.
struct StackHomeView: View {
  @EnvironmentObject private var stack: StackRuntime

  var body: some View {
    NavigationStack {
      StackLockGate(requiresUnlock: stack.requiresUnlock) {
        if let container = stack.container {
          StackDashboard().modelContainer(container)
        } else if stack.failedToOpen {
          ContentUnavailableView(
            "Stack could not be opened", systemImage: "externaldrive.badge.exclamationmark",
            description: Text("Your entries have been kept. Restart the app and try again."))
        } else {
          ProgressView().task { stack.open() }
        }
      }
      .caliberScreen()
      .navigationTitle("Stack")
      .profileAvatar()
    }
  }
}

/// A request to log or skip one dose.
struct StackLogRequest: Identifiable {
  let compound: StackCompound
  let scheduledFor: Date?
  var id: String {
    String(describing: compound.persistentModelID) + "\(scheduledFor ?? .distantPast)"
  }
}

private struct StackDashboard: View {
  @EnvironmentObject private var stack: StackRuntime
  @Query(sort: \StackCompound.createdAt) private var compounds: [StackCompound]
  @Environment(\.modelContext) private var context
  @Environment(\.calendar) private var calendar
  @Environment(\.heliosTheme) private var theme
  @State private var isAdding = false
  @State private var editing: StackCompound?
  @State private var logging: StackLogRequest?

  var body: some View {
    TimelineView(.periodic(from: .now, by: 60)) { timeline in
      ScrollView {
        VStack(alignment: .leading, spacing: HeliosTokens.space(4)) {
          if compounds.isEmpty {
            emptyCard
          } else {
            StackTodayCard(
              compounds: compounds, now: timeline.date,
              log: { logging = $0 }, skip: skip, edit: { editing = $0 })
            ForEach(stack.showsEstimate ? compounds.filter(StackPlanner.canShowLevel) : []) {
              compound in
              StackLevelCard(compound: compound, now: timeline.date)
            }
            ForEach(compounds.filter { $0.supplyDoses > 0 }) { compound in
              StackSupplyCard(compound: compound)
            }
          }
          StackScopeNote()
        }
        .padding()
      }
    }
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button {
          isAdding = true
        } label: {
          Label("Add to Stack", systemImage: "plus")
        }
        .accessibilityIdentifier("stackAddCompound")
      }
    }
    .sheet(isPresented: $isAdding) { StackCompoundEditor(compound: nil) }
    .sheet(item: $editing) { StackCompoundEditor(compound: $0) }
    .sheet(item: $logging) { StackLogDoseView(request: $0) }
  }

  private var emptyCard: some View {
    VStack(alignment: .leading, spacing: HeliosTokens.space(3)) {
      SectionHeader("Add what you take")
      Text(
        "Enter each medication, peptide or supplement with your own amount and schedule. Stack then shows what is due, what you logged and how much supply is left."
      )
      .heliosFont(.callout)
      .foregroundStyle(theme.palette.text.secondary.color)
      Button {
        isAdding = true
      } label: {
        Text("Add to Stack").frame(maxWidth: .infinity)
      }
      .buttonStyle(.heliosPrimary)
      .accessibilityIdentifier("stackAddFirst")
    }
    .glassCard()
  }

  private func skip(_ request: StackLogRequest) {
    context.insert(
      StackDose(
        compound: request.compound, amountText: request.compound.amountText, takenAt: nil,
        scheduledFor: request.scheduledFor))
    try? context.save()
  }
}

/// "Doses today": the dose that needs attention first, then the rest of today.
private struct StackTodayCard: View {
  let compounds: [StackCompound]
  let now: Date
  let log: (StackLogRequest) -> Void
  let skip: (StackLogRequest) -> Void
  let edit: (StackCompound) -> Void
  @Environment(\.calendar) private var calendar
  @Environment(\.heliosTheme) private var theme

  var body: some View {
    let today = StackPlanner.today(for: compounds, now: now, calendar: calendar)
    let focus = today.first { $0.status == .due || $0.status == .missed && $0.dose == nil }
    VStack(alignment: .leading, spacing: HeliosTokens.space(3)) {
      HStack(alignment: .firstTextBaseline) {
        SectionHeader("Doses today")
        Text("Now \(now.formatted(date: .omitted, time: .shortened))")
          .heliosFont(.footnote)
          .foregroundStyle(theme.palette.text.secondary.color)
          .fixedSize(horizontal: false, vertical: true)
      }
      if let focus, let compound = compound(named: focus.compoundName) {
        StackFocusTile(
          compound: compound, scheduled: focus, now: now,
          log: { log(StackLogRequest(compound: compound, scheduledFor: focus.scheduledAt)) },
          skip: { skip(StackLogRequest(compound: compound, scheduledFor: focus.scheduledAt)) })
      }
      ForEach(today.filter { $0.id != focus?.id }) { item in
        if let compound = compound(named: item.compoundName) {
          StackDoseRow(compound: compound, item: item) { edit(compound) }
        }
      }
      ForEach(unscheduledToday(today)) { compound in
        StackCompoundRow(compound: compound, now: now) {
          log(StackLogRequest(compound: compound, scheduledFor: nil))
        } edit: {
          edit(compound)
        }
      }
    }
    .glassCard()
  }

  private func compound(named name: String) -> StackCompound? {
    compounds.first { $0.name == name }
  }

  private func unscheduledToday(_ today: [StackScheduledDose]) -> [StackCompound] {
    let names = Set(today.map(\.compoundName))
    return compounds.filter { !names.contains($0.name) }
  }
}

private struct StackIcon: View {
  let form: StackForm
  @Environment(\.heliosTheme) private var theme

  var body: some View {
    Image(systemName: form.symbol)
      .foregroundStyle(theme.palette.data.peptide.color)
      .frame(width: 40, height: 40)
      .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(theme.palette.data.peptide.color.opacity(0.14))
      )
      .accessibilityHidden(true)
  }
}

/// The raised tile for the dose that needs attention, with Log dose and Skip.
private struct StackFocusTile: View {
  let compound: StackCompound
  let scheduled: StackScheduledDose
  let now: Date
  let log: () -> Void
  let skip: () -> Void
  @Environment(\.heliosTheme) private var theme

  var body: some View {
    VStack(alignment: .leading, spacing: HeliosTokens.space(3)) {
      HStack(alignment: .top, spacing: HeliosTokens.space(3)) {
        StackIcon(form: compound.form)
        VStack(alignment: .leading, spacing: 2) {
          Text(compound.name).heliosFont(.bodyStrong)
          Text(
            "\(StackText.amount(compound)) · \(compound.repeatPattern.title.lowercased()) · planned \(scheduled.scheduledAt.formatted(date: .omitted, time: .shortened))"
          )
          .heliosFont(.footnote)
          .foregroundStyle(theme.palette.text.secondary.color)
          if now > scheduled.scheduledAt {
            Label {
              Text("Overdue by \(StackText.duration(from: scheduled.scheduledAt, to: now))")
            } icon: {
              Image(systemName: "exclamationmark.triangle.fill")
            }
            .heliosFont(.footnote)
            .foregroundStyle(theme.palette.status.warning.color)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      ViewThatFits(in: .horizontal) {
        HStack(spacing: HeliosTokens.space(2)) { buttons }
        VStack(spacing: HeliosTokens.space(2)) { buttons }
      }
    }
    .padding(HeliosTokens.space(3))
    .background { GlassBackground(level: .raised, cornerRadius: HeliosTokens.radius.tile) }
    .accessibilityElement(children: .contain)
  }

  @ViewBuilder private var buttons: some View {
    Button(action: log) {
      Text("Log dose").frame(maxWidth: .infinity)
    }
    .buttonStyle(.heliosPrimary)
    .accessibilityIdentifier("stackLogDose")
    Button("Skip", action: skip)
      .buttonStyle(.heliosSecondary)
      .accessibilityIdentifier("stackSkipDose")
  }
}

/// A scheduled dose that is upcoming, taken, skipped or missed.
private struct StackDoseRow: View {
  let compound: StackCompound
  let item: StackScheduledDose
  let edit: () -> Void
  @Environment(\.heliosTheme) private var theme

  var body: some View {
    Button(action: edit) {
      HStack(spacing: HeliosTokens.space(3)) {
        StackIcon(form: compound.form)
        VStack(alignment: .leading, spacing: 2) {
          Text(compound.name).heliosFont(.bodyStrong)
            .foregroundStyle(theme.palette.text.primary.color)
          Text("\(StackText.amount(compound)) · \(compound.repeatPattern.title.lowercased())")
            .heliosFont(.footnote)
            .foregroundStyle(theme.palette.text.secondary.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        status
      }
      .frame(minHeight: 48)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder private var status: some View {
    switch item.status {
    case .takenOnTime, .takenLate, .takenEarly:
      StatusBadge(
        .success,
        "Taken \(item.dose?.takenAt?.formatted(date: .omitted, time: .shortened) ?? "")")
    case .skipped:
      Text("Skipped").heliosFont(.footnote)
        .foregroundStyle(theme.palette.text.secondary.color)
    case .missed:
      StatusBadge(.warning, "Not logged")
    case .due, .upcoming:
      Label {
        Text(item.scheduledAt, format: .dateTime.hour().minute())
      } icon: {
        Image(systemName: "clock")
      }
      .heliosFont(.footnote)
      .foregroundStyle(theme.palette.text.secondary.color)
    }
  }
}

/// Something not scheduled today: as-needed entries and other-day schedules.
private struct StackCompoundRow: View {
  let compound: StackCompound
  let now: Date
  let log: () -> Void
  let edit: () -> Void
  @Environment(\.calendar) private var calendar
  @Environment(\.heliosTheme) private var theme

  var body: some View {
    HStack(spacing: HeliosTokens.space(3)) {
      Button(action: edit) {
        HStack(spacing: HeliosTokens.space(3)) {
          StackIcon(form: compound.form)
          VStack(alignment: .leading, spacing: 2) {
            Text(compound.name).heliosFont(.bodyStrong)
              .foregroundStyle(theme.palette.text.primary.color)
            Text(detail).heliosFont(.footnote)
              .foregroundStyle(theme.palette.text.secondary.color)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 48)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      Button("Log", action: log)
        .buttonStyle(.heliosSecondary)
        .accessibilityLabel("Log \(compound.name)")
    }
  }

  private var detail: String {
    if compound.isPaused { return "\(StackText.amount(compound)) · paused" }
    if let next = StackPlanner.next(for: [compound], now: now, calendar: calendar) {
      return
        "\(StackText.amount(compound)) · next \(next.scheduledAt.formatted(.dateTime.weekday(.abbreviated).hour().minute()))"
    }
    return "\(StackText.amount(compound)) · \(compound.repeatPattern.title.lowercased())"
  }
}

/// The illustrative active amount (STK-10), labelled as an estimate and never as a level in
/// the blood. Shown only when the person entered a half-life with its source.
private struct StackLevelCard: View {
  let compound: StackCompound
  let now: Date
  @Environment(\.calendar) private var calendar
  @Environment(\.heliosTheme) private var theme

  var body: some View {
    let start = calendar.date(byAdding: .day, value: -28, to: now) ?? now
    let series = StackPlanner.levelSeries(for: compound, in: start...now) ?? []
    VStack(alignment: .leading, spacing: HeliosTokens.space(3)) {
      HStack(alignment: .firstTextBaseline) {
        SectionHeader("\(compound.name) estimate")
        Text("Illustrative · \(compound.unit.symbol)")
          .heliosFont(.footnote)
          .foregroundStyle(theme.palette.text.secondary.color)
          .fixedSize(horizontal: false, vertical: true)
      }
      if let latest = series.last {
        Text("Now about \(StackText.number(latest.amount)) \(compound.unit.symbol)")
          .heliosFont(.metricValue)
        StackLevelChart(series: series, tint: theme.palette.data.peptide.color)
          .frame(height: 140)
          .accessibilityElement()
          .accessibilityLabel("Illustrative active amount over the last four weeks")
          .accessibilityValue(
            "Now about \(StackText.number(latest.amount)) \(compound.unit.symbol)")
      } else {
        Text("Log a dose to see the estimate.")
          .heliosFont(.callout)
          .foregroundStyle(theme.palette.text.secondary.color)
      }
      Text(
        "A simplified model from the half-life you entered (\(compound.halfLifeSource)). It is not a blood level and is not advice on timing or amount."
      )
      .heliosFont(.caption)
      .foregroundStyle(theme.palette.text.secondary.color)
    }
    .glassCard()
  }
}

private struct StackLevelChart: View {
  let series: [(date: Date, amount: Double)]
  let tint: Color

  var body: some View {
    Chart {
      ForEach(series.indices, id: \.self) { index in
        AreaMark(x: .value("Date", series[index].date), y: .value("Amount", series[index].amount))
          .foregroundStyle(tint.opacity(0.1))
        LineMark(x: .value("Date", series[index].date), y: .value("Amount", series[index].amount))
          .foregroundStyle(tint)
          .lineStyle(StrokeStyle(lineWidth: 2))
      }
    }
    .heliosChartStyle()
  }
}

/// "3 of 4 doses left" with a meter.
private struct StackSupplyCard: View {
  let compound: StackCompound
  @Environment(\.heliosTheme) private var theme

  var body: some View {
    let left = StackPlanner.remainingSupply(of: compound) ?? 0
    let fraction = Double(left) / Double(max(1, compound.supplyDoses))
    VStack(alignment: .leading, spacing: HeliosTokens.space(2)) {
      // Both lines wrap rather than truncate as text grows.
      HStack(alignment: .firstTextBaseline) {
        Text("\(compound.name) \(compound.form.title.lowercased())").heliosFont(.bodyStrong)
          .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: HeliosTokens.space(2))
        Text("\(left) of \(compound.supplyDoses) doses left").heliosFont(.callout)
          .multilineTextAlignment(.trailing)
          .fixedSize(horizontal: false, vertical: true)
      }
      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule().fill(theme.palette.border.hairline.color)
          Capsule().fill(theme.palette.accent.base.color)
            .frame(width: proxy.size.width * fraction)
        }
      }
      .frame(height: 8)
      .accessibilityHidden(true)
    }
    .glassCard()
    .accessibilityElement(children: .combine)
  }
}

/// Brief §11.1: every Stack screen that shows a calculation states the scope.
struct StackScopeNote: View {
  @Environment(\.heliosTheme) private var theme

  var body: some View {
    Text(
      "Stack records what you enter. It does not recommend doses, timing or combinations. Talk to a licensed clinician about medical decisions."
    )
    .heliosFont(.footnote)
    .foregroundStyle(theme.palette.text.secondary.color)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

enum StackText {
  static func amount(_ compound: StackCompound) -> String {
    "\(compound.amountText) \(compound.unit.symbol)"
  }

  static func number(_ value: Double) -> String {
    value.formatted(.number.precision(.significantDigits(1...3)))
  }

  static func duration(from start: Date, to end: Date) -> String {
    Duration.seconds(max(0, end.timeIntervalSince(start)))
      .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
  }
}
