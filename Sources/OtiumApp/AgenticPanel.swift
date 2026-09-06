import AppKit
import SwiftUI
import OtiumCore

/// **Il pannello della modalità Agentic: la pausa che non copre lo schermo.**
///
/// Nasce da una sua richiesta del 2026-09-06, guardando gli agenti lavorare nel browser mentre lo
/// scudo li fermava: *«una modalità che mi indica solamente esercizi da fare, mi mette il timer in
/// alto a destra però non oscura la pagina così che se io ho gli agenti che stanno lavorando questi
/// possono continuare perché magari stiamo usando interceptor»*.
///
/// **Parte da `WarningHUD`, non da zero**, ed è la ragione per cui è un `NSPanel` non-attivante: è
/// l'unica classe che entra nello Space di un'app a schermo intero senza rubarle niente. Da lì in
/// poi le due cose divergono su un punto solo, e vale la pena scriverlo: il preavviso è una
/// notifica che se ne va da sola, questo resta finché la pausa è aperta e chi lo guarda ci deve
/// poter lavorare accanto.
///
/// **Cosa questo pannello NON fa, ed è la metà che conta.** Non chiama mai `NSApp.activate`, non
/// diventa mai `keyWindow` (`canBecomeKey` resta `false`), non tocca `presentationOptions` e non
/// ha nessun battito che si rimetta davanti. Ognuna di quelle righe, che nello scudo è giusta,
/// qui sarebbe il difetto: l'app davanti resta quella di prima, e chi sta scrivendo in un
/// terminale o guardando un agente lavorare non perde un carattere. La prova non è questo
/// commento, è `--agentic-demo`, che stampa l'app in primo piano e lo stato di key prima e dopo.
///
/// **La pausa resta la stessa pausa.** Cambia dove la vedi, non cosa ti chiede: esercizio
/// confermato *e* tempo scaduto, come sotto lo scudo. Un pannello che si chiudesse prima sarebbe
/// un rinvio travestito.
final class AgenticPanel: NSPanel {

    /// **Il fuoco non si prende mai, ed è il contratto di questa modalità.**
    ///
    /// I pulsanti SwiftUI rispondono lo stesso al clic dentro un pannello non-key — il clic arriva
    /// come evento del mouse, che non ha bisogno dello stato di key: quello serve alla tastiera.
    /// Il prezzo dichiarato è proprio quello: qui dentro non funzionano le scorciatoie da
    /// tastiera, quindi «Fatte tutte» si preme col mouse. È il prezzo giusto, perché la modalità
    /// esiste per lasciare la tastiera all'app con cui stai lavorando.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Chi apre, sposta e chiude il pannello.
final class AgenticPanelController {

    private unowned let model: AppModel
    private var panel: AgenticPanel?
    private var moveObserver: NSObjectProtocol?

    /// Dove l'hai lasciato l'ultima volta: **l'angolo in alto a sinistra**, in coordinate dello
    /// schermo.
    ///
    /// **Sta in `UserDefaults` e non nelle impostazioni dell'app**, che sono le tue scelte e
    /// vivono in un file che si legge: la posizione di una finestra è stato dell'interfaccia, non
    /// una preferenza, e mescolarli vorrebbe dire far comparire in `Settings` un campo che nessuno
    /// ha scelto. È la stessa distinzione che macOS fa da sempre con i frame delle finestre.
    ///
    /// **Il bordo alto e non l'origine di AppKit, che è l'angolo in basso, e la differenza l'ho
    /// pagata misurando** (2026-09-06): il pannello si adatta in altezza tenendo fermo il bordo
    /// alto, quindi la sua origine cambia da sé a ogni cambio di faccia. Salvandola, la posizione
    /// ricordata scivolava verso il basso di pausa in pausa. Il bordo alto invece non si muove per
    /// costruzione: qualunque cosa faccia l'altezza, quel numero resta quello che hai scelto tu.
    private static let chiaveOrigine = "agenticPanelOrigin"

