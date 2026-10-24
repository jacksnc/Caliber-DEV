import Foundation

// MARK: Cache

public enum FoodCacheEntry: Equatable, Sendable {
    case hit(FoodRecord, storedAt: Date)
    /// Every reachable source said it does not know the product.
    case miss(storedAt: Date)
    /// No source could be reached. Kept briefly so a dead network is not hammered.
    case failure(storedAt: Date)

    var storedAt: Date {
        switch self {
        case let .hit(_, date), let .miss(date), let .failure(date): return date
        }
    }
}

public protocol FoodCache: Sendable {
    func entry(for gtin: GTIN) async -> FoodCacheEntry?
    func store(_ entry: FoodCacheEntry, for gtin: GTIN) async
    func remove(_ gtin: GTIN) async
}

/// Bounded in-memory cache (oldest entry out first). The app persists the same protocol in its database.
public actor InMemoryFoodCache: FoodCache {
    private var entries: [GTIN: FoodCacheEntry] = [:]
    private var order: [GTIN] = []
    private let capacity: Int

    public init(capacity: Int = 500) {
        self.capacity = max(1, capacity)
    }

    public func entry(for gtin: GTIN) -> FoodCacheEntry? { entries[gtin] }

    public func store(_ entry: FoodCacheEntry, for gtin: GTIN) {
        if entries[gtin] == nil { order.append(gtin) } else { order.removeAll { $0 == gtin }; order.append(gtin) }
        entries[gtin] = entry
        while order.count > capacity {
            entries[order.removeFirst()] = nil
        }
    }

    public func remove(_ gtin: GTIN) {
        entries[gtin] = nil
        order.removeAll { $0 == gtin }
    }

    public var count: Int { entries.count }
}

// MARK: Providers

public protocol FoodSourceProvider: Sendable {
    var source: FoodSource { get }
    /// nil means the source definitively does not have the product. Failures throw `LookupError`.
    func lookup(_ gtin: GTIN) async throws -> FoodRecord?
}

/// Foods the user typed or scanned themselves. They win over every external source and are never cached.
public protocol UserFoodLookup: Sendable {
    func userFood(for gtin: GTIN) async -> FoodRecord?
}

enum HTTPOutcome {
    case body(Data)
    case notFound
}

enum ProviderHTTP {
    static func send(_ request: HTTPRequest, via transport: any HTTPTransport) async throws -> HTTPOutcome {
        let response: HTTPResponse
        do {
            response = try await transport.send(request)
        } catch let error as LookupError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw LookupError.unavailable("\(error)")
        }
        switch response.status {
        case 200..<300: return .body(response.body)
        case 404: return .notFound
        case 401, 403: throw LookupError.unauthorized
        case 429: throw LookupError.rateLimited
        case 500..<600: throw LookupError.unavailable("HTTP \(response.status)")
        default: throw LookupError.malformed("HTTP \(response.status)")
        }
    }
}

public struct OpenFoodFactsProvider: FoodSourceProvider {
    public let source: FoodSource = .openFoodFacts
    private let transport: any HTTPTransport
    private let userAgent: String
    private let baseURL: URL
    private let now: @Sendable () -> Date

    public init(transport: any HTTPTransport, userAgent: String, baseURL: URL = OpenFoodFacts.defaultBaseURL, now: @escaping @Sendable () -> Date = { Date() }) {
        self.transport = transport
        self.userAgent = userAgent
        self.baseURL = baseURL
        self.now = now
    }

    public func lookup(_ gtin: GTIN) async throws -> FoodRecord? {
        for key in OpenFoodFacts.requestKeys(for: gtin) {
            let outcome = try await ProviderHTTP.send(OpenFoodFacts.productRequest(key: key, userAgent: userAgent, base: baseURL), via: transport)
            guard case let .body(data) = outcome else { continue }
            switch OpenFoodFacts.map(data, requested: gtin.consumerUnit, now: now()) {
            case let .found(record): return record
            case .notFound: continue
            case let .malformed(reason): throw LookupError.malformed(reason)
            }
        }
        return nil
    }
}

