import XCTest
@testable import FoodCore

final class ScanStabilizerTests: XCTestCase {
    func testTwoReadsWithinWindowConfirm() {
        var stabilizer = ScanStabilizer()
        XCTAssertEqual(stabilizer.ingest(payload: "036000291452", symbology: .upcA, at: 0.0), .pending(reads: 1, needed: 2))
        guard case let .confirmed(scan) = stabilizer.ingest(payload: "036000291452", symbology: .upcA, at: 0.3) else { return XCTFail() }
        XCTAssertEqual(scan.candidates.first?.gtin.digits14, "00036000291452")
    }

    func testReadsOutsideTheWindowDoNotAccumulate() {
        var stabilizer = ScanStabilizer()
        _ = stabilizer.ingest(payload: "036000291452", symbology: .upcA, at: 0.0)
        XCTAssertEqual(stabilizer.ingest(payload: "036000291452", symbology: .upcA, at: 1.0), .pending(reads: 1, needed: 2))
    }

    func testUPCAAndLeadingZeroEAN13CountAsTheSameCode() {
        var stabilizer = ScanStabilizer()
        _ = stabilizer.ingest(payload: "036000291452", symbology: .upcA, at: 0.0)
        guard case .confirmed = stabilizer.ingest(payload: "0036000291452", symbology: .ean13, at: 0.2) else { return XCTFail() }
    }

    func testCooldownSuppressesRepeatsThenAllowsRescan() {
        var stabilizer = ScanStabilizer()
        _ = stabilizer.ingest(payload: "4006381333931", symbology: .ean13, at: 0.0)
        guard case .confirmed = stabilizer.ingest(payload: "4006381333931", symbology: .ean13, at: 0.1) else { return XCTFail() }
        XCTAssertEqual(stabilizer.ingest(payload: "4006381333931", symbology: .ean13, at: 1.0), .ignored)
        XCTAssertEqual(stabilizer.ingest(payload: "4006381333931", symbology: .ean13, at: 2.0), .ignored)
        // After the cooldown a second scan of the same product (two cans) is possible again.
        XCTAssertEqual(stabilizer.ingest(payload: "4006381333931", symbology: .ean13, at: 3.0), .pending(reads: 1, needed: 2))
        guard case .confirmed = stabilizer.ingest(payload: "4006381333931", symbology: .ean13, at: 3.2) else { return XCTFail() }
    }

    func testMisreadsFailingTheCheckDigitAreRejectedAndNeverCount() {
        var stabilizer = ScanStabilizer()
        guard case .rejected(.badCheckDigit) = stabilizer.ingest(payload: "036000291453", symbology: .upcA, at: 0.0) else { return XCTFail() }
        XCTAssertEqual(stabilizer.ingest(payload: "036000291452", symbology: .upcA, at: 0.1), .pending(reads: 1, needed: 2),
                       "a rejected read must not count towards the real code")
    }

    func testAlternatingBetweenTwoProductsDoesNotConfirmEither() {
        var stabilizer = ScanStabilizer()
        _ = stabilizer.ingest(payload: "036000291452", symbology: .upcA, at: 0.0)
        XCTAssertEqual(stabilizer.ingest(payload: "4006381333931", symbology: .ean13, at: 0.1), .pending(reads: 1, needed: 2))
        guard case .confirmed = stabilizer.ingest(payload: "036000291452", symbology: .upcA, at: 0.2) else { return XCTFail("two reads of the same code within the window confirm it") }
    }

    func testErrorCorrectedTwoDimensionalCodesConfirmOnFirstRead() {
        var stabilizer = ScanStabilizer()
        guard case .confirmed = stabilizer.ingest(payload: "]d20109506000134352", symbology: .dataMatrix, at: 0.0) else { return XCTFail() }
    }

    func testConfigurableAndReset() {
        var stabilizer = ScanStabilizer(config: ScanStabilizerConfig(requiredReads: 3, window: 1.0, cooldown: 0.5))
        _ = stabilizer.ingest(payload: "036000291452", symbology: nil, at: 0.0)
        XCTAssertEqual(stabilizer.ingest(payload: "036000291452", symbology: nil, at: 0.2), .pending(reads: 2, needed: 3))
        stabilizer.reset()
        XCTAssertEqual(stabilizer.ingest(payload: "036000291452", symbology: nil, at: 0.3), .pending(reads: 1, needed: 3))
        XCTAssertEqual(ScanStabilizerConfig(requiredReads: 0).requiredReads, 1)
    }