    /// La larghezza del pannello sul 16" di riferimento. Stretta di proposito: deve stare accanto
    /// al lavoro, non davanti.
    private static let larghezzaRiferimento: CGFloat = 360
    /// L'aria fra il pannello e i due bordi da cui parte, in alto a destra.
    private static let margineRiferimento: CGFloat = 16
    /// Sotto questa altezza il pannello sarebbe una fessura: serve solo come rete se la misura del
    /// contenuto arrivasse a zero, non come altezza vera. L'altezza vera la detta il contenuto,
    /// come in `WarningHUD.present`.
    private static let altezzaMinimaRiferimento: CGFloat = 180

    init(model: AppModel) {
        self.model = model
    }

    private var schermo: Schermo { model.schermo }
    private var larghezza: CGFloat { schermo.misura(Self.larghezzaRiferimento) }
    private var margine: CGFloat { schermo.misura(Self.margineRiferimento) }

    // MARK: - Aprire e chiudere

    func show(plan: BreakPlan) {
        guard panel == nil else { return }

        let ospite = PannelloOspite(rootView: AgenticPanelView(model: model))
        ospite.sizingOptions = [.intrinsicContentSize]
        let altezza = max(schermo.misura(Self.altezzaMinimaRiferimento), ceil(ospite.fittingSize.height))

        let p = AgenticPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: larghezza, height: altezza)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        // Lo sfondo lo disegna la vista, perché è lei ad avere gli angoli arrotondati: una finestra
        // opaca sotto una carta stondata lascerebbe quattro spigoli quadrati agli angoli.
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        // **`hidesOnDeactivate` spento**, come nello scudo e per la stessa ragione al contrario: un
        // `NSPanel` di suo sparisce quando l'app perde il fuoco, e qui l'app il fuoco non ce l'ha
        // mai — senza questa riga il pannello non si vedrebbe proprio mai.
        p.hidesOnDeactivate = false
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        // Si sposta da qualunque punto della sua superficie: non c'è una barra da afferrare, e una
        // maniglia sarebbe un controllo in più da spiegare in un pannello che ne ha già cinque.
        p.isMovableByWindowBackground = true
        p.isReleasedWhenClosed = false
        p.contentView = ospite
        p.setFrame(NSRect(origin: origineIniziale(altezza: altezza),
                          size: NSSize(width: larghezza, height: altezza)),
                   display: true)
        // **`orderFrontRegardless()` e basta.** È il verbo che mostra una finestra senza attivare
        // l'app: `makeKeyAndOrderFront` la attiverebbe, ed è esattamente quello che questa
        // modalità esiste per non fare.
        p.orderFrontRegardless()
        panel = p

        // **Si salva solo quando a spostarlo sei tu**, e il modo di saperlo è il pulsante del
        // mouse premuto: un trascinamento è per definizione una sequenza di spostamenti a
        // pulsante giù. Ogni altro `didMove` — l'adattamento dell'altezza, un ritaglio dentro
        // lo schermo, una mossa di AppKit — è mio, e una posizione che non hai scelto non deve
        // sopravvivere alla pausa.
        //
        // **Una bandiera «adesso mi sto spostando io» non basta, provata e scartata:** la
        // notifica viene consegnata sulla coda principale in un giro successivo, quindi la
        // bandiera è già stata rimessa a posto quando il blocco gira. Il pulsante del mouse è
        // invece una domanda al sistema nell'istante in cui serve la risposta.
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: p, queue: .main
        ) { [weak self] _ in
            guard NSEvent.pressedMouseButtons != 0 else { return }
            self?.ricorda(cornice: p.frame)
        }

