//
//  UserProfile.swift
//  Caliber (DEV)
//

import Foundation
import SwiftData

/// The user's profile and daily goals, used by the TDEE calculator and the
/// diary's daily totals screen.
@Model
final class UserProfile {
    var id: UUID
    var heightInInches: Double
    var startingWeight: Double
    var activityLevel: ActivityLevel = ActivityLevel.sedentary
    var dailyCalorieGoal: Double
    var proteinGoal: Double
    var carbGoal: Double
    var fatGoal: Double

    init(
        heightInInches: Double,
        startingWeight: Double,
        activityLevel: ActivityLevel,
        dailyCalorieGoal: Double,
        proteinGoal: Double,
        carbGoal: Double,
        fatGoal: Double
    ) {
        self.id = UUID()
        self.heightInInches = heightInInches
        self.startingWeight = startingWeight
        self.activityLevel = activityLevel
        self.dailyCalorieGoal = dailyCalorieGoal
        self.proteinGoal = proteinGoal
        self.carbGoal = carbGoal
        self.fatGoal = fatGoal
    }
}
