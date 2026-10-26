import HeliosDesign
import StackCore
import SwiftData
import SwiftUI

/// Adds or edits one compound with the person's own amount and schedule (STK-01, STK-02).
/// No field is prefilled with a suggested amount, time or half-life.
struct StackCompoundEditor: View {
  let compound: StackCompound?
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  @Environment(\.locale) private var locale
  @Environment(\.calendar) private var calendar
  @State private var name = ""
  @State private var form = StackForm.pen
  @State private var unit = StackUnit.mg
  @State private var amount = ""
  @State private var repeatPattern = StackRepeat.daily
  @State private var intervalDays = 2
  @State private var weekdays: Set<Int> = []
  @State private var time = Date.now
  @State private var startDate = Date.now
  @State private var tracksSupply = false
  @State private var supplyDoses = 4
  @State private var supplyStarted = Date.now
  @State private var halfLife = ""
  @State private var halfLifeInDays = true
  @State private var halfLifeSource = ""
  @State private var notes = ""
  @State private var isPaused = false
  @State private var problem: String?
  @State private var confirmsDelete = false
  @State private var didLoad = false

  var body: some View {
    NavigationStack {
      Form {
        Group {
          Section {
            TextField("Name", text: $name)
              .accessibilityIdentifier("stackName")
            Picker("Form", selection: $form) {
              ForEach(StackForm.allCases) { Text($0.title).tag($0) }
            }
          } header: {
            Text("What you take")
          }

          Section {
            LabeledContent("Amount") {
              TextField("Your amount", text: $amount)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .accessibilityIdentifier("stackAmount")
            }
            Picker("Unit", selection: $unit) {
              ForEach(StackUnit.allCases) { Text($0.symbol).tag($0) }
            }
          } header: {
            Text("Amount")
          } footer: {
            Text("Enter the amount from your own plan or prescription. Stack does not suggest one.")
          }

          Section {
            Picker("Repeat", selection: $repeatPattern) {
              ForEach(StackRepeat.allCases) { Text($0.title).tag($0) }
            }
            .accessibilityIdentifier("stackRepeat")
            if repeatPattern == .everyNDays {
              Stepper("Every \(intervalDays) days", value: $intervalDays, in: 2...60)
            }
            if repeatPattern == .weekdays {
              StackWeekdayPicker(selection: $weekdays)
            }
            if repeatPattern != .asNeeded {
              DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
              DatePicker("Starts", selection: $startDate, displayedComponents: .date)
            }
            if compound != nil {
              Toggle("Paused", isOn: $isPaused)
            }
          } header: {
            Text("Schedule")
          }

          Section {
            Toggle("Track supply", isOn: $tracksSupply)
            if tracksSupply {
              Stepper("\(supplyDoses) doses in this supply", value: $supplyDoses, in: 1...365)
              DatePicker("Started", selection: $supplyStarted, displayedComponents: .date)
            }
          } header: {
            Text("Supply")
          } footer: {
            Text("Each dose logged after the start date counts down the supply.")
          }

          Section {
            LabeledContent("Half-life") {
              TextField("Optional", text: $halfLife)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .accessibilityIdentifier("stackHalfLife")
            }
            Picker("Unit", selection: $halfLifeInDays) {
              Text("Days").tag(true)
              Text("Hours").tag(false)
            }
            .pickerStyle(.segmented)
            TextField("Where this value comes from", text: $halfLifeSource)
              .accessibilityIdentifier("stackHalfLifeSource")
          } header: {
            Text("Estimate")
          } footer: {
            Text(
              "Optional. With a half-life and its source, Stack draws a simplified, illustrative estimate. It is not a blood level. Leave it empty to turn the estimate off."
            )
          }

          Section("Notes") {
            TextField("Optional", text: $notes, axis: .vertical)
          }

          if let problem {
            Section {
              Label(problem, systemImage: "exclamationmark.triangle")
                .accessibilityIdentifier("stackEditorProblem")
            }
          }

          if compound != nil {
            Section {
              Button("Delete from Stack", role: .destructive) { confirmsDelete = true }
                .frame(minHeight: 48)
            } footer: {
              Text("Deleting also removes its logged doses.")
            }
          }
        }
        .listRowBackground(CaliberRowBackground())
      }
      .caliberScreen()
      .navigationTitle(compound == nil ? "Add to Stack" : "Edit")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save", action: save).accessibilityIdentifier("stackSave")
        }
      }
      .confirmationDialog(
        "Delete \(name) and its logged doses?", isPresented: $confirmsDelete,
        titleVisibility: .visible
      ) {
        Button("Delete", role: .destructive, action: delete)
      }
      .onAppear(perform: load)
    }
  }

  private func load() {
    guard !didLoad else { return }
    didLoad = true
    guard let compound else { return }
    name = compound.name
    form = compound.form
    unit = compound.unit
    amount = StackDecimal.display(compound.amountText, locale: locale)
    repeatPattern = compound.repeatPattern
    intervalDays = max(2, compound.intervalDays)
    weekdays = Set(compound.weekdays)
    time =
      calendar.date(
        byAdding: .minute, value: compound.timeMinutes, to: calendar.startOfDay(for: .now))
      ?? .now
    startDate = compound.startDate
    tracksSupply = compound.supplyDoses > 0
    supplyDoses = max(1, compound.supplyDoses)
    supplyStarted = compound.supplyStartedAt ?? .now
    if let hours = compound.halfLifeHours {
      halfLifeInDays = hours >= 48
      halfLife = StackText.number(halfLifeInDays ? hours / 24 : hours)
    }
    halfLifeSource = compound.halfLifeSource
    notes = compound.notes
    isPaused = compound.isPaused
  }

  private func save() {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      problem = "Enter a name."
      return
    }
    guard let canonical = StackDecimal.canonical(amount, locale: locale) else {
      problem = "Enter your amount as a number greater than zero."
      return
    }
    if repeatPattern == .weekdays && weekdays.isEmpty {
      problem = "Choose at least one day."
      return
    }
    var halfLifeHours: Double?
    if !halfLife.trimmingCharacters(in: .whitespaces).isEmpty {
      guard let value = StackDecimal.canonical(halfLife, locale: locale).flatMap(Double.init)
      else {
        problem = "Enter the half-life as a number, or leave it empty."
        return
      }
      guard !halfLifeSource.trimmingCharacters(in: .whitespaces).isEmpty else {
        problem = "Say where the half-life comes from, or leave it empty."
        return
      }
      halfLifeHours = halfLifeInDays ? value * 24 : value
    }
    let parts = calendar.dateComponents([.hour, .minute], from: time)
    let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    let target =
      compound
      ?? StackCompound(
        name: trimmed, form: form, unit: unit, amountText: canonical,
        repeatPattern: repeatPattern, timeMinutes: minutes, startDate: startDate)
    target.name = trimmed
    target.formRaw = form.rawValue
    target.unitRaw = unit.rawValue
    target.amountText = canonical
    target.repeatRaw = repeatPattern.rawValue
    target.intervalDays = repeatPattern == .everyNDays ? intervalDays : 1
    target.weekdays = repeatPattern == .weekdays ? weekdays.sorted() : []
    target.timeMinutes = minutes
    target.startDate = startDate
    target.isPaused = isPaused
    target.supplyDoses = tracksSupply ? supplyDoses : 0
    target.supplyStartedAt = tracksSupply ? supplyStarted : nil
    target.halfLifeHours = halfLifeHours
    target.halfLifeSource = halfLifeHours == nil ? "" : halfLifeSource
    target.notes = notes
    if compound == nil { context.insert(target) }
    do {
      try context.save()
      dismiss()
    } catch {
      problem = "Stack could not save this. Try again."
    }
  }

  private func delete() {
    guard let compound else { return }
    context.delete(compound)
    try? context.save()
    dismiss()
  }
}

