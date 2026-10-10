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
        "message.fill", "bubble.left.and.bubble.right.fill", "bell.fill", "phone.fill", "creditcard.fill",
        "heart.fill", "person.fill", "camera.fill", "photo.fill", "cart.fill", "tag.fill", "star.fill",
        "checkmark.seal.fill", "music.note", "gamecontroller.fill", "newspaper.fill", "car.fill", "lock.fill",
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

// MARK: - Icônes alternatives de l'app
//
// Sans l'autorisation « Communication Notifications », iOS affiche toujours l'icône de l'app
// sur les notifications. On peut en revanche changer l'icône de l'app elle-même (aucune
// autorisation requise) : toutes les notifications prennent alors cette icône.
// Limites iOS : changement uniquement app ouverte, avec une alerte de confirmation.

enum AppIcons {
    struct Choice: Identifiable {
        let name: String?   // nil = icône principale (Nova)
        let label: String
        var id: String { name ?? "nova" }
        var preview: String { name.map { "Preview-" + $0 } ?? "Emblem" }
    }

    static let choices: [Choice] = [
        Choice(name: nil, label: "Nova"),
        Choice(name: "AppIcon-Messages", label: "Messages"),
        Choice(name: "AppIcon-Banque", label: "Banque"),
        Choice(name: "AppIcon-Social", label: "Social"),
        Choice(name: "AppIcon-Alerte", label: "Alerte"),
    ]

    /// Applique l'icône si elle diffère de l'actuelle. Doit être appelé app au premier plan.
    @MainActor
    static func apply(_ name: String?, completion: @escaping (String?) -> Void) {
        let app = UIApplication.shared
        guard app.supportsAlternateIcons else {
            completion("Cet appareil ne permet pas de changer l'icône de l'app.")
            return
        }
        guard app.alternateIconName != name else {
            completion(nil)
            return
        }
        app.setAlternateIconName(name) { error in
            DispatchQueue.main.async { completion(error?.localizedDescription) }
        }
    }
}


// MARK: - Préréglages

enum Presets {
    /// À incrémenter quand de nouveaux exemples sont ajoutés : ils sont alors proposés aux installations existantes.
    static let version = 2

    private struct Spec {
        var symbol: String? = nil
        var initials: String? = nil
        var color: Int
        var title: String
        var subtitle = ""
        var body: String
        var persona: String? = nil
        var weight: Double = 1
        var isRare = false
    }

    // Couleurs : 0 vert, 1 bleu, 2 indigo, 3 orange, 4 rouge, 5 rose, 6 turquoise, 7 gris, 8 noir
    private static let specs: [Spec] = [
        // Messages
        Spec(initials: "L", color: 7, title: "Léa",
             body: "Tu es dispo ce soir ? On pourrait se faire un resto 🍝", persona: "messages", weight: 2),
        Spec(initials: "TM", color: 7, title: "Thomas Martin", subtitle: "Re : Dossier projet",
             body: "Je t'ai envoyé la dernière version, dis-moi ce que tu en penses.", persona: "messages"),
        Spec(initials: "M", color: 7, title: "Maman",
             body: "Tu peux m'appeler quand tu as 5 minutes ? 😊", persona: "messages"),
        Spec(initials: "H", color: 7, title: "Hugo",
             body: "Bien arrivé ! On se voit demain 👍", persona: "messages"),

        // Photos
        Spec(symbol: "heart.fill", color: 4, title: "Nouveau j'aime",
             body: "camille.dvl a aimé ta photo.", persona: "photos", weight: 2),
        Spec(symbol: "message.fill", color: 4, title: "Nouveau commentaire",
             body: "julien_m : « Trop belle cette photo 🔥 »", persona: "photos"),
        Spec(symbol: "camera.fill", color: 4, title: "Nouvelle story",
             body: "lea.martin vient de publier une story.", persona: "photos"),
        Spec(symbol: "star.fill", color: 4, title: "Ta publication décolle 🚀",
             body: "Ta dernière photo a dépassé 1 000 j'aime.", persona: "photos", isRare: true),

        // Chat
        Spec(symbol: "bubble.left.and.bubble.right.fill", color: 2, title: "Les potes · #général",
             body: "Alex : quelqu'un est chaud pour une partie ce soir ?", persona: "chat", weight: 2),
        Spec(initials: "S", color: 2, title: "Sarah",
             body: "t'es là ? 👀", persona: "chat"),
        Spec(symbol: "bubble.left.and.bubble.right.fill", color: 2, title: "Mention dans #projets",
             body: "Lucas : tu peux regarder ça quand tu as le temps ?", persona: "chat"),

        // Banque
        Spec(symbol: "creditcard.fill", color: 2, title: "Paiement accepté",
             body: "Carte •••• 4821 : 23,90 € au Supermarché du Centre.", persona: "banque"),
        Spec(symbol: "creditcard.fill", color: 2, title: "Virement reçu",
             body: "Vous avez reçu 150,00 € de Jean Dupont.", persona: "banque"),
        Spec(symbol: "creditcard.fill", color: 2, title: "Solde mis à jour",
             body: "Votre solde disponible est de 1 254,32 €.", persona: "banque"),

        // Social
        Spec(symbol: "heart.fill", color: 5, title: "Nouvel abonné",
             body: "camille.dvl a commencé à vous suivre.", persona: "social"),
        Spec(symbol: "person.fill", color: 5, title: "Demande d'ami",
             body: "Emma Leroy souhaite t'ajouter en ami.", persona: "social"),
        Spec(symbol: "star.fill", color: 5, title: "Anniversaire 🎂",
             body: "C'est l'anniversaire de Noah aujourd'hui. Souhaite-le-lui !", persona: "social"),

        // Nova
        Spec(symbol: "bell.fill", color: 6, title: "Rappel",
             body: "Pense à boire un verre d'eau 💧", persona: "nova"),
        Spec(symbol: "checkmark.seal.fill", color: 6, title: "Bonne nouvelle 🎉",
             body: "Votre candidature a été retenue. Nous revenons vers vous très vite.", persona: "nova", isRare: true),

        // Boutique
        Spec(symbol: "cart.fill", color: 8, title: "Commande expédiée 🚚",
             body: "Ta commande n° 1042 est en route. Livraison prévue demain.", persona: "boutique"),
        Spec(symbol: "cart.fill", color: 8, title: "Ton panier t'attend",
             body: "3 articles sont toujours dans ton panier.", persona: "boutique"),
        Spec(symbol: "tag.fill", color: 8, title: "Vente flash ⚡",
             body: "-30 % sur une sélection pendant 24 h seulement.", persona: "boutique"),

        // Ventes
        Spec(symbol: "heart.fill", color: 3, title: "Nouveau favori",
             body: "lucie_b a ajouté « Veste en jean » à ses favoris.", persona: "ventes"),
        Spec(symbol: "tag.fill", color: 3, title: "Nouvelle offre",
             body: "Offre de 18 € sur « Veste en jean ».", persona: "ventes"),
        Spec(symbol: "tag.fill", color: 3, title: "Article vendu 🎉",
             body: "« Veste en jean » a trouvé preneur. Prépare l'envoi.", persona: "ventes", isRare: true),
    ]

