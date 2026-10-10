import CoreLocation

// MARK: - Maintien en arrière-plan par la localisation
//
// Pendant un scénario, Nova doit rester active pour envoyer chaque notification à l'heure prévue.
// La localisation en arrière-plan est le moyen fiable de le faire sur iPhone (flèche bleue visible).
// La position n'est ni enregistrée ni envoyée.

final class KeepAlive: NSObject, CLLocationManagerDelegate {
    static let shared = KeepAlive()

    private let manager = CLLocationManager()
    private var wanted = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = kCLDistanceFilterNone
        manager.pausesLocationUpdatesAutomatically = false
        manager.activityType = .other
    }

    var isDenied: Bool {
        let status = manager.authorizationStatus
        return status == .denied || status == .restricted
    }

    func start() {
        wanted = true
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        begin()
    }

    func stop() {
        wanted = false
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }

    private func begin() {
        let status = manager.authorizationStatus
        guard wanted, status == .authorizedWhenInUse || status == .authorizedAlways else { return }
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        begin()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {}

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
