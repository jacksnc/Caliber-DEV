import Foundation

public struct ScanStabilizerConfig: Equatable, Sendable {
    /// Identical reads needed before a 1D code is trusted. A misread that still passes the check digit is rare, and
    /// seeing the same wrong digits twice in a row is much rarer.
    public var requiredReads: Int
    /// The reads must fall within this many seconds.
    public var window: TimeInterval
    /// After a code is confirmed it is ignored for this long, so a steady camera does not log it twice.
    public var cooldown: TimeInterval
    /// Symbologies with built-in error correction are trusted after a single read.
    public var singleReadSymbologies: Set<BarcodeSymbology>

    public init(
        requiredReads: Int = 2,
        window: TimeInterval = 0.8,
        cooldown: TimeInterval = 2.5,
        singleReadSymbologies: Set<BarcodeSymbology> = [.dataMatrix, .qr, .aztec, .pdf417]
    ) {
        self.requiredReads = max(1, requiredReads)
        self.window = window
        self.cooldown = cooldown
        self.singleReadSymbologies = singleReadSymbologies
    }
}

public struct StabilizedScan: Equatable, Sendable {
    public let payload: String
    public let symbology: BarcodeSymbology?
    public let interpretation: ScanInterpretation

    /// The candidates to look up, most likely first.
    public var candidates: [BarcodeCandidate] { interpretation.normalization.candidates }
}

public enum ScanFeedback: Equatable, Sendable {
    /// Trusted: look it up.
    case confirmed(StabilizedScan)
    /// A valid read that has not been repeated yet.
    case pending(reads: Int, needed: Int)
    /// Not a usable code (bad check digit, wrong length, no GTIN). The UI can say "hold steady".
    case rejected(BarcodeIssue)
    /// The same code arrived again during the cooldown.
    case ignored
}

/// Turns the noisy stream of camera detections into one confirmed scan per physical barcode.
/// Pure and time-injected so it is deterministic to test; the scanner view feeds it detections and a monotonic clock.
public struct ScanStabilizer: Sendable {
    public let config: ScanStabilizerConfig
    private var reads: [String: [TimeInterval]] = [:]
    private var quietUntil: [String: TimeInterval] = [:]

    public init(config: ScanStabilizerConfig = ScanStabilizerConfig()) {
        self.config = config
    }

    public mutating func ingest(payload: String, symbology: BarcodeSymbology?, at time: TimeInterval) -> ScanFeedback {
        let interpretation = BarcodeNormalizer.interpret(payload, symbology: symbology)
        guard case let .valid(candidates) = interpretation.normalization, let first = candidates.first else {
            if case let .invalid(issue) = interpretation.normalization { return .rejected(issue) }
            return .rejected(.notAProductCode)
        }

        prune(at: time)
        let key = first.gtin.digits14
        if let until = quietUntil[key], time < until { return .ignored }

        let needed = symbology.map(config.singleReadSymbologies.contains) == true ? 1 : config.requiredReads
        var recent = (reads[key] ?? []).filter { time - $0 <= config.window }
        recent.append(time)

        if recent.count >= needed {
            reads[key] = nil
            quietUntil[key] = time + config.cooldown
            return .confirmed(StabilizedScan(payload: payload, symbology: symbology, interpretation: interpretation))
        }
        reads[key] = recent
        return .pending(reads: recent.count, needed: needed)
    }

    /// Forget everything, e.g. when the scanner view reappears.
    public mutating func reset() {
        reads = [:]
        quietUntil = [:]
    }

    private mutating func prune(at time: TimeInterval) {
        quietUntil = quietUntil.filter { $0.value > time }
        reads = reads.compactMapValues { times in
            let fresh = times.filter { time - $0 <= config.window }
            return fresh.isEmpty ? nil : fresh
        }
    }
}

/// Exponential backoff for lookups that failed because the network or a source was unavailable.
public struct RetryPolicy: Equatable, Sendable, Codable {
    public var base: TimeInterval
    public var factor: Double
    public var cap: TimeInterval
    public var maxAttempts: Int

    public init(base: TimeInterval = 30, factor: Double = 2, cap: TimeInterval = 6 * 3600, maxAttempts: Int = 8) {
        self.base = base
        self.factor = factor
        self.cap = cap
        self.maxAttempts = maxAttempts
    }

    /// Delay before the next try after `failures` failed attempts (1 = first failure); nil once attempts are exhausted.
    public func delay(afterFailures failures: Int) -> TimeInterval? {
        guard failures >= 1, failures < maxAttempts else { return nil }
        return min(cap, base * pow(factor, Double(failures - 1)))
    }
}

public struct PendingScan: Equatable, Sendable, Codable {
    public let gtin: GTIN
    public let scannedAt: Date
    public var failures: Int
    public var nextAttempt: Date
}

/// Barcodes scanned while offline, retried later so the user can keep scanning in a shop with no signal.
public struct PendingScanQueue: Equatable, Sendable, Codable {
    public private(set) var items: [PendingScan] = []

    public init() {}

    /// Adds a scan to retry; a code already waiting keeps its original time and schedule.
    public mutating func enqueue(_ gtin: GTIN, at now: Date) {
        guard !items.contains(where: { $0.gtin == gtin }) else { return }
        items.append(PendingScan(gtin: gtin, scannedAt: now, failures: 0, nextAttempt: now))
    }

    public func due(at now: Date) -> [PendingScan] {
        items.filter { $0.nextAttempt <= now }.sorted { $0.scannedAt < $1.scannedAt }
    }

    /// Records a failed retry. Returns false when the policy gives up and the scan is dropped.
    @discardableResult
    public mutating func recordFailure(_ gtin: GTIN, at now: Date, policy: RetryPolicy = RetryPolicy()) -> Bool {
        guard let index = items.firstIndex(where: { $0.gtin == gtin }) else { return false }
        items[index].failures += 1
        guard let delay = policy.delay(afterFailures: items[index].failures) else {
            items.remove(at: index)
            return false
        }
        items[index].nextAttempt = now.addingTimeInterval(delay)
        return true
    }

    public mutating func resolve(_ gtin: GTIN) {
        items.removeAll { $0.gtin == gtin }
    }
}
