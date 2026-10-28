import CaliberCore
import HeliosDesign
import SwiftData
import SwiftUI

/// Today, drawn to the look book: the Fuel rings, the training card, the weight trend and,
/// when Stack is on, the next dose. Logging starts from the floating + button.
struct TodayFoundationView: View {
  @EnvironmentObject private var runtime: FoundationRuntime
  @Query(sort: \DiaryEntry.date) private var diary: [DiaryEntry]
  @Query private var profiles: [UserProfile]
  @Query(sort: \TrainingWorkout.startedAt, order: .reverse) private var workouts: [TrainingWorkout]
  @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
  @Environment(\.heliosTheme) private var theme
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.scenePhase) private var scenePhase
  /// The day shown. Refreshed at midnight and when the app returns, so an app left open
  /// overnight does not keep showing yesterday.
  @State private var day = Date.now
  private var today: [DiaryEntry] {
    diary.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: HeliosTokens.space(3)) {
          CaliberHeader(
            "Today", identifier: "Today",
            overline: Text(day, format: .dateTime.weekday(.wide).month(.wide).day()))
          TodayFuelCard(entries: today, profile: profiles.first)
          TodayTrainCard(workouts: workouts)
          tiles
          demoCard
        }
        .padding(.horizontal, HeliosTokens.space(4))
        .padding(.top, HeliosTokens.space(1))
        .padding(.bottom, HeliosTokens.space(4))
      }
      .caliberScreen()
      .compactNavigationTitle("Today")
      .profileAvatar()
    }
    .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
      day = .now
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { day = .now }
    }
  }

  /// Two small tiles side by side; stacked at accessibility text sizes.
  @ViewBuilder private var tiles: some View {
    if typeSize.isAccessibilitySize {
      VStack(spacing: HeliosTokens.space(3)) {
        TodayWeightTile(entries: weights)
        TodayDoseTile()
      }
    } else {
      HStack(alignment: .top, spacing: HeliosTokens.space(3)) {
        TodayWeightTile(entries: weights)
        TodayDoseTile()
      }
    }
  }

  private var demoCard: some View {
    VStack(alignment: .leading, spacing: HeliosTokens.space(3)) {
      SectionHeader("Explore")
      Button {
        Task { await runtime.showDemo() }
      } label: {
        Label(
          runtime.isLoadingDemo ? "Preparing Demo…" : "Explore a Year of Demo Data",
          systemImage: "chart.xyaxis.line"
        )
        .frame(maxWidth: .infinity, minHeight: 48)
      }
      .buttonStyle(.heliosSecondary)
      .disabled(runtime.isLoadingDemo)
      .accessibilityIdentifier("openDemo")
      Text("Fictional data lives in separate storage. Your diary and photos stay as they are.")
        .heliosFont(.footnote)
        .foregroundStyle(theme.palette.text.secondary.color)
    }
    .glassCard()
  }
}

/// "Fuel": four concentric rings (energy outside, then protein, carbs, fat) with a legend.
/// Left shows what remains of each goal; Eaten shows what was logged.
private struct TodayFuelCard: View {
  let entries: [DiaryEntry]
  let profile: UserProfile?
  @EnvironmentObject private var runtime: FoundationRuntime
  @Environment(\.heliosTheme) private var theme
  @Environment(\.locale) private var locale
  @Environment(\.caliberProfileAction) private var openProfile
  @State private var showsLeft = true
  /// The ring grows with text size so its centre label always has room.
  @ScaledMetric(relativeTo: .title3) private var scaledRing = 168.0
  @Environment(\.dynamicTypeSize) private var typeSize
  /// Never wider than the card; at accessibility sizes the figure moves below the ring.
  private var ringSize: Double { min(scaledRing, 240) }

  private struct Row: Identifiable {
    let id: String
    let title: LocalizedStringKey
    let unit: String
    let eaten: Double
    let goal: Double?
    let color: Color
  }

