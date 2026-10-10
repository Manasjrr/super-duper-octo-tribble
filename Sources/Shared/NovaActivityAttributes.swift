import ActivityKit
import Foundation

// Partagé entre l'app et l'extension « Activité en direct ».
// Attention : iOS limite le contenu dynamique (ContentState) à 4 Ko, icône comprise.
struct NovaActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var subtitle: String
        var body: String
        var iconData: Data?     // petite vignette JPEG (≈ 40 px)
        var sent: Int
        var total: Int
        var date: Date
    }

    var configName: String
}
