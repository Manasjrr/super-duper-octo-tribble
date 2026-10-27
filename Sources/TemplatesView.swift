import SwiftUI

// MARK: - Liste des modèles, rangés par appli expéditrice

struct TemplatesView: View {
    @EnvironmentObject var store: AppStore
    @State private var editing: NotifTemplate?
    @State private var search = ""
    @State private var filter: String?      // appli affichée (nil = toutes)

    var body: some View {
        let visible = store.templates.filter { (filter == nil || $0.sender == filter) && matches($0) }
        let groups = store.groupedBySender(visible)

        NavigationStack {
            List {
                if store.templates.isEmpty {
                    Text("Aucun modèle. Appuie sur + pour en créer un.")
                        .foregroundStyle(BW.mist)
                        .listRowBackground(BW.hull)
                } else if groups.isEmpty {
                    Text(search.isEmpty ? "Aucun modèle pour cette appli." : "Aucun résultat.")
                        .foregroundStyle(BW.mist)
                        .listRowBackground(BW.hull)
                }
                ForEach(groups) { group in
                    Section {
                        rows(group.templates)
                    } header: {
                        SenderGroupHeader(slot: group.slot, count: group.templates.count) {
                            Button { create(for: group.slot.id) } label: {
                                Image(systemName: "plus.circle.fill").font(.body)
                            }
                        }
                    }
                }
            }
            .bwForm()
            .safeAreaInset(edge: .top, spacing: 0) {
                SenderFilterBar(selection: $filter)
            }
            .searchable(text: $search, prompt: "Rechercher un modèle")
            .navigationTitle("Modèles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { create(for: filter) } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $editing) { t in
                TemplateEditor(original: t, isNew: !store.templates.contains { $0.id == t.id })
            }
        }
    }

    private func create(for sender: String?) {
        var t = NotifTemplate()
        if let sender, sender != WebPersonas.defaultSender { t.personaID = sender }
        editing = t
    }

    private func matches(_ t: NotifTemplate) -> Bool {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        let sender = WebPersonas.slot(t.sender).map { store.senderName($0) } ?? ""
        let texts = [t.displayTitle, t.subtitle, t.body, sender] + t.steps.flatMap { [$0.title, $0.body] }
        return texts.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    @ViewBuilder private func rows(_ list: [NotifTemplate]) -> some View {
        // Réordonner seulement hors recherche, à l'intérieur de chaque appli
        let move: ((IndexSet, Int) -> Void)? = search.isEmpty
            ? { from, to in store.moveTemplates(list, from: from, to: to) }
            : nil
        ForEach(list) { t in
            Button { editing = t } label: { TemplateRow(template: t) }
                .listRowBackground(BW.hull)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { store.deleteTemplate(t) } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                    Button { store.duplicateTemplate(t) } label: {
                        Label("Dupliquer", systemImage: "doc.on.doc")
                    }
                    .tint(BW.sea)
                }
                .swipeActions(edge: .leading) {
                    Button { store.sendTest(t) } label: {
                        Label("Tester", systemImage: "bell.fill")
                    }
                    .tint(BW.gold)
                }
                .contextMenu {
                    Button { store.sendTest(t) } label: { Label("Tester", systemImage: "bell.fill") }
                    Button { editing = t } label: { Label("Modifier", systemImage: "pencil") }
                    Button { store.duplicateTemplate(t) } label: { Label("Dupliquer", systemImage: "doc.on.doc") }
                    Button(role: .destructive) { store.deleteTemplate(t) } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                }
        }
        .onMove(perform: move)
    }
}

/// Filtre par appli, toujours visible en haut de la liste.
private struct SenderFilterBar: View {
    @EnvironmentObject var store: AppStore
    @Binding var selection: String?