  var body: some View {
    let totals = MacroCalculator.totals(for: entries)
    let energyUnit = runtime.settings.energyUnit
    let palette = theme.palette.data
    let rows = [
      Row(
        id: "energy", title: "Energy", unit: energyUnit.rawValue,
        eaten: UnitFormatting.energy(totals.calories, unit: energyUnit),
        goal: goal(profile?.dailyCalorieGoal).map { UnitFormatting.energy($0, unit: energyUnit) },
        color: palette.energy.color),
      Row(
        id: "protein", title: "Protein", unit: "g", eaten: totals.protein,
        goal: goal(profile?.proteinGoal), color: palette.protein.color),
      Row(
        id: "carbs", title: "Carbs", unit: "g", eaten: totals.carbs,
        goal: goal(profile?.carbGoal), color: palette.carbs.color),
      Row(
        id: "fat", title: "Fat", unit: "g", eaten: totals.fat, goal: goal(profile?.fatGoal),
        color: palette.fat.color),
    ]
    VStack(alignment: .leading, spacing: HeliosTokens.space(3)) {
      HStack {
        SectionHeader("Fuel")
        if rows[0].goal != nil {
          HStack(spacing: 2) {
            modeChip("Left", isLeft: true)
            modeChip("Eaten", isLeft: false)
          }
          .padding(3)
          .background { HeliosSegmentTrack(cornerRadius: 14) }
        }
      }
      ViewThatFits(in: .horizontal) {
        HStack(spacing: HeliosTokens.space(4)) {
          rings(rows).frame(width: ringSize, height: ringSize)
          legend(rows)
        }
        VStack(alignment: .leading, spacing: HeliosTokens.space(4)) {
          rings(rows).frame(width: ringSize, height: ringSize).frame(maxWidth: .infinity)
          if typeSize.isAccessibilitySize {
            let energy = rows[0]
            ringFigure(
              showsLeft && energy.goal != nil
                ? max(0, (energy.goal ?? 0) - energy.eaten) : energy.eaten, energy: energy
            )
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
          }
          legend(rows)
        }
      }
      if entries.isEmpty {
        Label("No food logged today", systemImage: "fork.knife")
          .heliosFont(.callout)
          .foregroundStyle(theme.palette.text.secondary.color)
      }
      if rows[0].goal == nil { goalHint }
    }
    .glassCard()
  }