/// Seven day toggles, Monday first, using ISO weekday numbers.
private struct StackWeekdayPicker: View {
  @Binding var selection: Set<Int>
  @Environment(\.calendar) private var calendar

  var body: some View {
    let symbols = calendar.shortWeekdaySymbols
    VStack(alignment: .leading) {
      Text("Days")
      FlowingChips(items: Array(1...7)) { day in
        // Calendar symbols start at Sunday; ISO weekday 7 is Sunday.
        let label = symbols[day % 7]
        Button {
          if selection.contains(day) { selection.remove(day) } else { selection.insert(day) }
        } label: {
          HeliosChip(LocalizedStringKey(label), isSelected: selection.contains(day))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection.contains(day) ? .isSelected : [])
      }
    }
  }
}

/// Wraps chips onto as many rows as the text size needs.
private struct FlowingChips<Content: View>: View {
  let items: [Int]
  @ViewBuilder let content: (Int) -> Content

  var body: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 8)], alignment: .leading) {
      ForEach(items, id: \.self) { content($0) }
    }
  }
}

/// Logs one dose the person has taken (STK-04). The amount starts as their own planned
/// amount; they can change it. A second dose soon after the last asks for confirmation.
struct StackLogDoseView: View {
  let request: StackLogRequest
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  @Environment(\.locale) private var locale
  @Environment(\.heliosTheme) private var theme
  @State private var amount = ""
  @State private var takenAt = Date.now
  @State private var site = ""
  @State private var notes = ""
  @State private var problem: String?
  @State private var doubleDoseHours: Double?
  @State private var didLoad = false

