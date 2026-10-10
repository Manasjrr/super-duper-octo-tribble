import SwiftUI
import UserNotifications
import Intents

// MARK: - Sauvegarde

private struct SavedState: Codable {
    var templates: [NotifTemplate] = []
    var configs: [SendConfig] = []
    var activeConfigID: UUID? = nil
    var run: Run? = nil
    var history: [HistoryEntry] = []

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        templates = c.value(.templates, [])
        configs = c.value(.configs, [])
        activeConfigID = try? c.decodeIfPresent(UUID.self, forKey: .activeConfigID)
        run = try? c.decodeIfPresent(Run.self, forKey: .run)
        history = c.value(.history, [])
    }
}

// MARK: - Store

@MainActor
final class AppStore: ObservableObject {
    /// iOS limite à 64 notifications en attente par app : on garde une marge.
    static let pendingLimit = 58
    static let historyLimit = 200

    @Published var templates: [NotifTemplate] = [] { didSet { save() } }
    @Published var configs: [SendConfig] = [] { didSet { save() } }
    @Published var activeConfigID: UUID? { didSet { save() } }
    @Published var run: Run? { didSet { save() } }
    @Published var history: [HistoryEntry] = [] { didSet { save() } }
    @Published var authorization: UNAuthorizationStatus = .notDetermined
    @Published var message: String?

    private var loading = true
    private var timer: Timer?
    private let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("etat.json")

