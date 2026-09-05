import SwiftUI
import CoreLocation
import MapKit

final class ParkingManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var savedLocation: CLLocationCoordinate2D?
    @Published var savedAt: Date?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        load()
    }

    func saveCurrentPosition() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func clear() {
        savedLocation = nil; savedAt = nil
        UserDefaults.standard.removeObject(forKey: "idom.parking.lat")
        UserDefaults.standard.removeObject(forKey: "idom.parking.lon")
        UserDefaults.standard.removeObject(forKey: "idom.parking.date")
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        savedLocation = location.coordinate
        savedAt = .now
        UserDefaults.standard.set(location.coordinate.latitude, forKey: "idom.parking.lat")
        UserDefaults.standard.set(location.coordinate.longitude, forKey: "idom.parking.lon")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "idom.parking.date")
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { }

    private func load() {
        guard UserDefaults.standard.object(forKey: "idom.parking.lat") != nil else { return }
        savedLocation = .init(latitude: UserDefaults.standard.double(forKey: "idom.parking.lat"), longitude: UserDefaults.standard.double(forKey: "idom.parking.lon"))
        let timestamp = UserDefaults.standard.double(forKey: "idom.parking.date")
        if timestamp > 0 { savedAt = Date(timeIntervalSince1970: timestamp) }
    }
}

struct ParkingView: View {
    @StateObject private var parking = ParkingManager()

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: parking.savedLocation == nil ? "car" : "car.circle.fill")
                    .font(.system(size: 72)).foregroundStyle(.blue).padding(.top, 35)
                Text(parking.savedLocation == nil ? "Dove hai parcheggiato?" : "Auto salvata")
                    .font(.title2.bold())
                Text(parking.savedLocation == nil ? "Salva la posizione dell'auto e iDom ti aiuterà a tornarci." : "Posizione memorizzata sul tuo iPhone.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal)

                if let date = parking.savedAt {
                    Label(date.formatted(date: .abbreviated, time: .shortened), systemImage: "clock").foregroundStyle(.secondary)
                }

                if let coordinate = parking.savedLocation {
                    Button {
                        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                        item.name = "Auto parcheggiata"
                        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
                    } label: { Label("Portami all'auto", systemImage: "figure.walk") }
                    .buttonStyle(.borderedProminent).controlSize(.large)

                    Button("Rimuovi posizione", role: .destructive) { parking.clear() }
                } else {
                    Button { parking.saveCurrentPosition() } label: { Label("Salva posizione attuale", systemImage: "location.fill") }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                }
            }.frame(maxWidth: .infinity)
        }
        .navigationTitle("Parcheggio")
    }
}