        // Il contenuto cambia mentre la pausa va avanti — il numero grande diventa il conto della
        // tenuta, l'esercizio diventa riposo, il circuito sparisce se ne esci — e ogni cambio può
        // volere un'altezza diversa. **Cresce verso il basso**, cioè col bordo alto fermo: un
        // pannello che si alza sotto le mani mentre lo guardi è la stessa cosa che il testo che si
        // riscrive, e la regola di casa dice che le transizioni non muovono quello che leggi.
        ospite.suAltezzaCambiata = { [weak self] nuova in self?.adatta(altezza: nuova) }
    }

    func hide() {
        if let moveObserver {
            NotificationCenter.default.removeObserver(moveObserver)
            self.moveObserver = nil
        }
        panel?.orderOut(nil)
        panel = nil
    }

    /// Il frame vero, per le sonde: senza, `--agentic-demo` misurerebbe un'intenzione.
    var frame: NSRect? { panel?.frame }
    var isKey: Bool { panel?.isKeyWindow ?? false }

    // MARK: - Dove sta

    private func adatta(altezza nuova: CGFloat) {
        guard let panel else { return }
        let voluta = max(schermo.misura(Self.altezzaMinimaRiferimento), ceil(nuova))
        // Mezzo punto di tolleranza: senza, un arrotondamento che va e viene farebbe rimbalzare la
        // finestra fra due altezze a ogni passata di layout.
        guard abs(voluta - panel.frame.height) > 0.5 else { return }
        let alto = panel.frame.maxY
        var cornice = panel.frame
        cornice.size.height = voluta
        cornice.origin.y = alto - voluta
        panel.setFrame(dentro(cornice), display: true)
    }

    /// Dove aprirlo: dove l'hai lasciato, se c'è ancora posto, altrimenti in alto a destra.
    private func origineIniziale(altezza: CGFloat) -> NSPoint {
        let cornice = NSRect(origin: origineSalvata(altezza: altezza) ?? angoloAltoADestra(altezza: altezza),
                             size: NSSize(width: larghezza, height: altezza))
        return dentro(cornice).origin
    }

    /// In alto a destra dello schermo **dove sta il puntatore**, che è dove stai guardando: con due
    /// monitor, aprirlo sempre sul principale vorrebbe dire metterlo dietro le spalle di chi
    /// lavora sull'altro. `visibleFrame` esclude già la barra dei menu e il Dock.
    private func angoloAltoADestra(altezza: CGFloat) -> NSPoint {
        let visibile = schermoSottoIlPuntatore().visibleFrame
        return NSPoint(x: visibile.maxX - larghezza - margine,
                       y: visibile.maxY - altezza - margine)
    }

    /// **Riportarlo dentro non è una cortesia, è l'unico modo di non perderlo.** La posizione
    /// salvata viene da una scrivania che può non esistere più — monitor staccato, risoluzione
    /// cambiata, dock spostato — e una finestra senza barra del titolo che si apre fuori schermo
    /// non si può né vedere né riportare indietro trascinandola.
    private func dentro(_ cornice: NSRect) -> NSRect {
        let visibile = schermo(che: cornice).visibleFrame
        var messa = cornice
        messa.origin.x = min(max(cornice.minX, visibile.minX), max(visibile.minX, visibile.maxX - cornice.width))
        messa.origin.y = min(max(cornice.minY, visibile.minY), max(visibile.minY, visibile.maxY - cornice.height))
        return messa
    }

    private func schermoSottoIlPuntatore() -> NSScreen {
        let dove = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(dove) } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    /// Lo schermo che contiene di più questa cornice; senza intersezioni, quello del puntatore.
    private func schermo(che cornice: NSRect) -> NSScreen {
        let candidati = NSScreen.screens.map { ($0, $0.frame.intersection(cornice)) }
            .filter { !$0.1.isNull && $0.1.width > 0 && $0.1.height > 0 }
        let migliore = candidati.max { $0.1.width * $0.1.height < $1.1.width * $1.1.height }
        return migliore?.0 ?? schermoSottoIlPuntatore()
    }

    /// L'angolo in alto a sinistra ricordato, riportato all'origine che AppKit vuole per questa
    /// altezza. È qui che il bordo alto salvato torna a essere una cornice.
    private func origineSalvata(altezza: CGFloat) -> NSPoint? {
        guard let coppia = UserDefaults.standard.array(forKey: Self.chiaveOrigine) as? [Double],
              coppia.count == 2 else { return nil }
        return NSPoint(x: coppia[0], y: coppia[1] - altezza)
    }

    private func ricorda(cornice: NSRect) {
        UserDefaults.standard.set([Double(cornice.minX), Double(cornice.maxY)],
                                  forKey: Self.chiaveOrigine)
    }

    /// Impone una posizione: serve a `--agentic-demo --origine=x,y`, che deve poter provare anche
    /// una posizione fuori schermo — cioè il caso che il ritaglio esiste per curare, e che a mano
    /// non si sa produrre.
    ///
    /// **Passa dal disco di proposito**, cioè fa scattare il salvataggio come farebbe un
    /// trascinamento vero: è l'unico modo che una sonda ha di provare che la posizione si ricorda,
    /// visto che il gesto di trascinare non si scrive in uno script.
    func imponi(origine: NSPoint) {
        guard let panel else { return }
        let messa = dentro(NSRect(origin: origine, size: panel.frame.size))
        panel.setFrame(messa, display: true)
        // Il salvataggio è **esplicito** qui, perché il cancello del pulsante del mouse — giusto
        // per la finestra vera — escluderebbe la sonda insieme a tutto il resto.
        ricorda(cornice: messa)
    }
}

