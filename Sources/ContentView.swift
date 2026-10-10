import SwiftUI
import UserNotifications

struct ContentView: View {
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Accueil", systemImage: "house.fill") }
            TemplatesView()
                .tabItem { Label("Modèles", systemImage: "square.stack.fill") }
            ConfigsView()
                .tabItem { Label("Configurations", systemImage: "slider.horizontal.3") }
            HistoryView()
                .tabItem { Label("Historique", systemImage: "clock.fill") }
        }
        .environmentObject(store)
        .tint(BW.gold)
        .preferredColorScheme(.dark)
        .task {
            // Demande l'autorisation au premier lancement
            await store.requestAuthorization()
            store.tick()
        }
        .onOpenURL { url in store.handle(url: url) }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            store.tick()
            Task { await store.refreshAuthorization() }
        }
    }
}

// MARK: - Page principale

struct HomeView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if store.authorization == .denied {
                        AuthWarning()
                    }
                    if IconSupport.current == .missing && store.templates.contains(where: { $0.iconFile != nil }) {
                        IconWarning()
                    }
                    if store.activeConfig?.webPush == true && store.personas.isEmpty {
                        NavigationLink {
                            PersonasView()
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Aucune appli expéditrice installée", systemImage: "app.badge")
                                    .font(BW.font(.headline, .semibold))
                                    .foregroundStyle(BW.gold)
                                Text("La configuration est en affichage « Applis web ». Installe au moins un expéditeur pour avoir des icônes différentes.")
                                    .font(.footnote)
                                    .foregroundStyle(BW.mist)
                                    .multilineTextAlignment(.leading)
                            }
                            .bwCard()
                        }
                        .buttonStyle(.plain)
                    }
                    if store.activeConfig?.webPush != true && (store.activeConfig?.liveActivity == true || store.run?.isLive == true) {
                        LiveDiagnostics()
                    }
                    if let run = store.run {
                        RunCard(run: run)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    if let id = store.activeConfig?.id {
                        QuickSettings(config: store.configBinding(id))
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Aucune configuration.").foregroundStyle(BW.mist)
                            Button("Créer une configuration") {
                                store.activeConfigID = store.addConfig().id
                            }
                            .buttonStyle(BWButtonStyle())
                        }
                        .bwCard()
                    }
                    if let message = store.message {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(BW.rust)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
                .animation(.easeInOut(duration: 0.35), value: store.run?.status)
            }
            .background(BWBackground())
            .navigationTitle("Nova")
        }
    }
}

private struct AuthWarning: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Notifications désactivées", systemImage: "bell.slash.fill")
                .font(BW.font(.headline))
                .foregroundStyle(BW.rust)
            Text("Autorise les notifications de Nova dans Réglages pour que les envois fonctionnent.")
                .font(.footnote)
                .foregroundStyle(BW.mist)
            Button("Ouvrir Réglages") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(BWButtonStyle(color: BW.rust, filled: false))
        }
        .bwCard()
    }
}

private struct IconWarning: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Icônes personnalisées indisponibles", systemImage: "person.crop.circle.badge.exclamationmark")
                .font(BW.font(.headline, .semibold))
                .foregroundStyle(BW.gold)
            Text("Cette installation n'a pas reçu l'autorisation « Communication Notifications » (réservée aux comptes Apple payants) : iOS n'affiche pas une icône différente par notification. Deux solutions dans Configurations : l'affichage « Activité en direct » (une icône par envoi), ou une « Icône de l'app » pour tout le scénario.")
                .font(.footnote)
                .foregroundStyle(BW.mist)
        }
        .bwCard()
    }
}

