import Foundation

// MARK: - Préréglages

enum Presets {
    /// À incrémenter quand les exemples ou les données changent : la migration du store s'exécute alors une fois.
    static let version = 5

    private struct Spec {
        var title: String
        var subtitle = ""
        var body: String
        var persona: String
        var weight: Double = 1
        var isRare = false
        var key: String? = nil          // identifiant pour les cascades
        var followUp: String? = nil     // clé du modèle envoyé ensuite
        var followUpDelay: Double = 10
        var onlyAsFollowUp = false
        var since = 2                   // version où l'exemple est apparu
    }

    private static let specs: [Spec] = [
        // ───────── Messages ─────────
        Spec(title: "Léa", body: "Tu es dispo ce soir ? On pourrait se faire un resto 🍝", persona: "messages", weight: 2),
        Spec(title: "Thomas Martin", subtitle: "Re : Dossier projet",
             body: "Je t'ai envoyé la dernière version, dis-moi ce que tu en penses.", persona: "messages"),
        Spec(title: "Maman", body: "Tu peux m'appeler quand tu as 5 minutes ? 😊", persona: "messages"),
        Spec(title: "Hugo", body: "Bien arrivé ! On se voit demain 👍", persona: "messages"),
        Spec(title: "Papa", body: "On mange à quelle heure ce soir ?", persona: "messages", since: 5),
        Spec(title: "Mamie", body: "Bisous mon grand, appelle-moi ce week-end ❤️", persona: "messages", since: 5),
        Spec(title: "Lucas", body: "T'as vu le match hier ?? ⚽", persona: "messages", since: 5),
        Spec(title: "Chloé", body: "Je suis devant chez toi 🚪", persona: "messages", since: 5),
        Spec(title: "Week-end ski 🎿", body: "Max : j'ai réservé le chalet, 45 € chacun !", persona: "messages", since: 5),
        Spec(title: "Inès", body: "J'ai une dinguerie à te raconter 😱", persona: "messages",
             key: "ines1", followUp: "ines2", followUpDelay: 15, since: 5),
        Spec(title: "Inès", body: "Appelle-moi dès que tu peux", persona: "messages",
             key: "ines2", followUp: "ines3", followUpDelay: 20, onlyAsFollowUp: true, since: 5),
        Spec(title: "Inès", body: "Bon je t'envoie un vocal 🎙️", persona: "messages",
             key: "ines3", onlyAsFollowUp: true, since: 5),
        Spec(title: "Numéro inconnu", body: "Salut, c'est bien toi ? On s'est croisés samedi 🙂",
             persona: "messages", isRare: true, since: 5),

        // ───────── Photos ─────────
        Spec(title: "Nouveau j'aime", body: "camille.dvl a aimé ta photo.", persona: "photos", weight: 2),
        Spec(title: "Nouveau commentaire", body: "julien_m : « Trop belle cette photo 🔥 »", persona: "photos"),
        Spec(title: "Nouvelle story", body: "lea.martin vient de publier une story.", persona: "photos"),
        Spec(title: "Ta publication décolle 🚀", body: "Ta dernière photo a dépassé 1 000 j'aime.",
             persona: "photos", isRare: true),
        Spec(title: "Nouvelle abonnée", body: "sarah.mrt a commencé à te suivre.", persona: "photos", since: 5),
        Spec(title: "Tu as été identifié", body: "hugo_b t'a identifié sur une photo.", persona: "photos", since: 5),
        Spec(title: "Souvenir 📸", body: "Il y a 3 ans aujourd'hui… Revois tes photos de vacances.", persona: "photos", since: 5),
        Spec(title: "Live en cours 🔴", body: "lea.martin est en direct maintenant.", persona: "photos", since: 5),
        Spec(title: "emma.lrd a commenté", body: "« Trop stylé 😍 »", persona: "photos",
             key: "emma1", followUp: "emma2", followUpDelay: 12, since: 5),
        Spec(title: "emma.lrd a commenté", body: "« Tu m'envoies la photo ? »", persona: "photos",
             key: "emma2", onlyAsFollowUp: true, since: 5),
        Spec(title: "Ta story a été vue 500 fois 👀", body: "Elle cartonne aujourd'hui !",
             persona: "photos", isRare: true, since: 5),

        // ───────── Chat ─────────
        Spec(title: "Les potes · #général", body: "Alex : quelqu'un est chaud pour une partie ce soir ?",
             persona: "chat", weight: 2),
        Spec(title: "Sarah", body: "t'es là ? 👀", persona: "chat", key: "sarah1", followUp: "sarah2", followUpDelay: 20),
        Spec(title: "Sarah", body: "allô ? réponds 😤", persona: "chat", key: "sarah2", onlyAsFollowUp: true, since: 4),
        Spec(title: "Mention dans #projets", body: "Lucas : tu peux regarder ça quand tu as le temps ?", persona: "chat"),
        Spec(title: "Serveur Gaming · #annonces", body: "Tournoi ce soir 21 h, inscriptions ouvertes !",
             persona: "chat", since: 5),
        Spec(title: "Nathan", body: "go vocal ?", persona: "chat",
             key: "nathan1", followUp: "nathan2", followUpDelay: 15, since: 5),
        Spec(title: "Nathan", body: "on t'attend 🎧", persona: "chat", key: "nathan2", onlyAsFollowUp: true, since: 5),
        Spec(title: "Appel entrant 📞", body: "Alex t'appelle dans #vocal", persona: "chat", since: 5),
        Spec(title: "Réaction", body: "Sarah a réagi 😂 à ton message.", persona: "chat", since: 5),
        Spec(title: "Nouveau message privé", body: "Quelqu'un t'a envoyé un message.", persona: "chat", since: 5),

        // ───────── Banque ─────────
        Spec(title: "Paiement accepté", body: "Carte •••• 4821 : 23,90 € au Supermarché du Centre.", persona: "banque"),
        Spec(title: "Virement reçu", body: "Vous avez reçu 150,00 € de Jean Dupont.", persona: "banque"),
        Spec(title: "Solde mis à jour", body: "Votre solde disponible est de 1 254,32 €.", persona: "banque"),
        Spec(title: "Paiement sans contact", body: "Carte •••• 4821 : 4,20 € à la Boulangerie du Marché.",
             persona: "banque", since: 5),
        Spec(title: "Remboursement reçu", body: "+42,50 € · Remboursement de ton achat.", persona: "banque", since: 5),
        Spec(title: "Prélèvement à venir", body: "Abonnement téléphone : 19,99 € le 5 du mois.", persona: "banque", since: 5),
        Spec(title: "Plafond presque atteint", body: "Tu as utilisé 90 % de ton plafond de paiement.",
             persona: "banque", since: 5),
        Spec(title: "Bonne nouvelle 💶", body: "Ton remboursement d'impôts de 312 € est arrivé.",
             persona: "banque", isRare: true, since: 5),

        // ───────── Social ─────────
        Spec(title: "Nouvel abonné", body: "camille.dvl a commencé à vous suivre.", persona: "social"),
        Spec(title: "Demande d'ami", body: "Emma Leroy souhaite t'ajouter en ami.", persona: "social"),
        Spec(title: "Anniversaire 🎂", body: "C'est l'anniversaire de Noah aujourd'hui. Souhaite-le-lui !", persona: "social"),
        Spec(title: "Nouveau message", body: "Emma t'a envoyé un message.", persona: "social", since: 5),
        Spec(title: "Événement demain 🎉", body: "Soirée chez Lucas · 20 h. 12 personnes participent.",
             persona: "social", since: 5),
        Spec(title: "Invitation", body: "Noah t'invite à rejoindre le groupe « Randos du dimanche ».",
             persona: "social", since: 5),
        Spec(title: "Tu as été mentionné", body: "Léa t'a mentionné dans un commentaire.", persona: "social", since: 5),
        Spec(title: "Tes souvenirs", body: "Tu as 4 souvenirs à revoir aujourd'hui.", persona: "social", since: 5),

        // ───────── Nova ─────────
        Spec(title: "Rappel", body: "Pense à boire un verre d'eau 💧", persona: "nova"),
        Spec(title: "Bonne nouvelle 🎉", body: "Votre candidature a été retenue. Nous revenons vers vous très vite.",
             persona: "nova", isRare: true),
        Spec(title: "Pause 🧘", body: "Lève-toi et étire-toi 2 minutes.", persona: "nova", since: 5),
        Spec(title: "Défi du jour 💪", body: "20 pompes avant ce soir. Tu relèves le défi ?", persona: "nova", since: 5),
        Spec(title: "Citation du jour", body: "« Le meilleur moment pour commencer, c'est maintenant. »",
             persona: "nova", since: 5),
        Spec(title: "Rendez-vous 🗓️", body: "Coiffeur demain à 10 h 30.", persona: "nova", since: 5),
        Spec(title: "Météo ☀️", body: "Grand soleil cet après-midi, 24 °C.", persona: "nova", since: 5),
        Spec(title: "Jour de chance 🍀", body: "Aujourd'hui, tout est possible.", persona: "nova", isRare: true, since: 5),

        // ───────── Boutique ─────────
        Spec(title: "Commande expédiée 🚚", body: "Ta commande n° 1042 est en route. Livraison prévue demain.",
             persona: "boutique", key: "commande", followUp: "livreur", followUpDelay: 30),
        Spec(title: "Ton livreur arrive 📍", body: "Livraison dans environ 10 minutes. Sois prêt !",
             persona: "boutique", key: "livreur", onlyAsFollowUp: true, since: 4),
        Spec(title: "Ton panier t'attend", body: "3 articles sont toujours dans ton panier.", persona: "boutique"),
        Spec(title: "Vente flash ⚡", body: "-30 % sur une sélection pendant 24 h seulement.", persona: "boutique"),
        Spec(title: "Nouveautés 🛍️", body: "La nouvelle collection est arrivée.", persona: "boutique", since: 5),
        Spec(title: "Code promo 🎁", body: "-15 % avec le code NOVA15, valable 48 h.", persona: "boutique", since: 5),
        Spec(title: "De retour en stock", body: "La « Veste en jean » est de nouveau disponible.", persona: "boutique", since: 5),
        Spec(title: "Retour accepté", body: "Ton remboursement de 29,90 € est en cours.", persona: "boutique", since: 5),
        Spec(title: "Commande livrée ✅", body: "Ta commande a été déposée devant ta porte.", persona: "boutique",
             key: "livree", followUp: "avis", followUpDelay: 60, since: 5),
        Spec(title: "Donne ton avis ⭐", body: "Comment s'est passée ta commande ?", persona: "boutique",
             key: "avis", onlyAsFollowUp: true, since: 5),

        // ───────── Ventes ─────────
        Spec(title: "Nouveau favori", body: "lucie_b a ajouté « Veste en jean » à ses favoris.", persona: "ventes"),
        Spec(title: "Nouvelle offre", body: "Offre de 18 € sur « Veste en jean ».", persona: "ventes"),
        Spec(title: "Article vendu 🎉", body: "« Veste en jean » a trouvé preneur. Prépare l'envoi.",
             persona: "ventes", isRare: true),
        Spec(title: "Question d'un acheteur", body: "« Il est toujours disponible ? »", persona: "ventes", since: 5),
        Spec(title: "Baisse de prix 📉", body: "Un article de tes favoris passe à 12 €.", persona: "ventes", since: 5),
        Spec(title: "Évaluation reçue ⭐", body: "lucie_b t'a laissé 5 étoiles.", persona: "ventes", since: 5),
        Spec(title: "Offre acceptée 🤝", body: "Ton offre de 15 € a été acceptée.", persona: "ventes",
             key: "offre", followUp: "envoi", followUpDelay: 45, since: 5),
        Spec(title: "Envoi à préparer 📦", body: "Tu as 5 jours pour envoyer l'article.", persona: "ventes",
             key: "envoi", onlyAsFollowUp: true, since: 5),
    ]

