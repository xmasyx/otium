import XCTest
@testable import OtiumCore

/// La crescita oltre il 100%, e i freni che la tengono onesta.
final class ProgressionTests: XCTestCase {

    /// **Una giornata buona non è una capacità nuova.** Serve la seconda conferma.
    func testOneGoodDayIsNotEnough() {
        var p = ExerciseProgress()
        p = Progression.advance(p, attempt: .complete)
        XCTAssertEqual(p.level, 1.0, accuracy: 0.0001, "dopo una sola conferma non si sale")
        XCTAssertEqual(p.streak, 1)

        p = Progression.advance(p, attempt: .complete)
        XCTAssertEqual(p.level, 1.05, accuracy: 0.0001, "alla seconda si sale del 5%")
        XCTAssertEqual(p.streak, 0, "il conto riparte, non si accumula")
    }

    /// La serie si interrompe: due conferme non consecutive non fanno salire niente.
    func testTheStreakMustBeConsecutive() {
        var p = ExerciseProgress()
        p = Progression.advance(p, attempt: .complete)
        p = Progression.advance(p, attempt: .partial)
        p = Progression.advance(p, attempt: .complete)
        XCTAssertEqual(p.level, 1.0, accuracy: 0.0001)
    }

    /// **Il 100% è il pavimento.** Il programma è quello, il resto è allenamento in più: per
    /// quanto male vada una settimana, l'app non scende sotto ciò che ha promesso.
    func testItNeverGoesBelowOneHundredPercent() {
        var p = ExerciseProgress()
        for _ in 0..<20 { p = Progression.advance(p, attempt: .partial) }
        XCTAssertEqual(p.level, 1.0, accuracy: 0.0001)
    }

    /// Si scende di un gradino solo, e con la stessa pazienza con cui si sale.
    func testItStepsDownAfterTwoMissesOnly() {
        var p = ExerciseProgress(level: 1.1025, streak: 0)   // due incrementi
        p = Progression.advance(p, attempt: .partial)
        XCTAssertEqual(p.level, 1.1025, accuracy: 0.0001, "una mancata non fa scendere")
        p = Progression.advance(p, attempt: .partial)
        XCTAssertEqual(p.level, 1.05, accuracy: 0.0001, "alla seconda si scende di un gradino")
    }

    /// Il tetto è **tempo**, non gusto: quante ripetizioni ci stanno in quella pausa.
    func testTheCeilingComesFromTheBreakLength() {
        // 90 secondi di micro-pausa, squat da 2,5 s l'uno: 90 × 0,6 / 2,5 = 21.
        XCTAssertEqual(Progression.ceiling(for: .squat, breakSeconds: 90), 21)
        // In una pausa piena da 5 minuti ce ne stanno molti di più.
        XCTAssertGreaterThan(Progression.ceiling(for: .squat, breakSeconds: 300),
                             Progression.ceiling(for: .squat, breakSeconds: 90))
        // Il tetto non scende mai sotto il numero di base, o l'app proporrebbe meno del programma.
        XCTAssertGreaterThanOrEqual(Progression.ceiling(for: .burpee, breakSeconds: 20),
                                    ExerciseKind.burpee.baseReps)
    }

    /// Al tetto si propone il movimento più duro, **e anche prima** quando stai andando bene.
    func testHarderIsSuggestedAtTheCeilingAndBefore() {
        let base = ExerciseProgress()
        // Numero ancora basso e nessuna crescita: non c'è niente da proporre.
        XCTAssertNil(Progression.suggestHarder(kind: .kneePushUp, reps: 6,
                                               progress: base, breakSeconds: 90))
        // Al tetto: proposta, con la ragione giusta.
        let alTetto = Progression.suggestHarder(kind: .kneePushUp, reps: 99,
                                                progress: base, breakSeconds: 90)
        XCTAssertEqual(alTetto?.kind, .inclinePushUp)
        XCTAssertEqual(alTetto?.reason, .ceiling)
        // Prima del tetto, ma con tre incrementi alle spalle: invito, non tetto.
        let cresciuto = ExerciseProgress(level: 1.16, streak: 0)
        let prima = Progression.suggestHarder(kind: .kneePushUp, reps: 6,
                                              progress: cresciuto, breakSeconds: 90)
        XCTAssertEqual(prima?.kind, .inclinePushUp)
        XCTAssertEqual(prima?.reason, .doingWell)
    }

    /// In cima alla scala non si propone niente: meglio un tetto che una bugia.
    func testNothingIsSuggestedAtTheTopOfTheLadder() {
        XCTAssertNil(Progression.harder(than: .burpee))
        XCTAssertNil(Progression.suggestHarder(kind: .burpee, reps: 999,
                                               progress: ExerciseProgress(level: 2.0),
                                               breakSeconds: 90))
    }

    /// La scala della spinta sale davvero, e passo per passo arriva in cima senza cicli.
    func testThePushLadderTerminates() {
        var kind = ExerciseKind.wallPushUp
        var passi = 0
        var visti: Set<ExerciseKind> = [kind]
        while let up = Progression.harder(than: kind) {
            XCTAssertFalse(visti.contains(up), "la scala gira in tondo su \\(up.rawValue)")
            visti.insert(up)
            kind = up
            passi += 1
            XCTAssertLessThan(passi, 20, "scala troppo lunga o infinita")
        }
        XCTAssertGreaterThanOrEqual(passi, 4, "dal muro si deve poter arrivare in cima")
    }

    /// Il registro degli esercizi tiene ognuno per conto suo: essere avanti sugli squat non
    /// regala niente sui push-up.
    func testProgressIsPerExercise() {
        var book = ProgressBook()
        book.record(.complete, for: .squat)
        book.record(.complete, for: .squat)
        XCTAssertEqual(book.progress(for: .squat).level, 1.05, accuracy: 0.0001)
        XCTAssertEqual(book.progress(for: .pushUp).level, 1.0, accuracy: 0.0001)
    }
}
