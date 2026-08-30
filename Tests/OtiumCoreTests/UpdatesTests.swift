import Foundation
import XCTest
@testable import OtiumCore

/// Il contratto del modulo aggiornamenti, con un polo negativo per ogni regola che potrebbe
/// avviare l'azione sbagliata su un Mac che non la può eseguire.
final class UpdatesVersionTests: XCTestCase {
    func testTagConPrefissoPiuNuovo() {
        XCTAssertEqual(Updates.newerVersion(current: "1.2.0", latestTag: "v1.3.0"), "1.3.0")
    }

    func testTagSenzaPrefisso() {
        XCTAssertEqual(Updates.newerVersion(current: "1.2.0", latestTag: "1.2.1"), "1.2.1")
    }

    func testUgualeNonEPiuNuova() {
        XCTAssertNil(Updates.newerVersion(current: "1.2.0", latestTag: "v1.2.0"))
    }

    func testPiuVecchiaNonEPiuNuova() {
        XCTAssertNil(Updates.newerVersion(current: "1.3.0", latestTag: "v1.2.9"))
    }

    func testConfrontoNumericoNonLessicale() {
        XCTAssertEqual(Updates.newerVersion(current: "1.9.0", latestTag: "v1.10.0"), "1.10.0")
        XCTAssertNil(Updates.newerVersion(current: "1.10.0", latestTag: "v1.9.0"))
    }

    func testComponentiMancantiValgonoZero() {
        XCTAssertEqual(Updates.newerVersion(current: "1.2", latestTag: "v1.2.1"), "1.2.1")
        XCTAssertNil(Updates.newerVersion(current: "1.2.0", latestTag: "v1.2"))
    }

    func testSpazzaturaNonEUnaVersione() {
        XCTAssertNil(Updates.newerVersion(current: "1.2.0", latestTag: "garbage"))
        XCTAssertNil(Updates.newerVersion(current: "dev", latestTag: "v1.3.0"))
        XCTAssertNil(Updates.newerVersion(current: "1.2.0", latestTag: ""))
    }
}

final class UpdatesCadenceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testMaiControllatoEDovuto() {
        XCTAssertTrue(Updates.isDue(lastCheck: nil, now: now))
    }

    func testVentitreOreNonBastano() {
        XCTAssertFalse(Updates.isDue(lastCheck: now.addingTimeInterval(-23 * 3600), now: now))
    }

    func testVenticinqueOreBastano() {
        XCTAssertTrue(Updates.isDue(lastCheck: now.addingTimeInterval(-25 * 3600), now: now))
    }

    func testEsattamenteUnGiornoEDovuto() {
        XCTAssertTrue(Updates.isDue(lastCheck: now.addingTimeInterval(-86_400), now: now))
    }

    func testUnOrologioTornatoIndietroNonBlocca() {
        XCTAssertTrue(Updates.isDue(lastCheck: now.addingTimeInterval(+3 * 86_400), now: now))
    }
}

final class UpdatesSourceTests: XCTestCase {
    private let roots = ["/opt/homebrew/Caskroom", "/usr/local/Caskroom"]
    private let home = "/Users/prova"

    private func exists(_ present: Set<String>) -> (String) -> Bool {
        { present.contains($0) }
    }

    func testCaskroomEBundleInApplications() {
        let source = Updates.source(
            bundlePath: "/Applications/Otium.app", caskroomRoots: roots, homeDirectory: home,
            fileExists: exists(["/opt/homebrew/Caskroom/otium"])
        )
        XCTAssertEqual(source, .homebrew)
    }

    func testSecondaRadiceIntel() {
        let source = Updates.source(
            bundlePath: "/Applications/Otium.app", caskroomRoots: roots, homeDirectory: home,
            fileExists: exists(["/usr/local/Caskroom/otium"])
        )
        XCTAssertEqual(source, .homebrew)
    }

    func testApplicationsDiCasa() {
        let source = Updates.source(
            bundlePath: "/Users/prova/Applications/Otium.app", caskroomRoots: roots,
            homeDirectory: home, fileExists: exists(["/opt/homebrew/Caskroom/otium"])
        )
        XCTAssertEqual(source, .homebrew)
    }

    func testSenzaCaskroomEManuale() {
        let source = Updates.source(
            bundlePath: "/Applications/Otium.app", caskroomRoots: roots, homeDirectory: home,
            fileExists: exists([])
        )
        XCTAssertEqual(source, .manual)
    }

    func testCaskroomDiUnAltraAppNonConta() {
        let source = Updates.source(
            bundlePath: "/Applications/Otium.app", caskroomRoots: roots, homeDirectory: home,
            fileExists: exists(["/opt/homebrew/Caskroom/kalamos"])
        )
        XCTAssertEqual(source, .manual)
    }

    func testBundleFuoriDaApplicationsEManuale() {
        let source = Updates.source(
            bundlePath: "/Users/prova/Desktop/Otium.app", caskroomRoots: roots,
            homeDirectory: home, fileExists: exists(["/opt/homebrew/Caskroom/otium"])
        )
        XCTAssertEqual(source, .manual)
    }
}

final class UpdatesActionTests: XCTestCase {
    func testArgomentiEsattiPerBrew() {
        XCTAssertEqual(Updates.upgradeArguments(), ["upgrade", "--cask", "xmasyx/tap/otium"])
    }

    func testDaBrewSiAggiornaERiavvia() {
        XCTAssertEqual(
            Updates.action(for: .homebrew, version: "1.3.0"),
            .upgradeAndRelaunch(arguments: ["upgrade", "--cask", "xmasyx/tap/otium"])
        )
    }

    func testAManoSiApreLaPaginaDellaRelease() {
        let url = URL(string: "https://github.com/xmasyx/otium/releases/tag/v1.3.0")!
        XCTAssertEqual(Updates.action(for: .manual, version: "1.3.0"), .openReleasePage(url))
    }
}

final class UpdatesJSONTests: XCTestCase {
    func testLeggeIlTag() {
        let data = Data(#"{"tag_name":"v1.3.0","name":"1.3.0","draft":false}"#.utf8)
        XCTAssertEqual(Updates.latestTag(fromReleaseJSON: data), "v1.3.0")
    }

    func testSenzaTagNil() {
        XCTAssertNil(Updates.latestTag(fromReleaseJSON: Data("{}".utf8)))
    }

    func testNonJSONNil() {
        XCTAssertNil(Updates.latestTag(fromReleaseJSON: Data("<html>".utf8)))
    }
}
