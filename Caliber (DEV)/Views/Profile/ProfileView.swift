import CaliberCore
import SwiftData
import SwiftUI

struct ProfileView: View {
  /// True when Profile is presented as a sheet from the avatar button.
  var showsDone = false
  @Environment(\.dismiss) private var dismiss
  @Environment(\.locale) private var locale
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject private var account: HostedAccountModel
  @EnvironmentObject private var runtime: FoundationRuntime
  @Query private var profiles: [UserProfile]

  @State private var ageText = ""
  @State private var heightText = ""
  @State private var weightText = ""
  @State private var calorieText = ""
  @State private var proteinText = ""
  @State private var carbohydrateText = ""
  @State private var fatText = ""
  @State private var activity = ActivityLevel.sedentary
  @State private var coefficient = EnergyEquationCoefficient.plusFive
  @State private var goal = EnergyGoal.maintain
  @State private var weeklyRatePercent = 0.5
  @State private var estimate: EnergyTargetEstimate?
  @State private var message: String?
  @State private var didLoad = false

  private var massUnit: MassUnit { runtime.settings.massUnit }
  private var distanceUnit: DistanceUnit { runtime.settings.distanceUnit }

  var body: some View {
    NavigationStack {
      Form {
        Group {
          // Settings comes first: Profile opens from the avatar on every screen.
          Section("App") {
            NavigationLink("Settings") { FoundationSettingsView() }
              .frame(minHeight: 48)
              .accessibilityIdentifier("openSettings")
          }
          Section("Account") {
            Label(
              account.isSignedIn ? "Signed in" : "Local profile",
              systemImage: account.isSignedIn
                ? "person.crop.circle.badge.checkmark" : "person.crop.circle")
            NavigationLink("Account & Sync") { HostedAccountView() }
              .frame(minHeight: 48)
            Text(
              account.isSignedIn
                ? "Your account is connected. Health, food, workout, and photo data still stay on this device."
                : "An account is optional. Your profile and logs work offline on this device."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
          }

          Section {
            numericField("Age", text: $ageText, suffix: "years", identifier: "profileAge")
            numericField(
              "Height", text: $heightText, suffix: distanceUnit.rawValue,
              identifier: "profileHeight")
            numericField(
              "Weight", text: $weightText, suffix: massUnit.rawValue,
              identifier: "profileWeight")
            Picker(selection: $activity) {
              ForEach(ActivityLevel.allCases) { Text($0.displayName).tag($0) }
            } label: {
              Text("Activity").font(.body)
            }
          } header: {
            Text("Body and Activity")
          } footer: {
            Text("These values stay on this device and are used only to make a starting estimate.")
              .font(.footnote).fixedSize(horizontal: false, vertical: true)
          }

          Section {
            Picker("Equation form", selection: $coefficient) {
              Text("+5 coefficient").tag(EnergyEquationCoefficient.plusFive)
              Text("−161 coefficient").tag(
                EnergyEquationCoefficient.minusOneHundredSixtyOne)
            }
            Picker("Goal", selection: $goal) {
              ForEach(EnergyGoal.allCases, id: \.self) { Text(goalName($0)).tag($0) }
            }
            if goal == .cut || goal == .leanBulk || goal == .bulk {
              Picker("Weekly rate", selection: $weeklyRatePercent) {
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { value in
                  Text("\(value, format: .number)% body weight").tag(value)
                }
              }
            }
            Button("Calculate and Save Goals", action: calculateAndSave)
              .frame(minHeight: 48)
              .accessibilityIdentifier("profileCalculate")
          } header: {
            Text("Calorie Estimate")
          } footer: {
            Text(
              "Choose the published equation form explicitly. Caliber does not infer it from your name, appearance, or gender identity. The result is an estimate, not medical advice."
            )
          }

          if let estimate {
            Section("Estimate Details") {
              LabeledContent("Resting estimate", value: energy(estimate.restingEnergy))
              LabeledContent("Maintenance estimate", value: energy(estimate.maintenanceEnergy))
              LabeledContent("Saved calorie goal", value: energy(estimate.calorieTarget))
                .accessibilityIdentifier("profileSavedCalorieGoal")
              LabeledContent(
                "Macro starting point",
                value:
                  "\(estimate.proteinGrams.rounded().formatted(.number))g P · \(estimate.carbohydrateGrams.rounded().formatted(.number))g C · \(estimate.fatGrams.rounded().formatted(.number))g F"
              )
              LabeledContent(
                "Fiber starting point",
                value: "\(estimate.fiberGrams.rounded().formatted(.number)) g")
              if estimate.floorWasApplied {
                Label(
                  "The safety floor was applied instead of saving the lower calculated value.",
                  systemImage: "exclamationmark.shield"
                )
                .foregroundStyle(.orange)
              }
            }
          }

          Section {
            numericField(
              "Calories", text: $calorieText, suffix: "kcal", identifier: "profileCalories")
            numericField(
              "Protein", text: $proteinText, suffix: "g", identifier: "profileProtein")
            numericField(
              "Carbohydrates", text: $carbohydrateText, suffix: "g",
              identifier: "profileCarbohydrates")
            numericField("Fat", text: $fatText, suffix: "g", identifier: "profileFat")
            Button("Save Edited Goals", action: saveEditedGoals)
              .frame(minHeight: 48)
              .accessibilityIdentifier("profileSaveGoals")
          } header: {
            Text("Daily Goals")
          } footer: {
            Text("You can edit these goals after calculation. Calorie safety floors still apply.")
          }

        }
        .listRowBackground(CaliberRowBackground())
      }
      .caliberScreen()
      .navigationTitle("Profile")
      .toolbar {
        if showsDone {
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") { dismiss() }.frame(minHeight: 48).accessibilityIdentifier("closeProfile")
          }
        }
      }
      .onAppear(perform: loadOnce)
      .alert(
        "Profile",
        isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })
      ) {
        Button("OK", role: .cancel) { message = nil }
      } message: {
        Text(message ?? "Please check your entries.")
      }
    }
  }

  private func numericField(
    _ title: String, text: Binding<String>, suffix: String, identifier: String
  ) -> some View {
    LabeledContent(title) {
      HStack(spacing: 6) {
        TextField(title, text: text)
          .keyboardType(.decimalPad)
          .multilineTextAlignment(.trailing)
          .accessibilityIdentifier(identifier)
        Text(suffix).foregroundStyle(.secondary)
      }
    }
  }

  private func loadOnce() {
    guard !didLoad else { return }
    didLoad = true
    guard let profile = profiles.first else { return }
    heightText = number(
      distanceUnit == .centimeters ? profile.heightInInches * 2.54 : profile.heightInInches)
    let weightKilograms = profile.startingWeight * 0.45359237
    weightText = number(massUnit.fromKilograms(weightKilograms))
    activity = profile.activityLevel
    calorieText = number(profile.dailyCalorieGoal)
    proteinText = number(profile.proteinGoal)
    carbohydrateText = number(profile.carbGoal)
    fatText = number(profile.fatGoal)
  }

  private func calculateAndSave() {
    do {
      let body = try bodyValues(requireAge: true)
      let result = try EnergyTargetCalculator.estimate(
        EnergyTargetInput(
          weightKilograms: body.weightKilograms,
          heightCentimeters: body.heightCentimeters,
          ageYears: body.age,
          coefficient: coefficient,
          activityMultiplier: activity.activityMultiplier,
          weeklyWeightChangePercent:
            goal == .maintain || goal == .recomp ? 0 : weeklyRatePercent,
          goal: goal))
      try persist(
        body: body, calories: result.calorieTarget.rounded(),
        protein: result.proteinGrams.rounded(),
        carbohydrates: result.carbohydrateGrams.rounded(), fat: result.fatGrams.rounded())
      estimate = result
      message = "Your estimated daily goals were saved on this device."
    } catch {
      message = errorMessage(error)
    }
  }

  private func saveEditedGoals() {
    do {
      let body = try bodyValues(requireAge: false)
      let calories = try positive(calorieText)
      let protein = try nonnegative(proteinText)
      let carbohydrates = try nonnegative(carbohydrateText)
      let fat = try nonnegative(fatText)
      try EnergyTargetCalculator.validateManualTarget(
        calories: calories, coefficient: coefficient)
      let bmi = body.weightKilograms / pow(body.heightCentimeters / 100, 2)
      if goal == .cut, bmi < 18.5 { throw EnergyTargetError.deficitBlockedForLowBMI }
      try persist(
        body: body, calories: calories, protein: protein,
        carbohydrates: carbohydrates, fat: fat)
      estimate = nil
      message = "Your edited daily goals were saved on this device."
    } catch {
      message = errorMessage(error)
    }
  }

  private func persist(
    body: BodyValues, calories: Double, protein: Double, carbohydrates: Double, fat: Double
  ) throws {
    let profile: UserProfile
    if let existing = profiles.first {
      profile = existing
    } else {
      profile = UserProfile(
        heightInInches: body.heightCentimeters / 2.54,
        startingWeight: body.weightKilograms / 0.45359237,
        activityLevel: activity, dailyCalorieGoal: calories,
        proteinGoal: protein, carbGoal: carbohydrates, fatGoal: fat)
      modelContext.insert(profile)
    }
    profile.heightInInches = body.heightCentimeters / 2.54
    profile.startingWeight = body.weightKilograms / 0.45359237
    profile.activityLevel = activity
    profile.dailyCalorieGoal = calories
    profile.proteinGoal = protein
    profile.carbGoal = carbohydrates
    profile.fatGoal = fat
    try modelContext.save()
    calorieText = number(calories)
    proteinText = number(protein)
    carbohydrateText = number(carbohydrates)
    fatText = number(fat)
  }

  private func bodyValues(requireAge: Bool) throws -> BodyValues {
    let enteredWeight = try EnteredMass(text: weightText, unit: massUnit, locale: locale)
    guard enteredWeight.kilograms > 0 else { throw EnergyTargetError.invalidMeasurement }
    let enteredHeight = try positive(heightText)
    let heightCentimeters =
      distanceUnit == .centimeters ? enteredHeight : enteredHeight * 2.54
    let age: Int
    if requireAge {
      guard let parsed = Int(ageText),
        String(parsed) == ageText.trimmingCharacters(in: .whitespacesAndNewlines)
      else {
        throw EnergyTargetError.invalidAge
      }
      age = parsed
    } else {
      age = Int(ageText) ?? 18
    }
    return BodyValues(
      weightKilograms: enteredWeight.kilograms, heightCentimeters: heightCentimeters, age: age)
  }

  private func positive(_ text: String) throws -> Double {
    let value = try QuantityParsing.nonnegative(text, locale: locale)
    guard value > 0 else { throw EnergyTargetError.invalidMeasurement }
    return value
  }

  private func nonnegative(_ text: String) throws -> Double {
    try QuantityParsing.nonnegative(text, locale: locale)
  }

  private func number(_ value: Double) -> String {
    UnitFormatting.number(value, locale: locale, fractionDigits: 1)
  }

  private func energy(_ value: Double) -> String {
    "\(value.rounded().formatted(.number)) kcal/day"
  }

  private func goalName(_ value: EnergyGoal) -> String {
    switch value {
    case .cut: "Cut"
    case .maintain: "Maintain"
    case .leanBulk: "Lean Bulk"
    case .bulk: "Bulk"
    case .recomp: "Recomposition"
    }
  }

  private func errorMessage(_ error: Error) -> String {
    switch error as? EnergyTargetError {
    case .invalidAge: "Enter an age from 18 through 120."
    case .invalidMeasurement: "Enter valid height, weight, and goal numbers greater than zero."
    case .invalidActivityMultiplier: "Choose a valid activity level."
    case .invalidRate: "Choose a valid weekly rate."
    case .lossRateAboveLimit: "Weight-loss goals cannot exceed 1% of body weight per week."
    case .deficitBlockedForLowBMI:
      "Caliber cannot set a deficit goal when BMI is below 18.5. Please discuss your goal with a licensed clinician."
    case .incompatibleMacroTargets:
      "These calorie and macro inputs are incompatible. Increase calories or adjust the inputs."
    case .belowCalorieFloor(let minimum):
      "Caliber cannot save a target below \(minimum.formatted(.number)) kcal without a future clinician-override flow."
    case nil: "Check every field and try again."
    }
  }
}

private struct BodyValues {
  let weightKilograms: Double
  let heightCentimeters: Double
  let age: Int
}
