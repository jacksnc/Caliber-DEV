//
//  AIScannerService.swift
//  Caliber (DEV)
//

import Foundation

/// Will eventually send a photo plus optional parameters (restaurant name,
/// portion size) to our backend, which identifies the food and looks up exact
/// nutrition from our restaurant database. Left unimplemented until that
/// backend exists — never call a third-party AI API directly from the app.
/// `imageData` is platform-agnostic (e.g. JPEG/PNG bytes) so this protocol
/// doesn't depend on UIKit, which isn't available on every build platform.
protocol AIScannerService {
    func identifyFood(imageData: Data, hint: String?) async throws -> FoodItem
}
