import CaliberCore
import HeliosDesign
import SwiftData
import SwiftUI

/// Four short steps. Values stay in this draft until the final Save button.
struct GoalSetupView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var context
  @Environment(\.locale) private var locale
  @Environment(\.heliosTheme) private var theme
  @Environment(\.dynamicTypeSize) private var typeSize
  @EnvironmentObject private var runtime: FoundationRuntime
  let profile: UserProfile?
  @State private var mass: MassUnit
  @State private var length: DistanceUnit
  @State private var draft = GoalSetupDraft()
  @State private var step = 0
  @State private var didLoad = false
  @State private var message: String?
  @FocusState private var focusedField: String?

  init(profile: UserProfile?, mass: MassUnit, length: DistanceUnit) {
    self.profile = profile
    _mass = State(initialValue: mass)
    _length = State(initialValue: length)
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Text("Step \(step + 1) of 4").heliosFont(.footnote)
            .foregroundStyle(theme.palette.text.secondary.color)
            .accessibilityIdentifier("goalSetupStep")
          ProgressView(value: Double(step + 1), total: 4)
            .accessibilityLabel("Goal setup progress")
          if runtime.settings.hideNumbers {
            Text(
              "Goal numbers are hidden. You can return to setup after changing this in Settings."
            )
            .fixedSize(horizontal: false, vertical: true)
          } else {
            stepContent
            if let message {
              Text(message).foregroundStyle(theme.palette.status.warning.color)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("goalSetupError")
            }
          }
        }
        .padding()
      }
      .caliberScreen()
      .scrollDismissesKeyboard(.interactively)
      .navigationTitle("Your nutrition goals")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") { focusedField = nil }.accessibilityIdentifier("goalSetupKeyboardDone")
        }
      }
      .safeAreaInset(edge: .bottom) { footer }
      .onAppear(perform: load)
      .onChange(of: mass) { old, new in draft.changeMass(from: old, to: new, locale: locale) }
      .onChange(of: length) { old, new in draft.changeLength(from: old, to: new, locale: locale) }
      .onChange(of: draft.goal) { _, new in
        if new == .maintain || new == .recomp { draft.setTargetWeight("") }
        message = nil
      }
    }
  }

  @ViewBuilder private var stepContent: some View {
    switch step {
    case 0: bodyStep
    case 1: estimateStep
    case 2: goalStep
    default: reviewStep
    }
  }

  private var bodyStep: some View {
    VStack(alignment: .leading, spacing: 16) {
      heading(
        "Your starting point",
        detail: "These values are used for a starting estimate and stay on this device.")
      field("Age (18 or older)", text: $draft.age, id: "goalSetupAge", integer: true)
      Picker("Height unit", selection: $length) {
        ForEach(DistanceUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
      }.pickerStyle(.segmented).accessibilityIdentifier("goalSetupHeightUnit")
      field(
        "Height (\(length.rawValue))",
        text: Binding(get: { draft.height }, set: { draft.setHeight($0) }), id: "goalSetupHeight")
      Picker("Weight unit", selection: $mass) {
        ForEach(MassUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
      }.pickerStyle(.segmented).accessibilityIdentifier("goalSetupWeightUnit")
      field(
        "Current weight (\(mass.rawValue))",
        text: Binding(get: { draft.weight }, set: { draft.setWeight($0) }), id: "goalSetupWeight")
      Text("This does not add a weigh-in to Progress. You can log one there separately.")
        .heliosFont(.footnote).foregroundStyle(theme.palette.text.secondary.color)
    }.glassCard()
  }

  private var estimateStep: some View {
    VStack(alignment: .leading, spacing: 16) {
      heading(
        "Choose your starting estimate",
        detail:
          "The Mifflin–St Jeor equation uses one of two sex-based forms. Choose the form you want to use; Caliber does not infer it from your identity."
      )
      ForEach(EnergyEquationCoefficient.allCases, id: \.self) { value in
        Button {
          draft.coefficient = value
          message = nil
        } label: {
          HStack {
            Text(value == .plusFive ? "Male equation form (+5)" : "Female equation form (−161)")
              .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Image(systemName: draft.coefficient == value ? "checkmark.circle.fill" : "circle")
              .accessibilityHidden(true)
          }.frame(minHeight: 48).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(draft.coefficient == value ? [.isSelected] : [])
        .accessibilityIdentifier("goalSetupEquation-" + value.rawValue)
      }
      Text(
        "Not sure which form to use? You can set up later and enter your own daily goals in Profile."
      )
      .heliosFont(.footnote).foregroundStyle(theme.palette.text.secondary.color)
      Picker("Activity", selection: $draft.activity) {
        ForEach(ActivityLevel.allCases) { Text($0.displayName).tag($0) }
      }.accessibilityIdentifier("goalSetupActivity")
      Text("Activity and calorie needs are estimates. You can change your inputs later.")
        .heliosFont(.footnote).foregroundStyle(theme.palette.text.secondary.color)
    }.glassCard()
  }

  private var goalStep: some View {
    VStack(alignment: .leading, spacing: 16) {
      heading(
        "What are you working toward?",
        detail: "Choose a starting goal. Your saved targets remain editable.")
      ForEach(EnergyGoal.allCases, id: \.self) { value in
        Button {
          draft.chooseGoal(value)
        } label: {
          HStack {
            Text(value.goalSetupName).fixedSize(horizontal: false, vertical: true)
            Spacer()
            Image(systemName: draft.goal == value ? "checkmark.circle.fill" : "circle")
              .accessibilityHidden(true)
          }.frame(minHeight: 48).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(draft.goal == value ? [.isSelected] : [])
        .accessibilityIdentifier("goalSetupGoal-" + value.rawValue)
      }
      if draft.goal != .maintain && draft.goal != .recomp {
        Picker("Weekly rate", selection: $draft.weeklyRate) {
          ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { value in
            Text("\(value, format: .number)% of body weight per week").tag(value)
          }
        }.accessibilityIdentifier("goalSetupRate")
        field(
          "Target weight (\(mass.rawValue), optional)",
          text: Binding(get: { draft.targetWeight }, set: { draft.setTargetWeight($0) }),
          id: "goalSetupTargetWeight")
        Text("A target is optional. Caliber does not promise a rate of change or a finish date.")
          .heliosFont(.footnote).foregroundStyle(theme.palette.text.secondary.color)
      }
    }.glassCard()
  }

  private var reviewStep: some View {
    VStack(alignment: .leading, spacing: 16) {
      heading(
        "Review your daily goals",
        detail:
          "This is a starting estimate, not a prescription. Only Save goals changes your profile.")
      Text(draft.goal.goalSetupName).heliosFont(.section)
      if let plan = try? draft.plan(mass: mass, length: length, locale: locale) {
        Text("\(plan.targets.calories, format: .number.precision(.fractionLength(0...1))) kcal/day")
          .heliosFont(.hero).fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("goalSetupReviewCalories")
        Text(
          "\(plan.targets.protein, format: .number.precision(.fractionLength(0...1))) g protein · \(plan.targets.carbohydrates, format: .number.precision(.fractionLength(0...1))) g carbs · \(plan.targets.fat, format: .number.precision(.fractionLength(0...1))) g fat"
        )
        .fixedSize(horizontal: false, vertical: true)
        if let estimate = try? EnergyTargetCalculator.estimate(plan.input), estimate.floorWasApplied
        {
          Text("The starting estimate was raised to Caliber's calorie safety floor.")
            .heliosFont(.footnote).fixedSize(horizontal: false, vertical: true)
        }
      }
      Toggle("Adjust these targets", isOn: $draft.overridesEstimate)
        .accessibilityIdentifier("goalSetupEditTargets")
      if draft.overridesEstimate {
        field("Calories per day", text: $draft.calories, id: "goalSetupCalories")
        field("Protein (g)", text: $draft.protein, id: "goalSetupProtein")
        field("Carbohydrates (g)", text: $draft.carbohydrates, id: "goalSetupCarbohydrates")
        field("Fat (g)", text: $draft.fat, id: "goalSetupFat")
      }
      Text(
        "Your measurements and targets stay on this device. This does not enable cloud sync, Health access or photo uploads."
      )
      .heliosFont(.footnote).foregroundStyle(theme.palette.text.secondary.color)
      Text(
        "Caliber is a logging and education tool, not medical advice. Consult a licensed clinician for medical decisions."
      )
      .heliosFont(.footnote).foregroundStyle(theme.palette.text.secondary.color)
    }.glassCard()
  }

  private var footer: some View {
    VStack(spacing: 8) {
      (typeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))) {
          if step > 0 {
            Button {
              focusedField = nil
              step -= 1
              message = nil
            } label: {
              Text("Back").frame(maxWidth: .infinity, minHeight: 48)
                .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.heliosSecondary).accessibilityIdentifier("goalSetupBack")
          }
          Button(action: advance) {
            Text(step == 3 ? "Save goals" : "Next")
              .frame(maxWidth: .infinity, minHeight: 48)
              .fixedSize(horizontal: false, vertical: true)
          }
          .buttonStyle(.heliosPrimary)
          .disabled(runtime.settings.hideNumbers)
          .accessibilityIdentifier(step == 3 ? "goalSetupSave" : "goalSetupNext")
        }
      Button("Set up later") { dismiss() }
        .frame(maxWidth: .infinity, minHeight: 48)
        .accessibilityIdentifier("goalSetupCancel")
    }
    .padding()
    .background { theme.palette.canvasBottom.color.ignoresSafeArea(edges: .bottom) }
  }

  private func heading(_ title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).heliosFont(.title).accessibilityAddTraits(.isHeader)
      Text(detail).fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(theme.palette.text.secondary.color)
    }
  }

  private func field(_ title: String, text: Binding<String>, id: String, integer: Bool = false)
    -> some View
  {
    VStack(alignment: .leading, spacing: 4) {
      Text(title).heliosFont(.footnote).fixedSize(horizontal: false, vertical: true)
      TextField("", text: text)
        .keyboardType(integer ? .numberPad : .decimalPad)
        .focused($focusedField, equals: id)
        .padding(12).frame(minHeight: 48)
        .background { GlassBackground(level: .raised, cornerRadius: 12) }
        .accessibilityLabel(title).accessibilityIdentifier(id)
    }
  }

  private func load() {
    guard !didLoad else { return }
    didLoad = true
    let plan = profile.flatMap { try? GoalSetupEditor.latest(for: $0.id, in: context)?.plan }
    draft = .loaded(profile: profile, plan: plan, mass: mass, length: length, locale: locale)
  }

  private func advance() {
    focusedField = nil
    message = nil
    do {
      if step == 0 {
        try draft.validateBody(mass: mass, length: length, locale: locale)
      } else if step == 1 {
        var input = try draft.input(mass: mass, length: length, locale: locale)
        // Goal selection is next. A saved cut must not prevent choosing Maintain.
        input.goal = .maintain
        input.weeklyWeightChangePercent = 0
        _ = try EnergyTargetCalculator.estimate(input)
      } else {
        let plan = try draft.plan(mass: mass, length: length, locale: locale)
        if step == 3 {
          let existing = try (profile ?? context.fetch(FetchDescriptor<UserProfile>()).first)
          try GoalSetupEditor.save(plan, replacing: existing, in: context)
          dismiss()
          return
        }
        if !draft.overridesEstimate { draft.showEstimate(plan, locale: locale) }
      }
      step += 1
    } catch { message = GoalSetupMessages.message(for: error) }
  }
}