    func testNonProductPayloadIsRejected() {
        var stabilizer = ScanStabilizer()
        XCTAssertEqual(stabilizer.ingest(payload: "https://example.com", symbology: .qr, at: 0), .rejected(.notAProductCode))
        XCTAssertEqual(stabilizer.ingest(payload: "", symbology: nil, at: 0), .rejected(.empty))
    }
}

final class RetryQueueTests: XCTestCase {
    func testBackoffSchedule() {
        let policy = RetryPolicy(base: 30, factor: 2, cap: 300, maxAttempts: 6)
        XCTAssertEqual(policy.delay(afterFailures: 1), 30)
        XCTAssertEqual(policy.delay(afterFailures: 2), 60)
        XCTAssertEqual(policy.delay(afterFailures: 3), 120)
        XCTAssertEqual(policy.delay(afterFailures: 4), 240)
        XCTAssertEqual(policy.delay(afterFailures: 5), 300, "capped")
        XCTAssertNil(policy.delay(afterFailures: 6), "attempts exhausted")
        XCTAssertNil(policy.delay(afterFailures: 0))
    }

    func testQueueLifecycle() throws {
        let gtin = try XCTUnwrap(GTIN("036000291452"))
        let other = try XCTUnwrap(GTIN("4006381333931"))
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        var queue = PendingScanQueue()
        queue.enqueue(gtin, at: t0)
        queue.enqueue(other, at: t0.addingTimeInterval(5))
        queue.enqueue(gtin, at: t0.addingTimeInterval(99))   // duplicate keeps the original
        XCTAssertEqual(queue.items.count, 2)
        XCTAssertEqual(queue.due(at: t0.addingTimeInterval(10)).map(\.gtin), [gtin, other], "oldest scan first")

        let policy = RetryPolicy(base: 60, factor: 2, cap: 3600, maxAttempts: 3)
        XCTAssertTrue(queue.recordFailure(gtin, at: t0.addingTimeInterval(10), policy: policy))
        XCTAssertEqual(queue.due(at: t0.addingTimeInterval(30)).map(\.gtin), [other], "first retry waits 60 s")
        XCTAssertEqual(queue.due(at: t0.addingTimeInterval(70)).map(\.gtin), [gtin, other])

        XCTAssertTrue(queue.recordFailure(gtin, at: t0.addingTimeInterval(70), policy: policy))
        XCTAssertFalse(queue.recordFailure(gtin, at: t0.addingTimeInterval(200), policy: policy), "third failure gives up")
        XCTAssertEqual(queue.items.map(\.gtin), [other])

        queue.resolve(other)
        XCTAssertTrue(queue.items.isEmpty)
        XCTAssertFalse(queue.recordFailure(other, at: t0, policy: policy), "unknown code")
    }

    func testQueueCodableRoundTrip() throws {
        var queue = PendingScanQueue()
        queue.enqueue(try XCTUnwrap(GTIN("036000291452")), at: Date(timeIntervalSince1970: 1_000_000))
        let decoded = try JSONDecoder().decode(PendingScanQueue.self, from: JSONEncoder().encode(queue))
        XCTAssertEqual(decoded, queue)
    }
}

// MARK: Resolver

/// Wall clock for tests that can be moved forward.
private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var time: Date
    init(_ start: Date = Date(timeIntervalSince1970: 1_700_000_000)) { time = start }
    func now() -> Date { lock.lock(); defer { lock.unlock() }; return time }
    func advance(_ seconds: TimeInterval) { lock.lock(); time = time.addingTimeInterval(seconds); lock.unlock() }
}

