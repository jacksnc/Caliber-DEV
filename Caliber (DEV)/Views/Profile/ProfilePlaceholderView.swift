//
//  ProfilePlaceholderView.swift
//  Caliber (DEV)
//

import SwiftUI

struct ProfilePlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Profile",
                systemImage: "person.crop.circle",
                description: Text("Goals, TDEE calculator, and settings are coming soon.")
            )
            .navigationTitle("Profile")
        }
    }
}

#Preview {
    ProfilePlaceholderView()
}
