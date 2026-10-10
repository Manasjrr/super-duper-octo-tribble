import ActivityKit
import SwiftUI
import WidgetKit

@main
struct NovaWidgets: WidgetBundle {
    var body: some Widget {
        NovaLiveActivity()
    }
}

// Activité en direct dessinée comme une pile de notifications, avec des icônes libres.
struct NovaLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NovaActivityAttributes.self) { context in
            NotificationStackView(state: context.state)
                .activityBackgroundTint(Color(red: 0.10, green: 0.11, blue: 0.13).opacity(0.88))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ActivityIcon(data: context.state.current.iconData, size: 44)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.current.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        if !context.state.current.subtitle.isEmpty {
                            Text(context.state.current.subtitle)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                        }
                        Text(context.state.current.body)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                ActivityIcon(data: context.state.current.iconData, size: 22)
            } compactTrailing: {
                Text("\(context.state.sent)/\(context.state.total)")
                    .font(.caption2)
                    .monospacedDigit()
            } minimal: {
                ActivityIcon(data: context.state.current.iconData, size: 22)
            }
        }
    }
}

/// La dernière notification en grand, les précédentes en dessous en plus petit.
struct NotificationStackView: View {
    let state: NovaActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MainRow(entry: state.current)
            ForEach(Array(state.previous.prefix(2).enumerated()), id: \.offset) { index, entry in
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 0.5)
                CompactRow(entry: entry)
                    .opacity(index == 0 ? 0.85 : 0.65)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct MainRow: View {
    let entry: NovaActivityAttributes.Entry

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ActivityIcon(data: entry.iconData, size: 38)
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(entry.date, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !entry.subtitle.isEmpty {
                    Text(entry.subtitle)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                }
                Text(entry.body)
                    .font(.subheadline)
                    .lineLimit(2)
            }
        }
    }
}

private struct CompactRow: View {
    let entry: NovaActivityAttributes.Entry

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ActivityIcon(data: entry.iconData, size: 22)
            Text(entry.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .layoutPriority(1)
            Text(entry.body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(entry.date, style: .time)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct ActivityIcon: View {
    let data: Data?
    let size: CGFloat

    var body: some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            ZStack {
                Circle().fill(LinearGradient(colors: [Color(red: 0.12, green: 0.38, blue: 0.40),
                                                      Color(red: 0.05, green: 0.10, blue: 0.15)],
                                             startPoint: .top, endPoint: .bottom))
                Image(systemName: "sparkle")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
        }
    }
}