private actor ScriptedProvider: FoodSourceProvider {
    nonisolated let source: FoodSource
    private let result: Result<FoodRecord?, LookupError>
    private let delay: TimeInterval
    private(set) var calls = 0

    init(_ source: FoodSource, result: Result<FoodRecord?, LookupError>, delay: TimeInterval = 0) {
        self.source = source
        self.result = result
        self.delay = delay
    }

    func lookup(_ gtin: GTIN) async throws -> FoodRecord? {
        calls += 1
        if delay > 0 { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
        return try result.get()
    }
}

private struct UserFoods: UserFoodLookup {
    let record: FoodRecord?
    func userFood(for gtin: GTIN) async -> FoodRecord? { record }
}

private func sampleRecord(_ source: FoodSource, kcal: Double = 418, name: String = "Sunny Oat Crunch") -> FoodRecord {
    var record = FoodRecord(
        id: "\(source.rawValue):1", gtin: GTIN("012345678905"), name: name, brand: "Fictional Foods Co.", source: source,
        per100g: NutrientSet([.energyKcal: kcal, .protein: 5.45, .carbohydrate: 67.27, .fat: 14.55]),
        serving: ServingSize(quantity: 55, unit: "g", grams: 55, text: "55 g"), ingredients: "oats"
    )
    record.flags = NutritionValidator.validate(record)
    return record
}

final class FoodResolverTests: XCTestCase {
    private let code = "012345678905"

    private func resolver(
        _ providers: [any FoodSourceProvider],
        cache: any FoodCache = InMemoryFoodCache(),
        user: FoodRecord? = nil,
        policy: ResolverPolicy = ResolverPolicy(),
        clock: TestClock = TestClock()
    ) -> FoodResolver {
        FoodResolver(providers: providers, cache: cache, userFoods: user.map(UserFoods.init), policy: policy, now: { clock.now() })
    }

    func testMergesAllSourcesAndCaches() async throws {
        let usda = ScriptedProvider(.usdaBranded, result: .success(sampleRecord(.usdaBranded)))
        var offRecord = sampleRecord(.openFoodFacts)
        offRecord.per100g?[.fiber] = 7.27
        let off = ScriptedProvider(.openFoodFacts, result: .success(offRecord))
        let cache = InMemoryFoodCache()
        let resolver = resolver([off, usda], cache: cache)

        guard case let .found(record, fromCache, sources) = await resolver.resolve(code) else { return XCTFail() }
        XCTAssertFalse(fromCache)
        XCTAssertEqual(Set(sources), [.openFoodFacts, .usdaBranded])
        XCTAssertEqual(record.source, .usdaBranded, "higher trust is the base")
        XCTAssertEqual(record.per100g?[.fiber], 7.27, "gap filled from the other source")

        guard case let .found(_, secondFromCache, _) = await resolver.resolve(code) else { return XCTFail() }
        XCTAssertTrue(secondFromCache)
        let offCalls = await off.calls
        let usdaCalls = await usda.calls
        XCTAssertEqual(offCalls, 1)
        XCTAssertEqual(usdaCalls, 1)
        let cached = await cache.count
        XCTAssertEqual(cached, 1)
    }

    func testUserFoodWinsAndSkipsNetwork() async throws {
        let off = ScriptedProvider(.openFoodFacts, result: .success(sampleRecord(.openFoodFacts)))
        var mine = sampleRecord(.userCreated, kcal: 400, name: "My Version")
        mine.id = "user:1"
        let resolver = resolver([off], user: mine)
        guard case let .found(record, _, sources) = await resolver.resolve(code) else { return XCTFail() }
        XCTAssertEqual(record.name, "My Version")
        XCTAssertEqual(sources, [.userCreated])
        let calls = await off.calls
        XCTAssertEqual(calls, 0)
    }

    func testNotFoundIsNegativelyCachedOnlyWhenEverySourceAnswered() async throws {
        let off = ScriptedProvider(.openFoodFacts, result: .success(nil))
        let usda = ScriptedProvider(.usdaBranded, result: .success(nil))
        let clock = TestClock()
        let resolver = resolver([off, usda], clock: clock)

        guard case let .notFound(answered) = await resolver.resolve(code) else { return XCTFail() }
        XCTAssertEqual(Set(answered), [.openFoodFacts, .usdaBranded])
        _ = await resolver.resolve(code)
        var calls = await off.calls
        XCTAssertEqual(calls, 1, "second lookup served by the negative cache")

        clock.advance(25 * 3600)
        _ = await resolver.resolve(code)
        calls = await off.calls
        XCTAssertEqual(calls, 2, "negative entries expire after a day")
    }

    func testPartialAnswerIsNotCachedAsMiss() async throws {
        let off = ScriptedProvider(.openFoodFacts, result: .failure(.unavailable("offline")))
        let usda = ScriptedProvider(.usdaBranded, result: .success(nil))
        let resolver = resolver([off, usda])
        guard case let .notFound(answered) = await resolver.resolve(code) else { return XCTFail() }
        XCTAssertEqual(answered, [.usdaBranded])
        _ = await resolver.resolve(code)
        let calls = await usda.calls
        XCTAssertEqual(calls, 2, "a partial answer must not poison the cache")
    }

    func testOneSourceDownStillResolvesFromTheOther() async throws {
        let off = ScriptedProvider(.openFoodFacts, result: .failure(.rateLimited))
        let usda = ScriptedProvider(.usdaBranded, result: .success(sampleRecord(.usdaBranded)))
        guard case let .found(record, _, sources) = await resolver([off, usda]).resolve(code) else { return XCTFail() }
        XCTAssertEqual(record.source, .usdaBranded)
        XCTAssertEqual(sources, [.usdaBranded])
    }

    func testAllSourcesDownIsUnavailableAndBrieflyCached() async throws {
        let off = ScriptedProvider(.openFoodFacts, result: .failure(.unavailable("offline")))
        let usda = ScriptedProvider(.usdaBranded, result: .failure(.rateLimited))
        let clock = TestClock()
        let resolver = resolver([off, usda], clock: clock)
        guard case let .unavailable(errors) = await resolver.resolve(code) else { return XCTFail() }
        XCTAssertEqual(Set(errors.map { "\($0)" }), Set([LookupError.unavailable("offline"), .rateLimited].map { "\($0)" }))

        _ = await resolver.resolve(code)
        var calls = await off.calls
        XCTAssertEqual(calls, 1, "failures are remembered for two minutes")
        clock.advance(121)
        _ = await resolver.resolve(code)
        calls = await off.calls
        XCTAssertEqual(calls, 2)
    }

    func testStaleCacheIsServedWhenEverythingIsOffline() async throws {
        let clock = TestClock()
        let cache = InMemoryFoodCache()
        let good = ScriptedProvider(.usdaBranded, result: .success(sampleRecord(.usdaBranded)))
        let firstResolver = resolver([good], cache: cache, clock: clock)
        _ = await firstResolver.resolve(code)

        clock.advance(40 * 24 * 3600)   // past the 30-day TTL
        let down = ScriptedProvider(.usdaBranded, result: .failure(.unavailable("offline")))
        let offlineResolver = resolver([down], cache: cache, clock: clock)
        guard case let .found(record, fromCache, _) = await offlineResolver.resolve(code) else { return XCTFail("stale data beats no data") }
        XCTAssertTrue(fromCache)
        XCTAssertEqual(record.name, "Sunny Oat Crunch")

        // The stale copy must survive the failed refresh.
        guard case .found = await offlineResolver.resolve(code) else { return XCTFail() }
        let stored = await cache.entry(for: GTIN(code)!)
        guard case .hit = stored else { return XCTFail("a failure must not replace a stale hit") }
    }

    func testExpiredEntryIsRefreshedWhenOnline() async throws {
        let clock = TestClock()
        let cache = InMemoryFoodCache()
        _ = await resolver([ScriptedProvider(.usdaBranded, result: .success(sampleRecord(.usdaBranded, kcal: 400)))], cache: cache, clock: clock).resolve(code)
        clock.advance(31 * 24 * 3600)
        let fresh = ScriptedProvider(.usdaBranded, result: .success(sampleRecord(.usdaBranded, kcal: 410)))
        guard case let .found(record, fromCache, _) = await resolver([fresh], cache: cache, clock: clock).resolve(code) else { return XCTFail() }
        XCTAssertFalse(fromCache)
        XCTAssertEqual(record.per100g?[.energyKcal], 410)
    }

    func testNonFoodBarcodesNeverHitTheNetwork() async throws {
        let off = ScriptedProvider(.openFoodFacts, result: .success(sampleRecord(.openFoodFacts)))
        let resolver = resolver([off])
        let variableWeight = await resolver.resolve("212345001233")
        let book = await resolver.resolve("9780306406157")
        let coupon = await resolver.resolve("512345678900")
        let typo = await resolver.resolve("036000291453")
        XCTAssertEqual(variableWeight, .notAFoodBarcode(.variableMeasure))
        XCTAssertEqual(book, .notAFoodBarcode(.book))
        XCTAssertEqual(coupon, .notAFoodBarcode(.coupon))
        XCTAssertEqual(typo, .invalid(.badCheckDigit(expected: 2, suggestions: ["036000291452"])))
        let calls = await off.calls
        XCTAssertEqual(calls, 0)
    }

    func testCaseCodeLooksUpTheConsumerUnit() async throws {
        // The source only knows the shopper-facing item, not the case.
        struct KnowsOnlyTheItem: FoodSourceProvider {
            let source: FoodSource = .usdaBranded
            func lookup(_ gtin: GTIN) async throws -> FoodRecord? {
                gtin.upcA == "012345678905" ? sampleRecord(.usdaBranded) : nil
            }
        }
        // GTIN-14 with packaging indicator 1 wrapping 012345678905 (check digit computed independently).
        let caseCode = GS1.appendingCheckDigit(to: "1" + "001234567890")!
        XCTAssertEqual(caseCode.count, 14)
        guard case .found = await resolver([KnowsOnlyTheItem()]).resolve(caseCode, symbology: .itf14) else { return XCTFail() }
    }

    func testAmbiguousEightDigitCodeFallsThroughToTheReadingThatExists() async throws {
        // 01000146 is both a valid EAN-8 and a valid UPC-E; the provider only knows the UPC-E expansion.
        struct OnlyUPCE: FoodSourceProvider {
            let source: FoodSource = .usdaBranded
            func lookup(_ gtin: GTIN) async throws -> FoodRecord? {
                gtin.upcA == "010000000016" ? sampleRecord(.usdaBranded, name: "Mint Tin") : nil
            }
        }
        guard case let .found(record, _, _) = await resolver([OnlyUPCE()]).resolve("01000146") else { return XCTFail() }
        XCTAssertEqual(record.name, "Mint Tin")
    }

    func testSlowSourceIsAbandonedAfterTheTimeout() async throws {
        var policy = ResolverPolicy()
        policy.providerTimeout = 0.15
        let slow = ScriptedProvider(.openFoodFacts, result: .success(sampleRecord(.openFoodFacts)), delay: 5)
        let quick = ScriptedProvider(.usdaBranded, result: .success(sampleRecord(.usdaBranded)))
        let started = Date()
        guard case let .found(_, _, sources) = await resolver([slow, quick], policy: policy).resolve(code) else { return XCTFail() }
        XCTAssertEqual(sources, [.usdaBranded])
        XCTAssertLessThan(Date().timeIntervalSince(started), 3, "must not wait for the slow source")
    }

    func testSequentialStrategyStopsOnceGoodEnough() async throws {
        var policy = ResolverPolicy()
        policy.strategy = .sequential
        let first = ScriptedProvider(.usdaBranded, result: .success(sampleRecord(.usdaBranded)))
        let second = ScriptedProvider(.openFoodFacts, result: .success(sampleRecord(.openFoodFacts)))
        _ = await resolver([first, second], policy: policy).resolve(code)
        let secondCalls = await second.calls
        XCTAssertEqual(secondCalls, 0, "the first result was good enough")

        let poor = ScriptedProvider(.openFoodFacts, result: .success(FoodRecord(id: "off:1", gtin: GTIN(code), name: "Thin", source: .openFoodFacts,
                                                                                per100g: NutrientSet([.energyKcal: 400]))))
        let rich = ScriptedProvider(.usdaBranded, result: .success(sampleRecord(.usdaBranded)))
        guard case let .found(record, _, sources) = await resolver([poor, rich], policy: policy).resolve(code) else { return XCTFail() }
        XCTAssertEqual(Set(sources), [.openFoodFacts, .usdaBranded], "a thin first answer does not stop the search")
        XCTAssertEqual(record.source, .usdaBranded)
    }

    func testConcurrentIdenticalLookupsShareOneRequest() async throws {
        let slow = ScriptedProvider(.usdaBranded, result: .success(sampleRecord(.usdaBranded)), delay: 0.2)
        let resolver = resolver([slow])
        async let first = resolver.resolve(code)
        async let second = resolver.resolve(code)
        async let third = resolver.resolve("0" + code)   // same item spelled as EAN-13
        _ = await (first, second, third)
        let calls = await slow.calls
        XCTAssertEqual(calls, 1)
    }

    func testCacheEvictsOldestEntries() async throws {
        let cache = InMemoryFoodCache(capacity: 2)
        let a = GTIN("036000291452")!, b = GTIN("4006381333931")!, c = GTIN("96385074")!
        let now = Date()
        await cache.store(.miss(storedAt: now), for: a)
        await cache.store(.miss(storedAt: now), for: b)
        await cache.store(.miss(storedAt: now), for: c)
        let first = await cache.entry(for: a)
        let last = await cache.entry(for: c)
        XCTAssertNil(first)
        XCTAssertNotNil(last)
        await cache.remove(c)
        let removed = await cache.entry(for: c)
        XCTAssertNil(removed)
    }
}

// MARK: Providers over a scripted transport

private final class ScriptedTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var routes: [(prefix: String, response: Result<HTTPResponse, Error>)]
    private(set) var requests: [HTTPRequest] = []

    init(_ routes: [(String, Result<HTTPResponse, Error>)]) { self.routes = routes.map { (prefix: $0.0, response: $0.1) } }

    private func route(for request: HTTPRequest) -> Result<HTTPResponse, Error>? {
        lock.lock()
        defer { lock.unlock() }
        requests.append(request)
        return routes.first { request.url.absoluteString.contains($0.prefix) }?.response
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard let match = route(for: request) else { return HTTPResponse(status: 404, body: Data()) }
        return try match.get()
    }
}

