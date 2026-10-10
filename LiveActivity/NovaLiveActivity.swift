import ActivityKit
import SwiftUI
import WidgetKit

@main
struct NovaWidgets: WidgetBundle {
    var body: some Widget {
        NovaLiveActivity()
    }
}

// Activité en direct dessinée comme une notification, avec une icône libre.
struct NovaLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NovaActivityAttributes.self) { context in
            NotificationLikeView(state: context.state)
                .activityBackgroundTint(Color(red: 0.10, green: 0.11, blue: 0.13).opacity(0.88))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ActivityIcon(data: context.state.iconData, size: 44)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        if !context.state.subtitle.isEmpty {
                            Text(context.state.subtitle)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                        }
                        Text(context.state.body)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                ActivityIcon(data: context.state.iconData, size: 22)
            } compactTrailing: {
                Text("\(context.state.sent)/\(context.state.total)")
                    .font(.caption2)
                    .monospacedDigit()
            } minimal: {
                ActivityIcon(data: context.state.iconData, size: 22)
            }
        }
    }
}

struct NotificationLikeView: View {
    let state: NovaActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ActivityIcon(data: state.iconData, size: 40)
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline) {
                    Text(state.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(state.date, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !state.subtitle.isEmpty {
                    Text(state.subtitle)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                }
                Text(state.body)
                    .font(.subheadline)
                    .lineLimit(3)
            }
        }
        .foregroundStyle(.white)
        .padding(14)
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