private struct LiveDiagnostics: View {
    @EnvironmentObject var store: AppStore
    @State private var expanded = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 2)) { _ in
            let checks = LiveMode.diagnostics()
            let allOK = checks.allSatisfy(\.ok)
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                } label: {
                    HStack {
                        Label("Activité en direct", systemImage: allOK ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(BW.font(.headline, .semibold))
                            .foregroundStyle(allOK ? BW.sea : BW.gold)
                        Spacer()
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(BW.mist)
                    }
                }
                .buttonStyle(.plain)

                if expanded || !LiveMode.extensionInstalled {
                    ForEach(checks) { check in
                        HStack(alignment: .firstTextBaseline) {
                            Image(systemName: check.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(check.ok ? BW.sea : BW.rust)
                            Text(check.label)
                            Spacer()
                            Text(check.detail)
                                .foregroundStyle(BW.mist)
                                .multilineTextAlignment(.trailing)
                        }
                        .font(.footnote)
                    }
                    if !LiveMode.extensionInstalled {
                        Text("Sans l'extension, iOS fait vibrer le téléphone mais n'a rien à afficher. Réinstalle Nova.ipa avec SideStore et, quand il demande quoi faire des extensions, choisis de les garder.")
                            .font(.caption)
                            .foregroundStyle(BW.gold)
                    }
                    Button {
                        if let t = store.pool(for: store.activeConfig ?? SendConfig()).first {
                            store.message = LiveMode.test(t)
                        }
                    } label: {
                        Label("Afficher une activité de test", systemImage: "rectangle.badge.checkmark")
                    }
                    .buttonStyle(BWButtonStyle(filled: false))
                }
            }
            .bwCard()
        }
    }
}

// MARK: - Scénario en cours

private struct RunCard: View {
    @EnvironmentObject var store: AppStore
    let run: Run

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let sent = run.sent(at: now)
            let left = max(0, run.plannedCount - sent)

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    statusBadge
                    Spacer()
                    Text(run.configName)
                        .font(.caption)
                        .foregroundStyle(BW.mist)
                        .lineLimit(1)
                }

                HStack(alignment: .firstTextBaseline) {
                    stat("Envoyées", sent)
                    Spacer()
                    stat(run.status == .stopped ? "Annulées" : "Restantes", left)
                }

                BWProgress(value: Double(sent) / Double(max(1, run.plannedCount)))

                if let next = run.next(after: now) {
                    HStack(spacing: 6) {
                        Image(systemName: run.status == .paused ? "pause.circle" : "hourglass")
                        if run.status == .paused {
                            Text("En pause")
                        } else {
                            Text("Prochaine dans \(formatCountdown(next.fireDate.timeIntervalSince(now)))")
                                .monospacedDigit()
                        }
                        Spacer()
                        Text(next.title)
                            .lineLimit(1)
                            .foregroundStyle(BW.mist)
                    }
                    .font(.footnote)
                }

                controls
            }
            .bwCard()
        }
    }

    @ViewBuilder private var statusBadge: some View {
        switch run.status {
        case .running:
            HStack(spacing: 8) { PulseDot(color: BW.sea); Text("En cours") }
                .font(BW.font(.headline))
                .foregroundStyle(BW.parchment)
        case .paused:
            HStack(spacing: 8) { PulseDot(color: BW.gold, animated: false); Text("En pause") }
                .font(BW.font(.headline))
                .foregroundStyle(BW.gold)
        case .finished:
            Label("Terminé", systemImage: "checkmark.seal.fill")
                .font(BW.font(.headline))
                .foregroundStyle(BW.gold)
        case .stopped:
            Label("Arrêté", systemImage: "xmark.octagon.fill")
                .font(BW.font(.headline))
                .foregroundStyle(BW.rust)
        }
    }

    private func stat(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(BW.parchment)
                .monospacedDigit()
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(BW.mist)
        }
    }

    @ViewBuilder private var controls: some View {
        switch run.status {
        case .running:
            HStack(spacing: 10) {
                Button { store.pause() } label: { Label("Pause", systemImage: "pause.fill") }
                    .buttonStyle(BWButtonStyle(filled: false))
                Button { store.stop() } label: { Label("Arrêter", systemImage: "stop.fill") }
                    .buttonStyle(BWButtonStyle(color: BW.rust, filled: false))
            }
        case .paused:
            HStack(spacing: 10) {
                Button { store.resume() } label: { Label("Reprendre", systemImage: "play.fill") }
                    .buttonStyle(BWButtonStyle())
                Button { store.stop() } label: { Label("Arrêter", systemImage: "stop.fill") }
                    .buttonStyle(BWButtonStyle(color: BW.rust, filled: false))
            }
        case .finished, .stopped:
            Button { store.clearRun() } label: { Label("Fermer", systemImage: "xmark") }
                .buttonStyle(BWButtonStyle(color: BW.mist, filled: false))
        }
    }
}