final class ProviderTests: XCTestCase {
    func testOpenFoodFactsProviderFindsProductOnSecondKey() async throws {
        // The padded 13-digit key misses; the 12-digit spelling hits.
        let transport = ScriptedTransport([
            ("/product/0012345678905.json", .success(HTTPResponse(status: 200, body: Data("{\"status\":0,\"status_verbose\":\"product not found\"}".utf8)))),
            ("/product/012345678905.json", .success(HTTPResponse(status: 200, body: Data(MapperTests.offCereal.utf8)))),
        ])
        let provider = OpenFoodFactsProvider(transport: transport, userAgent: "Helios-test/1.0")
        let record = try await provider.lookup(try XCTUnwrap(GTIN("012345678905")))
        XCTAssertEqual(record?.name, "Sunny Oat Crunch")
        XCTAssertEqual(transport.requests.count, 2)
        XCTAssertEqual(transport.requests.first?.headers["User-Agent"], "Helios-test/1.0")
    }

    private func lookupError(status: Int, for gtin: GTIN) async -> LookupError? {
        let transport = ScriptedTransport([("/product/", .success(HTTPResponse(status: status, body: Data())))])
        let provider = OpenFoodFactsProvider(transport: transport, userAgent: "t")
        do {
            _ = try await provider.lookup(gtin)
            return nil
        } catch {
            return error as? LookupError
        }
    }

