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
    let template: NotifTemplate

    var body: some View {
        HStack(spacing: 12) {
            TemplateThumbnail(template: template, size: 46)

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

/// Vignette d'un modèle : son icône, sinon son image, sinon l'icône de l'app.
struct TemplateThumbnail: View {
    let template: NotifTemplate
    var size: CGFloat = 46

    var body: some View {
        if let icon = ImageStore.load(template.iconFile) {
            Image(uiImage: icon)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else if let image = ImageStore.load(template.imageFile) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        } else {
            AppEmblem(size: size)
        }
    }
}

// MARK: - Aperçu façon bannière iOS

struct NotificationPreview: View {
    let title: String
    let subtitle: String
    let message: String
    let image: UIImage?
    var icon: UIImage? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            leading
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
                if !subtitle.isEmpty {
                    Text(subtitle).font(.subheadline.weight(.medium)).lineLimit(1)
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
            LinearGradient(colors: [BW.sea.opacity(0.45), BW.gold.opacity(0.25)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        )
    }

    @ViewBuilder private var leading: some View {
        if let icon {
            // Rendu d'une notification de communication : icône ronde + petit logo de l'app
            Image(uiImage: icon)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(alignment: .bottomTrailing) {
                    AppEmblem(size: 17)
                        .offset(x: 3, y: 3)
                }
        } else {
            AppEmblem(size: 38)
        }
    }
}

// MARK: - Édition d'un modèle

struct TemplateEditor: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let original: NotifTemplate
    let isNew: Bool
    @State private var draft: NotifTemplate
    @State private var previewImage: UIImage?
    @State private var iconImage: UIImage?
    @State private var photo: PhotosPickerItem?
    @State private var iconPhoto: PhotosPickerItem?
    @State private var loadingImage = false
    @State private var iconColor = 1
    @State private var iconSymbol: String?      // dernier symbole généré ("" = initiales)

    private static let emojis = ["💬", "📦", "💳", "📅", "🔔", "✅", "⚠️", "🎉", "❤️", "⭐️", "📸", "🛒", "🔥", "👋"]

    init(original: NotifTemplate, isNew: Bool) {
        self.original = original
        self.isNew = isNew
        _draft = State(initialValue: original)
        _previewImage = State(initialValue: ImageStore.load(original.imageFile))
        _iconImage = State(initialValue: ImageStore.load(original.iconFile))
    }

    private var initials: String {
        IconMaker.initials(from: draft.title)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NotificationPreview(title: draft.displayTitle, subtitle: draft.subtitle,
                                        message: draft.body, image: previewImage, icon: iconImage)
                        .animation(.easeInOut(duration: 0.2), value: draft)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                } header: {
                    Text("Aperçu")
                }

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

                iconSection

                Section("Image jointe") {
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
                        Button(role: .destructive) { setFile(\.imageFile, nil) } label: {
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
                        Label("Notification rare", systemImage: "star.fill")
                    }
                } header: {
                    Text("Apparition")
                } footer: {
                    Text("Un modèle ×3 sort trois fois plus souvent qu'un modèle ×1. Un modèle rare n'apparaît que selon la « chance de rare » réglée dans la configuration.")
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
                    Button("Annuler") { cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(draft.isEmpty)
                }
            }
            .onChange(of: photo) { item in
                guard let item else { return }
                Task { await loadPhoto(item, into: \.imageFile, maxSide: 1200) }
            }
            .onChange(of: iconPhoto) { item in
                guard let item else { return }
                Task { await loadPhoto(item, into: \.iconFile, maxSide: 400) }
            }
        }
        .interactiveDismissDisabled(draft != original)
    }

    // MARK: Icône

    private var iconSection: some View {
        Section {
            HStack(spacing: 14) {
                if let iconImage {
                    Image(uiImage: iconImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(Circle())
                } else {
                    AppEmblem(size: 52)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(iconImage == nil ? "Icône de l'app" : "Icône personnalisée")
                        .font(.subheadline.weight(.semibold))
                    Text("Choisis une photo ou crée une icône ci-dessous.")
                        .font(.caption)
                        .foregroundStyle(BW.mist)
                }
            }

            PhotosPicker(selection: $iconPhoto, matching: .images) {
                Label("Choisir une photo", systemImage: "person.crop.circle")
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Créer une icône").font(.subheadline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(IconMaker.colors.indices, id: \.self) { i in
                            Button {
                                iconColor = i
                                if let iconSymbol { generateIcon(symbol: iconSymbol) }
                            } label: {
                                Circle()
                                    .fill(Color(IconMaker.colors[i]))
                                    .frame(width: 28, height: 28)
                                    .overlay(Circle().strokeBorder(Color.white, lineWidth: iconColor == i ? 2.5 : 0))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button { generateIcon(symbol: "") } label: {
                            symbolTile(Text(initials.isEmpty ? "Aa" : initials)
                                .font(.system(size: 15, weight: .semibold, design: .rounded)))
                        }
                        .buttonStyle(.plain)
                        ForEach(IconMaker.symbols, id: \.self) { s in
                            Button { generateIcon(symbol: s) } label: {
                                symbolTile(Image(systemName: s).font(.system(size: 16, weight: .semibold)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if draft.iconFile != nil {
                Button(role: .destructive) {
                    iconSymbol = nil
                    setFile(\.iconFile, nil)
                } label: {
                    Label("Retirer l'icône", systemImage: "trash")
                }
            }
        } header: {
            Text("Icône")
        } footer: {
            Text("Comme dans les messageries : l'icône s'affiche en rond à gauche de la notification, avec le petit logo de Nova dans le coin. Le titre sert de nom d'expéditeur.")
        }
        .listRowBackground(BW.hull)
    }

    private func symbolTile<V: View>(_ content: V) -> some View {
        content
            .foregroundStyle(.white)
            .frame(width: 38, height: 38)
            .background(Circle().fill(Color(IconMaker.colors[iconColor])))
    }

    private func generateIcon(symbol: String) {
        iconSymbol = symbol
        let image: UIImage
        if symbol.isEmpty {
            image = IconMaker.render(initials: initials.isEmpty ? "?" : initials, color: IconMaker.colors[iconColor])
        } else {
            image = IconMaker.render(symbol: symbol, color: IconMaker.colors[iconColor])
        }
        setFile(\.iconFile, ImageStore.save(image: image, maxSide: 256))
    }

    // MARK: Fichiers

    private func setFile(_ keyPath: WritableKeyPath<NotifTemplate, String?>, _ name: String?) {
        // Un fichier ajouté pendant cette édition puis remplacé n'est plus utile
        if draft[keyPath: keyPath] != original[keyPath: keyPath] { ImageStore.delete(draft[keyPath: keyPath]) }
        draft[keyPath: keyPath] = name
        if keyPath == \NotifTemplate.iconFile {
            iconImage = ImageStore.load(name)
        } else {
            previewImage = ImageStore.load(name)
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem, into keyPath: WritableKeyPath<NotifTemplate, String?>,
                           maxSide: CGFloat) async {
        loadingImage = true
        if let data = try? await item.loadTransferable(type: Data.self),
           let name = ImageStore.save(data, maxSide: maxSide) {
            if keyPath == \NotifTemplate.iconFile { iconSymbol = nil }
            setFile(keyPath, name)
        } else {
            store.message = "Impossible de charger cette image."
        }
        loadingImage = false
        photo = nil
        iconPhoto = nil
    }

    private func cancel() {
        if draft.imageFile != original.imageFile { ImageStore.delete(draft.imageFile) }
        if draft.iconFile != original.iconFile { ImageStore.delete(draft.iconFile) }
        dismiss()
    }

    private func save() {
        store.upsertTemplate(draft)
        if original.imageFile != draft.imageFile { store.releaseImage(original.imageFile) }
        if original.iconFile != draft.iconFile { store.releaseImage(original.iconFile) }
        dismiss()
    }
}
