import Foundation

// Calcule les horaires d'un scénario et tire les messages.
enum Planner {

    /// Secondes depuis le lancement pour chaque notification (triées).
    static func offsets(for c: SendConfig) -> [Double] {
        let n = max(1, c.count)
        let (lo, hi) = bounds(c)
        var gaps: [Double] = []

        switch c.mode {
        case .regular:
            let g = n > 1 ? c.totalDuration / Double(n - 1) : 0
            gaps = Array(repeating: min(max(g, lo), hi), count: n - 1)

        case .random:
            let weights = (0..<(n - 1)).map { _ in Double.random(in: 0.3...1.7) }
            gaps = fit(weights, total: c.totalDuration, lo: lo, hi: hi)

        case .burst:
            let size = max(1, c.burstSize)
            let inner = max(1, c.burstGap)
            let bursts = Int((Double(n) / Double(size)).rounded(.up))
            let innerTime = Double(n - bursts) * inner
            let weights = (0..<(bursts - 1)).map { _ in Double.random(in: 0.5...1.5) }
            let between = fit(weights, total: max(0, c.totalDuration - innerTime), lo: lo, hi: hi)
            var k = 0
            for i in 1..<max(1, n) {
                if i % size == 0 {
                    gaps.append(between[k])
                    k += 1
                } else {
                    gaps.append(inner)
                }
            }
        }

        var t = max(1, c.startDelay)
        var result = [t]
        for g in gaps {
            t += g
            result.append(t)
        }
        return result
    }

    /// Durée réellement atteignable compte tenu des intervalles min / max.
    static func achievableDuration(_ c: SendConfig) -> ClosedRange<Double> {
        let n = max(1, c.count)
        let (lo, hi) = bounds(c)
        if c.mode == .burst {
            let size = max(1, c.burstSize)
            let bursts = Int((Double(n) / Double(size)).rounded(.up))
            let innerTime = Double(n - bursts) * max(1, c.burstGap)
            return (innerTime + Double(bursts - 1) * lo)...(innerTime + Double(bursts - 1) * hi)
        }
        return (Double(n - 1) * lo)...(Double(n - 1) * hi)
    }

    private static func bounds(_ c: SendConfig) -> (Double, Double) {
        let lo = max(1, min(c.minInterval, c.maxInterval))
        let hi = max(lo, c.maxInterval)
        return (lo, hi)
    }

    /// Répartit `total` selon les poids en respectant [lo, hi].
    private static func fit(_ weights: [Double], total: Double, lo: Double, hi: Double) -> [Double] {
        guard !weights.isEmpty else { return [] }
        let sum = weights.reduce(0, +)
        var g = weights.map { $0 / sum * total }
        for _ in 0..<20 {
            g = g.map { min(max($0, lo), hi) }
            let diff = total - g.reduce(0, +)
            if abs(diff) < 0.5 { break }
            let free = g.indices.filter { diff > 0 ? g[$0] < hi : g[$0] > lo }
            if free.isEmpty { break }
            let freeSum = free.reduce(0.0) { $0 + g[$1] }
            for i in free {
                g[i] += freeSum > 0 ? diff * g[i] / freeSum : diff / Double(free.count)
            }
        }
        return g.map { min(max($0, lo), hi) }
    }

    /// Probabilité approximative d'apparition de chaque message.
    static func probabilities(pool: [NotifTemplate], config: SendConfig) -> [UUID: Double] {
        let normal = pool.filter { !$0.isRare }
        let rare = pool.filter { $0.isRare }
        let rareShare = rare.isEmpty ? 0 : (normal.isEmpty ? 1 : config.rareChance)
        var result: [UUID: Double] = [:]
        func spread(_ items: [NotifTemplate], share: Double, weighted: Bool) {
            let total = items.reduce(0.0) { $0 + (weighted ? max(0, $1.weight) : 1) }
            guard total > 0 else { return }
            for t in items { result[t.id] = share * (weighted ? max(0, t.weight) : 1) / total }
        }
        spread(normal, share: 1 - rareShare, weighted: config.randomPick)
        spread(rare, share: rareShare, weighted: true)
        return result
    }
}

// Tire les messages un par un selon les réglages de la config.
struct ContentPicker {
    let pool: [NotifTemplate]
    let config: SendConfig
    private var lastID: UUID?
    private var cursor = 0

    init(pool: [NotifTemplate], config: SendConfig) {
        self.pool = pool
        self.config = config
    }

    mutating func next() -> NotifTemplate? {
        let normal = pool.filter { !$0.isRare }
        let rare = pool.filter { $0.isRare }
        guard !pool.isEmpty else { return nil }

        let useRare = !rare.isEmpty && (normal.isEmpty || Double.random(in: 0..<1) < config.rareChance)
        var pick: NotifTemplate

        if useRare {
            pick = Self.weighted(withoutLast(rare))
        } else if config.randomPick {
            pick = Self.weighted(withoutLast(normal))
        } else {
            pick = normal[cursor % normal.count]
            cursor += 1
        }

        if config.mixContent && !pick.isRare {
            if let b = normal.filter({ !$0.body.isEmpty }).randomElement() { pick.body = b.body }
            let withImages = normal.filter { $0.imageFile != nil }
            if !withImages.isEmpty {
                // Une image sur deux environ, pour varier aussi les notifs sans image
                pick.imageFile = Bool.random() ? withImages.randomElement()?.imageFile : nil
            }
        }

        lastID = pick.id
        return pick
    }

    private func withoutLast(_ items: [NotifTemplate]) -> [NotifTemplate] {
        guard config.avoidRepeats, items.count > 1, let lastID else { return items }
        return items.filter { $0.id != lastID }
    }

    private static func weighted(_ items: [NotifTemplate]) -> NotifTemplate {
        let total = items.reduce(0.0) { $0 + max(0, $1.weight) }
        guard total > 0 else { return items.randomElement()! }
        var r = Double.random(in: 0..<total)
        for t in items {
            r -= max(0, t.weight)
            if r < 0 { return t }
        }
        return items[items.count - 1]
    }
}
