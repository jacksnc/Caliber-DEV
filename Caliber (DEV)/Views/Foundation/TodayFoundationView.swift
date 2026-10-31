import CaliberCore
import HeliosDesign
import SwiftData
import SwiftUI

/// Today, drawn to Lookbook V2: the energy summary, the workout to continue, the weight trend
/// and, when Stack is on, the next dose. Logging starts from the floating + button.
struct TodayFoundationView: View {
  @EnvironmentObject private var runtime: FoundationRuntime
  @Query(sort: \DiaryEntry.date) private var diary: [DiaryEntry]
  @Query private var profiles: [UserProfile]
  @Query(sort: \TrainingWorkout.startedAt, order: .reverse) private var workouts: [TrainingWorkout]
  @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
  @Environment(\.heliosTheme) private var theme
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.scenePhase) private var scenePhase
  /// The narrowest a paired tile may be, card padding included; it grows with text size.
  @ScaledMetric(relativeTo: .body) private var tileWidth: CGFloat = 136
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

  /// Two small tiles side by side while each gets at least `tileWidth`; otherwise, and
  /// always at accessibility text sizes, stacked.
  @ViewBuilder private var tiles: some View {
    if typeSize.isAccessibilitySize {
      stackedTiles
    } else {
      // The paired variant reports `tileWidth` per tile as its ideal width, so it is chosen
      // only when two of those fit; text then wraps inside the real width.
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .top, spacing: HeliosTokens.space(3)) {
          TodayWeightTile(entries: weights, idealWidth: tileWidth)
          TodayDoseTile(idealWidth: tileWidth)
        }
        stackedTiles
      }
    }
  }

  private var stackedTiles: some View {
    VStack(spacing: HeliosTokens.space(3)) {
      TodayWeightTile(entries: weights)
      TodayDoseTile()
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
    .v2Surface()
  }
}

/// "Energy today": one centered energy ring with what is left (or eaten), the eaten and goal
/// figures under it, then protein, carbs and fat side by side with their own meters.
private struct TodayFuelCard: View {
  let entries: [DiaryEntry]
  let profile: UserProfile?
  @EnvironmentObject private var runtime: FoundationRuntime
  @Environment(\.heliosTheme) private var theme
  @Environment(\.locale) private var locale
  @Environment(\.caliberProfileAction) private var openProfile
  @Environment(\.selectCaliberTab) private var selectTab
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

  /// What the centre of the ring says. Above the goal, "left" becomes "over" rather than 0.
  /// Captions and the spoken sentence stay localized keys.
  private struct Figure {
    let value: String
    let caption: LocalizedStringKey
    let spoken: LocalizedStringKey
  }

