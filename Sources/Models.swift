import Foundation

// MARK: - Modèle de notification

struct NotifTemplate: Identifiable, Codable, Hashable {
    var id = UUID()
    var emoji = ""
    var title = ""
    var subtitle = ""
    var body = ""
    var imageFile: String? = nil
    var iconFile: String? = nil // icône ronde à gauche (notification de communication)
    var weight: Double = 1      // poids relatif pour le tirage
    var isRare = false          // n'apparaît qu'avec la « chance de rare » de la config

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
    var mixContent = false              // mélange titres / textes / images entre messages
    var rareChance: Double = 0.05
    var templateIDs: [UUID] = []        // vide = tous les messages
    var appIcon: String? = nil          // icône alternative de l'app pendant le scénario (nil = Nova)
}

// MARK: - Scénario en cours

struct PlannedNotif: Identifiable, Codable, Hashable {
    var id = UUID()
    var fireDate: Date
    var title: String
    var subtitle: String
    var body: String
    var imageFile: String?
    var iconFile: String? = nil
    var isRare: Bool
    var scheduled = false   // programmée auprès d'iOS
    var logged = false      // ajoutée au journal
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

// MARK: - Journal

struct HistoryEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var title: String
    var body: String
    var imageFile: String? = nil
    var iconFile: String? = nil
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
        imageFile = try? c.decodeIfPresent(String.self, forKey: .imageFile)
        iconFile = try? c.decodeIfPresent(String.self, forKey: .iconFile)
        weight = c.value(.weight, weight)
        isRare = c.value(.isRare, isRare)
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
        appIcon = try? c.decodeIfPresent(String.self, forKey: .appIcon)
    }
}