/// L'ospite AppKit del contenuto, che sa dire quando l'altezza del contenuto è cambiata.
///
/// Serve perché `fittingSize` letto una volta all'apertura è la misura di **quella** faccia: la
/// pausa ne cambia almeno tre (esercizio, tenuta in corso, riposo), e una finestra ferma
/// all'altezza della prima taglierebbe le altre. `layout()` è il punto in cui SwiftUI ha appena
/// finito di rimettere in fila il contenuto, quindi è lì che la misura nuova esiste davvero.
private final class PannelloOspite<V: View>: NSHostingView<V> {
    var suAltezzaCambiata: ((CGFloat) -> Void)?

    override func layout() {
        super.layout()
        suAltezzaCambiata?(fittingSize.height)
    }
}

/// **Una fila che va a capo quando la larghezza finisce**, cioè quello che in una pagina web fa
/// una riga di testo e che SwiftUI non ha fra i contenitori di serie.
///
/// Sta qui e non nel nucleo perché è disposizione, non aritmetica: dipende da quanto misurano le
/// etichette **a schermo**, con il carattere e il corpo veri, e quella misura la conosce solo il
/// motore di layout. `VariantLayout.rows`, che invece è aritmetica pura, resta nel nucleo con il
/// suo test — e continua a governare lo scudo.
private struct FilaCheVaACapo: Layout {
    let spazioX: CGFloat
    let spazioY: CGFloat

    private func righe(_ figlie: Subviews, larghezza: CGFloat) -> [[(Int, CGSize)]] {
        var tutte: [[(Int, CGSize)]] = []
        var riga: [(Int, CGSize)] = []
        var occupato: CGFloat = 0
        for (indice, figlia) in figlie.enumerated() {
            let misura = figlia.sizeThatFits(.unspecified)
            let servirebbe = riga.isEmpty ? misura.width : occupato + spazioX + misura.width
            // **Una figlia sola non va mai a capo da sé stessa**: se è più larga della colonna,
            // andare a capo non la farebbe stare comunque, e lascerebbe una riga vuota sopra.
            if !riga.isEmpty, servirebbe > larghezza {
                tutte.append(riga)
                riga = []
                occupato = 0
            }
            occupato = riga.isEmpty ? misura.width : occupato + spazioX + misura.width
            riga.append((indice, misura))
        }
        if !riga.isEmpty { tutte.append(riga) }
        return tutte
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let larghezza = proposal.width ?? .infinity
        let tutte = righe(subviews, larghezza: larghezza)
        // Spezzato in passi con i tipi scritti: in una sola espressione il compilatore non ce la
        // faceva a dedurli («unable to type-check this expression in reasonable time»).
        var alta: CGFloat = 0
        var larga: CGFloat = 0
        for riga in tutte {
            let altaRiga: CGFloat = riga.map { $0.1.height }.max() ?? 0
            var largaRiga: CGFloat = 0
            for (_, misura) in riga { largaRiga += misura.width }
            largaRiga += spazioX * CGFloat(max(0, riga.count - 1))
            alta += altaRiga
            larga = max(larga, largaRiga)
        }
        alta += spazioY * CGFloat(max(0, tutte.count - 1))
        return CGSize(width: min(larghezza, larga), height: alta)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for riga in righe(subviews, larghezza: bounds.width) {
            var x = bounds.minX
            let alta: CGFloat = riga.map { $0.1.height }.max() ?? 0
            for (indice, misura) in riga {
                subviews[indice].place(at: CGPoint(x: x, y: y + (alta - misura.height) / 2),
                                       proposal: ProposedViewSize(misura))
                x += misura.width + spazioX
            }
            y += alta + spazioY
        }
    }
}

