import XCTest
@testable import OtiumCore

/// La tenuta dei dati: cosa succede quando il disco, il file o il mondo non collaborano.
///
/// Nati dall'audit del 2026-07-28. Due difetti trovati e curati qui, tutti e due della stessa
/// famiglia — **fallire in silenzio** — che è la famiglia che costa di più, perché non lascia
/// tracce e si scopre mesi dopo guardando numeri che non tornano.
final class DurabilityTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("otium-durability-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    /// **Una scrittura fallita deve dirlo.** Prima `append` restituiva `true` anche quando la
    /// riga non veniva scritta: il lavoro spariva e l'app se ne dichiarava soddisfatta.
    func testAppendReportsFailureWhenItCannotWrite() throws {
        let url = tempDir.appendingPathComponent("ledger.jsonl")
        let ledger = Ledger(url: url)
        XCTAssertTrue(ledger.append(LedgerEntry(timestamp: Date(), type: .active, seconds: 10)),
                      "su un file scrivibile deve riuscire")

        // Sola lettura: da qui in avanti ogni scrittura fallisce davvero.
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: url.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path) }

        XCTAssertFalse(ledger.append(LedgerEntry(timestamp: Date(), type: .active, seconds: 10)),
                       "con il file in sola lettura `append` non può dire di sì")

        // **E soprattutto: non deve aver sostituito il registro.** È il difetto vero che questo
        // test ha trovato — il ripiego atomico riusciva comunque, perché rinomina un file nuovo
        // sopra il vecchio, e il permesso che conta è quello della cartella.
        XCTAssertEqual(ledger.entries().count, 1,
                       "la riga di prima deve essere ancora lì, non sostituita")
    }

    /// **Una riga rotta non porta via il resto, e non sparisce in silenzio.**
    ///
    /// Saltarla è giusto: un registro che si rifiuta di aprirsi per una riga sbagliata perde
    /// mesi di storia. Saltarla senza dirlo no: le statistiche verrebbero più basse del vero.
    func testACorruptLineIsSkippedAndCounted() throws {
        let url = tempDir.appendingPathComponent("ledger.jsonl")
        let buone = """
        {"seconds":300,"timestamp":"2026-07-28T10:00:00Z","type":"active"}
        {"rotta a metà, questa
        {"seconds":120,"timestamp":"2026-07-28T10:10:00Z","type":"active"}
        """
        try buone.write(to: url, atomically: true, encoding: .utf8)

        let ledger = Ledger(url: url)
        let righe = ledger.entries()
        XCTAssertEqual(righe.count, 2, "le due righe sane devono sopravvivere alla terza rotta")
        XCTAssertEqual(ledger.unreadableLines, 1, "e la riga persa dev'essere contata, non ignorata")
    }

    /// Le righe vuote non sono righe rotte: un file che finisce con «a capo» è normale.
    func testBlankLinesAreNotCountedAsDamage() throws {
        let url = tempDir.appendingPathComponent("ledger.jsonl")
        try "{\"seconds\":300,\"timestamp\":\"2026-07-28T10:00:00Z\",\"type\":\"active\"}\n\n\n"
            .write(to: url, atomically: true, encoding: .utf8)
        let ledger = Ledger(url: url)
        XCTAssertEqual(ledger.entries().count, 1)
        XCTAssertEqual(ledger.unreadableLines, 0)
    }

    /// **Un file di stato illeggibile non deve far ripartire l'app da zero senza rete.**
    ///
    /// Qui il comportamento giusto è il ripiego sui valori di serie — ed è quello che fanno tutti
    /// e tre gli archivi — ma il test esiste perché quel ripiego resti una scelta e non un caso.
    func testCorruptStateFilesFallBackInsteadOfCrashing() throws {
        let rotto = tempDir.appendingPathComponent("rotto.json")
        try "{ questo non è JSON".write(to: rotto, atomically: true, encoding: .utf8)

        XCTAssertNil(RotationStore.load(from: rotto), "la rotazione rotta si dichiara assente")
        // Non si confrontano due `Settings()` interi: `startDate` è `Date()` e due istanze create
        // a microsecondi di distanza non sono uguali. Si confronta ciò che il ripiego promette.
        let ricadute = SettingsStore.load(from: rotto)
        XCTAssertEqual(ricadute.rampWeeks, Settings().rampWeeks)
        XCTAssertEqual(ricadute.escapePhrase, Settings().escapePhrase)
        XCTAssertEqual(ricadute.cadence, Settings().cadence)
        XCTAssertEqual(ProgressStore.load(from: rotto), ProgressBook(),
                       "la progressione rotta riparte vuota, non a metà")
    }

    /// **Tutte le scritture di stato sono atomiche.** Un salvataggio interrotto a metà lascia il
    /// file precedente, mai un file mezzo scritto: su un `.json` una troncatura è illeggibile, e
    /// una progressione illeggibile è una progressione persa.
    func testStateWritesAreAtomic() throws {
        let sorgente = try String(contentsOf: URL(fileURLWithPath: "Sources/OtiumCore/Config.swift"),
                                  encoding: .utf8)
        let progressione = try String(contentsOf: URL(fileURLWithPath: "Sources/OtiumCore/Progression.swift"),
                                      encoding: .utf8)
        let tutte = sorgente + progressione
        let scritture = tutte.components(separatedBy: "data.write(to:").count - 1
        let atomiche = tutte.components(separatedBy: "options: .atomic").count - 1
        XCTAssertEqual(scritture, atomiche,
                       "\(scritture - atomiche) scritture di stato non sono atomiche")
    }

    /// Il registro sopravvive a scritture concorrenti: due thread che appendono insieme non si
    /// mangiano le righe a vicenda.
    func testConcurrentAppendsDoNotLoseRows() throws {
        let url = tempDir.appendingPathComponent("ledger.jsonl")
        let ledger = Ledger(url: url)
        let gruppo = DispatchGroup()
        for i in 0..<60 {
            DispatchQueue.global().async(group: gruppo) {
                _ = ledger.append(LedgerEntry(timestamp: Date(), type: .active, seconds: Double(i)))
            }
        }
        gruppo.wait()
        XCTAssertEqual(ledger.entries().count, 60, "sessanta scritture, sessanta righe")
        XCTAssertEqual(ledger.unreadableLines, 0, "nessuna riga mescolata con un'altra")
    }
}