    func testOpenFoodFactsProviderNotFoundAndErrors() async throws {
        let gtin = try XCTUnwrap(GTIN("012345678905"))
        let notFound = OpenFoodFactsProvider(transport: ScriptedTransport([("/product/", .success(HTTPResponse(status: 404, body: Data())))]), userAgent: "t")
        let missing = try await notFound.lookup(gtin)
        XCTAssertNil(missing)

        let rateLimited = await lookupError(status: 429, for: gtin)
        let forbidden = await lookupError(status: 403, for: gtin)
        let serverError = await lookupError(status: 503, for: gtin)
        let badRequest = await lookupError(status: 400, for: gtin)
        XCTAssertEqual(rateLimited, .rateLimited)
        XCTAssertEqual(forbidden, .unauthorized)
        XCTAssertEqual(serverError, .unavailable("HTTP 503"))
        XCTAssertEqual(badRequest, .malformed("HTTP 400"))

        struct Offline: Error {}
        let dead = OpenFoodFactsProvider(transport: ScriptedTransport([("/product/", .failure(Offline()))]), userAgent: "t")
        do { _ = try await dead.lookup(gtin); XCTFail("expected a throw") } catch {
            guard case .unavailable = error as? LookupError else { return XCTFail("transport errors become .unavailable, got \(error)") }
        }
        let garbage = OpenFoodFactsProvider(transport: ScriptedTransport([("/product/", .success(HTTPResponse(status: 200, body: Data("<html>".utf8))))]), userAgent: "t")
        do { _ = try await garbage.lookup(gtin); XCTFail("expected a throw") } catch {
            guard case .malformed = error as? LookupError else { return XCTFail() }
        }
    }