    var body: some View {
        let counts = Dictionary(grouping: store.templates, by: \.sender).mapValues(\.count)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(nil, label: "Toutes", count: store.templates.count)
                ForEach(WebPersonas.slots.filter { counts[$0.id] != nil || $0.id == selection }) { slot in
                    chip(slot, label: store.senderName(slot), count: counts[slot.id] ?? 0)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(BW.abyss.opacity(0.97))
    }

    private func chip(_ slot: WebPersonas.Slot?, label: String, count: Int) -> some View {
        let selected = selection == slot?.id
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selection = slot?.id }
        } label: {
            HStack(spacing: 6) {
                if let slot { SenderIcon(slot: slot, size: 22) }
                Text(label).lineLimit(1)
                Text("\(count)")
                    .foregroundStyle(selected ? BW.abyss.opacity(0.6) : BW.mist)
                    .monospacedDigit()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(selected ? BW.abyss : BW.parchment)
            .padding(.leading, slot == nil ? 12 : 5)
            .padding(.trailing, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(selected ? BW.gold : BW.hull))
        }
        .buttonStyle(.plain)
    }
}

/// En-tête d'une catégorie : icône et nom de l'appli expéditrice.
struct SenderGroupHeader<Trailing: View>: View {
    @EnvironmentObject var store: AppStore
    let slot: WebPersonas.Slot
    let count: Int
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 8) {
            SenderIcon(slot: slot, size: 22)
            Text(store.senderName(slot))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BW.parchment)
            Text("\(count)")
                .font(.subheadline)
                .foregroundStyle(BW.mist)
            if store.persona(slot.id) == nil {
                Text("non installée")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BW.gold)
            }
            Spacer()
            trailing
        }
        .textCase(nil)
    }
}

private struct TemplateRow: View {
    let template: NotifTemplate

    var body: some View {
        let steps = template.steps.filter { !$0.isEmpty }
        HStack(alignment: .top, spacing: 12) {
            SenderIcon(slot: WebPersonas.slot(template.sender), size: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(template.displayTitle.isEmpty ? "Sans titre" : template.displayTitle)
                    .font(BW.font(.body, .semibold))
                    .foregroundStyle(BW.parchment)
                    .lineLimit(1)
                if !template.body.isEmpty {
                    Text(template.body)
                        .font(.footnote)
                        .foregroundStyle(BW.mist)
                        .lineLimit(2)
                }
                if !steps.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(steps.prefix(2)) { step in
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.turn.down.right")
                                Text(step.body.isEmpty ? step.title : step.body)
                                    .lineLimit(1)
                            }
                        }
                        if steps.count > 2 {
                            Text("+ \(steps.count - 2) autre\(steps.count > 3 ? "s" : "")")
                                .padding(.leading, 18)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(BW.mist)
                }
                badges
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder private var badges: some View {
        let steps = template.steps.filter { !$0.isEmpty }.count
        if template.frequency != .normal || template.canRepeat || steps > 0 {
            HStack(spacing: 10) {
                if template.frequency == .rare {
                    Label("Rare", systemImage: "star.fill").foregroundStyle(BW.gold)
                }
                if template.frequency == .often {
                    Label("Souvent", systemImage: "bolt.fill").foregroundStyle(BW.gold)
                }
                if steps > 0 {
                    Label("Cascade de \(steps + 1)", systemImage: "square.stack.3d.down.right")
                }
                if template.canRepeat {
                    Label("Répétable", systemImage: "repeat")
                }
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(BW.mist)
            .padding(.top, 2)
        }
    }
}

// MARK: - Icônes des applis expéditrices

/// Même icône que celle installée sur l'écran d'accueil : celle de l'appli web, ou l'image choisie
/// pour un expéditeur « Perso ».
enum SenderIcons {
    private static var cache: [String: UIImage] = [:]
    private static let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Icones")

    static func image(_ slot: WebPersonas.Slot?) -> UIImage {
        let id = slot?.id ?? WebPersonas.defaultSender
        if let cached = cache[id] { return cached }
        let custom = slot?.custom == true ? UIImage(contentsOfFile: file(id).path) : nil
        let image = custom ?? UIImage(named: "Preview-Persona-" + id) ?? UIImage(named: "Emblem") ?? UIImage()
        cache[id] = image
        return image
    }

    static func saveCustom(_ data: Data, for id: String) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: file(id), options: .atomic)
        cache[id] = nil
    }

    private static func file(_ id: String) -> URL {
        folder.appendingPathComponent(id + ".jpg")
    }
}

/// Icône d'une appli expéditrice (celle de Nova par défaut).
struct SenderIcon: View {
    let slot: WebPersonas.Slot?
    var size: CGFloat = 44

