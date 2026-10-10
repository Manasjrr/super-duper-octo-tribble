import ActivityKit
import CoreLocation
import UIKit

// MARK: - Mode « Activité en direct »
//
// Contournement de la limite des comptes Apple gratuits : au lieu de notifications classiques
// (icône de l'app imposée), Nova affiche une Activité en direct dessinée comme une notification,
// avec une icône libre. Chaque envoi met l'activité à jour avec une alerte (écran allumé + son).
// Pour pouvoir faire ces mises à jour, Nova doit rester active en arrière-plan : on utilise la
// localisation (le seul mode d'arrière-plan qui permet de mettre à jour une activité sur iPhone).

@MainActor
enum LiveMode {
    private static var activity: Activity<NovaActivityAttributes>?

    static var activitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Démarre l'activité et le maintien en arrière-plan. Renvoie un message d'erreur éventuel.
    static func start(configName: String, total: Int) -> String? {
        guard activitiesEnabled else {
            return "Les Activités en direct sont désactivées pour Nova (Réglages > Nova)."
        }
        guard !KeepAlive.shared.isDenied else {
            return "Le mode Activité en direct a besoin de la localisation (Réglages > Nova > Position)."
        }
        end(immediately: true)
        let state = NovaActivityAttributes.ContentState(title: "Nova", subtitle: "",
                                                        body: "« \(configName) » en cours…",
                                                        iconData: nil, sent: 0, total: total, date: Date())
        do {
            activity = try Activity.request(attributes: NovaActivityAttributes(configName: configName),
                                            content: ActivityContent(state: state, staleDate: nil),
                                            pushType: nil)
        } catch {
            return "Impossible de démarrer l'Activité en direct : \(error.localizedDescription)"
        }
        KeepAlive.shared.start()
        return nil
    }

    /// Affiche une « notification » : met à jour l'activité avec une alerte.
    static func show(_ item: PlannedNotif, sent: Int, total: Int) {
        guard let current = activity ?? Activity<NovaActivityAttributes>.activities.first else { return }
        activity = current
        var state = NovaActivityAttributes.ContentState(title: item.title, subtitle: item.subtitle,
                                                        body: String(item.body.prefix(160)),
                                                        iconData: ImageStore.thumbnailData(item.iconFile, side: 40),
                                                        sent: sent, total: total, date: item.fireDate)
        // Sécurité pour rester sous la limite de 4 Ko
        if let data = try? JSONEncoder().encode(state), data.count > 3800 { state.iconData = nil }

        let alert = AlertConfiguration(title: LocalizedStringResource(String.LocalizationValue(item.title)),
                                       body: LocalizedStringResource(String.LocalizationValue(item.body)),
                                       sound: .default)
        Task {
            await current.update(ActivityContent(state: state, staleDate: nil), alertConfiguration: alert)
        }
    }

    static func pause() {
        KeepAlive.shared.stop()
    }

    static func resume() {
        KeepAlive.shared.start()
    }

    static func end(immediately: Bool) {
        KeepAlive.shared.stop()
        activity = nil
        // Liste figée maintenant : une activité démarrée juste après ne doit pas être fermée.
        let existing = Activity<NovaActivityAttributes>.activities
        Task {
            for a in existing {
                await a.end(nil, dismissalPolicy: immediately ? .immediate : .default)
            }
        }
    }
}

// MARK: - Maintien en arrière-plan par la localisation

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
