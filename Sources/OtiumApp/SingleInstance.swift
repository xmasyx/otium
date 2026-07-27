import AppKit
import Darwin
import OtiumCore

/// Una sola Otium alla volta.
///
/// Senza questo, cercarla da Spotlight una seconda volta avvia un **secondo timer**: due processi
/// che contano lo stesso tempo, due schermate di blocco che si accavallano, e due registri che
/// scrivono sullo stesso file. Su un'app che vive nella barra dei menu il difetto è quasi
/// invisibile — non c'è una finestra che ti dica "sono già qui" — ed è proprio per questo che
/// va impedito nel codice e non lasciato al sistema.
///
/// Il presidio è un **lock di file**, non un controllo sul bundle identifier: quest'ultimo
/// funziona solo se l'app è stata avviata come bundle, mentre il lock regge in ogni caso — anche
/// lanciando l'eseguibile a mano dal terminale, che è esattamente come nasce il doppione durante
/// lo sviluppo.
enum SingleInstance {

    static let bundleIdentifier = "app.otium.mac"
    /// «Ci sei? Fatti vedere.» — il secondo avvio chiede all'istanza viva di dare un segno.
    static let pingNotification = Notification.Name("app.otium.mac.ping")
    /// «Fai partire una pausa adesso.»
    static let breakNotification = Notification.Name("app.otium.mac.break")

    /// Tenuto aperto per tutta la vita del processo: il lock vive finché vive il descrittore, e
    /// il sistema lo rilascia da solo se il processo muore male.
    private static var lockDescriptor: Int32 = -1

    /// `true` se sei tu l'istanza buona; `false` se ce n'è già una viva.
    static func acquire() -> Bool {
        Paths.ensureDirectory()
        let path = Paths.supportDirectory.appendingPathComponent("otium.lock").path
        let descriptor = Darwin.open(path, O_CREAT | O_RDWR, 0o644)
        // Se il lock non si può nemmeno creare, non è una buona ragione per impedire l'avvio:
        // meglio un'app che parte di un'app che non parte per colpa di un file.
        guard descriptor >= 0 else { return true }

        if flock(descriptor, LOCK_EX | LOCK_NB) != 0 {
            close(descriptor)
            return false
        }
        lockDescriptor = descriptor
        return true
    }

    /// Sveglia l'istanza già viva, e portala davanti se è un'app vera.
    static func wakeExisting(requestBreak: Bool) {
        DistributedNotificationCenter.default().postNotificationName(
            requestBreak ? breakNotification : pingNotification,
            object: nil, userInfo: nil, deliverImmediately: true
        )
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        where app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            app.activate()
        }
    }

    static func observe(onPing: @escaping () -> Void, onBreak: @escaping () -> Void) {
        let center = DistributedNotificationCenter.default()
        center.addObserver(forName: pingNotification, object: nil, queue: .main) { _ in onPing() }
        center.addObserver(forName: breakNotification, object: nil, queue: .main) { _ in onBreak() }
    }
}
