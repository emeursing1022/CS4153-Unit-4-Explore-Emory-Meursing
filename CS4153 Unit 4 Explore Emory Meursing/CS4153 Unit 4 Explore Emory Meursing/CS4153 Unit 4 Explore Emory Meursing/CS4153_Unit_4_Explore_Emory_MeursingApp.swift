//
//  CS4153_Unit_4_Explore_Emory_MeursingApp.swift
//  CS4153 Unit 4 Explore Emory Meursing
//
//  Created by Sarah Luster on 4/30/25.
//

import SwiftUI
import CoreData
import MapKit

@main
struct LocationJournalApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
