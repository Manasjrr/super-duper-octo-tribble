import SwiftUI

// MARK: - Liste des modèles

struct TemplatesView: View {
    @EnvironmentObject var store: AppStore
    @State private var editing: NotifTemplate?

    var body: some View {
        NavigationStack {
            List {
                if store.templates.isEmpty {
                    Text("Aucun modèle. Appuie sur + pour en créer un.")
                        .foregroundStyle(BW.mist)
                        .listRowBackground(BW.hull)
                }
                ForEach(store.templates) { t in
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
                .onMove { store.templates.move(fromOffsets: $0, toOffset: $1) }
            }
            .bwForm()
            .navigationTitle("Modèles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { editing = NotifTemplate() } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $editing) { t in
                TemplateEditor(original: t, isNew: !store.templates.contains { $0.id == t.id })
            }
        }
    }
}

private struct TemplateRow: View {
    @EnvironmentObject var store: AppStore
    let template: NotifTemplate

    private var followUpTitle: String? {
        guard let id = template.followUpID, let next = store.templates.first(where: { $0.id == id }) else { return nil }
        return next.displayTitle.isEmpty ? "Sans titre" : next.displayTitle
    }

    var body: some View {
        let slot = WebPersonas.slot(template.personaID ?? WebPersonas.defaultSender)
        HStack(spacing: 12) {
            SenderIcon(slot: slot, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(template.displayTitle.isEmpty ? "Sans titre" : template.displayTitle)
                        .font(BW.font(.body, .semibold))
                        .foregroundStyle(BW.parchment)
                        .lineLimit(1)
                    if template.isRare {
                        Label("Rare", systemImage: "star.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(BW.gold)
                    }
                }
                Text(template.body)
                    .font(.footnote)
                    .foregroundStyle(BW.mist)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(slot?.label ?? "Nova")
                    if template.onlyAsFollowUp {
                        Text("· en suite uniquement")
                    }
                    if let next = followUpTitle {
                        Label(next, systemImage: "arrow.turn.down.right")
                            .lineLimit(1)
                    }
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(BW.mist)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                if template.weight != 1 {
                    Text("×\(Int(template.weight))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BW.gold)
                }
                if template.maxPerRun > 0 {
                    Label("\(template.maxPerRun)", systemImage: "number.circle")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(BW.mist)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

/// Icône d'une appli expéditrice (celle de Nova par défaut).
struct SenderIcon: View {
    let slot: WebPersonas.Slot?
    var size: CGFloat = 44

    var body: some View {
        Image(slot?.preview ?? "Emblem")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
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

// MARK: - Édition d'un modèle

struct TemplateEditor: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let original: NotifTemplate
    let isNew: Bool
    @State private var draft: NotifTemplate

    private static let emojis = ["💬", "📷", "💳", "💰", "🔔", "✅", "⚠️", "🎉", "❤️", "⭐️", "📸", "🛒", "🔥", "👋"]

    init(original: NotifTemplate, isNew: Bool) {
        self.original = original
        self.isNew = isNew
        _draft = State(initialValue: original)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NotificationPreview(title: draft.displayTitle, subtitle: draft.subtitle, message: draft.body,
                                        slot: WebPersonas.slot(draft.personaID ?? WebPersonas.defaultSender))
                        .animation(.easeInOut(duration: 0.2), value: draft)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                } header: {
                    Text("Aperçu")
                }

                Section {
                    Picker("Expéditeur", selection: $draft.personaID) {
                        Text(senderLabel(WebPersonas.defaultSender)).tag(String?.none)
                        ForEach(WebPersonas.slots.filter { $0.id != WebPersonas.defaultSender }) { slot in
                            Text(senderLabel(slot.id)).tag(Optional(slot.id))
                        }
                    }
                } header: {
                    Text("Expéditeur")
                } footer: {
                    Text("La notification arrive depuis cette appli, avec son icône et son nom. À installer une fois dans Configurations › Applis expéditrices.")
                }
                .listRowBackground(BW.hull)

                Section("Contenu") {
                    TextField("Titre (ou nom de l'expéditeur)", text: $draft.title)
                    TextField("Sous-titre (optionnel)", text: $draft.subtitle)
                    TextField("Message", text: $draft.body, axis: .vertical)
                        .lineLimit(2...6)
                    HStack {
                        TextField("Emoji", text: $draft.emoji)
                            .frame(width: 56)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Self.emojis, id: \.self) { e in
                                    Button { draft.emoji = e } label: { Text(e).font(.title3) }
                                        .buttonStyle(.plain)
                                }
                                Button { draft.emoji = "" } label: {
                                    Image(systemName: "xmark.circle").foregroundStyle(BW.mist)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .listRowBackground(BW.hull)

                Section {
                    Stepper(value: $draft.weight, in: 1...10, step: 1) {
                        HStack {
                            Text("Fréquence")
                            Spacer()
                            Text("×\(Int(draft.weight))").foregroundStyle(BW.gold).monospacedDigit()
                        }
                    }
                    Toggle(isOn: $draft.isRare) {
                        Label("Notification rare", systemImage: "star.fill")
                    }
                } header: {
                    Text("Apparition")
                } footer: {
                    Text("Un modèle ×3 sort trois fois plus souvent qu'un modèle ×1. Un modèle rare n'apparaît que selon la « chance de rare » réglée dans la configuration.")
                }
                .listRowBackground(BW.hull)

                Section {
                    Stepper(value: $draft.maxPerRun, in: 0...20) {
                        HStack {
                            Text("Maximum par scénario")
                            Spacer()
                            Text(verbatim: draft.maxPerRun == 0 ? "Illimité" : "\(draft.maxPerRun) fois")
                                .foregroundStyle(BW.gold)
                                .monospacedDigit()
                        }
                    }
                } header: {
                    Text("Répartition")
                } footer: {
                    Text("« 1 fois » : cette notification n'apparaît qu'une seule fois par scénario, jamais en double. Pour l'appliquer à tous les modèles, active « Aucun doublon » dans la configuration.")
                }
                .listRowBackground(BW.hull)

                Section {
                    Picker("Notification suivante", selection: $draft.followUpID) {
                        Text("Aucune").tag(UUID?.none)
                        ForEach(store.templates.filter { $0.id != draft.id && !$0.isEmpty }) { t in
                            Text(t.displayTitle.isEmpty ? "Sans titre" : t.displayTitle).tag(Optional(t.id))
                        }
                    }
                    if draft.followUpID != nil {
                        DurationStepper(label: "Délai avant la suite", seconds: $draft.followUpDelay, range: 1...3600)
                    }
                    Toggle("Uniquement en suite d'une autre", isOn: $draft.onlyAsFollowUp)
                } header: {
                    Text("Cascade")
                } footer: {
                    Text("Notification suivante : envoyée automatiquement après celle-ci, à chaque fois. « Uniquement en suite » : ce modèle n'est jamais tiré au sort seul, il n'arrive qu'à la suite d'un autre.")
                }
                .listRowBackground(BW.hull)

                Section {
                    Button { store.sendTest(draft) } label: {
                        Label("Envoyer un test maintenant", systemImage: "bell.badge.fill")
                    }
                    .disabled(draft.isEmpty)
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
                        store.upsertTemplate(draft)
                        dismiss()
                    }
                    .disabled(draft.isEmpty)
                }
            }
        }
        .interactiveDismissDisabled(draft != original)
    }

    private func senderLabel(_ id: String) -> String {
        if let persona = store.persona(id) { return persona.name }
        return (WebPersonas.slot(id)?.label ?? id) + " (non installé)"
    }
}
