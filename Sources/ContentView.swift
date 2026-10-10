import SwiftUI
import UserNotifications

struct ContentView: View {
    @State private var titre = "Test"
    @State private var message = "Ça marche 🎉"
    @State private var statut = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Notification") {
                    TextField("Titre", text: $titre)
                    TextField("Message", text: $message)
                }

                Section {
                    Button("Envoyer dans 5 secondes") {
                        Task { await envoyer() }
                    }
                }

                if !statut.isEmpty {
                    Section { Text(statut).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("MesNotifs")
        }
        .task {
            // Demande l'autorisation au premier lancement
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        }
    }

    func envoyer() async {
        let contenu = UNMutableNotificationContent()
        contenu.title = titre
        contenu.body = message
        contenu.sound = .default

        let declencheur = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let requete = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: contenu,
                                            trigger: declencheur)
        do {
            try await UNUserNotificationCenter.current().add(requete)
            statut = "Notif programmée, verrouille ton iPhone 🔒"
        } catch {
            statut = "Erreur : \(error.localizedDescription)"
        }
    }
}
