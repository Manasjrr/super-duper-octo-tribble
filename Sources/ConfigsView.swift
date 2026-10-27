import SwiftUI

// MARK: - Liste des configurations

struct ConfigsView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        PersonasView()
                    } label: {
                        Label("Applis expéditrices", systemImage: "app.badge")
                    }
                } footer: {
                    Text("Pour recevoir de vraies notifications avec des icônes différentes (Messages, Banque…).")
                }
                .listRowBackground(BW.hull)

                Section {
                    ForEach(store.configs) { c in
                        NavigationLink {
                            ConfigEditor(config: store.configBinding(c.id))
                        } label: {
                            ConfigRow(config: c, isActive: c.id == store.activeConfigID)
                        }
                        .listRowBackground(BW.hull)
                        .swipeActions(edge: .leading) {
                            Button { store.activeConfigID = c.id } label: {
                                Label("Choisir", systemImage: "checkmark")
                            }
                            .tint(BW.gold)
                        }
                        .swipeActions(edge: .trailing) {
                            if store.configs.count > 1 {
                                Button(role: .destructive) { store.deleteConfig(c) } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                            Button { store.duplicateConfig(c) } label: {
                                Label("Dupliquer", systemImage: "doc.on.doc")
                            }
                            .tint(BW.sea)
                        }
                        .contextMenu {
                            Button { store.activeConfigID = c.id } label: { Label("Choisir", systemImage: "checkmark") }
                            Button { store.duplicateConfig(c) } label: { Label("Dupliquer", systemImage: "doc.on.doc") }
                            if store.configs.count > 1 {
                                Button(role: .destructive) { store.deleteConfig(c) } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .onMove { store.configs.move(fromOffsets: $0, toOffset: $1) }
                } footer: {
                    Text("Glisse vers la droite pour choisir la configuration utilisée sur la page Accueil, vers la gauche pour la dupliquer ou la supprimer.")
                }
            }
            .bwForm()
            .navigationTitle("Configurations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { store.addConfig() } label: {
                            Label("Nouvelle configuration", systemImage: "plus")
                        }
                        Button { store.addPresets() } label: {
                            Label("Ajouter les préréglages", systemImage: "sparkles")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

private struct ConfigRow: View {
    let config: SendConfig
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isActive ? BW.gold : BW.mist)
                .font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                Text(config.name)
                    .font(BW.font(.body, .semibold))
                    .foregroundStyle(BW.parchment)
                Text("\(config.count) notifs · \(formatDuration(config.totalDuration)) · \(config.mode.label)")
                    .font(.footnote)
                    .foregroundStyle(BW.mist)
            }
        }
    }
}

// MARK: - Édition complète d'une configuration

struct ConfigEditor: View {
    @EnvironmentObject var store: AppStore
    @Binding var config: SendConfig
    @State private var sample: [Double] = []

