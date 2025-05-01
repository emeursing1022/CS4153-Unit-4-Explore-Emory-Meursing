//
//  ContentView.swift
//  CS4153 Unit 4 Explore Emory Meursing
//
//  Created by Sarah Luster on 4/30/25.
//

import SwiftUI
import CoreData
import MapKit

class PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentContainer

    init() {
        container = NSPersistentContainer(name: "JournalModel")
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
    }
}

extension JournalEntry {
    static func fetchRequest(_ predicate: NSPredicate) -> NSFetchRequest<JournalEntry> {
        let request = NSFetchRequest<JournalEntry>(entityName: "JournalEntry")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntry.timestamp, ascending: false)]
        request.predicate = predicate
        return request
    }
}

class JournalViewModel: ObservableObject {
    @Published var entries: [JournalEntry] = []
    private let viewContext = PersistenceController.shared.container.viewContext

    func fetchEntries(predicate: NSPredicate? = nil) {
        let request = JournalEntry.fetchRequest(predicate ?? NSPredicate(value: true))
        do {
            entries = try viewContext.fetch(request)
        } catch {
            print("Error fetching entries: \(error)")
        }
    }

    func addEntry(title: String, text: String, location: CLLocationCoordinate2D) async {
        await viewContext.perform {
            let newEntry = JournalEntry(context: self.viewContext)
            newEntry.title = title
            newEntry.text = text
            newEntry.latitude = location.latitude
            newEntry.longitude = location.longitude
            newEntry.timestamp = Date()
            // Fetch place details
            Task {
                let details = await self.fetchLocationDetails(lat: location.latitude, lon: location.longitude)
                newEntry.placeDetails = details
                try? self.viewContext.save()
                self.fetchEntries()
            }
        }
    }

    func updateEntry(_ entry: JournalEntry, title: String, text: String) {
        entry.title = title
        entry.text = text
        try? viewContext.save()
        fetchEntries()
    }

    func deleteEntry(_ entry: JournalEntry) {
        viewContext.delete(entry)
        try? viewContext.save()
        fetchEntries()
    }

    func fetchLocationDetails(lat: Double, lon: Double) async -> String {
        guard let url = URL(string: "https://api.openweathermap.org/data/2.5/weather?lat=\(lat)&lon=\(lon)&appid=YOUR_API_KEY") else {
            return ""
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let weather = json["weather"] as? [[String: Any]],
               let description = weather.first?["description"] as? String {
                return description
            }
        } catch {
            print("API error: \(error)")
        }
        return "No data"
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.first?.coordinate
    }
}

struct ContentView: View {
    @StateObject private var viewModel = JournalViewModel()
    @StateObject private var locationManager = LocationManager()

    @State private var title = ""
    @State private var text = ""

    @Environment(\.managedObjectContext) private var viewContext

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // default location (San Francisco)
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    var body: some View {
        NavigationView {
            VStack {
                // Map view centered on user's location
                Map(coordinateRegion: Binding(
                    get: {
                        if let loc = locationManager.location {
                            return MKCoordinateRegion(
                                center: loc,
                                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                            )
                        }
                        return region
                    },
                    set: { region = $0 }
                ), annotationItems: viewModel.entries) { entry in
                    MapPin(coordinate: CLLocationCoordinate2D(latitude: entry.latitude, longitude: entry.longitude))
                }
                .frame(height: 200)

                // Form to create a new journal entry
                Form {
                    TextField("Title", text: $title)
                    TextField("Description", text: $text)
                    Button("Add Entry") {
                        Task {
                            if let loc = locationManager.location {
                                await viewModel.addEntry(title: title, text: text, location: loc)
                                title = ""
                                text = ""
                            }
                        }
                    }
                }

                // List of journal entries
                List(viewModel.entries, id: \.objectID) { entry in
                    VStack(alignment: .leading) {
                        Text(entry.title ?? "No Title").bold()
                        Text(entry.text ?? "")
                        Text(entry.placeDetails ?? "Fetching...").italic().font(.caption)
                    }
                }
            }
            .onAppear {
                viewModel.fetchEntries()
            }
            .navigationTitle("Journal")
        }
    }
}
