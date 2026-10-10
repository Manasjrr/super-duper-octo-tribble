import UIKit

// MARK: - Génération d'icônes (pastille colorée + symbole ou initiales)

enum IconMaker {
    static let colors: [UIColor] = [
        UIColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1),  // vert
        UIColor(red: 0.04, green: 0.52, blue: 1.00, alpha: 1),  // bleu
        UIColor(red: 0.37, green: 0.36, blue: 0.90, alpha: 1),  // indigo
        UIColor(red: 1.00, green: 0.62, blue: 0.04, alpha: 1),  // orange
        UIColor(red: 1.00, green: 0.27, blue: 0.23, alpha: 1),  // rouge
        UIColor(red: 1.00, green: 0.22, blue: 0.37, alpha: 1),  // rose
        UIColor(red: 0.19, green: 0.69, blue: 0.78, alpha: 1),  // turquoise
        UIColor(red: 0.56, green: 0.58, blue: 0.62, alpha: 1),  // gris (contacts)
        UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1),  // noir
    ]

    static let symbols = [
        "message.fill", "envelope.fill", "bell.fill", "phone.fill", "shippingbox.fill", "creditcard.fill",
        "calendar", "heart.fill", "cart.fill", "person.fill", "star.fill", "checkmark.seal.fill",
        "camera.fill", "music.note", "gamecontroller.fill", "newspaper.fill", "car.fill", "lock.fill",
    ]

    /// Dessine une icône carrée (iOS l'arrondit en cercle dans la notification).
    static func render(symbol: String? = nil, initials: String? = nil, color: UIColor, size: CGFloat = 256) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        return UIGraphicsImageRenderer(size: rect.size, format: format).image { ctx in
            let cg = ctx.cgContext
            color.setFill()
            cg.fill(rect)
            // Léger dégradé pour un rendu « appli »
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: [UIColor(white: 1, alpha: 0.22).cgColor,
                                                  UIColor(white: 0, alpha: 0.08).cgColor] as CFArray,
                                         locations: [0, 1]) {
                cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size), options: [])
            }

            if let initials, !initials.isEmpty {
                let font = UIFont.systemFont(ofSize: size * (initials.count > 1 ? 0.38 : 0.46), weight: .semibold)
                let rounded = font.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: font.pointSize) } ?? font
                let attributes: [NSAttributedString.Key: Any] = [.font: rounded, .foregroundColor: UIColor.white]
                let text = initials as NSString
                let textSize = text.size(withAttributes: attributes)
                text.draw(at: CGPoint(x: (size - textSize.width) / 2, y: (size - textSize.height) / 2),
                          withAttributes: attributes)
            } else if let symbol {
                let config = UIImage.SymbolConfiguration(pointSize: size * 0.40, weight: .semibold)
                if let image = UIImage(systemName: symbol, withConfiguration: config)?
                    .withTintColor(.white, renderingMode: .alwaysOriginal) {
                    let s = image.size
                    image.draw(in: CGRect(x: (size - s.width) / 2, y: (size - s.height) / 2, width: s.width, height: s.height))
                }
            }
        }
    }

    /// Initiales à partir d'un nom : « Thomas Martin » → « TM ».
    static func initials(from name: String) -> String {
        let words = name.split(separator: " ").filter { $0.first?.isLetter == true }
        return words.prefix(2).compactMap { $0.first.map { String($0).uppercased() } }.joined()
    }
}

// MARK: - Préréglages

enum Presets {
    private struct Spec {
        var symbol: String? = nil
        var initials: String? = nil
        var color: Int
        var title: String
        var subtitle = ""
        var body: String
        var weight: Double = 1
        var isRare = false
    }

    private static let specs: [Spec] = [
        Spec(initials: "L", color: 7, title: "Léa",
             body: "Tu es dispo ce soir ? On pourrait se faire un resto 🍝"),
        Spec(initials: "TM", color: 7, title: "Thomas Martin", subtitle: "Re : Dossier projet",
             body: "Je t'ai envoyé la dernière version, dis-moi ce que tu en penses."),
        Spec(symbol: "shippingbox.fill", color: 3, title: "Votre colis arrive aujourd'hui",
             body: "Livraison prévue entre 14 h et 16 h. Suivez votre livreur en temps réel."),
        Spec(symbol: "creditcard.fill", color: 2, title: "Paiement accepté",
             body: "Carte •••• 4821 : 23,90 € au Supermarché du Centre."),
        Spec(symbol: "calendar", color: 4, title: "Réunion d'équipe", subtitle: "Dans 15 minutes",
             body: "Salle 2 · Point hebdomadaire"),
        Spec(symbol: "heart.fill", color: 5, title: "Nouvel abonné",
             body: "camille.dvl a commencé à vous suivre."),
        Spec(symbol: "checkmark.seal.fill", color: 6, title: "Bonne nouvelle 🎉",
             body: "Votre candidature a été retenue. Nous revenons vers vous très vite.", isRare: true),
    ]

    static var templateTitles: [String] { specs.map(\.title) }

    /// Crée les modèles d'exemple (et enregistre leurs icônes).
    static func makeTemplates(excludingTitles excluded: Set<String> = []) -> [NotifTemplate] {
        specs.filter { !excluded.contains($0.title) }.map { spec in
            let icon = IconMaker.render(symbol: spec.symbol, initials: spec.initials,
                                       color: IconMaker.colors[spec.color])
            return NotifTemplate(title: spec.title, subtitle: spec.subtitle, body: spec.body,
                                 iconFile: ImageStore.save(image: icon, maxSide: 256),
                                 weight: spec.weight, isRare: spec.isRare)
        }
    }

    static var configs: [SendConfig] {
        [
            SendConfig(name: "Test rapide", count: 5, totalDuration: 60, minInterval: 5, maxInterval: 30, mode: .regular),
            SendConfig(name: "Régulier · 10 en 5 min", count: 10, totalDuration: 300, minInterval: 10, maxInterval: 60, mode: .regular),
            SendConfig(name: "Aléatoire · 20 en 10 min", count: 20, totalDuration: 600, minInterval: 5, maxInterval: 90, mode: .random),
            SendConfig(name: "Rafales · 15 en 5 min", count: 15, totalDuration: 300, minInterval: 20, maxInterval: 120,
                       mode: .burst, burstSize: 3, burstGap: 2),
        ]
    }
}