    init() {
        if let data = try? Data(contentsOf: fileURL),
           let state = try? JSONDecoder().decode(SavedState.self, from: data) {
            templates = state.templates
            configs = state.configs
            activeConfigID = state.activeConfigID
            run = state.run
            history = state.history
        } else {
            templates = Presets.makeTemplates()
            configs = Presets.configs
        }
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

    private func save() {
        guard !loading else { return }
        var state = SavedState()
        state.templates = templates
        state.configs = configs
        state.activeConfigID = activeConfigID
        state.run = run
        state.history = history
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    // MARK: Autorisation

    func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        await refreshAuthorization()
    }

    func refreshAuthorization() async {
        authorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    // MARK: Messages

    func upsertTemplate(_ t: NotifTemplate) {
        if let i = templates.firstIndex(where: { $0.id == t.id }) {
            templates[i] = t
        } else {
            templates.append(t)
        }
    }

    func deleteTemplate(_ t: NotifTemplate) {
        templates.removeAll { $0.id == t.id }
        releaseImage(t.imageFile)
        releaseImage(t.iconFile)
        for i in configs.indices where configs[i].templateIDs.contains(t.id) {
            configs[i].templateIDs.removeAll { $0 == t.id }
        }
    }

    func duplicateTemplate(_ t: NotifTemplate) {
        var copy = t
        copy.id = UUID()
        copy.title = t.title.isEmpty ? t.title : t.title + " (copie)"
        copy.imageFile = ImageStore.copy(t.imageFile)
        copy.iconFile = ImageStore.copy(t.iconFile)
        if let i = templates.firstIndex(where: { $0.id == t.id }) {
            templates.insert(copy, at: i + 1)
        } else {
            templates.append(copy)
        }
    }

    /// Supprime le fichier image s'il n'est plus utilisé par aucun message.
    func releaseImage(_ name: String?) {
        guard let name, !templates.contains(where: { $0.imageFile == name || $0.iconFile == name }) else { return }
        ImageStore.delete(name)
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

    func addPresets() {
        for var p in Presets.configs {
            p.id = UUID()
            configs.append(p)
        }
        templates += Presets.makeTemplates(excludingTitles: Set(templates.map(\.title)))
    }

    /// Messages utilisés par une config (tous si aucune sélection).
    func pool(for config: SendConfig) -> [NotifTemplate] {
        let usable = templates.filter { !$0.isEmpty }
        let selected = usable.filter { config.templateIDs.contains($0.id) }
        return selected.isEmpty ? usable : selected
    }

    // MARK: Scénario

    func start() {
        guard let config = activeConfig else { return }
        if authorization == .denied {
            message = "Les notifications sont désactivées dans Réglages."
            return
        }
        let pool = pool(for: config)
        guard !pool.isEmpty else {
            message = "Ajoute au moins un modèle avant de démarrer."
            return
        }
        if run?.isActive == true { stop() }

        var picker = ContentPicker(pool: pool, config: config)
        let now = Date()
        let items: [PlannedNotif] = Planner.offsets(for: config).compactMap { offset in
            guard let t = picker.next() else { return nil }
            return PlannedNotif(fireDate: now.addingTimeInterval(offset),
                                title: t.displayTitle, subtitle: t.subtitle, body: t.body,
                                imageFile: t.imageFile, iconFile: t.iconFile, isRare: t.isRare)
        }
        if config.liveActivity, let error = LiveMode.start(configName: config.name, total: items.count) {
            message = error
            return
        }
        message = nil
        run = Run(configName: config.name, items: items, plannedCount: items.count,
                  live: config.liveActivity ? true : nil)
        tick()
        AppIcons.apply(config.appIcon) { [weak self] error in
            if let error { self?.message = "Icône de l'app non changée : \(error)" }
        }
    }

    func pause() {
        guard var r = run, r.status == .running else { return }
        let now = Date()
        Notifier.cancel(r.items.filter { $0.scheduled && $0.fireDate > now }.map(\.id))
        for i in r.items.indices where r.items[i].fireDate > now {
            r.items[i].scheduled = false
        }
        r.status = .paused
        r.pausedAt = now
        run = r
        if r.isLive { LiveMode.pause() }
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
        if r.isLive { LiveMode.resume() }
        tick()
    }

    func stop() {
        guard var r = run, r.isActive else { return }
        let ref = r.pausedAt ?? Date()
        Notifier.cancel(r.items.filter { $0.scheduled && $0.fireDate > ref }.map(\.id))
        r.items.removeAll { $0.fireDate > ref }
        r.status = .stopped
        r.pausedAt = nil
        r.endedAt = Date()
        run = r
        if r.isLive { LiveMode.end(immediately: true) }
        tick()
    }

    func clearRun() {
        guard run?.isActive != true else { return }
        run = nil
    }

    /// Appelé régulièrement : programme la suite, rattrape le retard, tient le journal.
    func tick() {
        guard var r = run else { return }
        let now = Date()

        if r.status == .running && r.isLive {
            // Activité en direct : on « livre » les envois arrivés à échéance (le dernier est affiché).
            let due = r.items.indices.filter { !r.items[$0].scheduled && r.items[$0].fireDate <= now }
            if let last = due.last {
                for i in due { r.items[i].scheduled = true }
                LiveMode.show(r.items[last], sent: r.sent(at: now), total: r.plannedCount)
            }
        } else if r.status == .running {
            // Des notifs non programmées sont passées (app fermée trop longtemps) : on décale la suite.
            if let idx = r.items.firstIndex(where: { !$0.scheduled && $0.fireDate <= now }) {
                let delta = now.addingTimeInterval(2).timeIntervalSince(r.items[idx].fireDate)
                for i in idx..<r.items.count where !r.items[i].scheduled {
                    r.items[i].fireDate += delta
                }
            }
            // On remplit la file d'attente iOS dans la limite autorisée.
            var budget = Self.pendingLimit - r.items.filter { $0.scheduled && $0.fireDate > now }.count
            for i in r.items.indices where budget > 0 && !r.items[i].scheduled {
                let it = r.items[i]
                Notifier.schedule(id: it.id, title: it.title, subtitle: it.subtitle, body: it.body,
                                  imageFile: it.imageFile, iconFile: it.iconFile, at: it.fireDate)
                r.items[i].scheduled = true
                budget -= 1
            }
        }

        // Journal
        var newEntries: [HistoryEntry] = []
        for i in r.items.indices where r.items[i].scheduled && !r.items[i].logged && r.items[i].fireDate <= now {
            let it = r.items[i]
            newEntries.append(HistoryEntry(date: it.fireDate, title: it.title, body: it.body,
                                           imageFile: it.imageFile, iconFile: it.iconFile, isRare: it.isRare))
            r.items[i].logged = true
        }
        if !newEntries.isEmpty { addHistory(newEntries) }

        if r.status == .running && r.items.allSatisfy({ $0.scheduled && $0.fireDate <= now }) {
            r.status = .finished
            r.endedAt = r.items.last?.fireDate ?? now
            if r.isLive { LiveMode.end(immediately: false) }
        }

        if r != run { run = r }
    }

    // MARK: Test immédiat

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
        let date = Date().addingTimeInterval(1)
        Notifier.schedule(id: UUID(), title: t.displayTitle, subtitle: t.subtitle, body: t.body,
                          imageFile: t.imageFile, iconFile: t.iconFile, at: date)
        addHistory([HistoryEntry(date: date, title: t.displayTitle, body: t.body,
                                 imageFile: t.imageFile, iconFile: t.iconFile, isTest: true, isRare: t.isRare)])
        message = nil
    }

    private func addHistory(_ entries: [HistoryEntry]) {
        var h = history + entries
        h.sort { $0.date > $1.date }
        if h.count > Self.historyLimit { h.removeLast(h.count - Self.historyLimit) }
        history = h
    }
}

// MARK: - Envoi des notifications

enum Notifier {
    static func schedule(id: UUID, title: String, subtitle: String, body: String,
                         imageFile: String?, iconFile: String?, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        content.sound = .default
        if let attachment = ImageStore.attachment(imageFile) {
            content.attachments = [attachment]
        }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow),
                                                        repeats: false)
        func add(_ c: UNNotificationContent) {
            let request = UNNotificationRequest(identifier: id.uuidString, content: c, trigger: trigger)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        }

        guard let iconFile, let iconData = ImageStore.data(iconFile) else {
            add(content)
            return
        }

        // Notification de communication : l'icône personnalisée remplace celle de l'app
        // (en rond, avec le petit logo de l'app dans le coin), comme les messageries.
        let avatar = INImage(imageData: iconData)
        let key = "nova-" + iconFile
        let sender = INPerson(personHandle: INPersonHandle(value: key, type: .unknown),
                              nameComponents: nil,
                              displayName: title,
                              image: avatar,
                              contactIdentifier: nil,
                              customIdentifier: key)
        let intent = INSendMessageIntent(recipients: nil,
                                         outgoingMessageType: .outgoingMessageText,
                                         content: body,
                                         speakableGroupName: nil,
                                         conversationIdentifier: key,
                                         serviceName: nil,
                                         sender: sender,
                                         attachments: nil)
        intent.setImage(avatar, forParameterNamed: \INSendMessageIntent.sender)
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.direction = .incoming
        interaction.donate { _ in
            // Sans l'autorisation « Communication Notifications », iOS refuse : on envoie la version normale.
            do {
                let updated = try content.updating(from: intent)
                add(updated)
                UserDefaults.standard.removeObject(forKey: lastIconErrorKey)
            } catch {
                add(content)
                UserDefaults.standard.set(error.localizedDescription, forKey: lastIconErrorKey)
            }
        }
    }

