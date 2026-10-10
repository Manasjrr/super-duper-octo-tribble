import ActivityKit
import Foundation

// Partagé entre l'app et l'extension « Activité en direct ».
// Attention : iOS limite le contenu dynamique (ContentState) à 4 Ko, icônes comprises.
struct NovaActivityAttributes: ActivityAttributes {
    public struct Entry: Codable, Hashable {
        var title: String
        var subtitle: String
        var body: String
        var iconData: Data?     // petite vignette JPEG
        var date: Date
    }

    public struct ContentState: Codable, Hashable {
        var current: Entry
        var previous: [Entry]   // les envois précédents, du plus récent au plus ancien (2 max)
        var sent: Int
        var total: Int
    }

    var configName: String
}