    private static func make(_ spec: Spec) -> NotifTemplate {
        let icon = IconMaker.render(symbol: spec.symbol, initials: spec.initials, color: IconMaker.colors[spec.color])
        return NotifTemplate(title: spec.title, subtitle: spec.subtitle, body: spec.body,
                             iconFile: ImageStore.save(image: icon, maxSide: 256),
                             personaID: spec.persona, weight: spec.weight, isRare: spec.isRare)
    }

    /// Modèles d'exemple d'une nouvelle installation (avec leurs icônes).
    static func makeTemplates() -> [NotifTemplate] {
        specs.map(make)
    }

    static var configs: [SendConfig] {
        [
            SendConfig(name: "Applis web · test rapide", count: 5, totalDuration: 60, minInterval: 5, maxInterval: 30,
                       mode: .regular, webPush: true),
            SendConfig(name: "Applis web · 12 en 5 min", count: 12, totalDuration: 300, minInterval: 5, maxInterval: 60,
                       mode: .random, webPush: true),
            SendConfig(name: "Test rapide", count: 5, totalDuration: 60, minInterval: 5, maxInterval: 30, mode: .regular),
            SendConfig(name: "Régulier · 10 en 5 min", count: 10, totalDuration: 300, minInterval: 10, maxInterval: 60, mode: .regular),
            SendConfig(name: "Aléatoire · 20 en 10 min", count: 20, totalDuration: 600, minInterval: 5, maxInterval: 90, mode: .random),
            SendConfig(name: "Rafales · 15 en 5 min", count: 15, totalDuration: 300, minInterval: 20, maxInterval: 120,
                       mode: .burst, burstSize: 3, burstGap: 2),
        ]
    }

    /// Ajoute les exemples et configurations manquants, et rattache les anciens exemples à leur expéditeur.
    /// Renvoie l'identifiant de la première configuration « Applis web » ajoutée, s'il y en a une.
    @discardableResult
    static func merge(templates: inout [NotifTemplate], configs: inout [SendConfig]) -> UUID? {
        for spec in specs {
            if let i = templates.firstIndex(where: { $0.title == spec.title }) {
                if templates[i].personaID == nil { templates[i].personaID = spec.persona }
            } else {
                templates.append(make(spec))
            }
        }
        let missing = Self.configs.filter { preset in !configs.contains { $0.name == preset.name } }
        configs.insert(contentsOf: missing.filter(\.webPush), at: 0)
        configs.append(contentsOf: missing.filter { !$0.webPush })
        return missing.first(where: \.webPush)?.id
    }
}