extension EnergyGoal {
  var goalSetupName: String {
    switch self {
    case .cut: "Lose weight"
    case .maintain: "Maintain weight"
    case .leanBulk: "Lean bulk"
    case .bulk: "Gain weight"
    case .recomp: "Recomposition"
    }
  }
}

enum GoalSetupMessages {
  static func message(for error: Error) -> String {
    switch error {
    case GoalSetupDraftError.chooseEquation: "Choose an equation form to continue."
    case EnergyTargetError.invalidAge: "Enter a whole-number age from 18 through 120."
    case EnergyTargetError.invalidMeasurement, QuantityError.invalidNumber, QuantityError.negative:
      "Enter valid positive height and weight numbers, using your selected number format."
    case EnergyTargetError.lossRateAboveLimit:
      "Weight-loss goals cannot exceed 1% of body weight per week."
    case EnergyTargetError.deficitBlockedForLowBMI:
      "Caliber cannot set a deficit goal when BMI is below 18.5. Please discuss your goal with a licensed clinician."
    case EnergyTargetError.belowCalorieFloor(let floor):
      "This target is below Caliber's \(floor.formatted(.number)) kcal safety floor."
    case GoalSetupError.invalidTargetWeight: "Enter a valid target weight, or leave it blank."
    case GoalSetupError.targetDirection:
      "Choose a target below your starting weight for loss, or above it for gain."
    case GoalSetupError.targetBelowMinimumBMI:
      "Caliber cannot set a weight-loss target below BMI 18.5. Please discuss your goal with a licensed clinician."
    case GoalSetupError.invalidMacros: "Enter finite, nonnegative calorie and macro targets."
    case EnergyTargetError.incompatibleMacroTargets:
      "The calorie and macro estimates do not fit together. Review your inputs."
    default: "Your goals could not be saved. Check your entries and try again."
    }
  }
}
