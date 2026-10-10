import SwiftUI
import PhotosUI

// MARK: - Liste des messages

struct TemplatesView: View {
    @EnvironmentObject var store: AppStore
    @State private var editing: NotifTemplate?

    var body: some View {
        NavigationStack {
            List {
                if store.templates.isEmpty {
                    Text("Aucun message. Appuie sur + pour en créer un.")
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
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { editing = NotifTemplate(emoji: "🍊") } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $editing) { t in
                TemplateEditor(original: t, isNew: !store.templates.contains { $0.id == t.id })
            }
        }
    }
}

private struct TemplateRow: View {
    let template: NotifTemplate

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(BW.abyss)
                if let image = ImageStore.load(template.imageFile) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Text(template.emoji.isEmpty ? "✉️" : template.emoji).font(.title2)
                }
            }
            .frame(width: 46, height: 46)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(template.title.isEmpty ? "Sans titre" : template.title)
                        .font(BW.serif(.body, .semibold))
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
            }
            Spacer(minLength: 0)
            if template.weight != 1 {
                Text("×\(Int(template.weight))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BW.gold)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Aperçu façon bannière iOS

struct NotificationPreview: View {
    let title: String
    let subtitle: String
    let message: String
    let image: UIImage?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AppEmblem(size: 38)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title.isEmpty ? "Titre" : title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text("maintenant")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !subtitle.isEmpty {
                    Text(subtitle).font(.subheadline).lineLimit(1)
                }
                Text(message.isEmpty ? "Message" : message)
                    .font(.subheadline)
                    .lineLimit(4)
            }
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 38, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .foregroundStyle(.primary)
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(
            // Fond flouté façon fond d'écran
            LinearGradient(colors: [BW.sea.opacity(0.5), BW.rust.opacity(0.35)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        )
    }
}

// MARK: - Édition d'un message

struct TemplateEditor: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let original: NotifTemplate
    let isNew: Bool
    @State private var draft: NotifTemplate
    @State private var previewImage: UIImage?
    @State private var photo: PhotosPickerItem?
    @State private var loadingImage = false

    private static let emojis = ["🍊", "🏴‍☠️", "⚓", "🦑", "💰", "🔫", "🍺", "🗡️", "🐚", "🔥", "💀", "🌊", "🪝", "🦜"]

    init(original: NotifTemplate, isNew: Bool) {
        self.original = original
        self.isNew = isNew
        _draft = State(initialValue: original)
        _previewImage = State(initialValue: ImageStore.load(original.imageFile))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NotificationPreview(title: draft.displayTitle, subtitle: draft.subtitle,
                                        message: draft.body, image: previewImage)
                        .animation(.easeInOut(duration: 0.2), value: draft)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                } header: {
                    Text("Aperçu")
                } footer: {
                    Text("L'icône à gauche est celle de l'app (imposée par iOS). L'emoji s'ajoute au titre.")
                }

                Section("Contenu") {
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
                    TextField("Titre", text: $draft.title)
                    TextField("Sous-titre (optionnel)", text: $draft.subtitle)
                    TextField("Message", text: $draft.body, axis: .vertical)
                        .lineLimit(2...6)
                }
                .listRowBackground(BW.hull)

                Section("Image") {
                    if let previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 150)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    PhotosPicker(selection: $photo, matching: .images) {
                        HStack {
                            Label(draft.imageFile == nil ? "Choisir une image" : "Changer l'image", systemImage: "photo")
                            if loadingImage {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    if draft.imageFile != nil {
                        Button(role: .destructive) { setImage(nil) } label: {
                            Label("Retirer l'image", systemImage: "trash")
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
                        Label("Message rare", systemImage: "star.fill")
                    }
                } header: {
                    Text("Apparition")
                } footer: {
                    Text("Un message ×3 sort trois fois plus souvent qu'un message ×1. Un message rare n'apparaît que selon la « chance de rare » réglée dans la configuration.")
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
            .navigationTitle(isNew ? "Nouveau message" : "Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(draft.isEmpty)
                }
            }
            .onChange(of: photo) { item in
                guard let item else { return }
                Task { await loadPhoto(item) }
            }
        }
        .interactiveDismissDisabled(draft != original)
    }

    private func setImage(_ name: String?) {
        // Une image ajoutée pendant cette édition et remplacée n'est plus utile
        if draft.imageFile != original.imageFile { ImageStore.delete(draft.imageFile) }
        draft.imageFile = name
        previewImage = ImageStore.load(name)
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        loadingImage = true
        if let data = try? await item.loadTransferable(type: Data.self), let name = ImageStore.save(data) {
            setImage(name)
        } else {
            store.message = "Impossible de charger cette image."
        }
        loadingImage = false
        photo = nil
    }

    private func cancel() {
        if draft.imageFile != original.imageFile { ImageStore.delete(draft.imageFile) }
        dismiss()
    }

    private func save() {
        store.upsertTemplate(draft)
        if original.imageFile != draft.imageFile { store.releaseImage(original.imageFile) }
        dismiss()
    }
}