// MARK: - Réglages essentiels

private struct QuickSettings: View {
    @EnvironmentObject var store: AppStore
    @Binding var config: SendConfig

    var body: some View {
        let pool = store.pool(for: config)
        let rareCount = pool.filter(\.isRare).count
        let running = store.run?.isActive == true
        let poolText = "\(pool.count) modèle\(pool.count > 1 ? "s" : "")"
            + (rareCount > 0 ? " · \(rareCount) rare\(rareCount > 1 ? "s" : "")" : "")

        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionTitle("Configuration", icon: "slider.horizontal.3")
                    Spacer()
                    Menu {
                        ForEach(store.configs) { c in
                            Button {
                                store.activeConfigID = c.id
                            } label: {
                                if c.id == config.id {
                                    Label(c.name, systemImage: "checkmark")
                                } else {
                                    Text(c.name)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(config.name).lineLimit(1)
                            Image(systemName: "chevron.up.chevron.down").font(.caption)
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                }

                CountStepper(label: "Notifications", value: $config.count)
                DurationStepper(label: "Durée totale", seconds: $config.totalDuration, range: 5...86_400)

                Picker("Mode", selection: $config.mode) {
                    ForEach(SendMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                Text(config.mode.explanation)
                    .font(.caption)
                    .foregroundStyle(BW.mist)

                Toggle("Tirage aléatoire des modèles", isOn: $config.randomPick)

                Divider().overlay(BW.gold.opacity(0.25))

                VStack(alignment: .leading, spacing: 6) {
                    Label(poolText, systemImage: "square.stack")
                    if config.count > 1 {
                        Label("≈ 1 notification toutes les \(formatDuration(config.totalDuration / Double(config.count - 1)))",
                              systemImage: "metronome")
                    }
                    let possible = Planner.achievableDuration(config)
                    if !possible.contains(config.totalDuration) && config.count > 1 {
                        Label("Avec ces intervalles, la durée réelle sera d'environ \(formatDuration(min(max(config.totalDuration, possible.lowerBound), possible.upperBound))).",
                              systemImage: "exclamationmark.triangle")
                            .foregroundStyle(BW.gold)
                    }
                    if config.count > AppStore.pendingLimit {
                        Label("iOS limite les notifications programmées : ouvre l'app de temps en temps pour que la suite soit envoyée.",
                              systemImage: "info.circle")
                    }
                }
                .font(.caption)
                .foregroundStyle(BW.mist)

                NavigationLink {
                    ConfigEditor(config: $config)
                } label: {
                    HStack {
                        Label("Tous les réglages", systemImage: "slider.horizontal.3")
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption)
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
            .bwCard()

            if !running {
                Button { store.start() } label: {
                    Label("Démarrer", systemImage: "play.fill")
                }
                .buttonStyle(BWButtonStyle())
                .disabled(pool.isEmpty)
            }

            Button { store.sendTest() } label: {
                Label("Tester une notification", systemImage: "bell.badge.fill")
            }
            .buttonStyle(BWButtonStyle(filled: false))
            .disabled(pool.isEmpty)
        }
    }
}
