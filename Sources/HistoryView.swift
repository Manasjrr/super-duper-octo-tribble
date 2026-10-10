import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var store: AppStore
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            List {
                if store.history.isEmpty {
                    Text("Aucune notification envoyée pour le moment.")
                        .foregroundStyle(BW.mist)
                        .listRowBackground(BW.hull)
                }
                ForEach(store.history) { entry in
                    HistoryRow(entry: entry)
                        .listRowBackground(BW.hull)
                }
            }
            .bwForm()
            .navigationTitle("Historique")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Effacer") { confirmClear = true }
                        .disabled(store.history.isEmpty)
                }
            }
            .confirmationDialog("Effacer tout l'historique ?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Effacer", role: .destructive) { store.history.removeAll() }
            }
        }
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let slot = WebPersonas.slot(entry.personaID) {
                Image(slot.preview)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else if let icon = ImageStore.load(entry.iconFile) {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
            } else {
                AppEmblem(size: 36)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.title.isEmpty ? "Sans titre" : entry.title)
                        .font(BW.font(.subheadline, .semibold))
                        .foregroundStyle(BW.parchment)
                        .lineLimit(1)
                    if entry.isRare {
                        Image(systemName: "star.fill").font(.caption2).foregroundStyle(BW.gold)
                    }
                    if entry.isTest {
                        Text("TEST")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(BW.sea.opacity(0.35)))
                            .foregroundStyle(BW.parchment)
                    }
                }
                if !entry.body.isEmpty {
                    Text(entry.body)
                        .font(.footnote)
                        .foregroundStyle(BW.mist)
                        .lineLimit(2)
                }
                Text(entry.date.formatted(.dateTime.day().month().hour().minute().second()))
                    .font(.caption2)
                    .foregroundStyle(BW.mist)
            }
            Spacer(minLength: 0)
            if let image = ImageStore.load(entry.imageFile) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}