  var body: some View {
    NavigationStack {
      Form {
        Group {
          Section {
            LabeledContent("Amount taken") {
              HStack(spacing: 6) {
                TextField("Amount", text: $amount)
                  .keyboardType(.decimalPad)
                  .multilineTextAlignment(.trailing)
                  .accessibilityIdentifier("stackLogAmount")
                Text(request.compound.unit.symbol)
                  .foregroundStyle(theme.palette.text.secondary.color)
              }
            }
            DatePicker("Taken", selection: $takenAt, in: ...Date.now)
            TextField("Site (optional)", text: $site)
            TextField("Notes (optional)", text: $notes, axis: .vertical)
          } header: {
            Text(request.compound.name)
          } footer: {
            if let scheduled = request.scheduledFor {
              Text("Planned for \(scheduled.formatted(date: .abbreviated, time: .shortened)).")
            }
          }

          if let hours = doubleDoseHours {
            Section {
              Label(
                "You logged \(request.compound.name) \(StackText.number(hours)) hours before this time. Log another dose?",
                systemImage: "exclamationmark.triangle.fill"
              )
              .foregroundStyle(theme.palette.status.warning.color)
              Button("Log Another Dose") { save(confirmed: true) }
                .frame(minHeight: 48)
                .accessibilityIdentifier("stackConfirmDoubleDose")
            }
          }

          if let problem {
            Section { Label(problem, systemImage: "exclamationmark.triangle") }
          }
        }
        .listRowBackground(CaliberRowBackground())
      }
      .caliberScreen()
      .navigationTitle("Log Dose")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { save(confirmed: false) }.accessibilityIdentifier("stackLogSave")
        }
      }
      .onAppear {
        guard !didLoad else { return }
        didLoad = true
        amount = StackDecimal.display(request.compound.amountText, locale: locale)
      }
    }
  }

  private func save(confirmed: Bool) {
    guard let canonical = StackDecimal.canonical(amount, locale: locale) else {
      problem = "Enter the amount you took as a number greater than zero."
      return
    }
    if !confirmed,
      let warning = StackPlanner.doubleDoseWarning(for: request.compound, at: takenAt)
    {
      doubleDoseHours = warning.hoursSinceLast
      return
    }
    context.insert(
      StackDose(
        compound: request.compound, amountText: canonical, takenAt: takenAt,
        scheduledFor: request.scheduledFor, site: site, notes: notes))
    do {
      try context.save()
      dismiss()
    } catch {
      problem = "Stack could not save this dose. Try again."
    }
  }
}

/// Decimal entry in the person's locale, stored as an exact POSIX decimal string.
enum StackDecimal {
  static func canonical(_ text: String, locale: Locale) -> String? {
    let formatter = NumberFormatter()
    formatter.locale = locale
    formatter.numberStyle = .decimal
    formatter.generatesDecimalNumbers = true
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    guard let number = formatter.number(from: trimmed) as? NSDecimalNumber,
      number.compare(NSDecimalNumber.zero) == .orderedDescending
    else { return nil }
    return number.decimalValue.description
  }

  static func display(_ canonical: String, locale: Locale) -> String {
    guard let value = Decimal(string: canonical, locale: Locale(identifier: "en_US_POSIX"))
    else { return canonical }
    return value.formatted(.number.locale(locale).grouping(.never))
  }
}