    var body: some View {
        let pool = store.pool(for: config)
        let probabilities = Planner.probabilities(pool: pool, config: config)
        let hasRare = pool.contains { $0.isRare }
        let possible = Planner.achievableDuration(config)
        let usable = store.templates.filter { !$0.isEmpty }

        Form {
            Section("Nom") {
                TextField("Nom", text: $config.name)
                if store.activeConfigID != config.id {
                    Button {
                        store.activeConfigID = config.id
                    } label: {
                        Label("Utiliser sur la page Accueil", systemImage: "checkmark.circle")
                    }
                } else {
                    Label("Configuration utilisée sur la page Accueil", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(BW.gold)
                }
            }
            .listRowBackground(BW.hull)

            Section("Volume") {
                CountStepper(label: "Notifications", value: $config.count)
                DurationStepper(label: "Durée totale", seconds: $config.totalDuration, range: 5...86_400)
                DurationStepper(label: "Délai avant le 1er envoi", seconds: $config.startDelay, range: 0...86_400)
            }
            .listRowBackground(BW.hull)

            Section {
                Picker("Mode", selection: $config.mode) {
                    ForEach(SendMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(config.mode.explanation)
                    .font(.footnote)
                    .foregroundStyle(BW.mist)
                DurationStepper(label: config.mode == .burst ? "Écart min. entre rafales" : "Intervalle minimum",
                                seconds: $config.minInterval, range: 1...86_400)
                DurationStepper(label: config.mode == .burst ? "Écart max. entre rafales" : "Intervalle maximum",
                                seconds: $config.maxInterval, range: 1...86_400)
                if config.mode == .burst {
                    CountStepper(label: "Notifs par rafale", value: $config.burstSize, range: 2...10)
                    DurationStepper(label: "Écart dans une rafale", seconds: $config.burstGap, range: 1...60)
                }
            } header: {
                Text("Rythme")
            } footer: {
                if config.count > 1 && !possible.contains(config.totalDuration) {
                    Text("Les intervalles min / max ne permettent pas de tenir \(formatDuration(config.totalDuration)) : la durée réelle sera d'environ \(formatDuration(min(max(config.totalDuration, possible.lowerBound), possible.upperBound))).")
                        .foregroundStyle(BW.gold)
                }
            }
            .listRowBackground(BW.hull)

            Section {
                RhythmPreview(offsets: sample)
                Button {
                    regenerate()
                } label: {
                    Label("Simuler un autre tirage", systemImage: "arrow.triangle.2.circlepath")
                }
            } header: {
                Text("Aperçu du rythme")
            } footer: {
                Text("Chaque point est une notification. Le tirage réel est refait à chaque lancement.")
            }
            .listRowBackground(BW.hull)

            Section {
                Toggle("Tirage aléatoire", isOn: $config.randomPick)
                Toggle("Éviter les répétitions", isOn: $config.avoidRepeats)
                Toggle("Aucun doublon", isOn: $config.noDuplicates)
                Toggle("Mélanger les textes", isOn: $config.mixContent)
                if hasRare {
                    VStack(alignment: .leading) {
                        HStack {
                            Label("Chance d'une notification rare", systemImage: "star.fill")
                            Spacer()
                            Text("\(Int((config.rareChance * 100).rounded())) %")
                                .foregroundStyle(BW.gold)
                                .monospacedDigit()
                        }
                        Slider(value: $config.rareChance, in: 0...0.5, step: 0.01)
                    }
                }
            } header: {
                Text("Tirage")
            } footer: {
                Text(tirageFooter(hasRare: hasRare))
            }
            .listRowBackground(BW.hull)

            Section {
                Text("\(pool.count) modèle\(pool.count > 1 ? "s" : "") sur \(usable.count)")
                    .foregroundStyle(BW.mist)
                if !config.templateIDs.isEmpty {
                    Button("Tout sélectionner") { config.templateIDs = [] }
                }
            } header: {
                Text("Modèles utilisés")
            } footer: {
                Text("Touche un modèle pour l'ajouter ou le retirer, ou « Tous » / « Aucun » pour toute une appli. Le pourcentage indique la chance approximative de chaque modèle à chaque envoi.")
            }
            .listRowBackground(BW.hull)

            ForEach(store.groupedBySender(usable)) { group in
                let allSelected = group.templates.allSatisfy { isSelected($0) }
                Section {
                    ForEach(group.templates) { t in
                        let selected = isSelected(t)
                        Button {
                            toggle(t)
                        } label: {
                            HStack {
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected ? BW.gold : BW.mist)
                                Text(t.displayTitle)
                                    .foregroundStyle(BW.parchment)
                                    .lineLimit(1)
                                if t.isRare {
                                    Image(systemName: "star.fill").font(.caption).foregroundStyle(BW.gold)
                                }
                                if !t.cascade.isEmpty {
                                    Image(systemName: "square.stack.3d.down.right").font(.caption).foregroundStyle(BW.mist)
                                }
                                Spacer()
                                if selected, let p = probabilities[t.id] {
                                    Text(formatPercent(p))
                                        .font(.footnote)
                                        .foregroundStyle(BW.mist)
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                } header: {
                    SenderGroupHeader(slot: group.slot, count: group.templates.count) {
                        Button(allSelected ? "Aucun" : "Tous") { toggle(group.templates, on: !allSelected) }
                            .font(.footnote.weight(.semibold))
                    }
                }
                .listRowBackground(BW.hull)
            }
        }
        .bwForm()
        .navigationTitle(config.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { regenerate() }
        .onChange(of: config) { _ in regenerate() }
        .onChange(of: config.minInterval) { v in
            if v > config.maxInterval { config.maxInterval = v }
        }
        .onChange(of: config.maxInterval) { v in
            if v < config.minInterval { config.minInterval = v }
        }
    }

    private func regenerate() {
        sample = Planner.offsets(for: config)
    }

    private func isSelected(_ t: NotifTemplate) -> Bool {
        config.templateIDs.isEmpty || config.templateIDs.contains(t.id)
    }

    private func toggle(_ t: NotifTemplate) {
        toggle([t], on: !isSelected(t))
    }

    /// Ajoute ou retire des modèles de la sélection (au moins un modèle reste sélectionné).
    private func toggle(_ list: [NotifTemplate], on: Bool) {
        let all = store.templates.filter { !$0.isEmpty }.map(\.id)
        var ids = config.templateIDs.isEmpty ? all : config.templateIDs
        let changed = Set(list.map(\.id))
        if on {
            ids += list.map(\.id).filter { !ids.contains($0) }
        } else {
            let rest = ids.filter { !changed.contains($0) }
            guard !rest.isEmpty else { return }
            ids = rest
        }
        config.templateIDs = Set(ids) == Set(all) ? [] : ids
    }

    private func tirageFooter(hasRare: Bool) -> String {
        var text = config.randomPick
            ? "Les modèles sont tirés au sort selon leur fréquence."
            : "Les modèles sont envoyés dans l'ordre de la liste."
        text += " « Mélanger » combine le titre d'un modèle avec le texte d'un autre."
        text += " « Éviter les répétitions » empêche deux fois la même d'affilée ; « Aucun doublon » envoie chaque modèle au plus une fois par scénario."
        if !hasRare { text += " Marque un modèle comme rare pour activer les apparitions rares." }
        return text
    }

    private func formatPercent(_ p: Double) -> String {
        let v = p * 100
        return v < 1 && v > 0 ? String(format: "%.1f %%", v) : "\(Int(v.rounded())) %"
    }
}

// MARK: - Frise du rythme

private struct RhythmPreview: View {
    let offsets: [Double]

    var body: some View {
        let total = max(offsets.last ?? 1, 1)

        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(BW.abyss).frame(height: 4)
                    ForEach(Array(offsets.enumerated()), id: \.offset) { _, o in
                        Circle()
                            .fill(BW.gold)
                            .frame(width: 7, height: 7)
                            .offset(x: CGFloat(o / total) * (geo.size.width - 7))
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 18)
            .animation(.easeInOut(duration: 0.4), value: offsets)

            HStack {
                Text("Lancement")
                Spacer()
                Text(formatDuration(total))
            }
            .font(.caption2)
            .foregroundStyle(BW.mist)
        }
        .padding(.vertical, 4)
    }
}