  /// Without goals the rings cannot show what is left; the hint opens Profile when it can.
  @ViewBuilder private var goalHint: some View {
    if let openProfile {
      Button(action: openProfile) {
        HStack(spacing: 2) {
          Text("Set daily goals in Profile to see what is left.")
            .fixedSize(horizontal: false, vertical: true)
          Image(systemName: "chevron.right").accessibilityHidden(true)
        }
        .heliosFont(.footnote)
        .foregroundStyle(theme.palette.accent.base.color)
        .frame(minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("todaySetGoals")
    } else {
      Text("Set daily goals in Profile to see what is left.")
        .heliosFont(.footnote)
        .foregroundStyle(theme.palette.text.secondary.color)
    }
  }

  private func goal(_ value: Double?) -> Double? {
    guard let value, value.isFinite, value > 0 else { return nil }
    return value
  }

  private func modeChip(_ title: LocalizedStringKey, isLeft: Bool) -> some View {
    Button {
      showsLeft = isLeft
    } label: {
      Text(title).heliosFont(.footnote)
        .foregroundStyle(
          showsLeft == isLeft ? theme.palette.accent.base.color : theme.palette.text.secondary.color
        )
        .padding(.horizontal, 12)
        .frame(minHeight: 38)
        .background {
          if showsLeft == isLeft { HeliosSegmentHighlight(cornerRadius: 11) }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(showsLeft == isLeft ? [.isSelected] : [])
    .accessibilityIdentifier(isLeft ? "fuelMode-left" : "fuelMode-eaten")
  }

  private func rings(_ rows: [Row]) -> some View {
    let energy = rows[0]
    let shown =
      showsLeft && energy.goal != nil ? max(0, (energy.goal ?? 0) - energy.eaten) : energy.eaten
    return MacroRings(
      rings: rows.map { row in
        (progress: row.goal.map { row.eaten / $0 } ?? 0, color: row.color)
      }, lineWidth: 9, gap: 3
    ) {
      if !typeSize.isAccessibilitySize { ringFigure(shown, energy: energy) }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      Text(
        showsLeft && energy.goal != nil
          ? "\(number(shown, digits: 0)) \(energy.unit) left today"
          : "\(number(shown, digits: 0)) \(energy.unit) eaten today"))
  }

  private func ringFigure(_ shown: Double, energy: Row) -> some View {
    VStack(spacing: 0) {
      Text(number(shown, digits: 0)).heliosFont(.metricValue)
      Text(showsLeft && energy.goal != nil ? "\(energy.unit) left" : "\(energy.unit) eaten")
        .heliosFont(.caption)
        .foregroundStyle(theme.palette.text.secondary.color)
    }
    .multilineTextAlignment(.center)
  }

  private func legend(_ rows: [Row]) -> some View {
    VStack(alignment: .leading, spacing: HeliosTokens.space(2)) {
      ForEach(rows) { row in
        VStack(alignment: .leading, spacing: 0) {
          HStack(spacing: HeliosTokens.space(1)) {
            Circle().fill(row.color).frame(width: 8, height: 8).accessibilityHidden(true)
            // One text, so the name and unit wrap together in a narrow legend.
            (Text(row.title) + Text(" · \(row.unit)")).heliosFont(.metricLabel)
              .foregroundStyle(theme.palette.text.secondary.color)
              .fixedSize(horizontal: false, vertical: true)
          }
          HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(number(row.eaten, digits: row.id == "energy" ? 0 : 1)).heliosFont(.bodyStrong)
              .fixedSize(horizontal: false, vertical: true)
            if let goal = row.goal {
              Text("/ \(number(goal, digits: 0))").heliosFont(.footnote)
                .foregroundStyle(theme.palette.text.secondary.color)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }
        .accessibilityElement(children: .combine)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func number(_ value: Double, digits: Int) -> String {
    UnitFormatting.number(value, locale: locale, fractionDigits: digits)
  }
}

/// Concentric progress rings, outermost first, with content in the middle.
struct MacroRings<Center: View>: View {
  let rings: [(progress: Double, color: Color)]
  var lineWidth = 11.0
  var gap = 3.0
  @ViewBuilder let center: () -> Center
  @Environment(\.heliosTheme) private var theme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      ForEach(rings.indices, id: \.self) { index in
        let inset = Double(index) * (lineWidth + gap) + lineWidth / 2
        let progress = min(max(rings[index].progress, 0), 1)
        Circle()
          .stroke(theme.palette.border.hairline.color, lineWidth: lineWidth)
          .padding(inset)
        Circle()
          .trim(from: 0, to: progress)
          .stroke(rings[index].color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
          .rotationEffect(.degrees(-90))
          .padding(inset)
          .animation(
            reduceMotion ? nil : .easeOut(duration: HeliosTokens.motion.base), value: progress)
      }
      center()
        .padding(Double(rings.count) * (lineWidth + gap))
    }
  }
}

/// The training card: continue the open workout, or start one with the last session as a hint.
private struct TodayTrainCard: View {
  let workouts: [TrainingWorkout]
  @Environment(\.selectCaliberTab) private var selectTab
  @Environment(\.heliosTheme) private var theme

  var body: some View {
    let active = workouts.first(where: \.isActive)
    let last = workouts.first { !$0.isActive }
    VStack(alignment: .leading, spacing: HeliosTokens.space(3)) {
      HStack(spacing: HeliosTokens.space(3)) {
        Image(systemName: "dumbbell")
          .foregroundStyle(theme.palette.accent.base.color)
          .frame(width: 40, height: 40)
          .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .fill(theme.palette.accent.subtle.color)
          )
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 2) {
          Text(active?.name ?? last?.name ?? "Training").heliosFont(.section)
          Text(detail(active: active, last: last)).heliosFont(.footnote)
            .foregroundStyle(theme.palette.text.secondary.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      if let hint = hint(last), active == nil {
        Text(hint).heliosFont(.callout)
      }
      Button {
        selectTab(.train)
      } label: {
        Text(active == nil ? "Start workout" : "Continue workout").frame(maxWidth: .infinity)
      }
      .buttonStyle(.heliosPrimary)
      .accessibilityIdentifier("todayStartWorkout")
    }
    .glassCard()
  }

  private func detail(active: TrainingWorkout?, last: TrainingWorkout?) -> String {
    if let active {
      return
        "In progress since \(active.startedAt.formatted(date: .omitted, time: .shortened)) · \(Self.exerciseCount(active))"
    }
    if let last {
      return
        "Last time \(last.startedAt.formatted(.dateTime.weekday(.wide))) · \(Self.exerciseCount(last))"
    }
    return "No workouts yet"
  }

  private static func exerciseCount(_ workout: TrainingWorkout) -> String {
    workout.exercises.count == 1 ? "1 exercise" : "\(workout.exercises.count) exercises"
  }

  private func hint(_ last: TrainingWorkout?) -> String? {
    guard let first = last?.sortedExercises.first, let name = first.exercise?.name else {
      return nil
    }
    let sets = first.sortedSets.filter { !$0.isWarmup && $0.completedAt != nil }
    guard let top = sets.max(by: { $0.weightKilograms < $1.weightKilograms }) else { return nil }
    let weight = top.enteredWeight.formatted(.number.precision(.fractionLength(0...1)))
    return
      "\(name): \(sets.count) sets · top \(weight) \(top.enteredWeightUnitRawValue) × \(top.repetitions)"
  }
}

/// Trend weight with a sparkline and this week's change.
private struct TodayWeightTile: View {
  let entries: [WeightEntry]
  @EnvironmentObject private var runtime: FoundationRuntime
  @Environment(\.heliosTheme) private var theme
  @Environment(\.locale) private var locale

  var body: some View {
    let unit = runtime.settings.massUnit
    // The smoothed trend (brief §9.3), as on Progress, not the latest raw reading.
    let trend = Array(WeightProgressSummary(entries: entries).trend.suffix(14))
    let values = trend.map { unit.fromKilograms($0.pounds * 0.45359237) }
    VStack(alignment: .leading, spacing: HeliosTokens.space(1)) {
      HStack(spacing: HeliosTokens.space(1)) {
        Circle().fill(theme.palette.data.weight.color).frame(width: 8, height: 8)
          .accessibilityHidden(true)
        Text("Trend weight").heliosFont(.metricLabel)
          .foregroundStyle(theme.palette.text.secondary.color)
      }
      if let latest = values.last {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
          Text(UnitFormatting.number(latest, locale: locale)).heliosFont(.metricValue)
          Text(unit.rawValue).heliosFont(.caption)
            .foregroundStyle(theme.palette.text.secondary.color)
        }
        if values.count > 1 {
          Sparkline(values: values, color: theme.palette.data.weight.color)
            .frame(height: 28)
            .accessibilityHidden(true)
        }
        Text(weekChange(trend: trend, unit: unit)).heliosFont(.caption)
          .foregroundStyle(theme.palette.text.secondary.color)
      } else {
        Text("Add a weigh-in to see your trend.").heliosFont(.footnote)
          .foregroundStyle(theme.palette.text.secondary.color)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .glassCard()
    .accessibilityElement(children: .combine)
  }

  private func weekChange(trend: [WeightProgressSummary.TrendReading], unit: MassUnit) -> String {
    let since = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
    let week = trend.filter { $0.date >= since }
    guard let first = week.first, let last = week.last, week.count > 1 else {
      return "No change to show this week"
    }
    let change = unit.fromKilograms((last.pounds - first.pounds) * 0.45359237)
    let text = UnitFormatting.number(abs(change), locale: locale)
    if abs(change) < 0.05 { return "About the same this week" }
    return change < 0
      ? "−\(text) \(unit.rawValue) this week" : "+\(text) \(unit.rawValue) this week"
  }
}

/// A minimal line for small tiles. The full chart lives on Progress.
struct Sparkline: View {
  let values: [Double]
  let color: Color
  @Environment(\.heliosTheme) private var theme

  var body: some View {
    GeometryReader { proxy in
      let low = values.min() ?? 0
      let span = max((values.max() ?? 0) - low, 0.0001)
      ZStack(alignment: .topLeading) {
        Path { path in
          for (index, value) in values.enumerated() {
            let point = CGPoint(
              x: proxy.size.width * Double(index) / Double(max(values.count - 1, 1)),
              y: proxy.size.height * (1 - (value - low) / span))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
          }
        }
        .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        if let last = values.last {
          Circle().fill(color)
            .overlay { Circle().strokeBorder(theme.palette.opaque.base.color, lineWidth: 2) }
            .frame(width: 10, height: 10)
            .position(x: proxy.size.width, y: proxy.size.height * (1 - (last - low) / span))
        }
      }
    }
  }
}

/// The next dose from Stack. While Stack is locked the tile shows no names or amounts.
private struct TodayDoseTile: View {
  @EnvironmentObject private var stack: StackRuntime
  @Environment(\.selectCaliberTab) private var selectTab
  @Environment(\.heliosTheme) private var theme
  @Environment(\.calendar) private var calendar

  var body: some View {
    if stack.isEnabled {
      Button {
        selectTab(.stack)
      } label: {
        VStack(alignment: .leading, spacing: HeliosTokens.space(1)) {
          HStack(spacing: HeliosTokens.space(1)) {
            Circle().fill(theme.palette.data.peptide.color).frame(width: 8, height: 8)
              .accessibilityHidden(true)
            Text("Next dose").heliosFont(.metricLabel)
              .foregroundStyle(theme.palette.text.secondary.color)
          }
          content
          HStack(spacing: 2) {
            Text(isDue ? "Log dose" : "Open Stack")
            Image(systemName: "chevron.right").accessibilityHidden(true)
          }
          .heliosFont(.footnote)
          .foregroundStyle(theme.palette.accent.base.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .glassCard()
      .accessibilityIdentifier("todayNextDose")
      // Opening the store publishes a change, so it happens after the first render.
      .task(id: stack.isLocked) { if !stack.isLocked { stack.open() } }
    }
  }

  @ViewBuilder private var content: some View {
    if stack.isLocked {
      Text("Locked").heliosFont(.bodyStrong)
      Text("Open Stack to see today's doses.").heliosFont(.caption)
        .foregroundStyle(theme.palette.text.secondary.color)
    } else if case (let next, let compound)? = nextDose() {
      Text(next.compoundName).heliosFont(.bodyStrong)
        .foregroundStyle(theme.palette.text.primary.color)
      Text(
        "\(StackText.amount(compound)) · \(next.scheduledAt.formatted(date: .omitted, time: .shortened))"
      )
      .heliosFont(.caption)
      .foregroundStyle(theme.palette.text.secondary.color)
      if next.scheduledAt < .now {
        Label(
          "Overdue by \(StackText.duration(from: next.scheduledAt, to: .now))",
          systemImage: "exclamationmark.triangle.fill"
        )
        .heliosFont(.caption)
        .foregroundStyle(theme.palette.status.warning.color)
      } else if !calendar.isDateInToday(next.scheduledAt) {
        Text(next.scheduledAt, format: .dateTime.weekday(.wide))
          .heliosFont(.caption)
          .foregroundStyle(theme.palette.text.secondary.color)
      }
    } else {
      Text("Nothing scheduled").heliosFont(.bodyStrong)
        .foregroundStyle(theme.palette.text.primary.color)
    }
  }

  private var isDue: Bool {
    guard !stack.isLocked, let next = nextDose()?.0 else { return false }
    return next.scheduledAt <= .now
  }

  private func nextDose() -> (StackScheduledDose, StackCompound)? {
    guard let context = stack.container?.mainContext,
      let compounds = try? context.fetch(FetchDescriptor<StackCompound>()),
      let next = StackPlanner.next(for: compounds, now: .now, calendar: calendar),
      let compound = compounds.first(where: { $0.name == next.compoundName })
    else { return nil }
    return (next, compound)
  }
}

/// Number hiding also removes numeric views from the accessibility tree and navigation.
/// Notes/photos remain available; old numeric editors cannot leak values through a sheet.
struct NumberFreeHomeView: View {
  @EnvironmentObject private var runtime: FoundationRuntime
  @Query(sort: \ProgressEntry.date, order: .reverse) private var entries: [ProgressEntry]
  @State private var checkIn = false
  var body: some View {
    NavigationStack {
      List {
        Group {
          Section {
            Label("Numbers are hidden", systemImage: "eye.slash")
            Text("Keep a photo or note without showing calories or weight.")
            Button {
              checkIn = true
            } label: {
              Text("Add a Photo or Note").frame(minHeight: 48)
            }
          }
          ForEach(entries) { entry in
            VStack(alignment: .leading) {
              Text(entry.date, format: .dateTime.month().day().year()).font(.headline)
              if !entry.notes.isEmpty { Text(entry.notes) }
              if let data = entry.sortedPhotos.first?.imageData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180)
                  .accessibilityLabel("Progress photo")
              }
            }
          }
          NavigationLink {
            FoundationSettingsView()
          } label: {
            Text("Settings").frame(minHeight: 48)
          }
        }
        .listRowBackground(CaliberRowBackground())
      }
      .caliberScreen().navigationTitle("Your Journal")
      .sheet(isPresented: $checkIn) {
        ProgressEntryForm(
          entry: entries.first { Calendar.current.isDateInToday($0.date) }, hidesWeight: true)
      }
    }
  }
}
