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
paths += [ROOT / p for p in [
    'Caliber (DEV)/App/FoodLibraryPreferences.swift',
    'Caliber (DEV)/Services/FoodReuseIndex.swift',
    'Caliber (DEV)/Services/FoodReuseUITestFixture.swift',
    'Caliber (DEV)/Utilities/FoodFavoriteEditor.swift',
    'Caliber (DEV)/Utilities/FoodPortionMath.swift',
    'Caliber (DEV)/Utilities/DiaryDay.swift',
    'Caliber (DEV)/Utilities/DiaryRepeatLogger.swift',
    'Caliber (DEV)/Views/Diary/CopyDiaryView.swift',
    'Caliber (DEV)/Views/Diary/DiaryView.swift',
    'Caliber (DEV)/Views/MyFoods/SavedFoodDetailView.swift',
    'Caliber (DEV)/Views/MyFoods/MyFoodsView.swift',
    'Caliber (DEV)/Views/MyMeals/SavedMealDetailView.swift',
    'Caliber (DEV)/Views/MyMeals/RecipeEditorView.swift',
    'Caliber (DEV)/Views/MyMeals/RecipeIngredientPicker.swift',
    'Caliber (DEV)/Services/RecipeEditor.swift',
    'Caliber (DEV)/Services/RecipeIngredientDraft.swift',
    'Caliber (DEV)/Utilities/RecipeBatchNutrition.swift',
    'Caliber (DEV)Tests/RecipeBatchNutritionTests.swift',
    'Caliber (DEV)Tests/RecipePersistenceTests.swift',
    'Caliber (DEV)UITests/RecipeBuilderUITests.swift',
    'Caliber (DEV)/Views/Restaurants/BuildYourOwnView.swift',
    'Caliber (DEV)/Views/Restaurants/MenuItemDetailView.swift',
    'Caliber (DEV)Tests/FoodReuseIndexTests.swift',
    'Caliber (DEV)Tests/FoodLibraryPreferencesTests.swift',
    'Caliber (DEV)Tests/DiaryRepeatLoggerTests.swift',
    'Caliber (DEV)Tests/FoodFavoriteEditorTests.swift',
    'Caliber (DEV)Tests/FoodPortionMathTests.swift',
    'Caliber (DEV)Tests/DiaryDayTests.swift',
]]
paths += [ROOT / 'Caliber (DEV)UITests/FoodShortcutsUITests.swift']
paths += [ROOT / 'Caliber (DEV)/Views/Components/MacroOverrideSection.swift']
paths += [ROOT / 'Caliber (DEV)Tests/ExpandedFoodDatabaseTests.swift']
paths += [ROOT / 'Caliber (DEV)/Services/BundledBarcodeService.swift']
paths += [ROOT / 'Caliber (DEV)Tests/PackagedBarcodeTests.swift']
paths += [ROOT / p for p in [
    'Caliber (DEV)/Services/BundledRestaurantMenuService.swift',
    'Caliber (DEV)/Views/Restaurants/ImportedRestaurantMenuView.swift',
    'Caliber (DEV)Tests/ImportedRestaurantMenuTests.swift',
]]
paths += [ROOT / 'Caliber (DEV)/Views/Components/CaliberAppearance.swift']
paths += [ROOT / 'Caliber (DEV)UITests/ThemeIntegrationUITests.swift']
paths += [ROOT / p for p in [
    'Caliber (DEV)/Models/TrainingExercise.swift',
    'Caliber (DEV)/Models/TrainingWorkout.swift',
    'Caliber (DEV)/Services/TrainingWorkoutLogger.swift',
    'Caliber (DEV)/Services/TrainingWorkoutHistory.swift',
    'Caliber (DEV)/Services/TrainingWorkoutRestTimer.swift',
    'Caliber (DEV)Tests/TrainingWorkoutLoggerTests.swift',
    'Caliber (DEV)Tests/WorkoutEnginePersistenceTests.swift',
    'Caliber (DEV)Tests/WorkoutLegacyMigrationTests.swift',
]]
paths += [ROOT / p for p in [
    'Caliber (DEV)/Services/CustomExerciseEditor.swift',
    'Caliber (DEV)/Views/Train/CustomExerciseView.swift',
    'Caliber (DEV)/Views/Train/ExerciseLibraryView.swift',
    'Caliber (DEV)Tests/CustomExerciseEditorTests.swift',
    'Caliber (DEV)UITests/CustomExerciseUITests.swift',
]]
paths += [ROOT / p for p in [
    'Caliber (DEV)/Views/Navigation/CaliberHeader.swift',
    'Caliber (DEV)/Views/Navigation/QuickLogSheet.swift',
    'Caliber (DEV)/Views/Progress/ProgressCards.swift',
    'Caliber (DEV)/Views/Progress/WeightTrendChart.swift',
    'Caliber (DEV)/Services/ShowcaseUITestFixture.swift',
    'Caliber (DEV)UITests/LookbookPolishUITests.swift',
]]
paths += [ROOT / p for p in [
    'Caliber (DEV)/Models/NutritionGoalSetup.swift',
    'Caliber (DEV)/Services/GoalSetupEditor.swift',
    'Caliber (DEV)/ViewModels/GoalSetupDraft.swift',
    'Caliber (DEV)/Views/Profile/ProfileView.swift',
    'Caliber (DEV)Tests/GoalSetupPersistenceTests.swift',
    'Caliber (DEV)UITests/GoalSetupUITests.swift',
]]
paths += sorted((ROOT / 'Caliber (DEV)/Views/Profile/GoalSetup').glob('*.swift'))
paths += [ROOT / p for p in [
    'Caliber (DEV)/Views/Components/AppearancePreviewPicker.swift',
    'Caliber (DEV)/Views/Progress/ProgressDashboardView.swift',
    'Caliber (DEV)/Views/Progress/ProgressTimelineRow.swift',
    'Caliber (DEV)UITests/VisualPass2UITests.swift',
]]
paths += [ROOT / p for p in [
    'Caliber (DEV)/Views/Diary/AddFoodView.swift',
    'Caliber (DEV)/Views/Diary/FoodEntryPass2Components.swift',
    'Caliber (DEV)/Views/MyMeals/MyMealsView.swift',
    'Caliber (DEV)Tests/FoodEntryPass2Tests.swift',
    'Caliber (DEV)UITests/FoodEntryPass2UITests.swift',
]]
paths += [ROOT / p for p in [
    'Caliber (DEV)/Views/Navigation/CaliberTabBar.swift',
    'Caliber (DEV)UITests/ResponsiveLayoutUITests.swift',
]]
subprocess.run(['xcrun', 'swift-format', 'lint', '--strict', *map(str, paths)], cwd=ROOT, check=True)