public struct USDAProvider: FoodSourceProvider {
    public let source: FoodSource = .usdaBranded
    private let transport: any HTTPTransport
    private let apiKey: String?
    private let baseURL: URL
    private let now: @Sendable () -> Date

    /// `baseURL` can point at your own edge function so the API key never ships inside the app.
    public init(transport: any HTTPTransport, apiKey: String?, baseURL: URL = USDAFoodDataCentral.defaultBaseURL, now: @escaping @Sendable () -> Date = { Date() }) {
        self.transport = transport
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.now = now
    }

    public func lookup(_ gtin: GTIN) async throws -> FoodRecord? {
        let unit = gtin.consumerUnit
        for key in USDAFoodDataCentral.searchKeys(for: unit) {
            let outcome = try await ProviderHTTP.send(USDAFoodDataCentral.searchRequest(key: key, apiKey: apiKey, base: baseURL), via: transport)
            guard case let .body(data) = outcome else { continue }
            switch USDAFoodDataCentral.mapSearch(data, matching: unit, now: now()) {
            case let .found(record): return record
            case .notFound: continue
            case let .malformed(reason): throw LookupError.malformed(reason)
            }
        }
        return nil
    }
}

// MARK: Resolver

public struct ResolverPolicy: Equatable, Sendable {
    public enum Strategy: Equatable, Sendable {
        /// Ask every source at once and merge: lowest latency, uses every source's data.
        case parallel
        /// Ask in the given order and stop once a result reaches `stopAtQuality`: fewest requests.
        case sequential
    }

    public var positiveTTL: TimeInterval = 30 * 24 * 3600
    public var negativeTTL: TimeInterval = 24 * 3600
    public var failureTTL: TimeInterval = 120
    public var providerTimeout: TimeInterval = 6
    public var strategy: Strategy = .parallel
    public var stopAtQuality: Double = 0.7

    public init() {}
}

public enum ResolveOutcome: Equatable, Sendable {
    case found(FoodRecord, fromCache: Bool, sources: [FoodSource])
    /// The sources that answered do not know this product: offer "add it" with the label scanner.
    case notFound(answered: [FoodSource])
    /// No source could be reached. Queue the scan for retry.
    case unavailable(errors: [LookupError])
    /// A coupon, book, store label, etc.: there is no product to look up.
    case notAFoodBarcode(BarcodeKind)
    case invalid(BarcodeIssue)
}

private struct ProviderResult: Sendable {
    let source: FoodSource
    let index: Int
    let record: FoodRecord?
    let error: LookupError?
    var answered: Bool { error == nil }
}

