import SwiftUI

// MARK: - Palette : bleu nuit, accent doré discret (clin d'œil à Bilgewater)

enum BW {
    static let abyss = Color(red: 0.047, green: 0.071, blue: 0.094)    // fond
    static let deep = Color(red: 0.063, green: 0.106, blue: 0.133)     // fond, bas du dégradé
    static let hull = Color(red: 0.098, green: 0.141, blue: 0.173)     // cartes et lignes
    static let sea = Color(red: 0.200, green: 0.560, blue: 0.540)      // succès / en cours
    static let gold = Color(red: 0.850, green: 0.690, blue: 0.380)     // accent
    static let rust = Color(red: 0.880, green: 0.330, blue: 0.290)     // destructif / alerte
    static let parchment = Color(red: 0.950, green: 0.955, blue: 0.965) // texte principal
    static let mist = Color(red: 0.950, green: 0.955, blue: 0.965).opacity(0.58) // texte secondaire

    static func font(_ style: Font.TextStyle, _ weight: Font.Weight = .bold) -> Font {
        .system(style).weight(weight)
    }

    /// Barres de navigation et d'onglets.
    static func applyUIKitAppearance() {
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(abyss)
        nav.shadowColor = UIColor(white: 1, alpha: 0.06)
        nav.titleTextAttributes = [.foregroundColor: UIColor(parchment)]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor(parchment)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(abyss)
        tab.shadowColor = UIColor(white: 1, alpha: 0.06)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }
}

// MARK: - Fond

struct BWBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [BW.abyss, BW.deep], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [BW.gold.opacity(0.05), .clear], center: .topTrailing,
                           startRadius: 10, endRadius: 420)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Cartes et titres

struct BWCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(BW.hull.opacity(0.92)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
    }
}

extension View {
    func bwCard() -> some View { modifier(BWCard()) }

    /// Formulaire sur le fond de l'app.
    func bwForm() -> some View {
        scrollContentBackground(.hidden)
            .background(BWBackground())
    }
}

struct SectionTitle: View {
    let text: String
    let icon: String

    init(_ text: String, icon: String) {
        self.text = text
        self.icon = icon
    }

    var body: some View {
        Label(text, systemImage: icon)
            .font(BW.font(.headline, .semibold))
            .foregroundStyle(BW.parchment)
    }
}

// MARK: - Boutons

struct BWButtonStyle: ButtonStyle {
    var color: Color = BW.gold
    var filled = true

    func makeBody(configuration: Configuration) -> some View {
        BWButtonBody(configuration: configuration, color: color, filled: filled)
    }
}

private struct BWButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let color: Color
    let filled: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(BW.font(.headline, .semibold))
            .foregroundStyle(filled ? BW.abyss : color)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(filled
                          ? AnyShapeStyle(LinearGradient(colors: [color, color.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                          : AnyShapeStyle(color.opacity(0.12)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(color.opacity(filled ? 0 : 0.55), lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Petits composants

struct BWProgress: View {
    let value: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(BW.abyss)
                Capsule()
                    .fill(LinearGradient(colors: [BW.rust, BW.gold], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(10, geo.size.width * min(1, max(0, value))))
            }
        }
        .frame(height: 10)
        .animation(.easeInOut(duration: 0.6), value: value)
    }
}

struct PulseDot: View {
    let color: Color
    let animated: Bool
    @State private var pulse = false

    init(color: Color, animated: Bool = true) {
        self.color = color
        self.animated = animated
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .overlay(
                Circle()
                    .stroke(color, lineWidth: 2)
                    .scaleEffect(pulse ? 2.4 : 1)
                    .opacity(pulse ? 0 : 0.8)
            )
            .onAppear {
                guard animated else { return }
                withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) { pulse = true }
            }
    }
}

/// Stepper de durée avec des paliers « ronds ».
struct DurationStepper: View {
    let label: String
    @Binding var seconds: Double
    var range: ClosedRange<Double> = 1...86_400

    private static let ladder: [Double] = [0, 1, 2, 3, 5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240, 300,
                                           420, 600, 900, 1200, 1800, 2700, 3600, 5400, 7200, 10_800,
                                           14_400, 21_600, 28_800, 43_200, 86_400]

    var body: some View {
        Stepper(onIncrement: {
            let next = Self.ladder.first { $0 > seconds } ?? seconds
            seconds = min(range.upperBound, next)
        }, onDecrement: {
            let prev = Self.ladder.last { $0 < seconds } ?? seconds
            seconds = max(range.lowerBound, prev)
        }) {
            HStack {
                Text(label)
                Spacer()
                Text(formatDuration(seconds))
                    .foregroundStyle(BW.gold)
                    .monospacedDigit()
            }
        }
    }
}

/// Stepper de nombre avec un pas qui grandit.
struct CountStepper: View {
    let label: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 1...500

    private func step(_ v: Int) -> Int { v < 10 ? 1 : (v < 50 ? 5 : 10) }

    var body: some View {
        Stepper(onIncrement: {
            value = min(range.upperBound, value + step(value))
        }, onDecrement: {
            value = max(range.lowerBound, value - step(value - 1))
        }) {
            HStack {
                Text(label)
                Spacer()
                Text("\(value)")
                    .foregroundStyle(BW.gold)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Formatage

func formatDuration(_ s: Double) -> String {
    let s = Int(s.rounded())
    if s < 60 { return "\(s) s" }
    if s < 3600 {
        let m = s / 60, r = s % 60
        return r == 0 ? "\(m) min" : "\(m) min \(r) s"
    }
    let h = s / 3600, m = (s % 3600) / 60
    return m == 0 ? "\(h) h" : "\(h) h \(m)"
}

func formatCountdown(_ s: Double) -> String {
    let s = max(0, Int(s.rounded(.up)))
    if s >= 3600 { return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60) }
    return String(format: "%d:%02d", s / 60, s % 60)
}