    var body: some View {
        Image(uiImage: SenderIcons.image(slot))
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .background(Color.black)    // comme sur l'écran d'accueil, la transparence apparaît en noir
            .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
    }
}

// MARK: - Aperçu façon bannière iOS

struct NotificationPreview: View {
    let title: String
    let subtitle: String
    let message: String
    let slot: WebPersonas.Slot?

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            SenderIcon(slot: slot, size: 38)
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title.isEmpty ? "Titre" : title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text("maintenant")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                // Les notifications web n'ont pas de sous-titre : il est ajouté en tête du texte
                Text(subtitle.isEmpty ? (message.isEmpty ? "Message" : message) : subtitle + "\n" + message)
                    .font(.subheadline)
                    .lineLimit(4)
            }
        }
        .foregroundStyle(.primary)
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(
            // Fond flouté façon fond d'écran
            LinearGradient(colors: [BW.sea.opacity(0.45), BW.gold.opacity(0.25)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        )
    }
}

/// La notification et toute sa cascade, dans l'ordre d'arrivée.
private struct CascadePreview: View {
    let template: NotifTemplate

    var body: some View {
        let slot = WebPersonas.slot(template.sender)
        VStack(spacing: 6) {
            NotificationPreview(title: template.displayTitle, subtitle: template.subtitle,
                                message: template.body, slot: slot)
            ForEach(Array(template.cascade.enumerated()), id: \.offset) { _, item in
                Label("\(formatDuration(item.1)) plus tard", systemImage: "arrow.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BW.mist)
                NotificationPreview(title: item.0.displayTitle, subtitle: "", message: item.0.body, slot: slot)
            }
        }
    }
}

// MARK: - Choix de l'appli expéditrice

private struct SenderPicker: View {
    @EnvironmentObject var store: AppStore
    @Binding var personaID: String?     // nil = Nova

    var body: some View {
        let current = WebPersonas.slot(personaID)?.id ?? WebPersonas.defaultSender
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(WebPersonas.slots) { slot in
                    let selected = slot.id == current
                    Button {
                        personaID = slot.id == WebPersonas.defaultSender ? nil : slot.id
                    } label: {
                        VStack(spacing: 6) {
                            SenderIcon(slot: slot, size: 50)
                                .opacity(selected || store.persona(slot.id) != nil ? 1 : 0.45)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                                        .strokeBorder(selected ? BW.gold : Color.clear, lineWidth: 2.5)
                                        .padding(-4)
                                )
                            Text(store.senderName(slot))
                                .font(.caption2.weight(selected ? .bold : .regular))
                                .foregroundStyle(selected ? BW.gold : BW.parchment)
                                .lineLimit(1)
                        }
                        .frame(width: 62)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
        }
    }
}

// MARK: - Édition d'un modèle

struct TemplateEditor: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let isNew: Bool
    @State private var initial: NotifTemplate
    @State private var draft: NotifTemplate
    @State private var confirmDelete = false

    private static let maxSteps = 10

    init(original: NotifTemplate, isNew: Bool) {
        // L'emoji fait partie du titre : un seul champ à remplir
        var t = original
        if !t.emoji.isEmpty {
            t.title = t.displayTitle
            t.emoji = ""
        }
        self.isNew = isNew
        _initial = State(initialValue: t)
        _draft = State(initialValue: t)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CascadePreview(template: draft)
                        .animation(.easeInOut(duration: 0.2), value: draft)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                } header: {
                    Text("Aperçu")
                }

                Section {
                    SenderPicker(personaID: $draft.personaID)
                        .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                } header: {
                    Text("Appli expéditrice")
                } footer: {
                    Text(senderFooter)
                }
                .listRowBackground(BW.hull)

                Section("Notification") {
                    TextField("Titre (ex. le nom de l'expéditeur)", text: $draft.title)
                    TextField("Message", text: $draft.body, axis: .vertical)
                        .lineLimit(2...6)
                    TextField("Sous-titre (optionnel)", text: $draft.subtitle)
                }
                .listRowBackground(BW.hull)