    func testUSDAProviderMatchesOnGTINAndSendsKeyInHeader() async throws {
        let transport = ScriptedTransport([("/foods/search", .success(HTTPResponse(status: 200, body: Data(MapperTests.usdaSearch.utf8))))])
        let provider = USDAProvider(transport: transport, apiKey: "SECRET")
        let record = try await provider.lookup(try XCTUnwrap(GTIN("012345678905")))
        XCTAssertEqual(record?.id, "usda:2000002")
        XCTAssertEqual(transport.requests.first?.headers["X-Api-Key"], "SECRET")
        XCTAssertFalse(transport.requests.first?.url.absoluteString.contains("SECRET") ?? true)
    }

    func testUSDAProviderTriesAlternateKeysThenGivesUp() async throws {
        let transport = ScriptedTransport([("/foods/search", .success(HTTPResponse(status: 200, body: Data("{\"foods\":[]}".utf8))))])
        let provider = USDAProvider(transport: transport, apiKey: nil)
        let record = try await provider.lookup(try XCTUnwrap(GTIN("036000291452")))
        XCTAssertNil(record)
        XCTAssertEqual(transport.requests.count, 3, "UPC-A, EAN-13 and GTIN-14 spellings")
    }

    func testResolverEndToEndOverTransports() async throws {
        let off = OpenFoodFactsProvider(transport: ScriptedTransport([("/product/", .success(HTTPResponse(status: 200, body: Data(MapperTests.offCereal.utf8))))]), userAgent: "t")
        let usda = USDAProvider(transport: ScriptedTransport([("/foods/search", .success(HTTPResponse(status: 200, body: Data(MapperTests.usdaSearch.utf8))))]), apiKey: "k")
        let resolver = FoodResolver(providers: [off, usda], cache: InMemoryFoodCache())
        guard case let .found(record, _, sources) = await resolver.resolve("012345678905") else { return XCTFail() }
        XCTAssertEqual(Set(sources), [.openFoodFacts, .usdaBranded])
        XCTAssertEqual(record.gtin, GTIN("012345678905"))
        XCTAssertEqual(record.allergens, [.gluten, .milk, .wheat, .peanut, .treeNut], "OFF tags and USDA ingredient detection are unioned")
    }
}

