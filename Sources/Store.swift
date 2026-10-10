import SwiftUI
import UserNotifications

// MARK: - Sauvegarde

private struct SavedState: Codable {
    var templates: [NotifTemplate] = []
    var configs: [SendConfig] = []
    var activeConfigID: UUID? = nil
    var run: Run? = nil
    var history: [HistoryEntry] = []
    var personas: [Persona] = []
    var webBaseURL = WebPersonas.defaultBaseURL

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        templates = c.value(.templates, [])
        configs = c.value(.configs, [])
        activeConfigID = try? c.decodeIfPresent(UUID.self, forKey: .activeConfigID)
        run = try? c.decodeIfPresent(Run.self, forKey: .run)
        history = c.value(.history, [])
        personas = c.value(.personas, [])
        webBaseURL = c.value(.webBaseURL, WebPersonas.defaultBaseURL)
    }
}

// MARK: - Store

@MainActor
final class AppStore: ObservableObject {
    static let historyLimit = 200

    @Published var templates: [NotifTemplate] = [] { didSet { save() } }
    @Published var configs: [SendConfig] = [] { didSet { save() } }
    @Published var activeConfigID: UUID? { didSet { save() } }
    @Published var run: Run? { didSet { save() } }
    @Published var history: [HistoryEntry] = [] { didSet { save() } }
    @Published var personas: [Persona] = [] { didSet { save() } }
    @Published var webBaseURL = WebPersonas.defaultBaseURL { didSet { save() } }
    @Published var locationDenied = false
    @Published var message: String?

    private var loading = true
    private var timer: Timer?
    private static let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private let fileURL = AppStore.documents.appendingPathComponent("etat.json")