  var body: some View {
    let totals = MacroCalculator.totals(for: entries)
    let energyUnit = runtime.settings.energyUnit
    let palette = theme.palette.data
    let energy = Row(
      id: "energy", title: "Energy", unit: energyUnit.rawValue,
      eaten: UnitFormatting.energy(totals.calories, unit: energyUnit),
      goal: goal(profile?.dailyCalorieGoal).map { UnitFormatting.energy($0, unit: energyUnit) },
      color: palette.energy.color)
    let macros = [
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
    let shown = figure(energy)
    VStack(alignment: .leading, spacing: HeliosTokens.space(4)) {
      header(hasGoal: energy.goal != nil)
      VStack(spacing: HeliosTokens.space(3)) {
        ring(energy, figure: shown).frame(width: ringSize, height: ringSize)
        if typeSize.isAccessibilitySize {
          ringFigure(shown).accessibilityHidden(true)
        }
        energyContext(energy)
      }
      .frame(maxWidth: .infinity)
      macroGrid(macros)
      if entries.isEmpty { emptyDay }
      if energy.goal == nil { goalHint }
    }
    .v2Surface()
  }

  /// Title and the Left/Eaten switch; the switch drops below the title when they do not fit.
  @ViewBuilder private func header(hasGoal: Bool) -> some View {
    if hasGoal {
      ViewThatFits(in: .horizontal) {
        HStack {
          SectionHeader("Energy today")
          modeSwitch
        }
        VStack(alignment: .leading, spacing: HeliosTokens.space(2)) {
          SectionHeader("Energy today")
          modeSwitch
        }
      }
    } else {
      SectionHeader("Energy today")
    }
  }

  private var modeSwitch: some View {
    HStack(spacing: 2) {
      modeChip("Left", isLeft: true)
      modeChip("Eaten", isLeft: false)
    }
    .padding(3)
    .background { HeliosSegmentTrack(cornerRadius: 14) }
  }

  /// Nothing logged yet: say so, and offer the Fuel tab where the day's meals are added.
  private var emptyDay: some View {
    VStack(alignment: .leading, spacing: HeliosTokens.space(2)) {
      Label("No food logged today", systemImage: "fork.knife")
        .heliosFont(.callout)
        .foregroundStyle(theme.palette.text.secondary.color)
      Button {
        selectTab(.fuel)
      } label: {
        Text("Open Fuel").frame(maxWidth: .infinity)
      }
      .buttonStyle(.heliosSecondary)
      .accessibilityIdentifier("todayOpenFuel")
    }
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
        .frame(minHeight: 48, alignment: .leading)
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

  /// The comparison uses the raw values; only the displayed overage is formatted. An
  /// overage below one unit reads "<1 … over", never "0 … over".
  private func figure(_ energy: Row) -> Figure {
    let unit = energy.unit
    guard showsLeft, let target = energy.goal else {
      let eaten = number(energy.eaten, digits: 0)
      return Figure(
        value: eaten, caption: "\(unit) eaten", spoken: "\(eaten) \(unit) eaten today")
    }
    let left = target - energy.eaten
    if left < 0 {
      let over = -left
      if over < 1 {
        let one = number(1, digits: 0)
        return Figure(
          value: "<\(one)", caption: "\(unit) over",
          spoken: "less than \(one) \(unit) over today's goal")
      }
      let shown = number(over, digits: 0)
      return Figure(
        value: shown, caption: "\(unit) over", spoken: "\(shown) \(unit) over today's goal")
    }
    let shown = number(left, digits: 0)
    return Figure(value: shown, caption: "\(unit) left", spoken: "\(shown) \(unit) left today")
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
        .frame(minHeight: 42)
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

  /// The ring shows reported energy against the saved goal; without a goal it stays empty.
  private func ring(_ energy: Row, figure: Figure) -> some View {
    MacroRings(
      rings: [(progress: energy.goal.map { energy.eaten / $0 } ?? 0, color: energy.color)],
      lineWidth: 12, gap: 0
    ) {
      if !typeSize.isAccessibilitySize { ringFigure(figure) }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(figure.spoken))
  }

  private func ringFigure(_ figure: Figure) -> some View {
    VStack(spacing: 0) {
      Text(verbatim: figure.value).heliosFont(.hero)
        .fixedSize(horizontal: false, vertical: true)
      Text(figure.caption)
        .heliosFont(.caption)
        .foregroundStyle(theme.palette.text.secondary.color)
        .fixedSize(horizontal: false, vertical: true)
    }
    .multilineTextAlignment(.center)
  }

  /// "1,840 eaten · 2,300 goal" under the ring, or the eaten total alone without a goal.
  private func energyContext(_ energy: Row) -> some View {
    let eaten = contextFigure(number(energy.eaten, digits: 0), caption: "\(energy.unit) eaten")
    return Group {
      if let target = energy.goal {
        ViewThatFits(in: .horizontal) {
          HStack(alignment: .top, spacing: HeliosTokens.space(6)) {
            eaten
            contextFigure(number(target, digits: 0), caption: "\(energy.unit) goal")
          }
          VStack(spacing: HeliosTokens.space(2)) {
            eaten
            contextFigure(number(target, digits: 0), caption: "\(energy.unit) goal")
          }
        }
      } else {
        contextFigure(
          number(energy.eaten, digits: 0), caption: "\(energy.unit) eaten · no goal set")
      }
    }
    .accessibilityElement(children: .combine)
  }

  private func contextFigure(_ value: String, caption: LocalizedStringKey) -> some View {
    VStack(spacing: 0) {
      Text(verbatim: value).heliosFont(.bodyStrong)
        .foregroundStyle(theme.palette.text.primary.color)
      Text(caption).heliosFont(.caption)
        .foregroundStyle(theme.palette.text.secondary.color)
    }
    .multilineTextAlignment(.center)
    .fixedSize(horizontal: false, vertical: true)
  }

  /// Three equal columns; one column per row at accessibility sizes or when they do not fit.
  @ViewBuilder private func macroGrid(_ rows: [Row]) -> some View {
    let cells = ForEach(rows) { row in macroCell(row) }
    if typeSize.isAccessibilitySize {
      VStack(alignment: .leading, spacing: HeliosTokens.space(3)) { cells }
    } else {
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .top, spacing: HeliosTokens.space(3)) { cells }
        VStack(alignment: .leading, spacing: HeliosTokens.space(3)) { cells }
      }
    }
  }

  private func macroCell(_ row: Row) -> some View {
    VStack(alignment: .leading, spacing: HeliosTokens.space(1)) {
      HStack(spacing: HeliosTokens.space(1)) {
        Circle().fill(row.color).frame(width: 8, height: 8).accessibilityHidden(true)
        Text(row.title).heliosFont(.metricLabel)
          .foregroundStyle(theme.palette.text.secondary.color)
          .fixedSize(horizontal: false, vertical: true)
      }
      Text("\(number(row.eaten, digits: 1)) \(row.unit)").heliosFont(.bodyStrong)
        .foregroundStyle(theme.palette.text.primary.color)
        .fixedSize(horizontal: false, vertical: true)
      if let goal = row.goal {
        Text("of \(number(goal, digits: 0)) \(row.unit)").heliosFont(.footnote)
          .foregroundStyle(theme.palette.text.secondary.color)
          .fixedSize(horizontal: false, vertical: true)
        meter(row.eaten / goal, color: row.color)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }

  private func meter(_ fraction: Double, color: Color) -> some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        Capsule().fill(theme.palette.border.hairline.color)
        Capsule().fill(color)
          .frame(width: proxy.size.width * min(max(fraction, 0), 1))
      }
    }
    .frame(height: 6)
    .accessibilityHidden(true)
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
      SectionHeader(active == nil ? "Training" : "Continue workout")
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
          Text(active?.name ?? last?.name ?? "Training").heliosFont(.bodyStrong)
            .fixedSize(horizontal: false, vertical: true)
          Text(detail(active: active, last: last)).heliosFont(.footnote)
            .foregroundStyle(theme.palette.text.secondary.color)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      if let active, let progress = Self.setProgress(active) {
        // Sets ticked so far out of the sets already added to this session.
        VStack(alignment: .leading, spacing: HeliosTokens.space(1)) {
          Text("\(progress.done) of \(progress.total) sets logged").heliosFont(.footnote)
            .foregroundStyle(theme.palette.text.secondary.color)
            .fixedSize(horizontal: false, vertical: true)
          GeometryReader { proxy in
            ZStack(alignment: .leading) {
              Capsule().fill(theme.palette.border.hairline.color)
              Capsule().fill(theme.palette.data.training.color)
                .frame(width: proxy.size.width * Double(progress.done) / Double(progress.total))
            }
          }
          .frame(height: 6)
          .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
      }
      if let hint = hint(last), active == nil {
        Text(hint).heliosFont(.callout)
          .fixedSize(horizontal: false, vertical: true)
      }
      Button {
        selectTab(.train)
      } label: {
        Text(active == nil ? "Start workout" : "Continue workout").frame(maxWidth: .infinity)
      }
      .buttonStyle(.heliosPrimary)
      .accessibilityIdentifier("todayStartWorkout")
    }
    .v2Surface()
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

  /// Completed sets out of all sets in the session; nil until a set has been added.
  private static func setProgress(_ workout: TrainingWorkout) -> (done: Int, total: Int)? {
    let total = workout.exercises.reduce(0) { $0 + $1.sets.count }
    guard total > 0 else { return nil }
    return (min(workout.completedSets.count, total), total)
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
  /// Set when paired, so the row knows when two tiles fit; nil when stacked.
  var idealWidth: CGFloat?
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
    .v2Surface()
    .frame(minWidth: 0, idealWidth: idealWidth, maxWidth: .infinity, alignment: .leading)
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
  /// Set when paired, so the row knows when two tiles fit; nil when stacked.
  var idealWidth: CGFloat?
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
      .v2Surface()
      .frame(minWidth: 0, idealWidth: idealWidth, maxWidth: .infinity, alignment: .leading)
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

extension View {
  /// A V2 card: padded, on the opaque tone of a glass level with the same edge and shadow,
  /// so text never sits on a see-through tint. Text contrast is audited on these tones.
  fileprivate func v2Surface(level: GlassLevel = .base) -> some View {
    padding(HeliosTokens.spacing[3])
      .background {
        GlassBackground(level: level)
          .transformEnvironment(\.heliosTheme) { $0.reduceTransparency = true }
      }
  }
}
