import Foundation
import SwiftUI

/// One Fuel navigation stack owns the library and its branches.
enum CaliberFuelDestination: Hashable { case library, search, barcode, restaurants, meals, foods }

struct CaliberFuelDestinationView: View {
  let destination: CaliberFuelDestination

  var body: some View {
    switch destination {
    case .library: FoodLibraryView()
    case .search: FoodSearchView()
    case .barcode: BarcodeFoodLookupView()
    case .restaurants: RestaurantListView()
    case .meals: MyMealsView()
    case .foods: MyFoodsView()
    }
  }
}

/// Navigation only: these destinations never insert records or enable sharing.
enum CaliberWidgetDestination: Equatable {
  case fuel, addFood

  init?(url: URL) {
    guard url.scheme?.lowercased() == "caliber" else { return nil }
    if url.host == "fuel", url.path.isEmpty {
      self = .fuel
    } else if url.host == "food", url.path == "/add" {
      self = .addFood
    } else {
      return nil
    }
  }
}

struct CaliberWidgetRequest: Equatable {
  let id = UUID()
  let destination: CaliberWidgetDestination
}

/// Profile owns its sheet locally. Report its presence so an external link waits
/// for the person to finish instead of changing tabs underneath an open editor.
private struct CaliberExternalNavigationPresenceKey: EnvironmentKey {
  static let defaultValue: (UUID, Bool) -> Void = { _, _ in }
}

extension EnvironmentValues {
  var caliberExternalNavigationPresence: (UUID, Bool) -> Void {
    get { self[CaliberExternalNavigationPresenceKey.self] }
    set { self[CaliberExternalNavigationPresenceKey.self] = newValue }
  }
}

private struct CaliberExternalNavigationHold: ViewModifier {
  @State private var presenceID = UUID()
  @Environment(\.caliberExternalNavigationPresence) private var reportPresence

  func body(content: Content) -> some View {
    content
      .onAppear { reportPresence(presenceID, true) }
      .onDisappear { reportPresence(presenceID, false) }
  }
}

extension View {
  /// Keep a shared draft editor intact until its presenting screen dismisses it.
  func defersExternalWidgetNavigation() -> some View {
    modifier(CaliberExternalNavigationHold())
  }
}