    static let lastIconErrorKey = "derniereErreurIcone"

    static func cancel(_ ids: [UUID]) {
        guard !ids.isEmpty else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids.map(\.uuidString))
    }
}

// MARK: - Diagnostic des icônes personnalisées

enum IconSupport {
    case granted    // le profil de signature contient l'autorisation
    case missing    // installée sans l'autorisation (cas de SideStore avec un compte gratuit)
    case unknown    // pas de profil lisible

    /// Lit le profil de signature installé avec l'app (embedded.mobileprovision).
    static let current: IconSupport = {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url) else { return .unknown }
        let text = String(decoding: data, as: UTF8.self)
        return text.contains("com.apple.developer.usernotifications.communication") ? .granted : .missing
    }()

    static var lastError: String? {
        UserDefaults.standard.string(forKey: Notifier.lastIconErrorKey)
    }
}

// MARK: - Images

enum ImageStore {
    private static let cache = NSCache<NSString, UIImage>()

    static var folder: URL {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func url(_ name: String) -> URL { folder.appendingPathComponent(name) }

    /// Redimensionne, compresse et enregistre une image. Renvoie son nom de fichier.
    static func save(_ data: Data, maxSide: CGFloat = 1200) -> String? {
        guard let image = UIImage(data: data) else { return nil }
        return save(image: image, maxSide: maxSide)
    }

    static func save(image: UIImage, maxSide: CGFloat = 1200) -> String? {
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let jpg = resized.jpegData(compressionQuality: 0.85) else { return nil }
        let name = UUID().uuidString + ".jpg"
        do {
            try jpg.write(to: url(name))
            return name
        } catch {
            return nil
        }
    }

    static func load(_ name: String?) -> UIImage? {
        guard let name else { return nil }
        if let cached = cache.object(forKey: name as NSString) { return cached }
        guard let image = UIImage(contentsOfFile: url(name).path) else { return nil }
        cache.setObject(image, forKey: name as NSString)
        return image
    }

    /// Vignette carrée très légère (pour les Activités en direct, limitées à 4 Ko).
    static func thumbnailData(_ name: String?, side: CGFloat) -> Data? {
        guard let image = load(name), image.size.width > 0, image.size.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let size = CGSize(width: side, height: side)
        let scale = max(side / image.size.width, side / image.size.height)
        let drawn = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let thumb = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(x: (side - drawn.width) / 2, y: (side - drawn.height) / 2,
                                  width: drawn.width, height: drawn.height))
        }
        return thumb.jpegData(compressionQuality: 0.6)
    }

    static func data(_ name: String) -> Data? {
        try? Data(contentsOf: url(name))
    }

    static func copy(_ name: String?) -> String? {
        guard let name else { return nil }
        let newName = UUID().uuidString + ".jpg"
        do {
            try FileManager.default.copyItem(at: url(name), to: url(newName))
            return newName
        } catch {
            return nil
        }
    }

    static func delete(_ name: String?) {
        guard let name else { return }
        cache.removeObject(forKey: name as NSString)
        try? FileManager.default.removeItem(at: url(name))
    }

    /// iOS déplace le fichier joint : on lui donne une copie temporaire.
    static func attachment(_ name: String?) -> UNNotificationAttachment? {
        guard let name, FileManager.default.fileExists(atPath: url(name).path) else { return nil }
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        do {
            try FileManager.default.copyItem(at: url(name), to: tmp)
            return try UNNotificationAttachment(identifier: name, url: tmp, options: nil)
        } catch {
            return nil
        }
    }
}