                ForEach(Array(draft.steps.enumerated()), id: \.element.id) { index, step in
                    Section {
                        DurationStepper(label: index == 0 ? "Après la notification" : "Après la suite \(index)",
                                        seconds: stepBinding(step.id).delay, range: 1...3600)
                        TextField("Titre (sinon « \(mainTitle) »)", text: stepBinding(step.id).title)
                        TextField("Message", text: stepBinding(step.id).body, axis: .vertical)
                            .lineLimit(1...6)
                        Button(role: .destructive) { removeStep(step.id) } label: {
                            Label("Retirer cette suite", systemImage: "minus.circle")
                        }
                    } header: {
                        Label("Suite \(index + 1)", systemImage: "arrow.turn.down.right")
                    }
                    .listRowBackground(BW.hull)
                }

                Section {
                    Button { addStep() } label: {
                        Label(draft.steps.isEmpty ? "Ajouter une suite" : "Ajouter une autre suite",
                              systemImage: "plus.circle.fill")
                    }
                    .disabled(draft.steps.count >= Self.maxSteps)
                } header: {
                    if draft.steps.isEmpty { Text("Cascade") }
                } footer: {
                    Text(cascadeFooter)
                }
                .listRowBackground(BW.hull)

                Section {
                    Picker("Fréquence", selection: $draft.frequency) {
                        ForEach(Frequency.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Peut revenir plusieurs fois", isOn: $draft.canRepeat)
                } header: {
                    Text("Apparition")
                } footer: {
                    Text("Souvent : sort plus souvent qu'une notification normale. Rare : n'apparaît que selon la « chance de rare » réglée dans la configuration. Sans « Peut revenir », elle n'arrive qu'une fois par scénario.")
                }
                .listRowBackground(BW.hull)

                Section {
                    Button { store.sendTest(draft) } label: {
                        Label(draft.cascade.isEmpty ? "Envoyer un test maintenant" : "Tester avec la cascade",
                              systemImage: "bell.badge.fill")
                    }
                    .disabled(draft.isEmpty)
                    if !isNew {
                        Button(role: .destructive) { confirmDelete = true } label: {
                            Label("Supprimer ce modèle", systemImage: "trash")
                        }
                    }
                }
                .listRowBackground(BW.hull)
            }
            .bwForm()
            .navigationTitle(isNew ? "Nouveau modèle" : "Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        var t = draft
                        t.steps.removeAll { $0.isEmpty }
                        store.upsertTemplate(t)
                        dismiss()
                    }
                    .disabled(draft.isEmpty)
                }
            }
            .confirmationDialog("Supprimer ce modèle ?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Supprimer", role: .destructive) {
                    store.deleteTemplate(initial)
                    dismiss()
                }
            }
        }
        .interactiveDismissDisabled(draft != initial)
    }

    private var mainTitle: String {
        draft.displayTitle.isEmpty ? "même titre" : draft.displayTitle
    }

    private var senderFooter: String {
        let slot = WebPersonas.slot(draft.sender)
        let name = slot.map { store.senderName($0) } ?? "Nova"
        if store.persona(draft.sender) == nil {
            return "« \(name) » n'est pas encore installée : la notification arrivera depuis Nova. Installe-la dans Configurations › Applis expéditrices."
        }
        return "La notification arrive depuis « \(name) », avec son icône et son nom."
    }

    private var cascadeFooter: String {
        if draft.steps.isEmpty {
            return "Une cascade envoie automatiquement d'autres notifications après celle-ci, depuis la même appli. Par exemple « t'es là ? », puis 20 s plus tard « allô ? réponds »."
        }
        return "Les suites arrivent à chaque fois après cette notification, dans l'ordre, même téléphone verrouillé. Titre vide : elles gardent « \(mainTitle) »."
    }

    private func stepBinding(_ id: UUID) -> Binding<CascadeStep> {
        Binding(
            get: { draft.steps.first { $0.id == id } ?? CascadeStep(id: id) },
            set: { v in
                if let i = draft.steps.firstIndex(where: { $0.id == id }) { draft.steps[i] = v }
            }
        )
    }

    private func addStep() {
        var step = CascadeStep()
        if let last = draft.steps.last { step.delay = last.delay }
        withAnimation { draft.steps.append(step) }
    }

    private func removeStep(_ id: UUID) {
        withAnimation { draft.steps.removeAll { $0.id == id } }
    }
}
