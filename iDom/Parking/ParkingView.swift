import SwiftUI
import Combine
import CoreLocation
import MapKit

final class ParkingManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var timeout: Timer?
    private var waitingForPermission = false
    @Published private(set) var savedLocation: CLLocationCoordinate2D?
    @Published private(set) var savedAt: Date?
    @Published private(set) var accuracy: Double?
    @Published private(set) var isLocating = false
    @Published private(set) var denied = false
    @Published var issue: AppIssue?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "idom.parking.lat") != nil && defaults.object(forKey: "idom.parking.lon") != nil {
            let coordinate = CLLocationCoordinate2D(latitude: defaults.double(forKey: "idom.parking.lat"), longitude: defaults.double(forKey: "idom.parking.lon"))
            if CLLocationCoordinate2DIsValid(coordinate) { savedLocation = coordinate }
            let timestamp = defaults.double(forKey: "idom.parking.date")
            if timestamp > 0 { savedAt = Date(timeIntervalSince1970: timestamp) }
            if defaults.object(forKey: "idom.parking.accuracy") != nil { accuracy = defaults.double(forKey: "idom.parking.accuracy") }
        }
    }
    func saveCurrentPosition() {
        guard !isLocating else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            waitingForPermission = true
            isLocating = true
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: locate()
        case .denied, .restricted: permissionError()
        @unknown default: permissionError()
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        denied = manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted
        if denied {
            if isLocating || waitingForPermission { permissionError() }
        } else if waitingForPermission && (manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse) {
            waitingForPermission = false
            locate()
        }
    }
    private func locate() {
        isLocating = true
        timeout?.invalidate()
        timeout = Timer.scheduledTimer(withTimeInterval: 20, repeats: false) { [weak self] _ in
            self?.fail("La posizione non arriva. Prova all'aperto e controlla che la localizzazione sia attiva. La posizione precedente è conservata.")
        }
        manager.startUpdatingLocation()
    }
    func cancel() {
        timeout?.invalidate()
        timeout = nil
        manager.stopUpdatingLocation()
        waitingForPermission = false
        isLocating = false
    }
    private func permissionError() {
        denied = true
        fail("Consenti la posizione a iDom in Impostazioni → Privacy e sicurezza → Localizzazione. Nessuna posizione è stata modificata.")
    }
    private func fail(_ message: String) { cancel(); issue = AppIssue(message: message) }
    func clear() {
        cancel()
        savedLocation = nil
        savedAt = nil
        accuracy = nil
        for key in ["lat", "lon", "date", "accuracy", "note"] { UserDefaults.standard.removeObject(forKey: "idom.parking." + key) }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isLocating, !waitingForPermission,
              let location = locations.filter({ $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy <= 100 && abs($0.timestamp.timeIntervalSinceNow) < 30 }).min(by: { $0.horizontalAccuracy < $1.horizontalAccuracy }) else { return }
        savedLocation = location.coordinate
        savedAt = .now
        accuracy = location.horizontalAccuracy
        let defaults = UserDefaults.standard
        defaults.set(location.coordinate.latitude, forKey: "idom.parking.lat")
        defaults.set(location.coordinate.longitude, forKey: "idom.parking.lon")
        defaults.set(Date().timeIntervalSince1970, forKey: "idom.parking.date")
        defaults.set(location.horizontalAccuracy, forKey: "idom.parking.accuracy")
        cancel()
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard isLocating else { return }
        if let error = error as? CLError, error.code == .locationUnknown { return }
        fail("Non riesco a ottenere la posizione. Controlla i permessi e riprova all'aperto. La posizione precedente è conservata.")
    }
}

struct ParkingView: View {
    @StateObject private var parking = ParkingManager()
    @AppStorage("idom.parking.note") private var note = ""
    @Environment(\.openURL) private var openURL
    @State private var confirmRemove = false
    @State private var confirmReplace = false
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let coordinate = parking.savedLocation {
                    Map(initialPosition: .region(MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)))) {
                        Marker("Auto parcheggiata", systemImage: "car.fill", coordinate: coordinate).tint(.orange)
                    }
                    .id("\(coordinate.latitude),\(coordinate.longitude)")
                    .frame(height: 230).clipShape(RoundedRectangle(cornerRadius: 20))
                    .accessibilityLabel("Mappa dell'auto parcheggiata")
                    Text("Auto salvata").font(.title2.bold())
                    if let date = parking.savedAt {
                        Label(date.formatted(date: .abbreviated, time: .shortened), systemImage: "clock").font(.subheadline)
                    }
                    if let accuracy = parking.accuracy { Text("Precisione indicativa: \(Int(accuracy.rounded())) m").font(.caption).foregroundStyle(.secondary) }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nota del parcheggio").font(.headline)
                        TextField("Piano, posto, punto di riferimento…", text: $note, axis: .vertical)
                            .lineLimit(2...5).textFieldStyle(.roundedBorder)
                        Text("La nota si salva automaticamente.").font(.caption).foregroundStyle(.secondary)
                    }
                    Button { openMaps(coordinate) } label: { Label("Portami all'auto", systemImage: "figure.walk") }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                    Button("Aggiorna posizione") { confirmReplace = true }.disabled(parking.isLocating)
                    Button("Rimuovi parcheggio", role: .destructive) { confirmRemove = true }.disabled(parking.isLocating)
                } else {
                    ContentUnavailableView("Dove hai parcheggiato?", systemImage: "car.fill", description: Text("Salva la posizione e aggiungi una nota per ritrovare la tua auto."))
                    Button { parking.saveCurrentPosition() } label: { Label("Salva posizione attuale", systemImage: "location.fill") }
                        .buttonStyle(.borderedProminent).controlSize(.large).disabled(parking.isLocating)
                }
                if parking.isLocating {
                    ProgressView("Ricerca della posizione…")
                    Button("Annulla ricerca") { parking.cancel() }
                }
                if parking.denied {
                    Text("Abilita la localizzazione per salvare una nuova posizione.").font(.callout).multilineTextAlignment(.center)
                    Button("Apri impostazioni") { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } }
                }
                Text("La posizione viene richiesta solo quando premi Salva o Aggiorna. Se il GPS è poco preciso, riprova all'aperto e abilita Posizione esatta.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.padding()
        }
        .navigationTitle("Parcheggio")
        .alert("Rimuovere il parcheggio?", isPresented: $confirmRemove) {
            Button("Rimuovi", role: .destructive) { parking.clear(); note = "" }
            Button("Annulla", role: .cancel) { }
        } message: { Text("Verranno eliminate la posizione e la nota salvate.") }
        .alert("Aggiornare la posizione?", isPresented: $confirmReplace) {
            Button("Aggiorna") { parking.saveCurrentPosition() }
            Button("Annulla", role: .cancel) { }
        } message: { Text("La vecchia posizione verrà sostituita solo se il GPS ne trova una nuova. La nota rimane invariata.") }
        .storageAlert($parking.issue)
        .onDisappear { parking.cancel() }
    }
    private func openMaps(_ coordinate: CLLocationCoordinate2D) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = "Auto parcheggiata"
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
}
