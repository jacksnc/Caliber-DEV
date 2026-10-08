//
//  BarcodeService.swift
//  Caliber (DEV)
//

import Foundation

/// Will eventually wrap a real barcode-scanning library. Left unimplemented
/// until we build the barcode scanning feature.
protocol BarcodeService {
    func lookupFood(barcode: String) async throws -> FoodItem?
}
