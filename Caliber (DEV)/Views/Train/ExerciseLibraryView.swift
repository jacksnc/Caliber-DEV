import SwiftData
import SwiftUI

struct ExerciseLibraryView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \TrainingExercise.name) private var exercises: [TrainingExercise]
  @State private var searchText = ""
  @State private var showingAdd = false
  @State private var message: String?

  private var filtered: [TrainingExercise] {
    let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !term.isEmpty else { return exercises }
    return exercises.filter {
      $0.name.localizedStandardContains(term) || $0.aliases.localizedStandardContains(term)
    }
  }

  var body: some View {
    List {
      Group {
        if filtered.isEmpty {
          ContentUnavailableView.search(text: searchText)
        } else {
          ForEach(filtered) { exercise in
            VStack(alignment: .leading, spacing: 4) {
              HStack {
                Text(exercise.name)
                if exercise.isCustom {
                  Text("Custom").font(.caption2).foregroundStyle(.secondary)
                }
              }
              Text(exercise.metricType.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(minHeight: 48, alignment: .leading)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
              if exercise.isCustom && exercise.workoutExercises.isEmpty {
                Button("Delete", role: .destructive) {
                  modelContext.delete(exercise)
                  do { try modelContext.save() } catch {
                    message = "The custom exercise could not be deleted."
                  }
                }
              }
            }
          }
        }
      }
      .listRowBackground(CaliberRowBackground())
    }
    .caliberScreen()
    .navigationTitle("Exercises")
    .toolbar(.visible, for: .navigationBar)
    .searchable(
      text: $searchText, placement: .navigationBarDrawer(displayMode: .always),
      prompt: "Name or alias"
    )
    .toolbar {
      Button {
        showingAdd = true
      } label: {
        Label("Add Exercise", systemImage: "plus")
          .accessibilityIdentifier("libraryCreateExercise")
      }
    }
    .sheet(isPresented: $showingAdd) { CustomExerciseView() }
    .alert(
      "Exercise Library",
      isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })
    ) {
      Button("OK", role: .cancel) { message = nil }
    } message: {
      Text(message ?? "Please try again.")
    }
  }
}