public actor FoodResolver {
    private let providers: [any FoodSourceProvider]
    private let cache: any FoodCache
    private let userFoods: (any UserFoodLookup)?
    private let policy: ResolverPolicy
    private let now: @Sendable () -> Date
    private var inFlight: [GTIN: Task<ResolveOutcome, Never>] = [:]

    public init(
        providers: [any FoodSourceProvider],
        cache: any FoodCache,
        userFoods: (any UserFoodLookup)? = nil,
        policy: ResolverPolicy = ResolverPolicy(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.providers = providers
        self.cache = cache
        self.userFoods = userFoods
        self.policy = policy
        self.now = now
    }

    /// Resolves a raw scan or typed code. When an 8-digit code could be EAN-8 or UPC-E, each reading is tried in turn.
    public func resolve(_ raw: String, symbology: BarcodeSymbology? = nil, preferUPCE: Bool = false) async -> ResolveOutcome {
        switch BarcodeNormalizer.normalize(raw, symbology: symbology, preferUPCE: preferUPCE) {
        case let .invalid(issue):
            return .invalid(issue)
        case let .valid(candidates):
            var first: ResolveOutcome?
            for candidate in candidates {
                let outcome = await resolve(gtin: candidate.gtin)
                if case .found = outcome { return outcome }
                first = first ?? outcome
            }
            return first ?? .invalid(.notAProductCode)
        }
    }

    public func resolve(gtin original: GTIN) async -> ResolveOutcome {
        let gtin = original.consumerUnit
        guard gtin.kind.isLookupWorthy else { return .notAFoodBarcode(gtin.kind) }

        if let userFoods, let own = await userFoods.userFood(for: gtin) {
            return .found(own, fromCache: false, sources: [own.source])
        }
        // Concurrent requests for the same code (a scanner firing twice) share one lookup.
        if let running = inFlight[gtin] { return await running.value }
        let task = Task { await self.perform(gtin) }
        inFlight[gtin] = task
        let outcome = await task.value
        inFlight[gtin] = nil
        return outcome
    }

    private func perform(_ gtin: GTIN) async -> ResolveOutcome {
        let moment = now()
        let cached = await cache.entry(for: gtin)
        var staleRecord: FoodRecord?
        switch cached {
        case let .hit(record, storedAt):
            if moment.timeIntervalSince(storedAt) < policy.positiveTTL {
                return .found(record, fromCache: true, sources: [record.source])
            }
            staleRecord = record
        case let .miss(storedAt):
            if moment.timeIntervalSince(storedAt) < policy.negativeTTL { return .notFound(answered: []) }
        case let .failure(storedAt):
            if moment.timeIntervalSince(storedAt) < policy.failureTTL { return .unavailable(errors: []) }
        case nil:
            break
        }

        let results = await query(gtin)
        let answered = results.filter(\.answered)
        let records = results.compactMap(\.record)

        if let merged = FoodMerger.merge(records.sorted { providerIndex($0) < providerIndex($1) }) {
            await cache.store(.hit(merged, storedAt: now()), for: gtin)
            return .found(merged, fromCache: false, sources: records.map(\.source))
        }
        if !answered.isEmpty {
            // A definitive "unknown" is only cached when every source answered; a partial answer may be wrong.
            if answered.count == providers.count { await cache.store(.miss(storedAt: now()), for: gtin) }
            return .notFound(answered: answered.map(\.source))
        }
        // Nothing reachable: fall back to an expired copy rather than failing the scan.
        if let staleRecord {
            return .found(staleRecord, fromCache: true, sources: [staleRecord.source])
        }
        if staleRecord == nil { await cache.store(.failure(storedAt: now()), for: gtin) }
        return .unavailable(errors: results.compactMap(\.error))
    }

    private func providerIndex(_ record: FoodRecord) -> Int {
        providers.firstIndex { $0.source == record.source } ?? providers.count
    }

    private func query(_ gtin: GTIN) async -> [ProviderResult] {
        switch policy.strategy {
        case .parallel:
            return await withTaskGroup(of: ProviderResult.self) { group in
                for (index, provider) in providers.enumerated() {
                    let timeout = policy.providerTimeout
                    group.addTask { await Self.ask(provider, index: index, gtin: gtin, timeout: timeout) }
                }
                var collected: [ProviderResult] = []
                for await result in group { collected.append(result) }
                return collected.sorted { $0.index < $1.index }
            }
        case .sequential:
            var collected: [ProviderResult] = []
            for (index, provider) in providers.enumerated() {
                let result = await Self.ask(provider, index: index, gtin: gtin, timeout: policy.providerTimeout)
                collected.append(result)
                if let record = result.record, FoodQuality.score(record) >= policy.stopAtQuality { break }
            }
            return collected
        }
    }

    private static func ask(_ provider: any FoodSourceProvider, index: Int, gtin: GTIN, timeout: TimeInterval) async -> ProviderResult {
        enum Raced: Sendable {
            case finished(FoodRecord?)
            case failed(LookupError)
            case timedOut
        }
        let raced = await withTaskGroup(of: Raced.self) { group -> Raced in
            group.addTask {
                do { return .finished(try await provider.lookup(gtin)) }
                catch let error as LookupError { return .failed(error) }
                catch { return .failed(.unavailable("\(error)")) }
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(max(0, timeout) * 1_000_000_000))
                return .timedOut
            }
            let first = await group.next() ?? .timedOut
            group.cancelAll()
            return first
        }
        switch raced {
        case let .finished(record): return ProviderResult(source: provider.source, index: index, record: record, error: nil)
        case let .failed(error): return ProviderResult(source: provider.source, index: index, record: nil, error: error)
        case .timedOut: return ProviderResult(source: provider.source, index: index, record: nil, error: .unavailable("timed out"))
        }
    }
}
