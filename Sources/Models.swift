import Foundation

// MARK: - Modèle de notification

struct NotifTemplate: Identifiable, Codable, Hashable {
    var id = UUID()
    var emoji = ""
    var title = ""
    var subtitle = ""
    var body = ""
    var personaID: String? = nil    // appli expéditrice (nil = Nova)
    var weight: Double = 1          // poids relatif pour le tirage
    var isRare = false              // n'apparaît qu'avec la « chance de rare » de la config
    var maxPerRun = 1               // apparitions max. par scénario (0 = illimité, 1 = pas de doublon)
    var steps: [CascadeStep] = []   // cascade : notifications envoyées automatiquement après celle-ci

    // Ancien système de cascade (suites rangées comme des modèles à part, reliées entre elles) :
    // lu uniquement pour convertir les anciennes sauvegardes en `steps`.
    var followUpID: UUID? = nil
    var followUpDelay: Double = 10
    var onlyAsFollowUp = false

    var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespaces)
        if emoji.isEmpty { return t }
        return t.isEmpty ? emoji : "\(emoji) \(t)"
    }

    var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespaces).isEmpty
            && body.trimmingCharacters(in: .whitespaces).isEmpty
            && emoji.isEmpty
    }

    /// Appli expéditrice (Nova si aucune n'est choisie).
    var sender: String {
        WebPersonas.slot(personaID)?.id ?? WebPersonas.defaultSender
    }

    var frequency: Frequency {
        get { isRare ? .rare : (weight > 1 ? .often : .normal) }
        set {
            isRare = newValue == .rare
            if newValue != .often {
                weight = 1
            } else if weight <= 1 {
                weight = 3
            }
        }
    }

    /// Peut apparaître plusieurs fois dans un même scénario.
    var canRepeat: Bool {
        get { maxPerRun != 1 }
        set { maxPerRun = newValue ? 0 : 1 }
    }

    /// Suites de la cascade prêtes à envoyer, avec leur délai depuis cette notification.
    var cascade: [(NotifTemplate, Double)] {
        var delay = 0.0
        return steps.filter { !$0.isEmpty }.map { step in
            delay += max(1, step.delay)
            let t = step.title.trimmingCharacters(in: .whitespaces)
            let next = NotifTemplate(title: t.isEmpty ? displayTitle : t, body: step.body,
                                     personaID: personaID, isRare: isRare)
            return (next, delay)
        }
    }
}

/// Une suite de cascade : arrive automatiquement après la notification précédente, depuis la même appli.
struct CascadeStep: Identifiable, Codable, Hashable {
    var id = UUID()
    var delay: Double = 15      // secondes après la notification précédente
    var title = ""              // vide = même titre que la notification de départ
    var body = ""

    var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespaces).isEmpty && body.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

enum Frequency: String, CaseIterable, Identifiable {
    case rare, normal, often

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rare: return "Rare"
        case .normal: return "Normale"
        case .often: return "Souvent"
        }
    }
}

// MARK: - Configuration d'envoi

enum SendMode: String, Codable, CaseIterable, Identifiable {
    case regular, random, burst

    var id: String { rawValue }

    var label: String {
        switch self {
        case .regular: return "Régulier"
        case .random: return "Aléatoire"
        case .burst: return "Rafales"
        }
    }

    var explanation: String {
        switch self {
        case .regular: return "Les notifications sont espacées de façon égale sur la durée."
        case .random: return "Les écarts varient au hasard entre le minimum et le maximum."
        case .burst: return "Les notifications arrivent par petits groupes rapprochés."
        }
    }
}

struct SendConfig: Identifiable, Codable, Hashable {
    var id = UUID()
    var name = "Nouvelle configuration"
    var count = 20
    var totalDuration: Double = 600     // secondes
    var minInterval: Double = 5         // secondes
    var maxInterval: Double = 120       // secondes
    var mode: SendMode = .random
    var startDelay: Double = 0          // secondes avant le premier envoi
    var burstSize = 3
    var burstGap: Double = 2            // secondes entre deux notifs d'une rafale
    var randomPick = true               // tirage aléatoire (sinon dans l'ordre de la liste)
    var avoidRepeats = true
    var mixContent = false              // mélange titres et textes entre modèles
    var rareChance: Double = 0.05
    var templateIDs: [UUID] = []        // vide = tous les modèles
    var noDuplicates = false            // chaque modèle au plus une fois par scénario
}

// MARK: - Scénario en cours

struct PlannedNotif: Identifiable, Codable, Hashable {
    var id = UUID()
    var fireDate: Date
    var title: String
    var subtitle: String
    var body: String
    var personaID: String? = nil
    var isRare: Bool
    var scheduled = false   // déjà envoyée
    var logged = false      // ajoutée à l'historique
}

enum RunStatus: String, Codable {
    case running, paused, finished, stopped
}

struct Run: Codable, Equatable {
    var configName: String
    var items: [PlannedNotif]
    var plannedCount: Int
    var status: RunStatus = .running
    var startedAt = Date()
    var pausedAt: Date? = nil
    var endedAt: Date? = nil

    var isActive: Bool { status == .running || status == .paused }

    func sent(at now: Date) -> Int {
        let ref = pausedAt ?? now
        return items.filter { $0.fireDate <= ref }.count
    }

    func next(after now: Date) -> PlannedNotif? {
        let ref = pausedAt ?? now
        return items.first { $0.fireDate > ref }
    }
}

// MARK: - Historique

struct HistoryEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var title: String
    var body: String
    var personaID: String? = nil
    var isTest = false
    var isRare = false
}

// MARK: - Décodage tolérant (les anciennes sauvegardes restent lisibles après une mise à jour)

extension KeyedDecodingContainer {
    func value<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        guard let v = try? decodeIfPresent(T.self, forKey: key) else { return fallback }
        return v
    }
}

extension NotifTemplate {
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, id)
        emoji = c.value(.emoji, emoji)
        title = c.value(.title, title)
        subtitle = c.value(.subtitle, subtitle)
        body = c.value(.body, body)
        personaID = try? c.decodeIfPresent(String.self, forKey: .personaID)
        weight = c.value(.weight, weight)
        isRare = c.value(.isRare, isRare)
        maxPerRun = c.value(.maxPerRun, 0)   // modèles d'avant ce réglage : illimités, comme avant
        steps = c.value(.steps, steps)
        followUpID = try? c.decodeIfPresent(UUID.self, forKey: .followUpID)
        followUpDelay = c.value(.followUpDelay, followUpDelay)
        onlyAsFollowUp = c.value(.onlyAsFollowUp, onlyAsFollowUp)
    }
}

extension CascadeStep {
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, id)
        delay = c.value(.delay, delay)
        title = c.value(.title, title)
        body = c.value(.body, body)
    }
}

extension SendConfig {
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, id)
        name = c.value(.name, name)
        count = c.value(.count, count)
        totalDuration = c.value(.totalDuration, totalDuration)
        minInterval = c.value(.minInterval, minInterval)
        maxInterval = c.value(.maxInterval, maxInterval)
        mode = c.value(.mode, mode)
        startDelay = c.value(.startDelay, startDelay)
        burstSize = c.value(.burstSize, burstSize)
        burstGap = c.value(.burstGap, burstGap)
        randomPick = c.value(.randomPick, randomPick)
        avoidRepeats = c.value(.avoidRepeats, avoidRepeats)
        mixContent = c.value(.mixContent, mixContent)
        rareChance = c.value(.rareChance, rareChance)
        templateIDs = c.value(.templateIDs, templateIDs)
        noDuplicates = c.value(.noDuplicates, noDuplicates)
    }
}