    private static func make(_ spec: Spec) -> NotifTemplate {
        NotifTemplate(title: spec.title, subtitle: spec.subtitle, body: spec.body,
                      personaID: spec.persona, weight: spec.weight, isRare: spec.isRare,
                      onlyAsFollowUp: spec.onlyAsFollowUp)
    }

    /// Retrouve l'exemple dans les modèles existants (une suite se reconnaît aussi à son texte).
    private static func find(_ spec: Spec, in templates: [NotifTemplate]) -> Int? {
        templates.firstIndex { t in
            t.title == spec.title && (spec.onlyAsFollowUp ? t.body == spec.body : !t.onlyAsFollowUp)
        }
    }

    /// Modèles d'exemple d'une nouvelle installation.
    static func makeTemplates() -> [NotifTemplate] {
        var templates: [NotifTemplate] = []
        var configs: [SendConfig] = []
        merge(templates: &templates, configs: &configs, newerThan: 0, includeConfigs: false)
        return templates
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

    /// Ajoute les exemples manquants apparus après la version `newerThan` (0 = tous), sans modifier
    /// les modèles existants, sauf pour compléter un expéditeur ou une suite qui n'étaient pas choisis.
    /// Renvoie l'identifiant de la première configuration ajoutée, s'il y en a une.
    @discardableResult
    static func merge(templates: inout [NotifTemplate], configs: inout [SendConfig],
                      newerThan version: Int = 0, includeConfigs: Bool = true) -> UUID? {
        let selected = specs.filter { $0.since > version }
        var ids: [String: UUID] = [:]
        for spec in selected {
            let index: Int
            if let i = find(spec, in: templates) {
                if templates[i].personaID == nil { templates[i].personaID = spec.persona }
                index = i
            } else {
                templates.append(make(spec))
                index = templates.count - 1
            }
            if let key = spec.key { ids[key] = templates[index].id }
        }
        // Cascades des exemples (sans écraser une suite déjà choisie)
        for spec in selected {
            guard let followKey = spec.followUp, let target = ids[followKey],
                  let i = find(spec, in: templates), templates[i].followUpID == nil else { continue }
            templates[i].followUpID = target
            templates[i].followUpDelay = spec.followUpDelay
        }
        guard includeConfigs else { return nil }
        let missing = Self.configs.filter { preset in !configs.contains { $0.name == preset.name } }
        configs.append(contentsOf: missing)
        return missing.first?.id
    }
}