// MARK: Draft builder

final class FoodDraftTests: XCTestCase {
    func testBuildFromScannedLabelDerivesPer100g() throws {
        let label = LabelParser.parse(LabelParserTests.clean)
        let draft = FoodDraft(gtin: GTIN("012345678905"), name: "  Sunny Oat Crunch ", brand: " Fictional Foods Co. ", label: label, packageSizeText: "340 g")
        let record = try FoodDraftBuilder.build(draft, now: Date(timeIntervalSince1970: 1_700_000_000)).get()
        XCTAssertEqual(record.id, "label:00012345678905")
        XCTAssertEqual(record.name, "Sunny Oat Crunch")
        XCTAssertEqual(record.brand, "Fictional Foods Co.")
        XCTAssertEqual(record.source, .labelScan)
        XCTAssertEqual(record.perServing?[.energyKcal], 230)
        XCTAssertEqual(record.per100g?[.energyKcal] ?? 0, 418.181818, accuracy: 1e-5, "230 kcal over 55 g")
        XCTAssertEqual(record.per100g?[.sodium] ?? 0, 290.909091, accuracy: 1e-5)
        XCTAssertEqual(record.packageSize?.grams, 340)
        XCTAssertEqual(record.nutrients(for: .grams(110))?[.energyKcal] ?? 0, 460, accuracy: 1e-3)
        XCTAssertEqual(record.flags, [])
    }

