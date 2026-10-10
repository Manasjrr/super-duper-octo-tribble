import CoreLocation

// MARK: - Maintien en arrière-plan par la localisation
//
// Pendant un scénario, Nova doit rester active pour envoyer chaque notification à l'heure prévue.
// La localisation en arrière-plan est le moyen fiable de le faire sur iPhone (flèche bleue visible).
// La position n'est ni enregistrée ni envoyée.

final class KeepAlive: NSObject, CLLocationManagerDelegate {
    static let shared = KeepAlive()

    /// Raisons de rester active (scénario en cours, test en cascade…) : on s'arrête quand il n'y en a plus.
    enum Reason: Hashable { case scenario, test }

    private let manager = CLLocationManager()
    private var reasons: Set<Reason> = []

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

    /// Demande l'autorisation dès le lancement, pour qu'elle soit prête au premier scénario.
    func requestPermission() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func start(_ reason: Reason) {
        reasons.insert(reason)
        requestPermission()
        begin()
    }

    func stop(_ reason: Reason) {
        reasons.remove(reason)
        guard reasons.isEmpty else { return }
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }

    private func begin() {
        let status = manager.authorizationStatus
        guard !reasons.isEmpty, status == .authorizedWhenInUse || status == .authorizedAlways else { return }
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
