import AppKit
import OtiumCore

/// **L'unico punto da cui esce un suono.**
///
/// Prima erano quattro `NSSound(named:)?.play()` sparsi — il preavviso, i tocchi del cambio lato,
/// la fine della tenuta, il via del respiro — e nessuno toccava il volume: il livello era quello
/// del Mac e basta. Un'impostazione di volume su quattro punti separati vuol dire quattro posti
/// dove ci si dimentica di applicarla, e il quarto suona più forte degli altri senza che nessun
/// test possa accorgersene, perché non c'è niente di rotto.
///
/// **Il volume è una quota di quello del Mac.** `NSSound.volume` moltiplica, non sostituisce: si
/// può stare sotto al resto di quello che stai ascoltando, mai sopra.
enum Suono {

    /// - Parameters:
    ///   - name: nome di un suono di sistema; vuoto o `nil` = niente.
    ///   - volume: 0…1, limitato da `Settings.clampSoundVolume` (la stessa funzione dell'init e
    ///     della decodifica, importata e non ricopiata).
    /// - Returns: l'oggetto che sta suonando, **per la sonda**: il livello si rilegge da lui e non
    ///   da un `NSSound(named:)` costruito dopo, che sarebbe un altro oggetto al volume di serie e
    ///   direbbe verde qualunque cosa faccia questa funzione.
    @discardableResult
    static func play(_ name: String?, volume: Double) -> NSSound? {
        guard let name, !name.isEmpty else { return nil }
        let livello = Settings.clampSoundVolume(volume)
        // A zero non si costruisce niente: un suono muto è comunque una risorsa audio aperta, e
        // la regola della casa è tenerla viva per la durata dell'uso, non del processo.
        guard livello > 0 else { return nil }
        guard let suono = NSSound(named: name) else { return nil }
        suono.volume = Float(livello)
        suono.play()
        return suono
    }
}