    func testCorrectionsOverrideOCRAndServingOverrideIsUsed() throws {
        let label = LabelParser.parse("Calories 230\nTotal Fat 8g 10%\nTotal Carbohydrate 37g\nProtein 3g")
        let draft = FoodDraft(name: "Bar", label: label, corrections: [.protein: 5], servingOverrideText: "1 bar (50 g)")
        let record = try FoodDraftBuilder.build(draft).get()
        XCTAssertEqual(record.perServing?[.protein], 5)
        XCTAssertEqual(record.serving?.unit, "bar")
        XCTAssertEqual(record.per100g?[.energyKcal], 460)
        XCTAssertTrue(record.id.hasPrefix("label:x"), "no barcode: id derives from the name")
    }

    func testIdForUnbarcodedFoodIsStable() throws {
        let label = LabelParser.parse("Calories 230\nTotal Fat 8g\nTotal Carbohydrate 37g\nProtein 3g")
        let a = try FoodDraftBuilder.build(FoodDraft(name: "Bar", brand: "Co", label: label)).get()
        let b = try FoodDraftBuilder.build(FoodDraft(name: "Bar", brand: "Co", label: label)).get()
        XCTAssertEqual(a.id, b.id)
        XCTAssertEqual(FoodDraftBuilder.stableHash("abc"), "e71fa2190541574b", "FNV-1a 64-bit reference value")
    }

    func testPer100LabelsAndVolumeServings() throws {
        let eu = LabelParser.parse("Per 100 ml\nEnergy 180kJ\nFat 0g\nCarbohydrate 10.6g\nProtein 0g")
        let drink = try FoodDraftBuilder.build(FoodDraft(name: "Cola", label: eu)).get()
        XCTAssertNil(drink.per100g)
        XCTAssertEqual(drink.per100ml?[.carbohydrate], 10.6)

        let canLabel = LabelParser.parse("Serving size 1 can (355 ml)\nCalories 150\nTotal Fat 0g\nTotal Carbohydrate 39g\nProtein 0g")
        let can = try FoodDraftBuilder.build(FoodDraft(name: "Cola", label: canLabel)).get()
        XCTAssertNil(can.per100g)
        XCTAssertEqual(can.per100ml?[.energyKcal] ?? 0, 42.253521, accuracy: 1e-5)
    }

    func testValidation() {
        let label = LabelParser.parse("Calories 230\nTotal Fat 8g\nTotal Carbohydrate 37g\nProtein 3g")
        XCTAssertEqual(FoodDraftBuilder.build(FoodDraft(name: "  ", label: label)), .failure(.nameRequired))
        XCTAssertEqual(FoodDraftBuilder.build(FoodDraft(name: "X", label: LabelParser.parse("Protein 3g\nTotal Fat 1g\nTotal Carbohydrate 5g"))), .failure(.caloriesRequired))
        XCTAssertEqual(FoodDraftBuilder.build(FoodDraft(name: "X", label: LabelParser.parse("Calories 100"))), .failure(.macrosRequired([.protein, .carbohydrate, .fat])))
        XCTAssertEqual(FoodDraftBuilder.build(FoodDraft(name: "X", label: label, corrections: [.protein: -3])), .failure(.negativeValue(.protein)))
        // Calories supplied by the user rescue a label where OCR missed the calories row.
        let noCalories = LabelParser.parse("Protein 3g\nTotal Fat 8g\nTotal Carbohydrate 37g")
        XCTAssertNotNil(try? FoodDraftBuilder.build(FoodDraft(name: "X", label: noCalories, corrections: [.energyKcal: 232])).get())
    }
}
