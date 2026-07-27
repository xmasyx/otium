import XCTest
@testable import OtiumCore

final class ActivityClockTests: XCTestCase {

    func testAccumulatesWhileThereIsInput() {
        var clock = ActivityClock(idleThreshold: 60)
        for _ in 0..<10 { clock.tick(elapsed: 1, idle: 0) }
        XCTAssertEqual(clock.activeSeconds, 10, accuracy: 0.001)
        XCTAssertFalse(clock.isIdle)
    }

    /// ISC-1 — oltre la soglia il tempo non conta.
    func testStopsAccumulatingBeyondIdleThreshold() {
        var clock = ActivityClock(idleThreshold: 60)
        for _ in 0..<100 { clock.tick(elapsed: 1, idle: 0) }
        let before = clock.activeSeconds
        for i in 0..<10 { clock.tick(elapsed: 1, idle: 60 + Double(i)) }
        XCTAssertTrue(clock.isIdle)
        XCTAssertLessThanOrEqual(clock.activeSeconds, before)
    }

    /// ISC-4 — l'invariante che conta: dopo aver attraversato la soglia, il contatore vale il
    /// tempo di lavoro **vero**, non quello gonfiato dal minuto di attesa.
    ///
    /// 200 secondi di lavoro, poi ci si ferma. Mentre l'inattività sale da 1 a 59 l'orologio
    /// continua a contare (non sa ancora che te ne sei andato) e arriva a 259; al sessantesimo
    /// secondo capisce, e restituisce esattamente quei 60. Deve tornare a ~200.
    func testCounterEqualsTrueWorkTimeAfterCrossingTheThreshold() {
        var clock = ActivityClock(idleThreshold: 60)
        for _ in 0..<200 { clock.tick(elapsed: 1, idle: 0) }
        XCTAssertEqual(clock.activeSeconds, 200, accuracy: 0.001)

        for i in 1...59 { clock.tick(elapsed: 1, idle: Double(i)) }
        XCTAssertEqual(clock.activeSeconds, 259, accuracy: 0.001, "prima di accorgersene, conta")

        clock.tick(elapsed: 1, idle: 60)
        XCTAssertEqual(clock.activeSeconds, 199, accuracy: 1.5, "restituisce la soglia: ~200")
        XCTAssertTrue(clock.isIdle)

        clock.tick(elapsed: 1, idle: 61)
        XCTAssertEqual(clock.activeSeconds, 199, accuracy: 1.5, "niente doppia sottrazione")
    }

    /// ISC-4 — una pausetta sotto la soglia non azzera niente: si riprende da dov'eri.
    func testShortPauseBelowThresholdKeepsTheCounter() {
        var clock = ActivityClock(idleThreshold: 60)
        for _ in 0..<100 { clock.tick(elapsed: 1, idle: 0) }
        for i in 0..<30 { clock.tick(elapsed: 1, idle: Double(i)) }   // 30 s fermo, sotto soglia
        XCTAssertFalse(clock.isIdle)
        XCTAssertEqual(clock.activeSeconds, 130, accuracy: 0.001)
    }

    /// ISC-2 — al rientro l'orologio dichiara quanto sei stato via.
    func testReportsNaturalBreakDurationOnReturn() {
        var clock = ActivityClock(idleThreshold: 60)
        for _ in 0..<100 { clock.tick(elapsed: 1, idle: 0) }
        for i in 0..<240 { clock.tick(elapsed: 1, idle: 60 + Double(i)) }
        let event = clock.tick(elapsed: 1, idle: 0.5)
        guard case .naturalBreak(let seconds) = event else {
            return XCTFail("atteso naturalBreak, ricevuto \(event)")
        }
        XCTAssertEqual(seconds, 299, accuracy: 1.0)
        XCTAssertFalse(clock.isIdle)
    }

    /// ISC-5 — il Mac chiuso in borsa non è tempo di lavoro.
    func testSleepGapIsNeverCreditedAsActiveTime() {
        var clock = ActivityClock(idleThreshold: 60, maxCredibleElapsed: 5)
        for _ in 0..<100 { clock.tick(elapsed: 1, idle: 0) }
        let event = clock.tick(elapsed: 3600, idle: 3600)   // coperchio chiuso per un'ora
        guard case .naturalBreak(let seconds) = event else {
            return XCTFail("atteso naturalBreak, ricevuto \(event)")
        }
        XCTAssertEqual(seconds, 3600, accuracy: 0.001)
        XCTAssertEqual(clock.activeSeconds, 100, accuracy: 0.001)
    }

    func testResetClearsTheCounter() {
        var clock = ActivityClock(idleThreshold: 60)
        for _ in 0..<50 { clock.tick(elapsed: 1, idle: 0) }
        clock.reset()
        XCTAssertEqual(clock.activeSeconds, 0)
        XCTAssertEqual(clock.secondsRemaining(of: 1800), 1800, accuracy: 0.001)
        XCTAssertEqual(clock.fraction(of: 1800), 0, accuracy: 0.001)
    }

    func testFractionIsCappedAtOne() {
        var clock = ActivityClock(idleThreshold: 60, maxCredibleElapsed: 120)
        for _ in 0..<100 { clock.tick(elapsed: 60, idle: 0) }
        XCTAssertEqual(clock.fraction(of: 1800), 1.0, accuracy: 0.001)
    }
}
