import SwiftUI
import PhotosUI

// Gestion des applis web expéditrices (une icône et un nom par expéditeur).
struct PersonasView: View {
    @EnvironmentObject var store: AppStore
    @State private var customSlot: WebPersonas.Slot?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("De vraies notifications, avec d'autres icônes")
                        .font(BW.font(.headline, .semibold))
                    Text("Chaque expéditeur est une petite appli web que tu ajoutes à ton écran d'accueil. Ses notifications arrivent avec sa propre icône et son nom, et s'empilent normalement. Nova les envoie pendant les scénarios.")
                        .font(.footnote)
                        .foregroundStyle(BW.mist)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(BW.hull)

            Section {
                step(1, "Touche « Installer » : la page de l'expéditeur s'ouvre dans Safari.")
                step(2, "Partager ⬆︎ › « Sur l'écran d'accueil ». Tu peux choisir son nom.")
                step(3, "Ouvre la nouvelle icône, puis « Activer les notifications ».")
                step(4, "L'appli web rouvre Nova : l'expéditeur apparaît comme connecté.")
            } header: {
                Text("Installation (une fois par expéditeur)")
            } footer: {
                Text("Nécessite iOS 16.4 ou plus récent. Utilise Safari pour l'ajout à l'écran d'accueil.")
            }
            .listRowBackground(BW.hull)

            Section("Expéditeurs") {
                ForEach(WebPersonas.slots) { slot in
                    PersonaRow(slot: slot, persona: store.persona(slot.id),
                               install: { install(slot) },
                               test: { store.testPersona(slot.id) },
                               remove: { store.removePersona(slot.id) })
                }
            }
            .listRowBackground(BW.hull)

            Section {
                Button {
                    store.importPersonaFromClipboard()
                } label: {
                    Label("Coller une connexion", systemImage: "doc.on.clipboard")
                }
            } footer: {
                Text("Si l'appli web n'a pas réussi à rouvrir Nova : dans l'appli web, touche « Renvoyer la connexion à Nova », reviens ici et colle.")
            }
            .listRowBackground(BW.hull)

            Section {
                TextField("Adresse du site", text: $store.webBaseURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.footnote)
            } header: {
                Text("Site des applis web")
            } footer: {
                Text("Pages du dossier docs/ du dépôt, publiées par GitHub Pages (Settings › Pages › Deploy from a branch › main, /docs).")
            }
            .listRowBackground(BW.hull)

            if let message = store.message {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(BW.rust)
                }
                .listRowBackground(BW.hull)
            }
        }
        .bwForm()
        .navigationTitle("Applis expéditrices")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $customSlot) { slot in
            CustomPersonaSheet(slot: slot) { name, icon in
                open(slot, name: name, icon: icon)
            }
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(n)")
                .font(.footnote.weight(.bold))
                .foregroundStyle(BW.abyss)
                .frame(width: 20, height: 20)
                .background(Circle().fill(BW.gold))
            Text(text).font(.footnote)
        }
    }

    private func install(_ slot: WebPersonas.Slot) {
        if slot.custom {
            customSlot = slot
        } else {
            open(slot, name: nil, icon: nil)
        }
    }

    private func open(_ slot: WebPersonas.Slot, name: String?, icon: Data?) {
        // La clé est aussi copiée, au cas où l'appli installée ne la recevrait pas par l'adresse.
        UIPasteboard.general.string = "NOVA-KEY:" + WebPush.publicKey
        guard let url = WebPersonas.installURL(base: store.webBaseURL, slot: slot, customName: name, customIcon: icon) else {
            store.message = "Adresse du site invalide."
            return
        }
        // Nova garde l'image choisie pour l'afficher avec cet expéditeur
        if let icon { SenderIcons.saveCustom(icon, for: slot.id) }
        UIApplication.shared.open(url)
    }
}

private struct PersonaRow: View {
    let slot: WebPersonas.Slot
    let persona: Persona?
    let install: () -> Void
    let test: () -> Void
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            SenderIcon(slot: slot, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(persona?.name ?? slot.label)
                    .font(BW.font(.body, .semibold))
                    .foregroundStyle(BW.parchment)
                if let persona {
                    if let status = persona.lastStatus {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(BW.rust)
                            .lineLimit(2)
                    } else {
                        Label("Connecté", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(BW.sea)
                    }
                } else {
                    Text(slot.custom ? "Nom et icône au choix" : "Non installé")
                        .font(.caption)
                        .foregroundStyle(BW.mist)
                }
            }
            Spacer(minLength: 4)
            if persona != nil {
                Button("Tester", action: test)
                    .buttonStyle(.borderless)
                    .font(.footnote.weight(.semibold))
            }
            Button(persona == nil ? "Installer" : "Refaire", action: install)
                .buttonStyle(.borderless)
                .font(.footnote.weight(.semibold))
        }
        .swipeActions(edge: .trailing) {
            if persona != nil {
                Button(role: .destructive, action: remove) {
                    Label("Oublier", systemImage: "trash")
                }
            }
        }
    }
}

/// Choix du nom et de l'icône d'un expéditeur « Perso ».
private struct CustomPersonaSheet: View {
    @Environment(\.dismiss) private var dismiss
    let slot: WebPersonas.Slot
    let onInstall: (String, Data?) -> Void

    @State private var name = ""
    @State private var photo: PhotosPickerItem?
    @State private var icon: UIImage?

    var body: some View {
        NavigationStack {
            Form {
                Section("Nom") {
                    TextField("Nom de l'appli", text: $name)
                }
                .listRowBackground(BW.hull)

                Section {
                    HStack(spacing: 14) {
                        Group {
                            if let icon {
                                Image(uiImage: icon).resizable().scaledToFill()
                            } else {
                                Image(uiImage: SenderIcons.image(slot)).resizable().scaledToFill()
                            }
                        }
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12.6, style: .continuous))

                        PhotosPicker(selection: $photo, matching: .images) {
                            Label(icon == nil ? "Choisir une image" : "Changer l'image", systemImage: "photo")
                        }
                    }
                } header: {
                    Text("Icône")
                } footer: {
                    Text("Image recadrée en carré. Si iOS ne la prend pas en compte, l'appli gardera l'icône de Nova.")
                }
                .listRowBackground(BW.hull)
            }
            .bwForm()
            .navigationTitle(slot.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Installer") {
                        let data = icon.flatMap { Self.squareJPEG($0, side: 180) }
                        dismiss()
                        onInstall(name.trimmingCharacters(in: .whitespaces), data)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: photo) { item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        icon = UIImage(data: data)
                    }
                }
            }
        }
    }

    /// Recadre au centre en carré et compresse (l'image voyage dans l'adresse de la page).
    private static func squareJPEG(_ image: UIImage, side: CGFloat) -> Data? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let scale = max(side / image.size.width, side / image.size.height)
        let drawn = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let square = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            image.draw(in: CGRect(x: (side - drawn.width) / 2, y: (side - drawn.height) / 2,
                                  width: drawn.width, height: drawn.height))
        }
        return square.jpegData(compressionQuality: 0.7)
    }
}
