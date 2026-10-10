import Foundation

// MARK: - Préréglages

enum Presets {
    /// À incrémenter quand les exemples ou les données changent : la migration du store s'exécute alors une fois.
    static let version = 3

    private struct Spec {
        var title: String
        var subtitle = ""
        var body: String
        var persona: String
        var weight: Double = 1
        var isRare = false
    }

    private static let specs: [Spec] = [
        // Messages
        Spec(title: "Léa", body: "Tu es dispo ce soir ? On pourrait se faire un resto 🍝", persona: "messages", weight: 2),
        Spec(title: "Thomas Martin", subtitle: "Re : Dossier projet",
             body: "Je t'ai envoyé la dernière version, dis-moi ce que tu en penses.", persona: "messages"),
        Spec(title: "Maman", body: "Tu peux m'appeler quand tu as 5 minutes ? 😊", persona: "messages"),
        Spec(title: "Hugo", body: "Bien arrivé ! On se voit demain 👍", persona: "messages"),

        // Photos
        Spec(title: "Nouveau j'aime", body: "camille.dvl a aimé ta photo.", persona: "photos", weight: 2),
        Spec(title: "Nouveau commentaire", body: "julien_m : « Trop belle cette photo 🔥 »", persona: "photos"),
        Spec(title: "Nouvelle story", body: "lea.martin vient de publier une story.", persona: "photos"),
        Spec(title: "Ta publication décolle 🚀", body: "Ta dernière photo a dépassé 1 000 j'aime.",
             persona: "photos", isRare: true),

        // Chat
        Spec(title: "Les potes · #général", body: "Alex : quelqu'un est chaud pour une partie ce soir ?",
             persona: "chat", weight: 2),
        Spec(title: "Sarah", body: "t'es là ? 👀", persona: "chat"),
        Spec(title: "Mention dans #projets", body: "Lucas : tu peux regarder ça quand tu as le temps ?", persona: "chat"),

        // Banque
        Spec(title: "Paiement accepté", body: "Carte •••• 4821 : 23,90 € au Supermarché du Centre.", persona: "banque"),
        Spec(title: "Virement reçu", body: "Vous avez reçu 150,00 € de Jean Dupont.", persona: "banque"),
        Spec(title: "Solde mis à jour", body: "Votre solde disponible est de 1 254,32 €.", persona: "banque"),

        // Social
        Spec(title: "Nouvel abonné", body: "camille.dvl a commencé à vous suivre.", persona: "social"),
        Spec(title: "Demande d'ami", body: "Emma Leroy souhaite t'ajouter en ami.", persona: "social"),
        Spec(title: "Anniversaire 🎂", body: "C'est l'anniversaire de Noah aujourd'hui. Souhaite-le-lui !", persona: "social"),

        // Nova
        Spec(title: "Rappel", body: "Pense à boire un verre d'eau 💧", persona: "nova"),
        Spec(title: "Bonne nouvelle 🎉", body: "Votre candidature a été retenue. Nous revenons vers vous très vite.",
             persona: "nova", isRare: true),

        // Boutique
        Spec(title: "Commande expédiée 🚚", body: "Ta commande n° 1042 est en route. Livraison prévue demain.",
             persona: "boutique"),
        Spec(title: "Ton panier t'attend", body: "3 articles sont toujours dans ton panier.", persona: "boutique"),
        Spec(title: "Vente flash ⚡", body: "-30 % sur une sélection pendant 24 h seulement.", persona: "boutique"),

        // Ventes
        Spec(title: "Nouveau favori", body: "lucie_b a ajouté « Veste en jean » à ses favoris.", persona: "ventes"),
        Spec(title: "Nouvelle offre", body: "Offre de 18 € sur « Veste en jean ».", persona: "ventes"),
        Spec(title: "Article vendu 🎉", body: "« Veste en jean » a trouvé preneur. Prépare l'envoi.",
             persona: "ventes", isRare: true),
    ]

    private static func make(_ spec: Spec) -> NotifTemplate {
        NotifTemplate(title: spec.title, subtitle: spec.subtitle, body: spec.body,
                      personaID: spec.persona, weight: spec.weight, isRare: spec.isRare)
    }

    /// Modèles d'exemple d'une nouvelle installation.
    static func makeTemplates() -> [NotifTemplate] {
        specs.map(make)
    }

    static var configs: [SendConfig] {
        [
            SendConfig(name: "Test rapide", count: 5, totalDuration: 60, minInterval: 5, maxInterval: 30, mode: .regular),
            SendConfig(name: "Aléatoire · 12 en 5 min", count: 12, totalDuration: 300, minInterval: 5, maxInterval: 60, mode: .random),
            SendConfig(name: "Régulier · 10 en 5 min", count: 10, totalDuration: 300, minInterval: 10, maxInterval: 60, mode: .regular),
            SendConfig(name: "Aléatoire · 20 en 10 min", count: 20, totalDuration: 600, minInterval: 5, maxInterval: 90, mode: .random),
            SendConfig(name: "Rafales · 15 en 5 min", count: 15, totalDuration: 300, minInterval: 20, maxInterval: 120,
                       mode: .burst, burstSize: 3, burstGap: 2),
        ]
    }

    /// Ajoute les exemples et configurations manquants, et rattache les anciens exemples à leur expéditeur.
    /// Renvoie l'identifiant de la première configuration ajoutée, s'il y en a une.
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
        configs.append(contentsOf: missing)
        return missing.first?.id
    }
}