/// Quello che il pannello dice, e niente di più.
///
/// **Niente frase, niente Zen, niente riga della presenza**, e la ragione è la stessa per tutte e
/// tre: in questa modalità stai continuando a lavorare, e la pausa deve occupare l'angolo dello
/// schermo per il tempo di dirti cosa fare. La citazione vive nello scudo, dove il resto della
/// pagina è vuoto apposta; il respiro guidato ha bisogno dell'alone grande al centro, che qui non
/// c'è; la presenza è uscita da tutte e due le facce il 2026-09-06.
struct AgenticPanelView: View {
    @ObservedObject var model: AppModel

    private var schermo: Schermo { model.schermo }
    /// La stessa funzione corta di `BreakView`, per la stessa ragione: qui ci passa **ogni** misura
    /// del pannello, e un nome lungo si trasformerebbe in un numero nudo alla prima occasione.
    private func p(_ valore: CGFloat) -> CGFloat { schermo.misura(valore) }

    var body: some View {
        VStack(alignment: .leading, spacing: p(12)) {
            if let plan = model.plan {
                intestazione(plan)
                barra(plan)
                corpo(plan)
                if plan.circuitActive { striscia(plan) }
                alternative
                azione(plan)
                viaDUscita(plan)
            } else {
                // Lo stesso stato dello scudo senza piano, e per la stessa ragione: se una rete a
                // monte dimenticasse di chiudere il pannello, qui c'è comunque una frase che dice
                // cosa sta succedendo invece di un rettangolo muto.
                Text(L.t("La pausa è finita.", "The break is over."))
                    .font(.system(size: p(15), weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.paper)
            }
        }
        .padding(p(18))
        .frame(width: schermo.misura(360), alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: p(16), style: .continuous)
                .fill(Palette.ink)
        )
        .overlay(
            RoundedRectangle(cornerRadius: p(16), style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    // MARK: - I pezzi

    /// Etichetta della pausa a sinistra, cronometro a destra: le stesse due informazioni che nello
    /// scudo stanno agli angoli in alto, avvicinate perché qui la riga è larga un quarto.
    private func intestazione(_ plan: BreakPlan) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(etichetta(plan))
                .font(.system(size: p(11), weight: .semibold, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(Palette.accent)
            Spacer()
            Text(orologio(model.secondsLeftOfBreak))
                .font(.system(size: p(15), weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(model.canReturnToWork ? Palette.accent : Palette.dim)
        }
    }

    /// La stessa etichetta dello scudo, senza il ramo Zen: in Agentic il respiro non esiste.
    private func etichetta(_ plan: BreakPlan) -> String {
        guard plan.kind == .long else { return L.t("MICRO-PAUSA", "MICRO-BREAK") }
        let minuti = max(1, Int((plan.duration / 60).rounded()))
        return L.t("PAUSA \(minuti)'", "BREAK \(minuti)'")
    }

    private func barra(_ plan: BreakPlan) -> some View {
        let fatta = min(1.0, max(0.0, model.breakElapsed / max(1, plan.duration)))
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.10))
                Capsule().fill(Palette.accent).frame(width: geo.size.width * fatta)
            }
        }
        .frame(height: p(5))
    }

    /// Il numero grande, il nome, l'istruzione. Su una tenuta il numero **scende**, come nello
    /// scudo: la logica è quella di `Hold`, letta qui a ogni ridisegno invece che contata a parte.
    @ViewBuilder
    private func corpo(_ plan: BreakPlan) -> some View {
        VStack(alignment: .leading, spacing: p(4)) {
            HStack(alignment: .firstTextBaseline, spacing: p(10)) {
                Text(numeroGrande(plan))
                    .font(.system(size: p(56), weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(model.exerciseDone ? Palette.accent : Palette.paper)
                if let sotto = sottotitoloDellaTenuta() {
                    Text(sotto)
                        .font(.system(size: p(12), weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.accent)
                }
            }
            Text(model.exerciseDone
                 ? L.t("Alzati e guarda lontano.", "Stand up and look far away.")
                 : plan.exercise.title)
                .font(.system(size: p(20), weight: .medium, design: .rounded))
                .foregroundStyle(Palette.paper)
                .fixedSize(horizontal: false, vertical: true)
            if !model.exerciseDone {
                Text(plan.exercise.kind.cue)
                    .font(.system(size: p(12)))
                    .foregroundStyle(Palette.dim)
                    // Tre righe: l'istruzione più lunga del corpus ci sta, e un'istruzione che
                    // cresce senza limite spingerebbe i pulsanti fuori dal pannello.
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func numeroGrande(_ plan: BreakPlan) -> String {
        guard !model.exerciseDone else { return orologio(model.secondsLeftOfBreak) }
        guard plan.exercise.kind.isTimed else { return "\(plan.exercise.displayReps)" }
        switch model.hold?.phase(at: Date()) {
        case .none, .done: return "\(plan.exercise.displayReps)"
        case .preparing(let manca), .switching(let manca): return "\(manca)"
        case .holding: return "\(model.hold?.secondsLeftOnCurrentSide(at: Date()) ?? 0)"
        }
    }

    /// Il cambio di lato si dice **prima** che arrivi, come nello scudo: quando arrivi sei a terra
    /// e non stai leggendo niente.
    private func sottotitoloDellaTenuta() -> String? {
        switch model.hold?.phase(at: Date()) {
        case .preparing: return L.t("preparati", "get ready")
        case .switching: return L.t("cambia lato", "switch sides")
        case .holding(let lato, _):
            guard model.plan?.exercise.kind.isPerSide == true else { return L.t("tieni", "hold") }
            return L.t("lato \(lato) di 2", "side \(lato) of 2")
        default: return nil
        }
    }

    /// Dove sei nel circuito, in pastiglie da dieci punti: fatte barrate, corrente accesa. È la
    /// stessa informazione della fila dello scudo, alla taglia di un pannello.
    private func striscia(_ plan: BreakPlan) -> some View {
        HStack(spacing: p(5)) {
            ForEach(Array(plan.circuit.enumerated()), id: \.offset) { indice, stazione in
                let fatta = indice < plan.stationIndex
                let corrente = indice == plan.stationIndex
                Text(stazione.kind.localizedName)
                    .font(.system(size: p(10), weight: corrente ? .semibold : .regular, design: .rounded))
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, p(7))
                    .padding(.vertical, p(3))
                    .foregroundStyle(corrente ? Palette.ink : Palette.paper.opacity(fatta ? 0.45 : 0.75))
                    .background(Capsule().fill(corrente ? Palette.accent : Color.white.opacity(fatta ? 0.04 : 0.08)))
                    .strikethrough(fatta, color: Palette.paper.opacity(0.4))
            }
        }
    }

    /// Le alternative, che vanno a capo **sulla larghezza vera** e non sul loro numero.
    ///
    /// **Qui il pannello si stacca da `VariantLayout.rows`, e l'ho scoperto in fotografia.** Quella
    /// regola è tarata sulla colonna dello scudo, larga 560-620 punti: fino a quattro alternative
    /// le tiene in fila, e in fila ci stanno. In 360 punti no — con i crunch, che ne offrono
    /// quattro, «sollevamento gambe» usciva dal bordo destro tagliato a metà (scatto del
    /// 2026-09-06). Un conteggio non può decidere un a capo quando le etichette hanno lunghezze
    /// diverse: a deciderlo è la larghezza, e per saperla bisogna misurarle.
    ///
    /// Il nucleo non si tocca: `rows` resta la regola dello scudo, dove è giusta.
    @ViewBuilder
    private var alternative: some View {
        let opzioni = model.variants
        if !opzioni.isEmpty, !model.exerciseDone {
            FilaCheVaACapo(spazioX: p(5), spazioY: p(5)) {
                ForEach(opzioni, id: \.kind) { opzione in
                    alternativa(opzione)
                }
            }
        }
    }

    /// **Si clicca tutto il rettangolo**: riempimento e sfondo stanno dentro l'etichetta, e
    /// `contentShape` dichiara la forma da colpire. Regola di casa, pagata due volte.
    private func alternativa(_ opzione: Exercise) -> some View {
        Button { model.swapExercise(to: opzione.kind) } label: {
            Text("\(opzione.kind.localizedName) \(opzione.displayReps)")
                .font(.system(size: p(10), weight: .medium, design: .rounded))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, p(8))
                .padding(.vertical, p(4))
                .foregroundStyle(Palette.paper.opacity(0.8))
                .background(Capsule().fill(Color.white.opacity(0.06)))
                .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// L'azione primaria, a tutta larghezza. Gli stati sono quelli dello scudo, nello stesso
    /// ordine, perché è lo stesso motore a risponderne: chiuso l'esercizio si torna al lavoro,
    /// su una tenuta si fa partire il conto, altrimenti si conferma.
    @ViewBuilder
    private func azione(_ plan: BreakPlan) -> some View {
        if model.exerciseDone {
            primario(L.t("Torna al lavoro", "Back to work"), acceso: model.canReturnToWork) {
                model.returnToWork()
            }
        } else if model.exerciseIsTimed, model.hold == nil {
            primario(L.t("Premi per iniziare — poi \(Int(Hold.prepareSeconds)) s per metterti in posizione",
                         "Press to start — then \(Int(Hold.prepareSeconds)) s to get into position"),
                     acceso: true) { model.startHold() }
        } else if model.hold != nil {
            primario(L.t("Interrompi il conto", "Stop the count"), acceso: true) { model.stopHold() }
        } else {
            // **Un pulsante spento senza una ragione accanto è indistinguibile da uno rotto**
            // (regola di casa, §5 delle app Mac). Nello scudo la riga c'è; qui il pulsante nasceva
            // grigio e muto, e la fotografia del 2026-09-06 lo mostra. Stesse parole dello scudo,
            // perché è lo stesso conto: il minimo di movimento, non il tempo della pausa.
            VStack(alignment: .leading, spacing: p(4)) {
                primario(model.moreStationsAhead ? L.t("Fatte tutte — avanti", "All done — next")
                                                 : L.t("Fatte tutte", "All done"),
                         acceso: model.canFinishNow) { model.markExerciseDone() }
                if !model.canFinishNow {
                    Text(L.t("ancora \(Int(model.secondsUntilCanFinish.rounded(.up))) s di movimento",
                             "\(Int(model.secondsUntilCanFinish.rounded(.up))) s of movement to go"))
                        .font(.system(size: p(11)))
                        .foregroundStyle(Palette.dim)
                        .monospacedDigit()
                }
            }
        }
    }

    private func primario(_ titolo: String, acceso: Bool, azione: @escaping () -> Void) -> some View {
        Button(action: azione) {
            Text(titolo)
                .font(.system(size: p(13), weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, p(12))
                .padding(.vertical, p(10))
                .frame(maxWidth: .infinity)
                .foregroundStyle(acceso ? Palette.ink : Palette.dim)
                .background(
                    RoundedRectangle(cornerRadius: p(10), style: .continuous)
                        .fill(acceso ? Palette.accent : Color.white.opacity(0.07))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!acceso)
    }

    /// Le due vie d'uscita, piccole e sotto: rinviare, e uscire dal circuito finché ha senso.
    ///
    /// **Non c'è l'uscita d'emergenza, e non è una dimenticanza.** Lo schermo non è coperto: se
    /// devi fare altro, fai altro — la pausa resta lì e non ti impedisce niente. L'emergenza
    /// esiste nello scudo perché lì l'unica alternativa sarebbe il tasto di accensione.
    @ViewBuilder
    private func viaDUscita(_ plan: BreakPlan) -> some View {
        HStack(spacing: p(12)) {
            // Le stesse parole dello scudo, per lo stesso gesto: lì «Non posso adesso» apre la frase
            // d'uscita e salta la pausa, e qui una frase non si può scrivere (il pannello non prende la
            // tastiera). Questo è un rinvio, e si chiama come il rinvio (madre, 2026-09-06).
            if model.canPostpone {
                minore(L.t("Rinvia 2 minuti", "Postpone 2 minutes")) { model.postpone() }
            }
            if model.engine.canLeaveCircuit {
                minore(L.t("Basta così", "That's enough")) { model.leaveCircuit() }
            }
            Spacer()
        }
    }

    private func minore(_ titolo: String, azione: @escaping () -> Void) -> some View {
        Button(action: azione) {
            Text(titolo)
                .font(.system(size: p(11)))
                .foregroundStyle(Palette.dim)
                .padding(.vertical, p(2))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func orologio(_ secondi: Double) -> String {
        let s = max(0, Int(secondi.rounded()))
        return String(format: "%d:%02d", s / 60, s % 60)   // lingua: ok formato numerico, non testo
    }
}
