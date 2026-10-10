import SwiftUI
import UserNotifications

struct ContentView: View {
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        TabView {
            PortView()
                .tabItem { Label("Port", systemImage: "sailboat.fill") }
            TemplatesView()
                .tabItem { Label("Messages", systemImage: "scroll.fill") }
            ConfigsView()
                .tabItem { Label("Cartes", systemImage: "map.fill") }
            HistoryView()
                .tabItem { Label("Journal", systemImage: "book.closed.fill") }
        }
        .environmentObject(store)
        .tint(BW.gold)
        .preferredColorScheme(.dark)
        .task {
            // Demande l'autorisation au premier lancement
            await store.requestAuthorization()
            store.tick()
        }
        .onReceive(timer) { _ in store.tick() }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            store.tick()
            Task { await store.refreshAuthorization() }
        }
    }
}

// MARK: - Page principale

struct PortView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if store.authorization == .denied {
                        AuthWarning()
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
            .navigationTitle("Bilgewater")
        }
    }
}

private struct AuthWarning: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Notifications désactivées", systemImage: "bell.slash.fill")
                .font(BW.serif(.headline))
                .foregroundStyle(BW.rust)
            Text("Autorise les notifications de MesNotifs dans Réglages pour que les envois fonctionnent.")
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
                .font(BW.serif(.headline))
                .foregroundStyle(BW.parchment)
        case .paused:
            HStack(spacing: 8) { PulseDot(color: BW.gold, animated: false); Text("En pause") }
                .font(BW.serif(.headline))
                .foregroundStyle(BW.gold)
        case .finished:
            Label("Terminé", systemImage: "checkmark.seal.fill")
                .font(BW.serif(.headline))
                .foregroundStyle(BW.gold)
        case .stopped:
            Label("Arrêté", systemImage: "xmark.octagon.fill")
                .font(BW.serif(.headline))
                .foregroundStyle(BW.rust)
        }
    }

    private func stat(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.system(size: 34, weight: .bold, design: .serif))
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
        let poolText = "\(pool.count) message\(pool.count > 1 ? "s" : "")"
            + (rareCount > 0 ? " · \(rareCount) rare\(rareCount > 1 ? "s" : "")" : "")

        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionTitle("Cap", icon: "map.fill")
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

                Toggle("Tirage aléatoire des messages", isOn: $config.randomPick)

                Divider().overlay(BW.gold.opacity(0.25))

                VStack(alignment: .leading, spacing: 6) {
                    Label(poolText, systemImage: "scroll")
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
                    Label("Lever l'ancre", systemImage: "sailboat.fill")
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
