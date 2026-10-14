#!/usr/bin/env python3
"""Lint new Foundation files without reformatting unrelated existing screens."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
paths = sorted((ROOT / 'Packages/CaliberFoundation/Sources').rglob('*.swift'))
paths += sorted((ROOT / 'Packages/CaliberFoundation/Tests').rglob('*.swift'))
paths += [ROOT / 'Packages/CaliberFoundation/Package.swift']
paths += [ROOT / p for p in [
    'Caliber (DEV)/App/FoundationRuntime.swift',
    'Caliber (DEV)/Views/RootTabView.swift',
    'Caliber (DEV)/App/HostedAccountModel.swift',
    'Caliber (DEV)/Views/Foundation/HostedAccountView.swift',
    'Caliber (DEV)/Services/LegacySnapshotAdapter.swift',
    'Caliber (DEV)/Services/LegacyRestoreRehearsal.swift',
    'Caliber (DEV)/Views/Foundation/FoundationSettingsView.swift',
    'Caliber (DEV)/Views/Foundation/TodayFoundationView.swift',
    'Caliber (DEV)Tests/LegacySnapshotTests.swift',
    'Caliber (DEV)Tests/LegacyRestoreTests.swift',
    'Caliber (DEV)Tests/HostedAccountTests.swift',
    'Caliber (DEV)UITests/FoundationUITests.swift',
]]
# Food pipeline and rehearsal changes belong to the same strict verification scope.
paths += [ROOT / p for p in [
    'Caliber (DEV)/App/BarcodeLookupCoordinator.swift',
    'Caliber (DEV)/Views/Diary/FoodSearchView.swift',
    'Caliber (DEV)/Views/Diary/FoodNutritionReviewView.swift',
    'Caliber (DEV)/Views/Diary/BarcodeFoodLookupView.swift',
    'Caliber (DEV)/Views/Diary/BarcodeScannerView.swift',
    'Caliber (DEV)/Views/FoodLibrary/FoodLibraryView.swift',
    'Caliber (DEV)/Views/Restaurants/RestaurantListView.swift',
    'Caliber (DEV)/Views/Restaurants/RestaurantDetailView.swift',
    'Caliber (DEV)/Views/Restaurants/AddRestaurantView.swift',
    'Caliber (DEV)/Services/BarcodeCaptureService.swift',
    'Caliber (DEV)/Services/BarcodeNutritionProduct.swift',
    'Caliber (DEV)/Services/BarcodeService.swift',
    'Caliber (DEV)/Services/OpenFoodFactsBarcodeService.swift',
    'Caliber (DEV)/Services/FoodCatalogTypes.swift',
    'Caliber (DEV)/Services/FoodNutritionReference.swift',
    'Caliber (DEV)/Services/BundledFoodSearchService.swift',
    'Caliber (DEV)/Services/FoodSearchService.swift',
    'Caliber (DEV)/Services/RestaurantSourceDirectory.swift',
    'Caliber (DEV)/Utilities/BarcodeValue.swift',
    'Caliber (DEV)Tests/BarcodeValueTests.swift',
    'Caliber (DEV)Tests/BarcodeLookupTests.swift',
    'Caliber (DEV)Tests/BarcodeCoordinatorTests.swift',
    'Caliber (DEV)Tests/FoodCatalogTests.swift',
    'Caliber (DEV)Tests/ReferenceFoodLoggingTests.swift',
    'Caliber (DEV)UITests/FoodExperienceUITests.swift',
    'Caliber (DEV)UITests/RestaurantCustomizationUITests.swift',
]]
subprocess.run(['xcrun', 'swift-format', 'lint', '--strict', *map(str, paths)], cwd=ROOT, check=True)
