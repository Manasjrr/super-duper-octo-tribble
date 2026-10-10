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

    private static func placeholder(_ text: String, total: Int) -> NovaActivityAttributes.ContentState {
        let entry = NovaActivityAttributes.Entry(title: "Nova", subtitle: "", body: text, iconData: nil, date: Date())
        return NovaActivityAttributes.ContentState(current: entry, previous: [], sent: 0, total: total)
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
        do {
            activity = try Activity.request(attributes: NovaActivityAttributes(configName: configName),
                                            content: ActivityContent(state: placeholder("« \(configName) » en cours…", total: total),
                                                                     staleDate: nil),
                                            pushType: nil)
        } catch {
            return "Impossible de démarrer l'Activité en direct : \(error.localizedDescription)"
        }
        KeepAlive.shared.start()
        return nil
    }

    /// Affiche une « notification » : met à jour l'activité avec une alerte.
    /// `archive` : range en plus une copie silencieuse dans le centre de notifications.
    static func show(_ item: PlannedNotif, sent: Int, total: Int, archive: Bool) {
        // Sans l'extension, l'activité ne peut pas s'afficher : on envoie une notification classique.
        guard extensionInstalled else {
            Notifier.schedule(id: item.id, title: item.title, subtitle: item.subtitle, body: item.body,
                              imageFile: item.imageFile, iconFile: item.iconFile, at: Date())
            return
        }
        guard let current = activity ?? Activity<NovaActivityAttributes>.activities.first else { return }
        activity = current

        // L'envoi affiché jusqu'ici passe dans la pile (sauf le message d'attente du départ)
        let old = current.content.state
        let previous = old.sent > 0 ? Array(([old.current] + old.previous).prefix(2)) : []
        let entry = NovaActivityAttributes.Entry(title: String(item.title.prefix(60)),
                                                 subtitle: String(item.subtitle.prefix(60)),
                                                 body: String(item.body.prefix(140)),
                                                 iconData: ImageStore.thumbnailData(item.iconFile, side: 40),
                                                 date: item.fireDate)
        var state = NovaActivityAttributes.ContentState(current: entry, previous: previous, sent: sent, total: total)
        // Les vignettes de la pile sont réduites, puis retirées si on dépasse la limite de 4 Ko
        for i in state.previous.indices {
            state.previous[i].iconData = ImageStore.shrinkJPEG(state.previous[i].iconData, side: 22)
            state.previous[i].body = String(state.previous[i].body.prefix(60))
        }
        if encodedSize(state) > 3800 {
            for i in state.previous.indices { state.previous[i].iconData = nil }
        }
        if encodedSize(state) > 3800 { state.current.iconData = nil }

        let alert = AlertConfiguration(title: LocalizedStringResource(String.LocalizationValue(item.title)),
                                       body: LocalizedStringResource(String.LocalizationValue(item.body)),
                                       sound: .default)
        Task {
            await current.update(ActivityContent(state: state, staleDate: nil), alertConfiguration: alert)
        }
        if archive {
            Notifier.schedule(id: item.id, title: item.title, subtitle: item.subtitle, body: item.body,
                              imageFile: item.imageFile, iconFile: nil, at: Date(), passive: true)
        }
    }

    private static func encodedSize(_ state: NovaActivityAttributes.ContentState) -> Int {
        (try? JSONEncoder().encode(state).count) ?? 0
    }

    // MARK: Diagnostic

    struct Check: Identifiable {
        let label: String
        let ok: Bool
        let detail: String
        var id: String { label }
    }

    static var extensionInstalled: Bool {
        guard let url = Bundle.main.builtInPlugInsURL?.appendingPathComponent("NovaLiveActivity.appex") else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    static func diagnostics() -> [Check] {
        var checks: [Check] = []
        let ext = extensionInstalled
        checks.append(Check(label: "Extension d'affichage", ok: ext,
                            detail: ext ? "installée" : "absente : SideStore l'a retirée à l'installation"))
        let enabled = activitiesEnabled
        checks.append(Check(label: "Activités en direct", ok: enabled,
                            detail: enabled ? "autorisées" : "désactivées (Réglages > Nova)"))
        checks.append(Check(label: "Localisation", ok: KeepAlive.shared.isAuthorized,
                            detail: KeepAlive.shared.statusText))
        if let a = Activity<NovaActivityAttributes>.activities.first {
            let state: String
            switch a.activityState {
            case .active: state = "affichée"
            case .stale: state = "périmée"
            case .ended: state = "terminée"
            case .dismissed: state = "masquée"
            @unknown default: state = "inconnue"
            }
            checks.append(Check(label: "Activité en cours", ok: a.activityState == .active, detail: state))
        } else {
            checks.append(Check(label: "Activité en cours", ok: false, detail: "aucune"))
        }
        return checks
    }

    /// Affiche tout de suite une activité d'essai avec ce modèle (app ouverte).
    static func test(_ template: NotifTemplate) -> String? {
        if activity == nil && Activity<NovaActivityAttributes>.activities.isEmpty {
            guard activitiesEnabled else { return "Les Activités en direct sont désactivées pour Nova (Réglages > Nova)." }
            do {
                activity = try Activity.request(attributes: NovaActivityAttributes(configName: "Test"),
                                                content: ActivityContent(state: placeholder("Test", total: 1), staleDate: nil),
                                                pushType: nil)
            } catch {
                return "Impossible de démarrer l'Activité en direct : \(error.localizedDescription)"
            }
        }
        let item = PlannedNotif(fireDate: Date(), title: template.displayTitle, subtitle: template.subtitle,
                                body: template.body, imageFile: nil, iconFile: template.iconFile, isRare: false)
        show(item, sent: 1, total: 1, archive: false)
        return nil
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

    var isAuthorized: Bool {
        let status = manager.authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    var statusText: String {
        switch manager.authorizationStatus {
        case .authorizedAlways: return "toujours autorisée"
        case .authorizedWhenInUse: return "autorisée"
        case .denied: return "refusée (Réglages > Nova > Position)"
        case .restricted: return "restreinte"
        case .notDetermined: return "pas encore demandée"
        @unknown default: return "inconnue"
        }
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