    init() {
        if let data = try? Data(contentsOf: fileURL),
           let state = try? JSONDecoder().decode(SavedState.self, from: data) {
            templates = state.templates
            configs = state.configs
            activeConfigID = state.activeConfigID
            run = state.run
            history = state.history
            personas = state.personas
            webBaseURL = state.webBaseURL
        } else {
            templates = Presets.makeTemplates()
            configs = Presets.configs
        }
        migrate()
        if configs.isEmpty { configs = Presets.configs }
        if activeConfigID == nil || !configs.contains(where: { $0.id == activeConfigID }) {
            activeConfigID = configs.first?.id
        }
        loading = false
        save()

        // Horloge interne : tourne aussi en arrière-plan quand Nova est maintenue active.
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Mises à jour des données des versions précédentes (une seule fois chacune).
    private func migrate() {
        let key = "versionExemples"
        let stored = UserDefaults.standard.integer(forKey: key)
        guard stored < Presets.version else { return }

        if stored < 3 {
            // Fin des anciens modes : les configurations « Applis web · … » deviennent des configurations normales
            let renames = ["Applis web · test rapide": "Test rapide", "Applis web · 12 en 5 min": "Aléatoire · 12 en 5 min"]
            for (old, new) in renames {
                guard let i = configs.firstIndex(where: { $0.name == old }) else { continue }
                if let other = configs.first(where: { $0.name == new }) {
                    if activeConfigID == configs[i].id { activeConfigID = other.id }
                    configs.remove(at: i)
                } else {
                    configs[i].name = new
                }
            }
            // Les icônes et images des modèles ne sont plus utilisées
            try? FileManager.default.removeItem(at: Self.documents.appendingPathComponent("Images"))
        }

        var t = templates
        var c = configs
        if let added = Presets.merge(templates: &t, configs: &c), stored < 2 { activeConfigID = added }
        templates = t
        configs = c
        UserDefaults.standard.set(Presets.version, forKey: key)
    }

    private func save() {
        guard !loading else { return }
        var state = SavedState()
        state.templates = templates
        state.configs = configs
        state.activeConfigID = activeConfigID
        state.run = run
        state.history = history
        state.personas = personas
        state.webBaseURL = webBaseURL
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    // MARK: Autorisations

    /// Notifications classiques : utilisées seulement en secours, si un envoi web échoue.
    func requestNotificationPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Les anciennes versions pouvaient changer l'icône de Nova : on remet l'icône d'origine.
    func resetAppIconIfNeeded() {
        guard UIApplication.shared.alternateIconName != nil else { return }
        UIApplication.shared.setAlternateIconName(nil, completionHandler: nil)
    }

    // MARK: Modèles

    func upsertTemplate(_ t: NotifTemplate) {
        if let i = templates.firstIndex(where: { $0.id == t.id }) {
            templates[i] = t
        } else {
            templates.append(t)
        }
    }

    func deleteTemplate(_ t: NotifTemplate) {
        templates.removeAll { $0.id == t.id }
        for i in configs.indices where configs[i].templateIDs.contains(t.id) {
            configs[i].templateIDs.removeAll { $0 == t.id }
        }
    }

    func duplicateTemplate(_ t: NotifTemplate) {
        var copy = t
        copy.id = UUID()
        copy.title = t.title.isEmpty ? t.title : t.title + " (copie)"
        if let i = templates.firstIndex(where: { $0.id == t.id }) {
            templates.insert(copy, at: i + 1)
        } else {
            templates.append(copy)
        }
    }

    // MARK: Configurations

    var activeConfig: SendConfig? {
        configs.first { $0.id == activeConfigID }
    }

    func configBinding(_ id: UUID) -> Binding<SendConfig> {
        Binding(
            get: { self.configs.first { $0.id == id } ?? SendConfig() },
            set: { v in
                if let i = self.configs.firstIndex(where: { $0.id == id }) { self.configs[i] = v }
            }
        )
    }

    @discardableResult
    func addConfig() -> SendConfig {
        let c = SendConfig()
        configs.append(c)
        return c
    }

    func duplicateConfig(_ c: SendConfig) {
        var copy = c
        copy.id = UUID()
        copy.name = c.name + " (copie)"
        if let i = configs.firstIndex(where: { $0.id == c.id }) {
            configs.insert(copy, at: i + 1)
        } else {
            configs.append(copy)
        }
    }

    func deleteConfig(_ c: SendConfig) {
        guard configs.count > 1 else { return }
        configs.removeAll { $0.id == c.id }
        if activeConfigID == c.id { activeConfigID = configs.first?.id }
    }

    /// Ajoute les exemples et configurations prédéfinies qui manquent.
    func addPresets() {
        var t = templates
        var c = configs
        Presets.merge(templates: &t, configs: &c)
        templates = t
        configs = c
    }

    /// Modèles utilisés par une config (tous si aucune sélection).
    func pool(for config: SendConfig) -> [NotifTemplate] {
        let usable = templates.filter { !$0.isEmpty }
        let selected = usable.filter { config.templateIDs.contains($0.id) }
        return selected.isEmpty ? usable : selected
    }

    // MARK: Scénario

    func start() {
        guard let config = activeConfig else { return }
        let pool = pool(for: config)
        guard !pool.isEmpty else {
            message = "Ajoute au moins un modèle avant de démarrer."
            return
        }
        guard !KeepAlive.shared.isDenied else {
            message = "Nova a besoin de la localisation pour rester active pendant le scénario (Réglages › Nova › Position)."
            return
        }
        if run?.isActive == true { stop() }

        var picker = ContentPicker(pool: pool, config: config)
        let now = Date()
        let items: [PlannedNotif] = Planner.offsets(for: config).compactMap { offset in
            guard let t = picker.next() else { return nil }
            return PlannedNotif(fireDate: now.addingTimeInterval(offset),
                                title: t.displayTitle, subtitle: t.subtitle, body: t.body,
                                personaID: t.personaID, isRare: t.isRare)
        }
        KeepAlive.shared.start()
        message = nil
        run = Run(configName: config.name, items: items, plannedCount: items.count)
        tick()
    }

    func pause() {
        guard var r = run, r.status == .running else { return }
        r.status = .paused
        r.pausedAt = Date()
        run = r
        KeepAlive.shared.stop()
    }

    func resume() {
        guard var r = run, r.status == .paused, let pausedAt = r.pausedAt else { return }
        let delta = Date().timeIntervalSince(pausedAt)
        for i in r.items.indices where r.items[i].fireDate > pausedAt {
            r.items[i].fireDate += delta
        }
        r.status = .running
        r.pausedAt = nil
        run = r
        KeepAlive.shared.start()
        tick()
    }

    func stop() {
        guard var r = run, r.isActive else { return }
        let ref = r.pausedAt ?? Date()
        r.items.removeAll { $0.fireDate > ref }
        r.status = .stopped
        r.pausedAt = nil
        r.endedAt = Date()
        run = r
        KeepAlive.shared.stop()
        tick()
    }

    func clearRun() {
        guard run?.isActive != true else { return }
        run = nil
    }

    /// Appelé chaque seconde : envoie ce qui arrive à échéance et tient l'historique.
    func tick() {
        let denied = KeepAlive.shared.isDenied
        if denied != locationDenied { locationDenied = denied }

        guard var r = run else { return }
        let now = Date()

        if r.status == .running {
            // Si Nova a été suspendue, on n'envoie que les 3 derniers en retard pour éviter une rafale.
            let due = r.items.indices.filter { !r.items[$0].scheduled && r.items[$0].fireDate <= now }
            for i in due { r.items[i].scheduled = true }
            for i in due.suffix(3) { deliver(r.items[i]) }
        }

        var newEntries: [HistoryEntry] = []
        for i in r.items.indices where r.items[i].scheduled && !r.items[i].logged && r.items[i].fireDate <= now {
            let it = r.items[i]
            newEntries.append(HistoryEntry(date: it.fireDate, title: it.title, body: it.body,
                                           personaID: it.personaID ?? WebPersonas.defaultSender, isRare: it.isRare))
            r.items[i].logged = true
        }
        if !newEntries.isEmpty { addHistory(newEntries) }

        if r.status == .running && r.items.allSatisfy({ $0.scheduled && $0.fireDate <= now }) {
            r.status = .finished
            r.endedAt = r.items.last?.fireDate ?? now
            KeepAlive.shared.stop()
        }

        if r != run { run = r }
    }

    // MARK: Envoi

    /// Envoie par l'appli expéditrice du modèle (Nova par défaut), sinon en notification classique.
    private func deliver(_ item: PlannedNotif) {
        send(title: item.title, subtitle: item.subtitle, body: item.body, personaID: item.personaID)
    }

    private func send(title: String, subtitle: String, body: String, personaID: String?) {
        guard let target = persona(personaID ?? WebPersonas.defaultSender) else {
            Notifier.show(title: title, subtitle: subtitle, body: body)
            return
        }
        WebPush.send(to: target, title: title, subtitle: subtitle, body: body,
                     id: UUID().uuidString) { [weak self] ok, detail in
            self?.setPersonaStatus(target.id, ok ? nil : detail)
            if !ok {
                // Secours : la notification part quand même, avec l'icône de Nova
                Notifier.show(title: title, subtitle: subtitle, body: body)
            }
        }
    }

    func sendTest(_ template: NotifTemplate? = nil) {
        var t = template
        if t == nil, let config = activeConfig {
            var picker = ContentPicker(pool: pool(for: config), config: config)
            t = picker.next()
        }
        guard let t, !t.isEmpty else {
            message = "Aucun modèle à tester."
            return
        }
        send(title: t.displayTitle, subtitle: t.subtitle, body: t.body, personaID: t.personaID)
        addHistory([HistoryEntry(date: Date(), title: t.displayTitle, body: t.body,
                                 personaID: t.personaID ?? WebPersonas.defaultSender, isTest: true, isRare: t.isRare)])
        message = nil
    }

    private func addHistory(_ entries: [HistoryEntry]) {
        var h = history + entries
        h.sort { $0.date > $1.date }
        if h.count > Self.historyLimit { h.removeLast(h.count - Self.historyLimit) }
        history = h
    }

    // MARK: Applis expéditrices

    func persona(_ id: String?) -> Persona? {
        personas.first { $0.id == id }
    }

    private func setPersonaStatus(_ id: String, _ status: String?) {
        guard let i = personas.firstIndex(where: { $0.id == id }), personas[i].lastStatus != status else { return }
        personas[i].lastStatus = status
    }

    func testPersona(_ id: String) {
        guard let target = persona(id) else { return }
        WebPush.send(to: target, title: target.name, subtitle: "", body: "Notification de test envoyée par Nova",
                     id: UUID().uuidString) { [weak self] ok, detail in
            self?.setPersonaStatus(id, ok ? nil : detail)
            self?.message = ok ? nil : "Échec de l'envoi vers « \(target.name) » : \(detail)"
        }
    }

    func removePersona(_ id: String) {
        personas.removeAll { $0.id == id }
    }

    /// Enregistre la connexion renvoyée par une appli web.
    @discardableResult
    func addPersona(fromPayload payload: String) -> Bool {
        guard var p = WebPersonas.decode(payload) else { return false }
        if let old = persona(p.id), old.name != p.name, p.name == WebPersonas.slot(p.id)?.label {
            p.name = old.name
        }
        personas.removeAll { $0.id == p.id }
        personas.append(p)
        personas.sort { a, b in
            (WebPersonas.slots.firstIndex { $0.id == a.id } ?? 99) < (WebPersonas.slots.firstIndex { $0.id == b.id } ?? 99)
        }
        message = nil
        return true
    }

    /// nova://persona?d=…
    func handle(url: URL) {
        guard url.scheme == "nova", url.host == "persona",
              let d = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "d" })?.value
        else { return }
        if !addPersona(fromPayload: d) { message = "Connexion d'appli web illisible." }
    }

    func importPersonaFromClipboard() {
        let text = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard text.hasPrefix("NOVA-SUB:"), addPersona(fromPayload: String(text.dropFirst("NOVA-SUB:".count))) else {
            message = "Le presse-papiers ne contient pas de connexion d'appli web."
            return
        }
    }
}

// MARK: - Notification classique (secours)

enum Notifier {
    /// Affiche tout de suite une notification de Nova.
    static func show(title: String, subtitle: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
