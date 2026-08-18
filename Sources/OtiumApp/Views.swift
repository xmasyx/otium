import SwiftUI
import OtiumCore

extension Color {
    init(_ rgb: RGB) { self.init(red: rgb.r, green: rgb.g, blue: rgb.b) }
}

extension NSColor {
    convenience init(_ rgb: RGB) {
        self.init(srgbRed: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1)
    }

    /// Un colore che **si risolve al momento di disegnare**, non al momento di scriverlo.
    ///
    /// È la sola forma che segue l'aspetto di sistema da sola: se scegli il colore adesso,
    /// leggendo com'è il Mac in questo istante, la finestra resta di quel colore anche quando
    /// alle otto di sera macOS passa allo scuro da solo. Un colore dinamico invece viene
    /// richiesto di nuovo a ogni ridisegno, e cambia insieme a tutte le altre finestre.
    static func dual(_ chiaro: RGB, _ scuro: RGB) -> NSColor {
        NSColor(name: nil) { aspetto in
            aspetto.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(scuro) : NSColor(chiaro)
        }
    }
}

/// I colori in uso, presi dal tema scelto.
///
/// Statici e non iniettati per una ragione pratica: sono letti da decine di punti, e passarli
/// per parametro renderebbe illeggibile ogni vista. Cambiano quando cambi tema in preferenze,
/// e la schermata di blocco si costruisce a ogni pausa — quindi il colore nuovo si vede subito.
enum Palette {
    private(set) static var current: ThemePalette = ThemeName.alloro.palette

    /// Applica la livrea, nella variante giusta. In modalità Zen cambia **solo l'accento**, e la
    /// ragione sta scritta accanto ai colori, in `ThemeName.zenPalette`.
    static func apply(_ theme: ThemeName, zen: Bool = false) {
        current = zen ? theme.zenPalette : theme.palette
    }

    static var ink: Color { Color(current.ink) }
    static var paper: Color { Color(current.paper) }
    static var accent: Color { Color(current.accent) }
    /// L'accento **scuro**, quello che regge su carta bianca.
    static var accentOnLight: Color { Color(current.accentOnLight) }

    /// L'accento giusto per una finestra normale, che segue l'aspetto del sistema.
    ///
    /// Difetto segnalato il 2026-07-27 guardando le statistiche in modalità scura: le barre
    /// usavano `accentOnLight` sempre — un verde scuro nato per il fondo bianco — e su fondo
    /// scuro diventava fango. Non è una questione di gusto, è la variante sbagliata: la palette
    /// ha già `accent`, che è **la stessa tinta pensata per il buio** ed è quella della schermata
    /// di blocco. Qui si sceglie in base all'aspetto vivo, non a un'ipotesi scritta nel nome.
    static var accentOnWindow: Color {
        isDarkAppearance ? Color(current.accent) : Color(current.accentOnLight)
    }

    /// Il testo che sta **sopra** un riempimento d'accento.
    ///
    /// Non è sempre bianco: in chiaro l'accento è verde bosco e vuole testo bianco, in scuro è
    /// salvia chiara e il bianco sopra sparirebbe — lì serve il verde notte del fondo.
    static var onAccentOnWindow: Color {
        isDarkAppearance ? Color(current.ink) : .white
    }

    static var isDarkAppearance: Bool {
        NSApp?.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
    static var dim: Color { Color(current.dim) }

    // MARK: - Le finestre normali

    /// La faccia giusta per adesso: carta di giorno, inchiostro di sera.
    static var surface: SurfacePalette { isDarkAppearance ? Surface.sera : Surface.giorno }

    static var windowPaper: Color { Color(surface.paper) }
    static var windowEdge: Color { Color(surface.edge) }
    static var card: Color { Color(surface.card) }
    static var text: Color { Color(surface.text) }
    static var textDim: Color { Color(surface.dim) }
    static var rule: Color { Color(surface.rule) }

    /// La velatura dietro la voce scelta nella colonna. Più marcata di sera, perché il 13% di un
    /// colore chiaro su un fondo d'inchiostro è un'insinuazione, non una selezione.
    static var accentWash: Color {
        isDarkAppearance ? Color(current.accent).opacity(0.22)
                         : Color(current.accentOnLight).opacity(0.13)
    }

    /// Lo stesso fondo per AppKit, che le finestre le colora lui.
    static var windowPaperNS: NSColor { .dual(Surface.giorno.paper, Surface.sera.paper) }
}

extension View {
    /// La livrea addosso ai **controlli di sistema**.
    ///
    /// Interruttori, pulsanti predefiniti, link e stepper prendono l'accento del **Mac**, non
    /// quello dell'app: senza questa riga una finestra verde resta piena di blu, che è la cosa
    /// che si nota per prima. Va messa alla radice di ogni finestra, perché `tint` scende
    /// nell'ambiente e vale per tutto quello che c'è sotto.
    func livrea() -> some View { tint(Palette.accentOnWindow) }
}

// MARK: - La schermata di blocco

struct BreakView: View {
    @ObservedObject var model: AppModel
    @State private var showEscape = false
    @State private var escArmed = false
    /// Il pannellino «quante ne hai fatte», che compare solo quando dici «non tutte».
    @State private var partialSheet = false
    @State private var partialReps = 0
    @FocusState private var escapeFocused: Bool

    private var plan: BreakPlan? { model.plan }

    var body: some View {
        ZStack {
            Palette.ink.ignoresSafeArea()
            if let plan {
                // **La pausa ha due mestieri, e adesso ha due facce.**
                //
                // Finché devi muoverti la pagina parla solo dell'esercizio. Fatto quello restano
                // tre minuti e mezzo in cui la schermata era identica a prima, con un pulsante
                // spento che diceva «ancora 3:28»: tempo vuoto, e l'unico momento della giornata
                // in cui una frase la leggeresti davvero. Prima la citazione stava a metà della
                // colonna dell'esercizio, fra l'elenco del circuito e il cronometro, nello stesso
                // grigio di tutto il resto — settima di dodici cose impilate. Vista all'uso
                // il 2026-07-29 con le parole giuste: «lì sembra persa».
                // **Le due facce condividono lo scheletro, o cambiare faccia sembra cambiare app.**
                //
                // Intestazione in alto, contenuto al centro, comandi in basso — e la parte bassa
                // ha la **stessa altezza** in tutte e due, perché le fessure che valgono solo per
                // una (l'istruzione del riposo, il «Perché» dell'esercizio) tengono il loro spazio
                // anche quando sono vuote. Senza, il cronometro e i pulsanti saltavano di una
                // trentina di punti nel momento esatto della transizione, ed era la cosa che
                // rendeva netto un passaggio che deve essere una dissolvenza.
                VStack(spacing: 0) {
                    ZStack {
                        if plan.isZen { header(plan) }
                        else if model.exerciseDone { restHeader(plan) }
                        else { header(plan) }
                    }
                    // **Lo spazio sopra è limitato, quello sotto no.** Con due molle uguali il
                    // contenuto si centra, e nel riposo — dove la frase è corta — finiva un terzo
                    // più in basso del numero grande dell'esercizio: nella dissolvenza il punto
                    // dove guardi saltava giù di centoventi punti. Bloccando la molla di sopra il
                    // baricentro delle due facce coincide, e in fase 1 non cambia niente perché
                    // lì il contenuto è alto e la molla è già schiacciata.
                    // **In Zen la molla di sopra si chiude quasi del tutto.** L'alone è grande il
                    // doppio su richiesta sua, e con i 140 punti dell'altra faccia la colonna
                    // usciva dallo schermo da tutte e due le parti: sopra spariva l'intestazione,
                    // sotto le vie d'uscita. Visto nella fotografia, che è l'unico posto dove una
                    // colonna troppo alta si vede.
                    Spacer(minLength: 8).frame(maxHeight: plan.isZen && !model.exerciseDone ? 8 : 140)
                    // Il crossfade: le due facce si scambiano dentro la stessa `ZStack`, quindi
                    // una sfuma mentre l'altra compare invece di sostituirla di scatto.
                    ZStack {
                        // In Zen la faccia è una sola e dura tutta la pausa: il respiro finisce
                        // nell'istante in cui il pulsante si accende, quindi non c'è una seconda
                        // faccia da mostrare — la frase sta già dentro la prima.
                        // **Finito il respiro torna la faccia del riposo.** Da quando il respiro
                        // guidato non riempie più tutta la pausa (2026-08-08), quello che avanza è
                        // riposo vero, con la frase grande: tenere l'alone spento a schermo per
                        // tre minuti direbbe «stai ancora facendo qualcosa», e non è vero.
                        if let respiro = plan.breath, !model.exerciseDone {
                            breathBody(plan, respiro)
                        } else if model.exerciseDone {
                            restBody.transition(.opacity.combined(with: .offset(y: 10)))
                        } else {
                            exercise(plan).transition(.opacity.combined(with: .offset(y: -10)))
                        }
                    }
                    Spacer(minLength: 8)
                    controls(plan)
                    footer
                }
                .padding(48)
                // Legata alla sola `exerciseDone`: il cronometro cambia ogni secondo e non deve
                // trascinarsi dietro nessuna animazione.
                .animation(.easeInOut(duration: 0.6), value: model.exerciseDone)
            } else {
                // **Terza rete, e la più semplice: una schermata senza pausa non è nera muta.**
                //
                // Con le due reti a monte questo stato dura al massimo due secondi. Ma è lo stato
                // che il 27 e il 28 luglio 2026 è costato due riavvii forzati, e allora l'`if let`
                // senza `else` disegnava esattamente niente: uno schermo nero che non dice cosa
                // sia, non dice come uscirne, e non si distingue da un Mac morto. Se un domani
                // entrambe le reti a monte fallissero, qui c'è comunque una via d'uscita visibile.
                VStack(spacing: 16) {
                    Text(L.t("La pausa è finita.", "The break is over."))
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.paper)
                    Text(L.t("Lo schermo si sta liberando. Se resta qui, premi il pulsante.",
                             "The screen is clearing. If it stays here, press the button."))
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.dim)
                    // Il pulsante grande, non quello discreto: questa è l'ultima uscita prima del
                    // tasto di accensione, e un'uscita d'emergenza si deve **vedere da lontano**.
                    primary(L.t("Sblocca lo schermo", "Unlock the screen"), enabled: true) { model.emergencyExit() }
                    Text(L.t("Puoi anche premere Esc due volte.", "You can also press Esc twice."))
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.dim)
                }
                .padding(48)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay { if partialSheet, let plan { partialPanel(plan) } }
        .onReceive(NotificationCenter.default.publisher(for: .otiumEscapePressed)) { _ in
            if escArmed {
                model.emergencyExit()
                escArmed = false
            } else {
                escArmed = true
                // L'innesco scade: se hai premuto Esc per sbaglio e poi fai gli squat, non
                // vuoi che il prossimo Esc distratto ti butti fuori.
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) { escArmed = false }
            }
        }
    }

    /// «Quante ne hai fatte?» — parte dal numero chiesto meno uno, perché chi dice «non tutte»
    /// quasi sempre ne ha fatte quasi tutte, e il caso più probabile deve costare zero clic.
    private func partialPanel(_ plan: BreakPlan) -> some View {
        ZStack {
            Palette.ink.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 18) {
                Text(L.t("Quante ne hai fatte?", "How many did you do?"))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.paper)
                Text(L.t("Contano lo stesso. Serve a non chiederti la prossima volta più di quanto riesci.",
                         "They count all the same. It's so we don't ask you for more than you can do next time."))
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.dim)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)

                HStack(spacing: 22) {
                    stepperButton("minus") { partialReps = max(0, partialReps - 1) }
                    Text("\(partialReps)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Palette.accent)
                        .frame(minWidth: 110)
                    stepperButton("plus") { partialReps = min(plan.exercise.reps, partialReps + 1) }
                }

                HStack(spacing: 14) {
                    SecondaryButton(title: L.t("Annulla", "Cancel"), systemImage: "xmark") {
                        partialSheet = false
                    }
                    primary(L.t("Conferma", "Confirm"), enabled: true) {
                        model.markExercisePartial(reps: partialReps)
                        partialSheet = false
                    }
                }
            }
            .padding(40)
        }
        .onAppear { partialReps = max(0, plan.exercise.reps - 1) }
    }

    /// **Un pulsante che è solo un'icona non ha nome**, e per VoiceOver diventa «pulsante» e
    /// basta: due tondi identici, uno che aggiunge e uno che toglie, indistinguibili a voce.
    /// Trovato nell'audit del 2026-07-29 — l'unico controllo dell'app in quella condizione.
    private func stepperButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .accessibilityLabel(symbol == "plus" ? L.t("una in più", "one more")
                                                     : L.t("una in meno", "one less"))
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 48, height: 48)
                .foregroundStyle(Palette.paper)
                .background(Circle().fill(Color.white.opacity(0.10)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    /// **Quanto dura questa pausa, non come la chiamiamo noi** (2026-08-19, sua richiesta
    /// guardando il circuito).
    ///
    /// «PAUSA PIENA» è una categoria del motore: dice a quale ramo appartiene la pausa, che è
    /// una cosa che interessa a chi l'ha scritta. Mentre la pausa la stai facendo, l'unica cosa
    /// che vuoi sapere in alto a sinistra è quanto dura. Il numero viene da `plan.duration` e
    /// non dalle preferenze lette adesso, per la stessa ragione per cui ci sta l'esercizio: il
    /// piano è la fotografia di cosa ti è stato chiesto, e cambiare impostazione a metà pausa
    /// non deve riscrivere la pausa in corso.
    private static func durationLabel(_ plan: BreakPlan) -> String {
        let minuti = max(1, Int((plan.duration / 60).rounded()))
        return L.t("PAUSA \(minuti)'", "BREAK \(minuti)'")
    }

    private func header(_ plan: BreakPlan) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text(plan.isZen
                     ? L.t("PAUSA ZEN", "ZEN BREAK")
                     : (plan.kind == .long ? Self.durationLabel(plan) : L.t("MICRO-PAUSA", "MICRO-BREAK")))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(Palette.accent)
                Spacer()
                Text(todayBadge(plan))
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Palette.dim)
            }
            // Se ti interrompo perché credo che tu sia fermo davanti allo schermo, ti dico
            // esattamente cosa ho riconosciuto. Un'app che agisce su una deduzione e non la
            // mostra è un'app a cui non puoi dare torto.
            if let presence = model.engine.lastPresence {
                HStack(spacing: 8) {
                    Image(systemName: Self.presenceIcon(presence.kind))
                        .foregroundStyle(Palette.dim)
                    Text(Self.presenceLabel(presence))
                        .foregroundStyle(Palette.dim)
                    Spacer()
                }
                .font(.system(size: 12))
            }
        }
    }

    /// **Uno `switch` esaustivo, non un ternario.** Con due soli rami `.call` diceva «fermo su un
    /// documento» mentre eri al telefono, e `.terminal` avrebbe ereditato in silenzio la stessa
    /// frase sbagliata. Così il compilatore obbliga chi aggiunge un tipo a scriverne la riga.
    static func presenceIcon(_ kind: PresenceKind) -> String {
        switch kind {
        case .media: return "play.rectangle"
        case .reading: return "doc.text"
        case .terminal: return "terminal"
        case .call: return "phone"
        }
    }

    static func presenceLabel(_ presence: PresenceSignal) -> String {
        let detail = presence.detail
        switch presence.kind {
        case .media:
            return L.t("fermo davanti a un video: \(detail)", "still, watching a video: \(detail)")
        case .reading:
            return L.t("fermo su un documento: \(detail)", "still, on a document: \(detail)")
        case .terminal:
            return L.t("fermo a leggere l'output: \(detail)", "still, reading output: \(detail)")
        case .call:
            return L.t("in conversazione: \(detail)", "on a call: \(detail)")
        }
    }

    private func exercise(_ plan: BreakPlan) -> some View {
        VStack(spacing: 20) {
            if plan.circuitActive { circuitTrack(plan) }
            // Il numero grande è quello **da eseguire adesso**: per gli esercizi a lati alterni è
            // il per lato, non il totale. Su una tenuta invece il numero grande **scende**, e chi
            // lo fa scendere è `holdFace`.
            if plan.exercise.kind.isTimed {
                holdFace(plan)
            } else {
                Text("\(plan.exercise.displayReps)")
                    .font(.system(size: 140, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.paper)
                    .monospacedDigit()
            }
            // Per una tenuta il numero grande è in secondi: senza l'unità, «45 plank» si legge
            // come quarantacinque plank.
            Text(plan.exercise.title)
                .font(.system(size: 44, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.paper)
                .multilineTextAlignment(.center)
            Text(plan.exercise.kind.cue)
                .font(.system(size: 17))
                .foregroundStyle(Palette.dim)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 560)
                // Senza, la riga delle varianti le ruba spazio e l'istruzione finisce troncata
                // a metà parola: il testo deve poter crescere in altezza, non accorciarsi.
                .fixedSize(horizontal: false, vertical: true)

            // **Il cambio di lato si dice PRIMA**, non quando arriva: è la correzione che ha
            // chiesto lui, e in plank laterale è la sola cosa che non puoi scoprire dopo, perché
            // quando arriva sei sotto e non guardi niente.
            if plan.exercise.kind.isTimed, model.hold == nil {
                Text(plan.exercise.kind.isPerSide
                     ? L.t("\(plan.exercise.displayReps) s per lato. Due tocchi ti avvisano \(Int(Hold.switchWarningSeconds)) s prima del cambio, poi hai \(Int(Hold.switchPrepareSeconds)) s per girarti, e un suono diverso chiude.",
                           "\(plan.exercise.displayReps) s per side. Two taps warn you \(Int(Hold.switchWarningSeconds)) s before the switch, then you get \(Int(Hold.switchPrepareSeconds)) s to turn over, and a different sound ends it.")
                     : L.t("Il tempo scende da solo e un suono chiude, non devi guardare lo schermo.",
                           "The time counts down on its own and a sound ends it: you do not have to watch the screen."))
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.accent.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Mentre il conto gira le alternative spariscono: sei a terra, non stai scegliendo.
            if model.hold == nil {
                variantRow(singleLine: plan.circuitActive)
                circuitOffer(plan)
            }
        }
    }

    // MARK: - La faccia della modalità Zen

    /// **La pausa che si può fare in un open space**: un respiro guidato al posto dell'esercizio.
    ///
    /// Chiesta il 2026-08-08. Tiene lo stesso scheletro dell'altra faccia — intestazione, contenuto
    /// al centro, comandi in basso — perché cambiare modalità non deve sembrare cambiare app.
    ///
    /// **La frase sta QUI dentro, e non nel riposo che viene dopo.** È l'unica scelta possibile una
    /// volta deciso che il respiro dura tutta la pausa: la faccia del riposo, in Zen, comparirebbe
    /// nell'istante esatto in cui il pulsante si accende, cioè verrebbe letta da nessuno. E in una
    /// schermata che chiede di rallentare, una riga da leggere è esattamente ciò che serve agli
    /// occhi mentre il resto del corpo non fa niente.
    private func breathBody(_ plan: BreakPlan, _ protocollo: BreathProtocol) -> some View {
        VStack(spacing: 26) {
            breathCircle(protocollo)
            // **La stessa `QuoteBlock` dell'altra faccia, non una copia.** Così i tagli di riga di
            // questa schermata li governa la stessa colonna che il cancello `--tagli` misura: una
            // colonna nuova qui sarebbe una superficie senza guardia.
            eyesClosedHint
            if let phrase = model.currentPhrase {
                QuoteBlock(phrase: phrase)
            }
            Text(breathFooterLine(plan, protocollo))
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Palette.dim)
                .monospacedDigit()
        }
    }

    /// **L'invito a chiudere gli occhi, e solo per i primi respiri.**
    ///
    /// Sua richiesta del 2026-08-08: *«invitiamo a farlo poi con gli occhi chiusi quando
    /// possibile»*. Il «poi» è la parte che conta e detta il momento: l'alone esiste per guidare
    /// chi guarda, quindi l'invito arriva **dopo** che il ritmo l'hai preso, non subito. Dal terzo
    /// respiro in avanti, e poi sparisce da solo: una riga che resta a schermo per cinque minuti
    /// smette di essere un invito e diventa arredamento.
    @ViewBuilder
    private var eyesClosedHint: some View {
        let ciclo: Int = {
            guard case .breathing(_, _, _, _, let n)? = model.breath?.phase(at: Date()) else { return 0 }
            return n
        }()
        ZStack {
            if ciclo >= 3, ciclo <= 6 {
                Text(L.t("Se puoi, da qui in poi chiudi gli occhi. Il ritmo ce l'hai.",
                         "From here on close your eyes if you can. You have the rhythm."))
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Palette.accent.opacity(0.85))
                    .transition(.opacity)
            }
        }
        // Altezza riservata, come le tre fessure dei comandi: comparendo e sparendo dentro uno
        // spazio suo non sposta di diciassette punti tutto quello che ha sotto.
        .frame(height: 17)
        .animation(.easeInOut(duration: 0.8), value: ciclo >= 3 && ciclo <= 6)
    }

    /// Il cerchio che si gonfia e si sgonfia, e la parola dentro.
    ///
    /// **Il ritmo lo dà l'occhio, non l'orecchio**: un suono a ogni cambio di passo vorrebbe dire
    /// cento suoni in cinque minuti, in ufficio, che è il posto dove questa modalità serve. Vedi la
    /// nota su `Breath.Cue`.
    @ViewBuilder
    private func breathCircle(_ protocollo: BreathProtocol) -> some View {
        let now = Date()
        // **Il respiro quadrato ha un disegno suo, e non è un vezzo.** Ho mandato la
        // sua animazione a parte, il 2026-08-08, e aveva ragione a distinguerla: una sfera che
        // pulsa non sa mostrare i due «trattieni», perché in quei quattro secondi non succede
        // niente e l'animazione si ferma. Il quadrato invece li mostra come lati, e i quattro tempi
        // uguali diventano quattro segmenti uguali, che è la cosa che quel protocollo ti chiede di
        // sentire. È anche la risposta alla sua richiesta iniziale: *«la differenza di movimento in
        // base all'esercizio scelto»*.
        switch model.breath?.phase(at: now) {
        case .none:
            // Il respiro è fermo: o non è ancora partito, o l'hai interrotto tu. Il disegno resta
            // al minimo invece di sparire, o la pagina si accorcia di trecento punti e i comandi in
            // basso saltano su.
            // **Niente parola** (sua richiesta, 2026-08-08). A respiro fermo non c'è niente da
            // fare, e una scritta al centro di un alone spento sembra un messaggio di errore.
            breathShape(protocollo, scale: 0.62, sideIndex: 0, sideProgress: 0, label: "", sub: "")

        case .preparing(let left):
            breathShape(protocollo, scale: 0.62, sideIndex: 0, sideProgress: 0,
                        label: L.t("Mettiti comodo", "Get comfortable"), sub: "\(left)")

        case .breathing(let step, let indice, let left, let progress, _):
            breathShape(protocollo,
                        scale: breathScale(step: step, stepIndex: indice, progress: progress),
                        sideIndex: indice,
                        sideProgress: progress,
                        label: step.localizedName,
                        sub: "\(left)")

        case .done:
            // Finito: resta l'alone al minimo, muto. Che sia finito lo dice il pulsante che si
            // accende, non una parola in mezzo allo schermo.
            breathShape(protocollo, scale: 0.62, sideIndex: 3, sideProgress: 1, label: "", sub: "")
        }
    }

    /// Quale delle due forme disegnare: il quadrato per il box breathing, l'alone per gli altri.
    @ViewBuilder
    private func breathShape(_ protocollo: BreathProtocol, scale: Double,
                             sideIndex: Int, sideProgress: Double,
                             label: String, sub: String) -> some View {
        if protocollo == .quadrato {
            squareShape(scale: scale, sideIndex: sideIndex, sideProgress: sideProgress,
                        label: label, sub: sub)
        } else {
            circleShape(scale: scale, label: label, sub: sub)
        }
    }

    /// **Il quadrato del box breathing**: un lato per tempo, e la linea che lo percorre.
    ///
    /// Il giro è quello del riferimento che ha mandato lui: il tratto luminoso sale lungo il lato
    /// **alto** mentre inspiri, scende lungo il **destro** mentre trattieni, torna indietro sul
    /// **basso** mentre espiri e risale sul **sinistro** nel secondo trattenimento. Alla fine del
    /// giro il quadrato è chiuso, e ricomincia.
    ///
    /// I lati già percorsi restano accesi, quello in corso si disegna: senza la memoria dei lati
    /// fatti, a metà del terzo tempo il quadrato sarebbe un trattino solo e non si capirebbe più a
    /// che punto del giro sei.
    /// **Stessa luce degli altri due, geometria diversa** (sua correzione, 2026-08-08: *«anche il
    /// box breath deve avere lo stesso stile e colore degli altri»*). Il quadrato disegnato con una
    /// linea sottile e netta era corretto e fuori posto: nella stessa app, a due clic di distanza,
    /// sembravano due prodotti. Qui sotto c'è **lo stesso alone** dell'altra faccia, che respira con
    /// il ciclo, e il tratto che percorre i lati è morbido e con il suo bagliore invece che una
    /// riga da diagramma. La geometria resta quadrata perché è quella a mostrare i quattro tempi.
    private func squareShape(scale: Double, sideIndex: Int, sideProgress: Double,
                             label: String, sub: String) -> some View {
        let lato: CGFloat = 320
        let pienezza = min(1, max(0, (scale - 0.62) / 0.38))
        return ZStack {
            // L'alone, identico a quello del respiro ciclico: è ciò che rende le due facce la
            // stessa app. Non sale e non scende, però — qui la quota la racconta già il lato che si
            // sta percorrendo, e due movimenti insieme si darebbero fastidio.
            RadialGradient(
                colors: [
                    Palette.ink.opacity(0.95),
                    Palette.accent.opacity(0.26 + 0.26 * pienezza),
                    Palette.accent.opacity(0.12 + 0.14 * pienezza),
                    Palette.accent.opacity(0),
                ],
                center: .center,
                startRadius: 6,
                endRadius: 168
            )
            .frame(width: 470, height: 470)
            .scaleEffect(0.86 + 0.18 * pienezza)
            .blur(radius: 16)

            // Il binario spento: dice dov'è il giro anche quando è appena cominciato.
            //
            // **`stroke` e non `strokeBorder`**, ed è la differenza fra due lati allineati e due
            // lati sfalsati di un punto e mezzo: `strokeBorder` rientra di mezza linea, i lati qui
            // sotto no, e nella fotografia il tratto acceso correva accanto al suo binario invece
            // che dentro. Visto solo nell'immagine, come sempre per queste cose.
            // Angoli vivi e non arrotondati: i quattro lati che si accendono sono segmenti dritti,
            // e un binario stondato sotto a un tratto dritto si vede subito che sono due disegni
            // diversi. La morbidezza la porta il bagliore, non il raggio.
            Rectangle()
                .stroke(Palette.accent.opacity(0.13), lineWidth: 2)
                .frame(width: lato, height: lato)

            // Il tratto vivo, disegnato due volte: una copia larga e sfocata fa il bagliore, quella
            // sopra tiene la linea leggibile. È lo stesso trucco dell'alone, ed è il motivo per cui
            // le due facce ora si somigliano davvero invece di condividere solo il colore.
            ForEach(0..<4, id: \.self) { i in
                let quanto = i < sideIndex ? 1.0 : (i == sideIndex ? sideProgress : 0.0)
                ZStack {
                    // **Testa piatta e non tonda sul bagliore.** Un capo tondo sporge di mezza
                    // linea oltre il suo estremo: su un tratto da dieci punti fanno cinque punti
                    // fuori da ogni angolo, e nella fotografia i lati accesi uscivano dal quadrato
                    // come quattro spilli. Sul tratto sottile sopra la sporgenza è un punto e mezzo
                    // e serve, perché è quella che dà la punta morbida al lato in corso.
                    SquareSide(index: i)
                        .trim(from: 0, to: quanto)
                        .stroke(Palette.accent.opacity(0.5),
                                style: StrokeStyle(lineWidth: 9, lineCap: .butt))
                        .blur(radius: 7)
                    SquareSide(index: i)
                        .trim(from: 0, to: quanto)
                        .stroke(Palette.accent.opacity(0.9),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }
                .frame(width: lato, height: lato)
            }

            VStack(spacing: 6) {
                Text(label.uppercased())
                    .font(.system(size: 26, weight: .medium, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(Palette.paper.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: 380)
                if !sub.isEmpty {
                    Text(sub)
                        .font(.system(size: 64, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Palette.accent)
                }
            }
        }
        .frame(height: 400)
        .animation(.linear(duration: 0.1), value: sideProgress)
    }

    /// Quanto è grande il cerchio adesso.
    ///
    /// Fra 0,62 e 1: sotto sembra un punto e sopra tocca i bordi della colonna. Cresce inspirando,
    /// resta fermo trattenendo, cala espirando. **La seconda inspirazione corta del sospiro parte da
    /// dove era arrivata la prima**, invece di ripartire dal basso, o l'animazione racconterebbe
    /// un respiro buttato via e ripreso da capo, che è il contrario di quello che stai facendo.
    /// **I due trattenimenti non sono lo stesso trattenimento.** Nel respiro quadrato si trattiene
    /// da pieni dopo l'inspirazione e da vuoti dopo l'espirazione: tenere l'alone al massimo in
    /// tutti e due i casi racconterebbe polmoni pieni mentre li hai vuoti. La distinzione la porta
    /// `stepIndex`, che è la stessa ragione per cui esiste (vedi `Breath.Phase`).
    private func breathScale(step: BreathProtocol.Step, stepIndex: Int, progress: Double) -> Double {
        let minimo = 0.62, massimo = 1.0
        switch step.action {
        case .inspira:   return minimo + (massimo - minimo) * 0.82 * progress
        case .ancora:    return minimo + (massimo - minimo) * (0.82 + 0.18 * progress)
        case .trattieni: return stepIndex <= 1 ? massimo : minimo
        case .pausa:     return minimo
        case .espira:    return massimo - (massimo - minimo) * progress
        }
    }

    /// **L'alone che respira**: sale e si illumina inspirando, scende e si spegne espirando.
    ///
    /// Nasce da tredici registrazioni di respiro fatte il
    /// 2026-08-08, e soprattutto dallo screenshot che le riassume: un alone radiale con il cuore
    /// scuro, la corona luminosa e **una parola sola al centro**. In nessuno dei riferimenti c'è un
    /// bordo netto, e infatti il cerchio con il contorno che c'era prima si leggeva come un anello
    /// di caricamento, cioè la cosa opposta a quella che deve dire.
    ///
    /// **Tre cose si muovono insieme, e sono tre perché lui le ha chieste tutte e tre**: la
    /// dimensione, la luce (*«una sfera che si illumina»*) e la quota (*«mentre sale inspirando…
    /// e discende durante l'espirazione»*). Muoverne una sola dà un'animazione corretta e morta;
    /// muoverle insieme è ciò che si segue con la coda dell'occhio, che è il punto: la guida serve
    /// a chi tiene gli occhi aperti, e dopo qualche ciclo si chiudono.
    ///
    /// **Il colore resta quello della livrea**, non l'arancione e il viola dei riferimenti: quelli
    /// sono pin a tutto schermo su fondo bianco, qui è una stanza buia, e la regola di famiglia dice
    /// che a cambiare è l'accento. La forma si prende, la tavolozza no.
    private func circleShape(scale: Double, label: String, sub: String) -> some View {
        // Quanto è "pieno" il respiro adesso, da 0 a 1: serve tre volte qui sotto, e ricavarlo tre
        // volte dalla scala sarebbe la stessa formula scritta in tre punti.
        let pienezza = min(1, max(0, (scale - 0.62) / 0.38))
        // La quota: in alto quando è pieno, in basso quando è vuoto. Ventidue punti in tutto, che a
        // occhio è un respiro e non un salto.
        let quota = 11 - pienezza * 22
        return ZStack {
            RadialGradient(
                colors: [
                    // Il cuore **più scuro del fondo**: è quello che nello screenshot fa sembrare
                    // la sfera piena invece che disegnata.
                    Palette.ink.opacity(0.95),
                    Palette.accent.opacity(0.30 + 0.32 * pienezza),
                    Palette.accent.opacity(0.14 + 0.16 * pienezza),
                    Palette.accent.opacity(0),
                ],
                center: .center,
                startRadius: 10,
                endRadius: 232
            )
            .frame(width: 470, height: 470)
            .scaleEffect(scale)
            .blur(radius: 16)
            .offset(y: quota)

            VStack(spacing: 6) {
                // Maiuscoletto spaziato, come nell'unico riferimento che guida davvero: una parola
                // al centro di un alone va vista in un colpo, non letta.
                Text(label.uppercased())
                    .font(.system(size: 26, weight: .medium, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(Palette.paper.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: 460)
                if !sub.isEmpty {
                    Text(sub)
                        .font(.system(size: 64, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Palette.accent)
                }
            }
            .offset(y: quota)
        }
        .frame(height: 400)
        // Si muove da sola a ogni ridisegno, dieci volte al secondo: l'animazione serve solo a
        // smussare i decimi, quindi è corta quanto il battito. Più lunga e l'alone resterebbe
        // indietro rispetto alla parola, che è la cosa che stai seguendo.
        .animation(.linear(duration: 0.1), value: scale)
    }

    /// La riga sotto: a che respiro sei, e quanti ne restano. Il tempo lo dice il cronometro qui
    /// sotto, quindi qui non si ripete.
    private func breathFooterLine(_ plan: BreakPlan, _ protocollo: BreathProtocol) -> String {
        let totali = model.breath?.plannedCycles ?? 0
        guard case .breathing(_, _, _, _, let ciclo)? = model.breath?.phase(at: Date()) else {
            return L.t("\(protocollo.localizedName) · \(protocollo.breathsPerMinute) respiri al minuto",
                       "\(protocollo.localizedName) · \(protocollo.breathsPerMinute) breaths a minute")
        }
        return L.t("respiro \(min(ciclo, totali)) di \(totali) · \(protocollo.localizedName)",
                   "breath \(min(ciclo, totali)) of \(totali) · \(protocollo.localizedName)")
    }

    /// **Il numero grande di una tenuta, che scende.**
    ///
    /// Nasce da una frase sua del 2026-07-31: *«45 secondi di plank, vorrei che il tempo vada
    /// all'indietro così so quanto devo tenere. Non lo posso far partire perché sono già giù»*.
    /// Da lì i tre stati: prima premi, poi hai cinque secondi per scendere, poi conta da solo e
    /// alla fine si segna da solo.
    ///
    /// Il numero non arriva da un contatore che scala: arriva dall'orologio, a ogni ridisegno.
    /// Vedi `Hold`, che è il posto dove questa cosa è provata.
    @ViewBuilder
    private func holdFace(_ plan: BreakPlan) -> some View {
        let now = Date()
        switch model.hold?.phase(at: now) {
        case .none:
            // Fermo: il numero è la promessa, e sotto continua a leggersi «secondi di plank». Il
            // pulsante sta in fondo, dove stanno tutti i pulsanti grandi: messo qui spezzava la
            // frase in due, e si leggeva «25 — Pronto — secondi di plank».
            Text("\(plan.exercise.displayReps)")
                .font(.system(size: 140, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.paper)
                .monospacedDigit()

        case .preparing(let left):
            VStack(spacing: 10) {
                Text("\(left)")
                    .font(.system(size: 140, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.accent)
                    .monospacedDigit()
                Text(L.t("preparati", "get ready"))
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.dim)
                    .tracking(2)
            }

        case .holding(let side, _):
            // Il numero è quello del **lato in corso**: il totale che scende da 40 non dice
            // quando girarti, e girarsi è la cosa che devi sapere.
            let left = model.hold?.secondsLeftOnCurrentSide(at: now) ?? 0
            let mancaPoco = plan.exercise.kind.isPerSide && side == 1
                && Double(left) <= Hold.switchWarningSeconds
            VStack(spacing: 10) {
                Text("\(left)")
                    .font(.system(size: 140, weight: .bold, design: .rounded))
                    .foregroundStyle(mancaPoco ? Palette.accent : Palette.paper)
                    .monospacedDigit()
                if plan.exercise.kind.isPerSide {
                    Text(mancaPoco
                         ? L.t("cambia lato fra \(left)", "switch sides in \(left)")
                         : L.t("lato \(side) di 2 — tieni la posizione", "side \(side) of 2 — hold"))
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(mancaPoco ? Palette.accent : Palette.dim)
                } else {
                    Text(L.t("tieni la posizione", "hold"))
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.dim)
                        .tracking(2)
                }
            }

        case .switching(let left):
            // **Il cambio di lato ha la faccia della preparazione, ed è voluto.** È la stessa cosa
            // che stai facendo — ti stai mettendo in posizione — e riconoscerla senza leggerla è
            // il punto: da terra, girato, quello che ti arriva è il colore e un numero che scende.
            VStack(spacing: 10) {
                Text("\(left)")
                    .font(.system(size: 140, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.accent)
                    .monospacedDigit()
                Text(L.t("cambia lato", "switch sides"))
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.accent)
                    .tracking(2)
            }

        case .done:
            // Stato di passaggio: il battito che vede la fine segna l'esercizio e cambia faccia.
            EmptyView()
        }
    }

    /// La proposta del giro completo, dentro la pausa piena.
    ///
    /// Sta qui e non nelle preferenze perché è una decisione che dipende da come stai **adesso**:
    /// alcune pause piene meritano quattro esercizi, altre no, e chiedertelo a freddo una volta
    /// per tutte darebbe la risposta sbagliata quasi sempre. Il default resta l'esercizio singolo:
    /// il circuito è un sì che devi dare tu.
    @ViewBuilder
    private func circuitOffer(_ plan: BreakPlan) -> some View {
        if model.canStartCircuit {
            VStack(spacing: 8) {
                Button { model.startCircuit() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "figure.strengthtraining.functional").font(.system(size: 13))
                        Text(L.t("Fai il microcircuito — \(plan.circuit.count) esercizi", "Do the circuit — \(plan.circuit.count) exercises"))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 11)
                    .foregroundStyle(Palette.paper)
                    .background(Capsule().fill(Palette.accent.opacity(0.22)))
                    .overlay(Capsule().stroke(Palette.accent.opacity(0.55), lineWidth: 1))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)

                Text(plan.circuit.map(\.label).joined(separator: " · "))
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.dim)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 620)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 10)
        }
    }

    /// Dove sei dentro il circuito: quattro pallini con la stazione in corso accesa.
    private func circuitTrack(_ plan: BreakPlan) -> some View {
        VStack(spacing: 10) {
            Text(L.t("CIRCUITO · STAZIONE \(plan.stationIndex + 1) DI \(plan.circuit.count)", "CIRCUIT · STATION \(plan.stationIndex + 1) OF \(plan.circuit.count)"))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .tracking(1.8)
                .foregroundStyle(Palette.accent)

            HStack(spacing: 10) {
                ForEach(Array(plan.circuit.enumerated()), id: \.offset) { index, station in
                    let done = index < plan.stationIndex
                    let current = index == plan.stationIndex
                    Text(station.kind.localizedName)
                        .font(.system(size: 12, weight: current ? .semibold : .regular, design: .rounded))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .foregroundStyle(current ? Palette.ink : Palette.paper.opacity(done ? 0.45 : 0.75))
                        .background(
                            Capsule().fill(current ? Palette.accent : Color.white.opacity(done ? 0.04 : 0.08))
                        )
                        .overlay(
                            Capsule().stroke(Color.white.opacity(current ? 0 : 0.14), lineWidth: 1)
                        )
                        .strikethrough(done, color: Palette.paper.opacity(0.4))
                }
            }
        }
    }

    /// L'intestazione della fase di riposo: cosa hai appena finito, e il conto della giornata.
    ///
    /// Prende il posto di «PAUSA PIENA», che a esercizio fatto risponde a una domanda scaduta.
    private func restHeader(_ plan: BreakPlan) -> some View {
        HStack {
            HStack(spacing: 7) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 13))
                Text(doneLabel(plan))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(Palette.accent)
            Spacer()
            Text(todayBadge(plan))
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Palette.dim)
        }
    }

    /// **Sul circuito il piano tiene l'esercizio *corrente*, che alla fine è l'ultimo.** Dirlo qui
    /// nominerebbe un quarto del lavoro fatto: è lo stesso difetto già corretto nella notifica di
    /// fine pausa il 2026-07-28, e questa riga nasce dopo, quindi non ha scuse per ripeterlo.
    /// La riga in alto a destra: dove sei nella giornata.
    ///
    /// **Due numeri accanto devono parlare dello stesso periodo.** Qui c'era `plan.index`, che è
    /// il contatore di sempre — serve alla rotazione degli esercizi, non a te — messo accanto
    /// alle ripetizioni **di oggi**: si leggeva «sessanta pause oggi», e non erano sessanta.
    /// Visto all'uso il 2026-07-28, quando il numero era 60 e le pause della giornata
    /// due.
    ///
    /// **Il conto dell'esercizio in corso sta davanti al totale** (2026-07-31, sua richiesta).
    /// «112 ripetizioni» è il volume della giornata e non risponde alla domanda che ti fai mentre
    /// sei lì: *quanti squat ho fatto oggi?* Il totale resta, ma dopo — e non e' il numero grande
    /// al centro dello schermo, che sono le ripetizioni **di adesso**: quello sarebbe lo stesso
    /// numero due volte, cioè il difetto chiuso a luglio col pulsante che diceva l'orario.
    ///
    /// Quando l'esercizio non è ancora uscito oggi, il pezzo di mezzo sparisce invece di dire
    /// «0 squat»: uno zero occupa lo spazio di un'informazione senza esserlo.
    private func todayBadge(_ plan: BreakPlan) -> String {
        let pausa = model.summary.completed + model.summary.natural + 1
        // **In Zen il conto delle ripetizioni non c'entra niente**, ed è la stessa ragione per cui
        // il registro non le scrive: quelle ripetizioni non le ha fatte nessuno. Qui si dice quante
        // pause di respiro hai fatto oggi, che è l'unico numero vero di questa modalità.
        if plan.isZen {
            let respiri = model.summary.zenBreaks
            guard respiri > 0 else {
                return L.t("oggi: \(pausa)ª pausa", "today: break #\(pausa)")
            }
            return L.t("oggi: \(pausa)ª pausa · \(respiri) di respiro",
                       "today: break #\(pausa) · \(respiri) breathing")
        }
        let kind = plan.exercise.kind
        let suoi = model.summary.repsByExercise[kind] ?? 0
        let totale = model.summary.totalReps
        guard suoi > 0 else {
            return L.t("oggi: \(pausa)ª pausa · \(totale) ripetizioni",
                       "today: break #\(pausa) · \(totale) reps")
        }
        return L.t("oggi: \(pausa)ª pausa · \(suoi) \(kind.localizedName) · \(totale) in tutto",
                   "today: break #\(pausa) · \(suoi) \(kind.localizedName) · \(totale) in all")
    }

    private func doneLabel(_ plan: BreakPlan) -> String {
        if plan.circuitActive, plan.circuit.count > 1 {
            return L.t("Circuito completo — \(plan.circuit.count) esercizi",
                       "Full circuit — \(plan.circuit.count) exercises")
        }
        return L.t("\(plan.exercise.label) — segnati", "\(plan.exercise.label) — logged")
    }

    /// La frase, quando è lei la pagina.
    @ViewBuilder
    private var restBody: some View {
        if let phrase = model.currentPhrase {
            RestQuote(phrase: phrase, zen: model.plan?.isZen == true)
        } else {
            // Il mazzo può essere vuoto solo se il file delle frasi è illeggibile, cioè quasi
            // mai. Ma «quasi mai» disegnava uno schermo nero muto ed è esattamente la ferita del
            // 27-28 luglio: qui la fase di riposo ha comunque qualcosa da dire.
            Text(L.t("Alzati e guarda lontano.", "Stand up and look far away."))
                .font(.system(size: 30, design: .serif))
                .foregroundStyle(Palette.paper.opacity(0.8))
        }
    }

    /// Le alternative, dentro la pausa.
    ///
    /// Il default resta quello che tocca alla rotazione: qui si sceglie il *come*, non il *se*.
    /// Le ripetizioni cambiano con la difficoltà — un archer push-up non se ne fanno dieci — e
    /// il cronometro del "fatto" riparte dal cambio, così non si passa al più corto un istante
    /// prima di premere.
    /// **Due righe, non una fila sola** (2026-07-31, sua richiesta). Quante ne vanno di sopra lo
    /// decide `VariantLayout`, che è nel nucleo e ha il suo test; qui restano solo gli spazi.
    /// Fra i pulsanti 12 punti invece di 8, e 10 fra le due righe: la lamentela era che si
    /// toccavano, e una riga in più senza aria intorno l'avrebbe spostata invece di toglierla.
    ///
    /// **Dentro il circuito invece la fila è una sola** (2026-08-19, sua richiesta guardando la
    /// schermata del circuito). Lì sopra le alternative c'è già una riga di pastiglie — le
    /// stazioni — e due blocchi impilati di pastiglie diverse si leggono come una griglia: non
    /// si capisce più quale riga risponde a quale domanda. La faccia a esercizio singolo, che
    /// quella riga non ce l'ha, tiene il layout del 31 luglio finché non la guardiamo insieme.
    @ViewBuilder
    private func variantRow(singleLine: Bool) -> some View {
        let options = model.variants
        if !options.isEmpty {
            VStack(spacing: 8) {
                Text(L.t("oppure", "or"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(Palette.dim)
                VStack(spacing: 10) {
                    let righe: [[Exercise]] = singleLine ? [options] : VariantLayout.rows(options)
                    ForEach(Array(righe.enumerated()), id: \.offset) { riga in
                        HStack(spacing: 12) {
                            ForEach(riga.element, id: \.kind) { option in
                                variantButton(option)
                            }
                        }
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    /// **Si clicca tutto il rettangolo, non la parola.** Riempimento e sfondo stanno dentro
    /// l'etichetta e non fuori dal `Button`, e `contentShape` dichiara la forma da colpire:
    /// senza, i punti trasparenti agli angoli arrotondati non rispondono, e un pulsante che
    /// risponde a volte sembra un'app rotta.
    private func variantButton(_ option: Exercise) -> some View {
        Button { model.swapExercise(to: option.kind) } label: {
            VStack(spacing: 2) {
                Text(option.kind.localizedName)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                Text(option.kind.isPerSide
                     ? L.t("\(option.displayReps) per lato", "\(option.displayReps) per side")
                     : "\(option.displayReps)")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Palette.accent.opacity(0.85))
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(Palette.paper.opacity(0.8))
            .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.14)))
            .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }

    /// Il conto alla rovescia della **pausa intera**, da quando comincia.
    ///
    /// Prima il tempo mostrato era quello dell'esercizio, e dopo il "fatto" ne partiva un altro:
    /// due cronometri diversi nella stessa schermata, nessuno dei quali era la pausa. Ora ce n'è
    /// uno solo, va da 90 a 0, e il pulsante si accende quando arriva in fondo.
    @ViewBuilder
    private func controls(_ plan: BreakPlan) -> some View {
        VStack(spacing: 13) {
            // Sopra il cronometro e non sotto il pulsante: nella fase di riposo è l'istruzione
            // della schermata, e un'istruzione sotto il suo pulsante arriva a cose fatte.
            // Fessura ad altezza fissa: piena nel riposo, vuota nell'esercizio, alta uguale in
            // tutte e due — è così che il cronometro qui sotto non si sposta al cambio di faccia.
            ZStack {
                if model.exerciseDone && !model.canReturnToWork {
                    Text(L.t("Alzati e guarda lontano. Il resto della pausa è tuo.",
                             "Stand up and look far away. The rest of the break is yours."))
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Palette.accent.opacity(0.85))
                }
            }
            .frame(height: 17)

            Text(clock(model.secondsLeftOfBreak))
                .font(.system(size: 34, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(model.canReturnToWork ? Palette.accent : Palette.dim)

            progressBar(plan)

            // **Il pulsante dice dove ti porta, non che ora è.**
            //
            // Nella fase di riposo diceva «ancora 2:11» mentre il cronometro sopra diceva 2:11:
            // lo stesso numero due volte, a dodici punti di distanza, e nessuno dei due che
            // spiegasse cosa succede quando arriva a zero. Visto all'uso il
            // 2026-07-30 con la soluzione già dentro la domanda — l'etichetta resta ferma sulla
            // destinazione, ed è lo stato spento a dire «non ancora». Il tempo lo racconta
            // l'orologio, che è lì apposta.
            if model.exerciseDone {
                primary(L.t("Torna al lavoro", "Back to work"), enabled: model.canReturnToWork) {
                    model.returnToWork()
                }
            } else if plan.isZen {
                // **In Zen il pulsante grande non serve, e non deve nemmeno sembrare che serva.**
                // Il respiro parte da solo e si chiude da solo, quindi qui c'è solo la meta, spenta
                // finché non ci si arriva — la stessa forma della fase di riposo, che è ciò che
                // questa schermata è. L'unica cosa premibile è la via d'uscita: se hai interrotto
                // il respiro, lo ritrovi.
                if model.breath == nil {
                    primary(L.t("Riprendi il respiro", "Resume breathing"), enabled: true) {
                        model.startBreath()
                    }
                } else {
                    primary(L.t("Torna al lavoro", "Back to work"), enabled: false) {}
                }
            } else if model.exerciseIsTimed, model.hold == nil {
                // **Su una tenuta il pulsante grande fa partire il tempo, non lo chiude.**
                // «Fatte tutte» qui non ha senso: la tenuta finisce quando finisce il tempo, e a
                // quel punto non c'è nessuno che possa premere, perché sei a terra.
                // **L'etichetta dice cosa fa il dito e cosa succede dopo.** «Pronto» chiedeva una
                // dichiarazione di stato — e la risposta onesta, a terra non ancora, era no.
                // Riscritta il 2026-08-04: prima l'azione, poi il tempo che
                // regala, così premi anche se non sei ancora giù.
                primary(L.t("Premi per iniziare, poi hai \(Int(Hold.prepareSeconds)) s per metterti in posizione",
                            "Press to start, then you have \(Int(Hold.prepareSeconds)) s to get into position"),
                        enabled: true) { model.startHold() }
            } else if model.hold != nil {
                // **Mentre il conto gira il pulsante non serve, e una via d'uscita sì.**
                //
                // «Fatte tutte» qui sarebbe una bugia in due modi: il tempo non è finito, e alla
                // fine si segna da solo. Al suo posto c'è il modo di mollare senza uscire dalla
                // pausa — perché una tenuta si può sbagliare, e l'unica alternativa sarebbe il
                // doppio Esc, che è l'uscita d'emergenza e va contata come tale.
                Button(L.t("Interrompi il conto", "Stop the count")) { model.stopHold() }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.dim)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
            } else {
                primary(model.moreStationsAhead ? L.t("Fatte tutte — avanti", "All done — next")
                                                : L.t("Fatte tutte", "All done"),
                        enabled: model.canFinishNow) {
                    model.markExerciseDone()
                }
            }

            // La riga sotto il pulsante: terza fessura ad altezza fissa, e per la stessa ragione
            // delle altre due. Ci passano tre cose diverse a seconda del momento, e senza uno
            // spazio riservato il cronometro saltava di quaranta punti appena una di queste
            // compariva — cioè proprio l'allineamento appena costruito, rotto da una riga.
            ZStack {
                // **Su una tenuta questa riga non ha più un mestiere.** Diceva quanto manca al
                // minimo di movimento, cioè al momento in cui «Fatte tutte» si accende; su una
                // tenuta il minimo *è* il tempo, e il tempo è già il numero grande al centro
                // dello schermo. Lasciarla vorrebbe dire scrivere lo stesso numero due volte.
                // **In Zen sparisce per la stessa ragione delle tenute, più una.** Il minimo è il
                // tempo, che è già il cronometro qui sopra; e la parola «movimento» descriveva un
                // lavoro che in questa modalità non stai facendo. Trovato guardando la fotografia
                // del pannello intero il 2026-08-08, non leggendo il codice: la riga è a due
                // centimetri dal cerchio del respiro e diceva «ancora 18 s di movimento».
                if !model.exerciseDone, !model.exerciseIsTimed, !plan.isZen {
                    if model.canFinishNow {
                        // **Due risposte, non una.** Il registro sa quante ripetizioni ti sono
                        // state chieste, non quante ne hai fatte: senza questa seconda via la
                        // progressione misurerebbe solo le giornate andate bene, e su quelle
                        // qualunque progressione sembra funzionare.
                        if model.settings.progressBeyondFull {
                            Button(L.t("Non tutte…", "Almost done…")) { partialSheet = true }
                                .buttonStyle(.plain)
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.dim)
                        }
                    } else {
                        // Qui il numero **non** era un doppione — l'orologio conta la pausa,
                        // questo conta il minimo di movimento — quindi non sparisce: scende sotto
                        // il pulsante, piccolo, e dice anche **perché** stai aspettando. Due
                        // numeri nudi uno sopra l'altro erano la parte confusa.
                        Text(L.t("ancora \(Int(model.secondsUntilCanFinish.rounded(.up))) s di movimento",
                                 "\(Int(model.secondsUntilCanFinish.rounded(.up))) s of movement to go"))
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.dim)
                            .monospacedDigit()
                    }
                }
            }
            .frame(height: 17)

            // Uscire dal circuito resta possibile a metà: le stazioni già confermate restano
            // fatte, e la pausa si chiude con l'esercizio singolo che le toccava.
            if plan.circuitActive && !model.canReturnToWork {
                Button(L.t("Basta così, torno all'esercizio singolo", "That's enough, back to the single exercise")) { model.leaveCircuit() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.dim)
            }

            // La scala, proposta e mai imposta: cambiare movimento è una decisione, e trovarsi
            // i diamond push-up senza averli chiesti è il modo di far spegnere l'app.
            if let su = model.harderSuggestion, !model.exerciseDone {
                VStack(spacing: 6) {
                    Text(su.reason == .ceiling
                         ? L.t("Più ripetizioni non ci stanno in questa pausa. Da qui si sale di movimento.",
                               "More reps don't fit in this break. From here you step up the movement.")
                         : L.t("Questo ormai lo fai. Vuoi provare la versione più dura?",
                               "You've got this one. Want to try the harder version?"))
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.dim)
                    SecondaryButton(title: L.t("Passa a \(su.kind.localizedName)",
                                               "Step up to \(su.kind.localizedName)"),
                                    systemImage: "arrow.up.right") {
                        model.stepUp(to: su.kind)
                    }
                }
            }

        }
    }

    /// Il pulsante grande della pausa. **Si clicca tutto**, non solo dove ci sono le lettere.
    ///
    /// Prima lo sfondo stava fuori dal `Button` e l'etichetta era un `Text` dentro una `frame`:
    /// SwiftUI prende come area sensibile la forma del contenuto disegnato, e il contenuto era il
    /// testo. Risultato: un rettangolo ambra da 300×54 che risponde solo sulla parola «Fatto» —
    /// e un pulsante che non risponde dove sembra un pulsante è indistinguibile da uno rotto.
    /// `contentShape(Rectangle())` dentro l'etichetta dichiara che l'area sensibile è tutto il
    /// rettangolo; lo sfondo entra nell'etichetta perché la forma sensibile segua la forma vista.
    private func primary(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                // **Il testo detta la misura, non il contrario.** Con `frame(width:height:)` fisso
                // un'etichetta lunga andava a capo e usciva dal rettangolo ambra, finendo sopra la
                // linea del piede: «3 archer push-ups per side — 17 s to go» tagliata a metà,
                // vista il 2026-07-30. Il minimo tiene la forma quando l'etichetta
                // è corta, il resto lo decide il contenuto.
                .padding(.horizontal, 26)
                .padding(.vertical, 15)
                .frame(minWidth: 300, minHeight: 54)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(enabled ? Palette.ink : Palette.dim)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(enabled ? Palette.accent : Color.white.opacity(0.07))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .keyboardShortcut(enabled ? .return : .end, modifiers: [])
    }

    private func progressBar(_ plan: BreakPlan) -> some View {
        let fraction = min(1.0, max(0.0, model.breakElapsed / max(1, plan.duration)))
        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.10))
                .frame(width: 420, height: 6)
            RoundedRectangle(cornerRadius: 3)
                .fill(Palette.accent)
                .frame(width: 420 * fraction, height: 6)
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            // Aria fra il pulsante grande e la linea del piede. Ne serviva: nello screenshot del
            // 2026-07-30 il pulsante e la linea si toccavano, e la parte bassa sembrava schiacciata
            // contro il bordo mentre a metà schermo restava un vuoto grande il doppio.
            Spacer().frame(height: 6)

            Divider().overlay(Color.white.opacity(0.08)).frame(width: 620)

            // **Il perché resta, ma su una riga sola, e solo mentre devi muoverti.**
            //
            // Il titolo per esteso dell'articolo occupava tre righe di grigio e rubava il ruolo
            // alla frase: due testi da leggere sulla stessa pagina, e vinceva il più lungo. Qui
            // resta la ragione — cosa governa questo studio — con chi la firma, e il titolo vive
            // dove serve davvero, nella finestra delle fonti insieme al link.
            //
            // Nella fase di riposo sparisce: lì la pagina è la frase, e il motivo per cui ti ho
            // interrotto l'hai già letto un minuto fa.
            //
            // Qui girano solo le fonti che giustificano qualcosa che sta succedendo. Le due voci
            // «non promesso» sono uscite dal giro della pausa — nel mezzo di un esercizio
            // spiegavano una funzione assente — e vivono nella finestra delle fonti.
            // L'altra fessura ad altezza fissa, gemella di quella dell'istruzione: piena
            // nell'esercizio, vuota nel riposo, e alta uguale in tutte e due, così le uscite
            // d'emergenza stanno allo stesso punto dello schermo in tutte e due le facce.
            ZStack {
                if !model.exerciseDone {
                    VStack(spacing: 8) {
                Text(L.t("Perché: \(model.currentStudy.localizedGoverns) — \(model.currentStudy.shortCitation), \(String(model.currentStudy.year)).",
                         "Why: \(model.currentStudy.localizedGoverns) — \(model.currentStudy.shortCitation), \(String(model.currentStudy.year))."))
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.dim)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 620)

                // **Qui il link non ci va, ci va l'indirizzo di dove trovarlo.** Questa schermata
                // esiste per staccarti dallo schermo: un link aperto durante la pausa aprirebbe il
                // browser, cioè annullerebbe la pausa nel momento in cui la stai facendo — e per
                // farlo dovrebbe pure smontare il blocco. Gli studi si leggono da fermi, dopo, e
                // sono già cliccabili nella finestra delle fonti.
                Text(L.t("Gli articoli per esteso, con il link, sono in Otium ▸ Le fonti.", "Full articles, with links, are in Otium ▸ The sources."))
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.dim)
                    .multilineTextAlignment(.center)
                    }
                }
            }
            .frame(height: 38)

            HStack(spacing: 14) {
                if model.canPostpone {
                    SecondaryButton(title: L.t("Rinvia 2 minuti", "Postpone 2 minutes"), systemImage: "clock.arrow.circlepath") {
                        model.postpone()
                    }
                }
                SecondaryButton(title: L.t("Emergenza", "Emergency"), systemImage: "exclamationmark.triangle") {
                    model.emergencyExit()
                }
                SecondaryButton(
                    title: showEscape ? L.t("Annulla", "Cancel") : L.t("Non posso adesso", "I can't right now"),
                    systemImage: showEscape ? "xmark" : "arrow.uturn.right"
                ) {
                    showEscape.toggle()
                    escapeFocused = showEscape
                }
            }

            if escArmed {
                VStack(spacing: 6) {
                    Text(L.t("Premi Esc di nuovo per uscire subito.", "Press Esc again to exit now."))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.paper)
                    Text(L.t("L'uscita d'emergenza viene contata e compare nelle statistiche.", "The emergency exit is counted and shows up in your statistics."))
                        .font(.system(size: 11)).foregroundStyle(Palette.dim)
                }
                .padding(.top, 4)
            }

            if showEscape {
                VStack(spacing: 8) {
                    Text(L.t("Per saltare questa pausa scrivi per intero: «\(model.settings.escapePhrase)»", "To skip this break, type in full: «\(model.settings.escapePhrase)»"))
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.dim)
                    TextField("", text: $model.escapeText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundStyle(Palette.paper)
                        .padding(8)
                        .frame(width: 320)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .focused($escapeFocused)
                        .onSubmit { model.attemptEscape() }
                    Text(L.t("Ogni salto finisce nel registro. Non è un giudizio, è un dato.",
                     "Every skip goes into the log. It is not a judgement: it is data."))
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.dim)
                }
            }
        }
    }

    private func clock(_ seconds: Double) -> String {
        let s = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}


/// La frase e la sua firma, come si vedono durante una pausa.
///
/// **Sta qui, e non dentro `BreakView`, perché il provino deve disegnare la stessa cosa.** Il
/// cancello delle citazioni prova che il testo esiste nella fonte; non dice come suona a
/// schermo, e la revisione del 28 luglio è nata da un errore che si vedeva solo lì. Se il
/// provino ricopiasse questi numeri invece di usare questa vista, il giorno che cambia la
/// tipografia della pausa il provino continuerebbe a mostrare quella vecchia — e un
/// verificatore che non condivide il codice del verificato è l'unico che vale.
/// La frase **quando è lei la pagina**, cioè nella fase di riposo della pausa.
///
/// Il corpo è grande sul serio: a quaranta punti su nero una riga di Seneca ti ferma, a diciotto
/// in mezzo agli esercizi sembrava una didascalia — che è esattamente il difetto visto all'uso
/// il 2026-07-29.
///
/// **La misura scende sulle frasi lunghe.** Il mazzo ne ammette fino a 145 caratteri, e una da 145
/// a quaranta punti mangerebbe l'altezza del cronometro. La soglia non si stima: sta qui perché il
/// provino la misura con `--surface=provino --riposo --misura`, e la misura vale solo se il
/// provino disegna **questa** vista invece di ricopiarne i numeri.
/// Un lato del quadrato del box breathing, come tracciato percorribile.
///
/// Quattro `Shape` separate e non un rettangolo con `trim` sopra: il `trim` di un `Rectangle`
/// parte dall'angolo che decide SwiftUI e gira sempre nello stesso verso, mentre qui ogni lato ha
/// il suo **verso di percorrenza** — il basso va da destra a sinistra e il sinistro dal basso in
/// alto — che è ciò che fa sembrare il tratto un giro invece che quattro lampi scollegati.
struct SquareSide: Shape {
    let index: Int

    func path(in rect: CGRect) -> Path {
        var p = Path()
        switch index {
        case 0:  // alto, da sinistra a destra: inspiri
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        case 1:  // destro, dall'alto in basso: trattieni
            p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case 2:  // basso, da destra a sinistra: espiri
            p.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        default: // sinistro, dal basso in alto: trattieni, e il giro si chiude
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        }
        return p
    }
}

struct RestQuote: View {
    let phrase: Phrase
    /// **In Zen la frase è dell'accento, non bianca** (sua richiesta, 2026-08-08: *«il bianco
    /// stona»*). Ha ragione, e la ragione è nella pagina: dopo il respiro lo schermo è fatto di
    /// una cosa sola, l'alone salvia, e un bianco pieno accanto è l'unico elemento che non
    /// appartiene alla stessa luce. Nella pausa con esercizio il bianco resta, perché lì la frase
    /// arriva **dopo** che il colore ha già smesso di parlare.
    var zen = false

    /// Larghezza vera della fase di riposo: 1440 di schermo meno i 48+48 di margine, arrotondati
    /// al valore che la vista impone. Serve al provino per misurare la stessa cosa che si vede.
    static let width: CGFloat = QuoteWrap.riposo.larghezza

    /// Il corpo scende sulle frasi lunghe: la soglia è misurata, non stimata (vedi sopra), e vive
    /// in `QuoteWrap.riposo` perché è la stessa che decide i tagli.
    static func corpo(_ phrase: Phrase) -> CGFloat { QuoteWrap.riposo.corpo(phrase.localizedText) }

    var body: some View {
        VStack(spacing: 24) {
            Text(QuoteWrap.wrapped(phrase.displayText, width: Self.width, size: Self.corpo(phrase)))
                .font(.system(size: Self.corpo(phrase), design: .serif))
                .foregroundStyle(zen ? Palette.accent.opacity(0.92) : Palette.paper.opacity(0.94))
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: Self.width)
            if phrase.kind != .voce {
                Text(phrase.localizedCredit)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(Palette.dim)
            }
        }
    }
}

struct QuoteBlock: View {
    let phrase: Phrase

    static let width: CGFloat = QuoteWrap.esercizio.larghezza
    static let corpo: CGFloat = QuoteWrap.esercizio.corpoBase

    var body: some View {
        VStack(spacing: 6) {
            // **La voce dell'app non porta i caporali e non porta una firma.** I caporali dicono
            // «questo lo ha detto qualcun altro» e «anonimo» dice «qualcuno l'ha detto e non
            // sappiamo chi»: su una riga scritta per Otium sono due affermazioni false.
            //
            // **Il carattere invece resta lo stesso** (scelta dell'autore, 2026-07-29). Avevo
            // messo il lineare per la voce e le grazie per le citazioni: due caratteri sulla
            // stessa schermata sono un cambio di tono che nessuno ha chiesto, e la distinzione la
            // fanno già i caporali che non ci sono.
            Text(QuoteWrap.wrapped(phrase.displayText, width: Self.width, size: Self.corpo))
                .font(.system(size: Self.corpo, design: .serif))
                .foregroundStyle(Palette.paper.opacity(0.62))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: Self.width)
            if phrase.kind != .voce {
                Text(phrase.localizedCredit)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.dim)
            }
        }
    }
}

/// I comandi in fondo alla schermata di blocco.
///
/// Prima erano parole grigie su fondo nero: sembravano didascalie, e una didascalia non si
/// clicca. Un bordo, uno sfondo e una reazione al passaggio del mouse bastano a dire "questo
/// è un comando" — su una schermata che ti sta bloccando il Mac, sapere dove sono le uscite
/// non è un dettaglio estetico.
struct SecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 12)) }
                Text(title).font(.system(size: 13, weight: .medium, design: .rounded))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .foregroundStyle(hovering ? Palette.ink : Palette.paper.opacity(0.85))
            .background(
                Capsule().fill(hovering ? Palette.paper.opacity(0.92) : Color.white.opacity(0.09))
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(hovering ? 0.0 : 0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

// MARK: - Il preavviso

struct HUDView: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 2).fill(Palette.accent).frame(width: 4)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                // **Il pannello si allarga in altezza, il testo non si taglia.**
                // Con un'altezza fissa a 84 punti «prossima pausa fra 30 min di lavoro attivo»
                // finiva in «…di lavoro att…», e la parola tagliata era proprio quella che
                // distingue il tempo di lavoro vero dall'orologio a muro. Visto all'uso
                // il 2026-07-28, guardando la notifica. Accorciare la frase avrebbe curato questa
                // e lasciato in piedi la prossima: qui cede il pannello, non il significato.
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 320, alignment: .leading)
        .frame(minHeight: 84)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

/// Il gesto delle notifiche di macOS: si scorre via verso destra, o si chiude con un clic.
///
/// Un pannello che resta lì finché non scade è una cosa che *subisci*; uno che si può spostare
/// con un dito è una cosa che *governi*. Sotto la soglia il pannello torna al suo posto, come
/// fa il Centro Notifiche: lo scorrimento incerto non deve far sparire niente.
struct Dismissible<Content: View>: View {
    let onDismiss: () -> Void
    @ViewBuilder var content: Content
    @State private var offset: CGFloat = 0
    private let threshold: CGFloat = 70

    var body: some View {
        content
            .offset(x: offset)
            .opacity(Double(1 - min(1, abs(offset) / 220)))
            .gesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { value in
                        // Solo verso destra, come le notifiche di sistema: verso sinistra il
                        // pannello non si muove, così un gesto sbagliato non lo fa sparire.
                        offset = max(0, value.translation.width)
                    }
                    .onEnded { value in
                        if value.translation.width > threshold {
                            withAnimation(.easeIn(duration: 0.18)) { offset = 420 }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: onDismiss)
                        } else {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) { offset = 0 }
                        }
                    }
            )
            .onTapGesture { onDismiss() }
    }
}

/// La frase dell'avvio.
struct QuoteHUDView: View {
    let phrase: Phrase

    static let width: CGFloat = QuoteWrap.pannello.larghezza
    static let corpo: CGFloat = QuoteWrap.pannello.corpoBase

    /// Chi l'ha detta, un pelo sotto la frase e più in sordina.
    private var credito: some View {
        Text(phrase.localizedCredit)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
    }

    var body: some View {
        // **Ogni numero di questa scatola viene da `QuoteWrap.Pannello`, nessuno è scritto qui.**
        // Erano scritti in due posti, e le due copie divergevano: qui c'erano tre elementi
        // nell'`HStack`, cioè due intervalli da 14, mentre il calcolo della colonna ne toglieva
        // uno solo. Quattordici punti di differenza bastavano a far spezzare di nuovo a `Text`
        // righe già impaginate. La storia per esteso sta accanto alle costanti.
        HStack(spacing: QuoteWrap.Pannello.stacco) {
            RoundedRectangle(cornerRadius: 2).fill(Palette.accent)
                .frame(width: QuoteWrap.Pannello.barra)
            VStack(alignment: .leading, spacing: 6) {
                // **Il blocco si centra come un tutt'uno, e va bene così.**
                //
                // Provata e scartata la via opposta il 2026-08-03: un contrappeso invisibile
                // sopra — la firma stessa, copiata e nascosta — che metteva la *frase* esatta
                // sull'asse centrale e lasciava la firma appesa sotto. Guardata a schermo, in una
                // scatola stretta come questa fa salire il peso visivo e il pannello sembra
                // sbilanciato in alto. Il difetto vero non era il centraggio: era l'altezza fissa
                // di 132 punti, in cui una frase di due righe ballava. Tolta quella, il blocco
                // centrato è la lettura giusta — e la frase, che occupa quasi tutto, di fatto
                // ci sta sopra.
                Text(QuoteWrap.wrapped(phrase.displayText, width: Self.width, size: Self.corpo))
                    .font(.system(size: Self.corpo, design: .serif))
                    // **L'interlinea di serie è pensata per una riga o due, non per quattro.**
                    // Sulla frase più lunga del mazzo — tre righe di serif in una colonna stretta
                    // — il blocco si legge come un muro. Tre punti d'aria fra le righe non si
                    // notano su una frase corta e salvano quella lunga.
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                if phrase.kind != .voce { credito }
            }
            // **La colonna del testo è dichiarata, non dedotta.** Prima c'era uno `Spacer` a
            // spingere il blocco a sinistra: essendo un terzo elemento aggiungeva un secondo
            // intervallo da 14 che il calcolo della colonna non contava, e le righe già
            // impaginate venivano spezzate di nuovo da `Text`.
            //
            // Nemmeno `maxWidth: .infinity` va bene, provato qui lo stesso giorno: rende il
            // contenuto avido, la `fittingSize` della vista ospitata schizza a 930 punti e il
            // pannello esce largo il doppio. Un numero esatto non ha nessuna di queste due
            // ambiguità, ed è **lo stesso** su cui sono stati calcolati i tagli.
            .frame(width: QuoteWrap.Pannello.colonna, alignment: .leading)
        }
        .padding(QuoteWrap.Pannello.respiro)
        // **Nessuna altezza scritta qui.** Erano 132 punti fissi: una frase di due righe ci
        // ballava dentro, e una lunga sarebbe stata tagliata. Ora la detta il contenuto, con il
        // solo minimo del pannello — la stessa regola che `WarningHUD` applica già alle altre.
        //
        // La larghezza invece resta scritta, ed è cresciuta da 380 a 420: la frase più lunga del
        // mazzo (Dhammapada, 137 caratteri) in 380 punti andava a tre righe strette e si leggeva
        // come un blocco compatto. Quaranta punti in più le tolgono una riga senza far invadere
        // al pannello mezzo schermo.
        .frame(width: QuoteWrap.Pannello.scatola, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Il pannello del menu

struct MenuPanel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Otium").font(.system(size: 15, weight: .semibold, design: .rounded))   // lingua: ok nome proprio
                Spacer()
                Text(model.phase == .paused ? L.t("sospesa", "paused")
                     : L.t("prossima fra \(model.minutesToNextBreak) min", "next in \(model.minutesToNextBreak) min"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: model.engine.clock.fraction(of: model.settings.cadence.intervalSeconds))
                .tint(Palette.accent)

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
                GridRow {
                    Text(L.t("davanti al Mac", "at the Mac")).foregroundStyle(.secondary)
                    Text(model.summary.activeHoursLabel).monospacedDigit()
                }
                GridRow {
                    Text(L.t("pause fatte", "breaks taken")).foregroundStyle(.secondary)
                    Text("\(model.summary.completed)").monospacedDigit()
                }
                GridRow {
                    Text(L.t("saltate", "skipped")).foregroundStyle(.secondary)
                    Text("\(model.summary.skipped)").monospacedDigit()
                }
                GridRow {
                    Text(L.t("sessioni intense", "vigorous bouts")).foregroundStyle(.secondary)
                    Text("\(model.summary.vigorousBouts) / \(model.settings.vigorousDailyTarget)")
                        .monospacedDigit()
                        .foregroundStyle(model.summary.vigorousBouts >= model.settings.vigorousDailyTarget
                                         ? Color.green : Color.primary)
                }
            }
            .font(.system(size: 13))

            // **Niente elenco degli esercizi qui.** Con dieci tipi in rotazione la lista cresce
            // per tutta la giornata, il pannello del menu ha una larghezza fissa, e i nomi lunghi
            // — «archer push-up», l'ultimo fatto — finivano tagliati. Il dettaglio per esercizio
            // vive nelle Statistiche, dove c'è spazio per leggerlo: ripeterlo qui costava una
            // riga tagliata in cambio di niente.
        }
        .padding(16)
        .frame(width: 280)
        .livrea()
    }
}

// MARK: - Le fonti

struct EvidenceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.t("Da dove vengono questi numeri", "Where these numbers come from"))
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                    // Niente asterischi: `Text` interpreta il markdown solo su una stringa
                    // letterale, e su una concatenazione li stampa come sono — visto a schermo.
                    Text(L.t("Ogni parametro di Otium risponde a uno studio: metabolismo, fatica e "
                       + "concentrazione. Le ultime due voci sono le cose che l'app NON fa e NON "
                       + "promette, con il motivo.",
                    "Every parameter in Otium answers to a study: metabolism, fatigue and "
                        + "concentration. The last two entries are the things the app does NOT do and "
                        + "does NOT promise: they are here so you can hold it to account."))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                ForEach(Evidence.all) { study in
                    VStack(alignment: .leading, spacing: 6) {
                        let isDisclaimer = Evidence.disclaimers.contains { $0.id == study.id }
                        Text(study.localizedGoverns)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isDisclaimer ? Color.secondary : Palette.accentOnWindow)
                        Text(study.localizedClaim)
                            .font(.system(size: 13))
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 6) {
                            Text("\(study.citation), \(String(study.year)).")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let url = URL(string: study.url) {
                            Link(L.t("apri l'articolo", "open the paper"), destination: url)
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.accentOnWindow)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(28)
        }
        .frame(minWidth: 640, maxWidth: 640, minHeight: 520)
        .livrea()
    }
}

// MARK: - Preferenze

/// Una scelta fra poche voci in fila, **con i colori nostri**.
///
/// Esiste per un difetto visto di notte (2026-07-31): `.pickerStyle(.segmented)` prende dal
/// `tint` il colore della casella scelta, ma il testo dentro **lo decide lui**, e sceglie il
/// bianco. Bianco su salvia chiara sta a 1,9:1, cioè sotto qualunque soglia: *«la scritta è
/// bianca e si vede poco»*. Non è una questione di gusto, è un testo che non si legge.
///
/// Non si può curare tingendo meglio, perché il colore che manca è quello che il controllo di
/// sistema non lascia toccare. Quindi la casella la disegniamo noi, con la stessa coppia che
/// tutta l'app usa già: `accentOnWindow` sotto, `onAccentOnWindow` sopra — che in chiaro è verde
/// bosco con testo bianco, e di notte salvia chiara con testo scuro.
///
/// Restano **pulsanti veri**, non testo cliccabile: tastiera e VoiceOver non si buttano via per
/// un colore. È lo stesso disegno del selettore del periodo nelle statistiche, che era già stato
/// riscritto a mano nel 2026-07-27 per una ragione parente — lì il controllo di sistema restava
/// blu in tutte e tre le livree.
struct SegmentedChoice<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    @Binding var selection: Value
    /// Le linguette delle famiglie riempiono la riga; una scelta fra due sta larga quanto le serve.
    var fillWidth = false
    /// **Larghezza fissa per segmento.** Senza, ogni controllo è largo quanto le sue parole, e
    /// due righe vicine finiscono su bordi destri diversi: «Italiano/English» è più largo di
    /// «Uomo/Donna» e la colonna si vede storta. Visto all'uso il 2026-08-11 con la
    /// fotografia delle due righe. Vale la regola dei pannelli: i comandi di una pagina finiscono
    /// tutti sullo stesso bordo.
    var segmentWidth: CGFloat? = nil

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { option in
                let selected = option.value == selection
                Button { selection = option.value } label: {
                    Text(option.label)
                        .font(.system(size: 12, weight: selected ? .semibold : .regular))
                        .foregroundStyle(selected ? Palette.onAccentOnWindow : Palette.text)
                        .lineLimit(1)
                        .frame(maxWidth: fillWidth ? .infinity : nil)
                        .frame(width: segmentWidth)
                        .padding(.horizontal, fillWidth ? 6 : (segmentWidth == nil ? 14 : 0))
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selected ? Palette.accentOnWindow : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Palette.isDarkAppearance ? Color.white.opacity(0.07) : Color.black.opacity(0.05))
        )
    }
}

struct PrefsView: View {
    @ObservedObject var model: AppModel
    /// Qualificato: in un file che importa SwiftUI, `Settings` da solo è ambiguo — SwiftUI ha
    /// una sua `Settings` (la scena delle preferenze).
    @State private var draft: OtiumCore.Settings
    @State private var applied = false
    /// L'ultimo «Applica» non è arrivato sul disco. Resta acceso finché non ritenti.
    @State private var saveFailed = false
    /// La voce aperta. Si riparte sempre da `profilo`: una finestra che riapre dove l'avevi
    /// lasciata la volta scorsa è comoda finché non ti chiedi perché non vedi più le altre.
    @State private var section: Section = .profilo
    /// Quale famiglia di esercizi è aperta. Vive qui, accanto alla voce, e non dentro il
    /// pannello: cambiando voce e tornando indietro deve ritrovarti dov'eri.
    @State private var famiglia: ExerciseCategory = .gambe

    /// La misura di un segmento nelle scelte a due voci. Una costante sola, perché il punto è
    /// che tutte queste righe finiscano sullo stesso bordo destro: se ognuna scegliesse la sua,
    /// tornerebbe il difetto. 82 punti tengono «Italiano», che è la parola più lunga fra quelle
    /// in gioco nelle due lingue.
    static let segmentoScelta: CGFloat = 82

    /// `initialSection` esiste per la sonda: `--surface=prefs --voce=cadenza` rende il pannello
    /// che si vuole guardare. Nell'app resta il default, cioè Profilo.
    init(model: AppModel, initialSection: Section = .profilo) {
        self.model = model
        _draft = State(initialValue: model.settings)
        _section = State(initialValue: initialSection)
    }

    /// Le voci della barra laterale.
    ///
    /// **Sei, non una lista sola.** Le preferenze erano un modulo unico da scorrere: cambiavi la
    /// cadenza, scendevi agli esercizi, e il pulsante che salva era già uscito dallo schermo.
    /// Visto all'uso il 2026-07-31 — *«la lista unica da scorrere è brutta e
    /// scomoda»*. Le voci ricalcano i raggruppamenti che le sezioni avevano già: non è una
    /// tassonomia nuova, è quella di prima resa navigabile.
    enum Section: String, CaseIterable, Identifiable, Hashable {
        case profilo, cadenza, esercizi, zen, interruzioni, aspetto, avanzate

        var id: String { rawValue }

        var title: String {
            switch self {
            case .profilo:      return L.t("Profilo", "Profile")
            case .cadenza:      return L.t("Cadenza", "Cadence")
            case .esercizi:     return L.t("Esercizi", "Exercises")
            case .zen:          return L.t("Zen", "Zen")
            case .interruzioni: return L.t("Interruzioni", "Interruptions")
            case .aspetto:      return L.t("Aspetto", "Appearance")
            case .avanzate:     return L.t("Avanzate", "Advanced")
            }
        }

        /// Il sottotitolo dice **cosa ci trovi**, che è l'unica cosa che rende una barra laterale
        /// meglio di una lista: senza, per trovare un interruttore devi aprirle tutte.
        var subtitle: String {
            switch self {
            case .profilo:      return L.t("lingua, ripetizioni, partenza", "language, reps, ramp-up")
            case .cadenza:      return L.t("ogni quanto, durata, rinvii", "how often, how long, postponements")
            // Corto perché la colonna è stretta: «quali girano, come vengono proposti» finiva in
            // «come vengono…», che è un sottotitolo che non dice niente. Visto nella finestra
            // vera il 2026-07-31, non nella resa.
            case .esercizi:     return L.t("rotazione, varianti, livello", "rotation, variants, level")
            case .zen:          return L.t("respiro invece di esercizio", "breathing instead of exercise")
            case .interruzioni: return L.t("call, video, ore attive", "calls, video, active hours")
            case .aspetto:      return L.t("livrea, suono", "theme, sound")
            case .avanzate:     return L.t("avvio, registro, segnalazioni", "startup, log, reporting")
            }
        }

        var icon: String {
            switch self {
            case .profilo:      return "person.crop.circle"
            case .cadenza:      return "metronome"
            case .esercizi:     return "figure.strengthtraining.functional"
            case .zen:          return "leaf"
            case .interruzioni: return "bell.badge"
            case .aspetto:      return "paintpalette"
            case .avanzate:     return "wrench.and.screwdriver"
            }
        }
    }

    var body: some View {
        // La barra del salvataggio sta **fuori** dalla vista divisa, e questo è il punto: la
        // bozza è una sola e attraversa i pannelli, quindi il pulsante non può vivere dentro uno
        // solo. Prima era l'ultima sezione di un modulo lungo, cioè visibile solo se avevi finito
        // di scorrere.
        // **Niente `NavigationSplitView`, e non è una questione di gusto.**
        //
        // La vista divisa di sistema disegna la barra laterale come un pannello che galleggia:
        // angoli arrotondati, ombra, staccato dal bordo della finestra. Visto all'uso
        // il 2026-07-31 con Kalamos accanto, dove la colonna è piena e arriva ai bordi. E porta
        // dietro la seconda cosa che non va, cioè la **selezione blu di sistema**: quel blu è
        // l'accento del Mac, non quello dell'app, e `tint` sulla lista non lo tocca.
        //
        // Le due cose hanno la stessa cura, cioè possedere la colonna invece di configurarla:
        // un `HStack`, una fila di pulsanti, la selezione stesa nell'accento della livrea. È la
        // struttura di Kalamos, copiata di proposito perché le due app devono leggersi uguali.
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(spacing: 0) {
                Form {
                    switch section {
                    case .profilo:      profiloSection
                    case .cadenza:      cadenzaSection
                    case .esercizi:     eserciziSection
                    case .zen:          zenSection
                    case .interruzioni: interruzioniSection
                    case .aspetto:      aspettoSection
                    case .avanzate:     avanzateSection
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)

                Divider()
                // La barra del salvataggio sta a destra della colonna e sotto il modulo: la
                // bozza è una sola e attraversa i pannelli, ma il pulsante appartiene alla
                // pagina, non alla colonna che la sceglie.
                applyBar
            }
            .background(Palette.windowPaper)
        }
        .frame(width: 760, height: 580)
        .background(Palette.windowPaper)
        .livrea()
        // **La stessa impostazione si gira anche dal menu della barra** (2026-08-09), e la bozza
        // non se ne accorgerebbe: l'interruttore resterebbe spento con la modalità accesa, cioè
        // di nuovo la distanza fra quello che vedi e quello che fa il motore. Si allinea solo il
        // campo di Zen, non tutta la bozza: le altre modifiche in sospeso restano tue.
        .onChange(of: model.settings.zenMode) { _, nuovo in draft.zenMode = nuovo }
    }

        /// La colonna: piena, attaccata ai bordi, con la selezione nella livrea scelta.
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Section.allCases) { voce in
                Button { section = voce } label: {
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: voce.icon)
                            .font(.system(size: 13))
                            .frame(width: 18)
                            .padding(.top, 1)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(voce.title)
                                .font(.system(size: 13, weight: section == voce ? .semibold : .regular))
                            Text(voce.subtitle)
                                .font(.system(size: 11))
                                .foregroundStyle(Palette.textDim)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(section == voce ? Palette.accentOnWindow : Palette.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    // Riempimento dentro l'etichetta e forma di collisione esplicita: una riga
                    // che si accende dove non si può cliccare sembra un'app rotta. Stessa regola
                    // dei pulsanti della pausa, pagata due volte fra Otium e Kalamos.
                    .background(RoundedRectangle(cornerRadius: 7)
                        .fill(section == voce ? Palette.accentWash : .clear))
                    .contentShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(12)
        .frame(width: 232, alignment: .topLeading)
        .background(Palette.windowEdge)
    }

    /// **Un interruttore si applica da solo, tutto il resto passa da «Applica».**
    ///
    /// La regola è mia e ha due date. Il 2026-08-08, per la sola modalità Zen:
    /// *«modalità zen ha il togle, non deve chiedere conferma di applica»*. Il 2026-08-12, estesa a
    /// ogni interruttore della finestra: *«quando metto il toggle sono sicuro che è come dico io»*,
    /// e nello stesso turno il verso opposto per quello che interruttore non è, cioè i menu di Zen,
    /// che tornano sotto «Applica».
    ///
    /// **La linea di taglio è la forma del comando, non la sua importanza.** Un interruttore ha due
    /// stati e li mostra entrambi: girarlo *è* la decisione, e un passaggio in più fra il gesto e
    /// l'effetto crea la distanza fra quello che vedi e quello che fa il motore, cioè il guasto che
    /// gli è costato una pausa sbagliata. Un menu, un campo di testo o delle frecce si attraversano
    /// per arrivare al valore che vuoi, e scrivere ogni valore di passaggio vorrebbe dire riscrivere
    /// il file dieci volte mentre stai ancora decidendo, e per un attimo lavorare con una cadenza
    /// che non hai scelto.
    ///
    /// **Scrive solo il proprio campo**, prendendo le impostazioni vive e non la bozza: se hai
    /// altre modifiche in sospeso in un altro pannello, girare questo interruttore non deve
    /// applicartele di straforo. La bozza si allinea insieme, o «Modifiche non applicate» si
    /// accenderebbe per una modifica che è già sul disco.
    private func vivo<V>(_ campo: WritableKeyPath<OtiumCore.Settings, V>) -> Binding<V> {
        Binding(
            get: { draft[keyPath: campo] },
            set: { nuovo in
                draft[keyPath: campo] = nuovo
                var vive = model.settings
                vive[keyPath: campo] = nuovo
                saveFailed = !model.update(settings: vive)
            }
        )
    }

    /// Il piede fisso: lo stato del salvataggio a sinistra, il pulsante a destra, sempre lì.
    private var applyBar: some View {
        HStack {
            // Un pulsante che non risponde è indistinguibile da un pulsante rotto: prima
            // "Applica" salvava in silenzio, e l'unico modo di sapere se aveva funzionato
            // era riaprire la finestra.
            if saveFailed {
                // Un salvataggio fallito non deve somigliare a uno riuscito: qui la riga resta
                // finché non ritenti, invece di sparire dopo due secondi e mezzo come il verde.
                Label(L.t("Non sono riuscito a salvare le preferenze",
                          "I could not save the preferences"), systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.system(size: 13, weight: .medium))
            } else if applied {
                Label(L.t("Preferenze aggiornate", "Preferences updated"), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Palette.accentOnWindow)
                    .font(.system(size: 13, weight: .medium))
                    .transition(.opacity)
            } else if draft != model.settings {
                // Il pendente si dice, perché cambiando pannello non si vede più cosa hai
                // toccato: senza questa riga, «Applica» acceso è l'unico indizio.
                Text(L.t("Modifiche non applicate", "Unapplied changes"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(L.t("Applica", "Apply")) {
                let scritto = model.update(settings: draft)
                saveFailed = !scritto
                guard scritto else { return }
                withAnimation { applied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation { applied = false }
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(draft == model.settings)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - I pannelli

    @ViewBuilder
    private var profiloSection: some View {
        // Le due risposte del primo avvio, dove si possono cambiare. Una scelta fatta una
        // volta sola e mai più modificabile è una trappola, non una configurazione.
        SwiftUI.Section {
            LabeledContent(L.t("Lingua", "Language")) {
                SegmentedChoice(
                    options: AppLanguage.allCases.map { ($0, $0.nativeName) },
                    selection: Binding(
                        get: { draft.language ?? AppLanguage.systemDefault },
                        set: { draft.language = $0 }),
                    segmentWidth: Self.segmentoScelta)
            }

            LabeledContent(L.t("Sesso", "Sex")) {
                SegmentedChoice(
                    options: [(Sex.male, L.t("Uomo", "Male")), (Sex.female, L.t("Donna", "Female"))],
                    selection: Binding(get: { draft.sex ?? .male }, set: { draft.sex = $0 }),
                    segmentWidth: Self.segmentoScelta)
            }

            Text(L.t("Il sesso decide da dove parti, cioè le ripetizioni per gruppo muscolare (Miller 1993) e la versione della spinta, sulle ginocchia invece che a terra. Non cambia la cadenza né nient'altro, e ogni esercizio resta scambiabile dentro la pausa.",
                     "Sex decides where you start: the reps per muscle group (Miller 1993) and the version of the push — on your knees instead of full. It changes nothing else, and every exercise stays swappable inside the break."))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

        }

        SwiftUI.Section(L.t("Ripetizioni", "Reps")) {
            conNota(L.t("Si sale del 5% dopo due conferme piene di fila (regola 2-for-2 dell'ACSM) e si scende dopo due mancate, mai sotto il 100%. A fine esercizio l'app ti chiede se le hai fatte tutte.",
                        "It goes up 5% after two full confirmations in a row (ACSM's 2-for-2 rule) and steps back after two shortfalls, never below 100%. At the end of each exercise the app asks whether you did them all.")) {
                Toggle(L.t("Fai crescere le ripetizioni oltre il 100%",
                           "Let the reps grow beyond 100%"), isOn: vivo(\.progressBeyondFull))
            }

            // «Rampa» era il calco di *ramp*: in italiano è la salita di un garage, non un
            // modo di allenarsi. Visto all'uso il 2026-07-28.
            LabeledContent(L.t("Partenza graduale", "Gradual start")) {
                numeroSelettore($draft.rampWeeks, in: 1...12,
                                unità: L.t("settimane", "weeks"))
            }
            // **La percentuale di partenza si tocca.** Il 55% viene da un default, non da una
            // misura su di te: chi riprende dopo un infortunio vuole meno, chi si allena già
            // vuole di più, e senza questo cursore l'unica alternativa era «tutto o niente».
            //
            // Il passo è di 5 e le frecce lo rispettano, quindi l'intervallo si esprime in gradini
            // (4…20) e il numero si moltiplica per leggerlo: uno `Stepper` con `step:` non entra
            // in `numeroSelettore`, e un secondo aiutante per un solo chiamante sarebbe la copia
            // che questa modifica esiste per togliere.
            LabeledContent(L.t("Si parte al", "Start at")) {
                numeroSelettore(Binding(
                    get: { Int((draft.rampStartFactor * 100).rounded()) / 5 },
                    set: { gradino in
                        let nuovo = gradino * 5
                        draft.rampStartFactor = Double(nuovo) / 100
                        // Scendendo sotto il pieno, la data del pieno non ha più senso: se
                        // restasse, la domanda sulla crescita oltre il 100% arriverebbe a
                        // qualcuno che al 100% non c'è.
                        if nuovo < 100 { draft.fullReachedAt = nil }
                    }
                ), in: 4...20) { "\($0 * 5)%" }
            }
            Text(L.t("Le ripetizioni partono ridotte e salgono un pochino ogni giorno, fino al 100%. Oggi sei \(ItalianNumber.al(Int(draft.rampFactor(now: Date()) * 100)))%.",
                     "The reps start reduced and go up a little every day, until 100%. Today you are at \(Int(draft.rampFactor(now: Date()) * 100))%."))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // **Il pieno si sceglie, non si aspetta.** Lo stepper arrivava già a 100, ma dice
            // «si parte al…» — parla di com'è cominciata, non di adesso — e chi vuole il numero
            // pieno oggi non ha motivo di leggerlo come la risposta alla sua domanda. L'unica
            // altra via era la finestra che l'app propone da sé dopo una settimana: una domanda
            // che arriva quando decide lei. Deciso il 2026-07-31.
            if draft.rampFactor(now: Date()) < 1.0 {
                Button(L.t("Passa subito al 100%", "Go to 100% now")) {
                    draft.rampStartFactor = 1.0
                    draft.fullReachedAt = Date()
                    // La domanda delle due settimane non ha più niente da chiedere.
                    draft.fullPaceAnswered = true
                }
                Text(L.t("Salta la partenza graduale: da adesso le ripetizioni sono quelle piene. Si torna indietro riabbassando la percentuale qui sopra.",
                         "Skip the gradual start: from now on the reps are the full ones. You can go back by lowering the percentage above."))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Label(L.t("Sei al numero pieno.", "You are on the full count."),
                      systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Palette.accentOnWindow)
            }
        }
    }

    @ViewBuilder
    private var cadenzaSection: some View {
        // **Dire di cosa si parla.** «30 min + pausa piena ogni 90» non dice *di che cosa* —
        // ogni quanto cosa, quanto dura cosa. Visto all'uso il 2026-07-31: *«ogni
        // quanto, quanto dura, ma cosa?»*. La risposta e' una riga in cima, non un nome di
        // preset piu' lungo.
        SwiftUI.Section {
            // Niente virgola prima della «e»: in italiano è l'eccezione, non la regola, e qui i
            // due membri sono la stessa cosa detta due volte. Segnalato da lui il 2026-07-31.
            Text(L.t("Ogni quanto Otium ti interrompe e quanto dura l'interruzione.",
                     "How often Otium interrupts you, and how long the interruption lasts."))
                .font(.system(size: 13, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
            // `Text(.init(...))`, non `Text(...)`: una stringa costruita a runtime non passa dal
            // markdown, e gli asterischi finiscono **a schermo** — visto nei pixel il 2026-07-31,
            // ed è lo stesso difetto già pagato sulle frasi in `Facts.swift`. Il grassetto qui
            // porta il senso della riga, quindi si tiene e si fa funzionare.
            Text(.init(L.t("Il conto è sul **tempo attivo**: trenta minuti di lavoro vero, non trenta minuti d'orologio. Se ti alzi, il conto si ferma.",
                           "The count is on **active time**: thirty minutes of real work, not thirty minutes on the clock. If you get up, the count stops.")))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        SwiftUI.Section {
            Picker(L.t("Preset", "Preset"), selection: Binding(
                get: { presetName(draft.cadence) },
                set: { applyPreset($0) }
            )) {
                Text(L.t("A — una pausa breve ogni 30 minuti, una piena ogni 90 (consigliata)",
                         "A — a short break every 30 minutes, a full one every 90 (recommended)")).tag("A")
                Text(L.t("B — una pausa piena ogni 50 minuti (deep work)",
                         "B — a full break every 50 minutes (deep work)")).tag("B")
                Text(L.t("C — una pausa piena ogni 30 minuti (protocollo Duran)",
                         "C — a full break every 30 minutes (Duran protocol)")).tag("C")
                // **«Personalizzata» c'e' solo se lo sei.** Era una voce sempre presente che
                // selezionandola non faceva niente — `applyPreset` non ha un caso per lei, perche'
                // non e' una scelta: e' lo stato in cui finisci toccando i valori qui sotto.
                // Adesso compare solo quando quello stato e' vero, e la riga sotto dice **cosa**
                // ti ci ha portato.
                if presetName(draft.cadence) == "X" {
                    Text(L.t("personalizzata", "custom")).tag("X")
                }
            }
            .pickerStyle(.menu)

            if presetName(draft.cadence) == "X" {
                Text(L.t("Hai valori tuoi: \(differenzeDalPresetPiuVicino()). Scegli un preset qui sopra per tornare indietro.",
                         "You have your own values: \(differenzeDalPresetPiuVicino()). Pick a preset above to go back."))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        SwiftUI.Section {
            LabeledContent(L.t("Intervallo", "Interval")) {
                minuteField($draft.cadence.intervalSeconds)
            }
            LabeledContent(L.t("Durata micro-pausa", "Micro-break length")) {
                secondField($draft.cadence.microDurationSeconds)
            }
            LabeledContent(L.t("Durata pausa piena", "Full break length")) {
                minuteField($draft.cadence.longDurationSeconds)
            }
            LabeledContent(L.t("Pausa piena ogni", "Full break every")) {
                numeroSelettore($draft.cadence.longEveryNBreaks, in: 1...8,
                                unità: L.t("micro-pause", "micro-breaks"))
            }
            // Detto qui perché è la domanda che ho fatto guardando lo schermo: la
            // prima pausa di oggi era piena, e la ragione stava in un contatore che non sapeva
            // che fosse cambiato il giorno.
            Text(L.t("Il conto riparte ogni giorno: la prima pausa della giornata è sempre breve.",
                     "The count restarts every day: the first break of the day is always a short one."))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            LabeledContent(L.t("Preavviso", "Warning")) {
                secondField($draft.cadence.warningSeconds)
            }
            // **I rinvii stanno qui dal 2026-08-12**, per mia decisione: *«il numero di
            // rinvii consentiti attualmente è in interruzioni, ha più senso averlo in cadenza, lo
            // stesso gruppo»*. È il campo di `Cadence` che viveva nel pannello sbagliato, e quella
            // distanza costava due volte — l'aveva già trovato lui il 2026-07-31, quando toccarlo
            // lo portò fuori dai preset senza che avesse aperto «Cadenza».
            conNota(L.t("Un rinvio sposta la pausa di due minuti, e finiti i rinvii la pausa arriva. Il preset consigliato ne dà due.",
                        "A postponement moves the break by two minutes, and once they are used up the break arrives. The recommended preset gives you two.")) {
                LabeledContent(L.t("Rinvii a mano", "Manual postponements")) {
                    numeroSelettore($draft.cadence.postponesAllowed, in: 0...3)
                }
            }
        }
    }

    @ViewBuilder
    private var eserciziSection: some View {
        // **Una famiglia per volta, scelta in alto.** Erano quattro sezioni impilate in un
        // pannello che scorreva per tre schermate: per arrivare agli esplosivi passavi davanti a
        // venticinque caselle che non stavi cercando. Deciso il 2026-07-31.
        //
        // Il contatore dentro la linguetta — «Gambe 4/5» — e' quello che rende il cambio un
        // guadagno netto invece di uno scambio: la lista lunga aveva un vantaggio, che si vedeva
        // tutto insieme, e senza il numero per aprire quattro pannelli servirebbe la memoria.
        SwiftUI.Section {
            SegmentedChoice(
                options: ExerciseCategory.allCases.map {
                    ($0, "\($0.localizedName)  \(attivi($0))/\(totali($0))")
                },
                selection: $famiglia,
                fillWidth: true)
        }

        ForEach(ExerciseCategory.allCases.filter { $0 == famiglia }, id: \.self) { category in
            SwiftUI.Section {
                ForEach(ExerciseKind.allCases.filter { $0.category == category }, id: \.self) { kind in
                    Toggle(isOn: binding(for: kind)) {
                        HStack {
                            Text(kind.localizedName)
                            Text(kind.isTimed
                                 ? L.t("\(kind.baseReps) s · tenuta", "\(kind.baseReps) s · hold")
                                 : L.t("\(kind.baseReps) rip. · \(kind.localizedMuscleGroup)", "\(kind.baseReps) reps · \(kind.localizedMuscleGroup)"))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(category.localizedName)
                        Text(category.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    // `.buttonStyle(.link)` si dipinge da sé con l'accento **di sistema** e
                    // non ascolta il `tint` dell'ambiente: qui il colore va detto a mano, o
                    // restano gli unici due blu di una finestra verde.
                    Button(L.t("tutti", "all")) { setAll(category, on: true) }
                        .buttonStyle(.link).font(.caption)
                        .foregroundStyle(Palette.accentOnWindow)
                    Button(L.t("nessuno", "none")) { setAll(category, on: false) }
                        .buttonStyle(.link).font(.caption)
                        .foregroundStyle(Palette.accentOnWindow)
                }
            }
        }

        // **Zen ha una voce sua dal 2026-08-11**, per mia scelta. Qui resta solo il
        // rimando, e non è cortesia: la ragione per cui Zen stava in questa pagina era che
        // *sostituisce* gli esercizi invece di affiancarli, e senza questa riga si può tarare con
        // cura la rotazione senza sapere che un interruttore in un'altra voce la spegne tutta.
        // Compare **solo quando Zen è accesa**, perché è lì che questa pagina mente.
        if draft.zenMode {
            SwiftUI.Section(L.t("Attenzione", "Heads up")) {
                Text(L.t("La modalità Zen è accesa, quindi le pause chiedono un respiro guidato e gli esercizi di questa pagina non vengono proposti. Si spegne dalla voce Zen.",
                         "Zen mode is on, so breaks ask for guided breathing and the exercises on this page are not offered. You turn it off under Zen."))
                    .font(.callout)
                    .foregroundStyle(Palette.accentOnWindow)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        SwiftUI.Section(L.t("Come vengono proposti", "How they are offered")) {
            // **Il livello della spinta sta qui dal 2026-08-12**, per mia decisione:
            // *«il livello per i push-ups secondo me deve andare nel gruppo esercizi e non in
            // profilo»*. Ha ragione, ed è la stessa regola per cui i rinvii sono andati in
            // «Cadenza»: dice quale movimento ti viene proposto, quindi appartiene agli esercizi.
            // In «Profilo» stavano le tre risposte del primo avvio, ed è lì che si era fermato.
            conNota(L.t("Automatica segue il sesso dichiarato in Profilo: sulle ginocchia per le donne, a terra per gli uomini. Scegliendo tu, la scelta vale sempre, anche dentro il circuito e nelle varianti.",
                        "Automatic follows the sex declared in Profile: on the knees for women, on the floor for men. If you choose yourself, your choice always holds — inside the circuit and in the variants too.")) {
                Picker(L.t("Livello per i push-up", "Push-up level"), selection: $draft.pushVariant) {
                    Text(L.t("automatica", "automatic")).tag(ExerciseKind?.none)
                    Text(L.t("al muro", "wall")).tag(ExerciseKind?.some(.wallPushUp))
                    Text(L.t("sulle ginocchia", "knees")).tag(ExerciseKind?.some(.kneePushUp))
                    Text(L.t("su rialzo", "elevated")).tag(ExerciseKind?.some(.inclinePushUp))
                    Text(L.t("a terra", "floor")).tag(ExerciseKind?.some(.pushUp))
                }
                .pickerStyle(.menu)
            }
            conNota(L.t("Durante una pausa push-up puoi passare a diamond, archer, dip su sedia, pike o inclinati con un clic. Le ripetizioni si adeguano alla difficoltà.",
                        "During a push-up break you can switch to diamond, archer, chair dips, pike or incline with one click. The reps adjust to the difficulty.")) {
                Toggle(L.t("Offri le varianti dentro la pausa", "Offer variants during the break"), isOn: vivo(\.offerVariants))
            }
            // **Una scelta, non due interruttori.** La spiegazione segue la voce scelta: dire
            // tutte e tre le cose insieme costringeva a leggerne due che non riguardavano te.
            conNota(draft.circuitMode.explanation) {
                Picker(L.t("Nelle pause piene", "In full breaks"), selection: $draft.circuitMode) {
                    ForEach(CircuitMode.allCases, id: \.self) { Text($0.localizedName).tag($0) }
                }
                .pickerStyle(.menu)
            }
        }
    }

    /// **La voce Zen**, che dal 2026-08-11 è una pagina sua e non più una sezione dentro gli
    /// esercizi (mia richiesta esplicita).
    ///
    /// Ha una pagina perché ha bisogno di spiegare, e una sezione dentro un'altra pagina non ha
    /// posto per farlo: il respiro non compare nell'elenco degli esercizi, quindi chi cerca lì
    /// «e se non posso muovermi» non trova niente, e chi accende l'interruttore senza leggere non
    /// sa perché dovrebbe funzionare. La riga di guardia sul fatto che Zen spegne gli esercizi
    /// resta nella pagina Esercizi, dove serve.
    @ViewBuilder
    private var zenSection: some View {
        SwiftUI.Section {
            conNota(L.t("Le pause chiedono un respiro guidato invece di un esercizio: si fa da seduti, senza cambiarsi e senza farsi notare. Vale sia per le micro-pause sia per quelle piene.",
                        "Breaks ask for guided breathing instead of an exercise: you do it seated, without changing clothes and without being noticed. It applies to both micro-breaks and full ones.")) {
                Toggle(L.t("Modalità Zen", "Zen mode"), isOn: vivo(\.zenMode))
            }
        }

        // **Il perché sta prima degli interruttori, non dopo.** Un'app che chiede di respirare
        // novanta secondi deve dire su cosa agisce, altrimenti chiede un atto di fede. La riga
        // non è scritta a mano: `Evidence.slowBreathing` è la stessa fonte che governa i cinque
        // secondi del protocollo a risonanza, quindi meccanismo e numero non possono divergere.
        SwiftUI.Section(L.t("Perché funziona", "Why it works")) {
            Text(L.t("Il respiro è l'unica funzione automatica che puoi prendere in mano, e rallentandolo sposti l'equilibrio del sistema nervoso verso la parte che frena invece di quella che accelera. Il segnale si misura: la variabilità del battito cardiaco a mediazione vagale sale mentre respiri lento, e resta più alta anche dopo. L'espirazione lunga conta più dell'inspirazione, perché è nella fase in cui butti fuori l'aria che il freno vagale agisce di più. Attorno ai sei respiri al minuto cuore e respiro entrano in fase, ed è lì che l'effetto è più grande.",
                     "Breathing is the one automatic function you can take over, and slowing it shifts the balance of the nervous system towards the part that brakes rather than the part that accelerates. The signal is measurable: vagally-mediated heart rate variability rises while you breathe slowly, and stays higher afterwards. The long exhale matters more than the inhale, because it is while you let the air out that the vagal brake acts most. Around six breaths a minute heart and breath fall into phase, and that is where the effect is largest."))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(Evidence.slowBreathing.shortCitation), \(String(Evidence.slowBreathing.year)).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        SwiftUI.Section(L.t("Quale respiro", "Which breathing")) {
            // **Due scelte e non una**, perché le due pause non chiedono la stessa cosa: la
            // piena dura quanto la sessione misurata da Laborde, la micro non dura quanto
            // niente di misurato. Il perché sta nella riga sotto ognuna, che cambia con la voce
            // scelta come già fa il circuito.
            conNota(draft.zenProtocolShort.explanation) {
                Picker(L.t("Nelle micro-pause", "In micro-breaks"), selection: $draft.zenProtocolShort) {
                    ForEach(BreathProtocol.allCases, id: \.self) { Text($0.localizedName).tag($0) }
                }
                .pickerStyle(.menu)
            }
            conNota(draft.zenProtocolLong.explanation) {
                Picker(L.t("Nelle pause piene", "In full breaks"), selection: $draft.zenProtocolLong) {
                    ForEach(BreathProtocol.allCases, id: \.self) { Text($0.localizedName).tag($0) }
                }
                .pickerStyle(.menu)
            }
            conNota(L.t("Le sessioni singole da 5, 10, 15 e 20 minuti danno lo stesso effetto sull'attività vagale, quindi più lungo non è meglio. Sotto i cinque minuti però non ha misurato nessuno: novanta secondi sono una scelta di comodità, non un numero preso da uno studio. Quello che avanza della pausa resta riposo.",
                        "Single sessions of 5, 10, 15 and 20 minutes give the same effect on vagal activity, so longer is not better. Below five minutes, though, nobody has measured: ninety seconds is a comfort choice, not a number from a study. What is left of the break stays rest.")) {
                Picker(L.t("Per quanto", "For how long"), selection: $draft.zenBreathSeconds) {
                    Text(L.t("60 secondi", "60 seconds")).tag(60.0)
                    Text(L.t("90 secondi", "90 seconds")).tag(90.0)
                    Text(L.t("3 minuti", "3 minutes")).tag(180.0)
                    Text(L.t("5 minuti, la dose studiata", "5 minutes, the studied dose")).tag(300.0)
                }
                .pickerStyle(.menu)
            }
        }

        // Il tetto è l'ultima cosa che si legge e viene dalla fonte, non da me.
        SwiftUI.Section(L.t("Quanto vale, e quanto no", "What it is worth, and what it is not")) {
            Text(Evidence.breathworkCeiling.localizedClaim)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(Evidence.breathworkCeiling.shortCitation), \(String(Evidence.breathworkCeiling.year)).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var interruzioniSection: some View {
        SwiftUI.Section {
            Toggle(L.t("Rimanda se un microfono è in uso (call)", "Defer while a microphone is in use (a call)"), isOn: vivo(\.deferWhenMicrophoneActive))
            conNota(L.t("Un film o un PDF sono immobilità perfetta, e senza questo guardare Netflix vale come una pausa ben fatta. Tetti senza un solo input: 45 min per un video, 15 per un documento. Una call non ha tetto, perché una riunione lunga è la seduta più lunga della giornata.",
                        "A film or a PDF is perfect stillness: without this, watching Netflix counts as a well-taken break. Caps without a single input: 45 min for a video, 15 for reading. A call has no cap, because a long meeting is the longest sit of the day.")) {
                Toggle(L.t("Conta anche video e lettura come tempo fermo", "Count video and reading as sitting time too"), isOn: vivo(\.detectQuietPresence))
            }
        }

        // I rinvii stavano qui e dal 2026-08-12 stanno in «Cadenza», che è il gruppo del campo a
        // cui appartengono. Resta la frase per saltare, che è davvero una via d'uscita e non un
        // parametro della cadenza.
        SwiftUI.Section(L.t("Vie d'uscita", "Ways out")) {
            LabeledContent(L.t("Frase per saltare", "Skip phrase")) {
                TextField("", text: $draft.escapePhrase).frame(width: 180)
            }
        }

        // **La sezione ha un titolo, e dentro una riga dice lo stato a parole.** Con il solo
        // interruttore spento la pagina non affermava niente: bisognava dedurre «allora è sempre
        // attivo» dall'assenza di una finestra, e dedurre non è leggere. Visto all'uso
        // il 2026-08-04: *«non dice che è sempre attivo»*. La riga è **derivata**, non un'altra
        // impostazione — dice cosa farà il motore, e si riscrive da sola quando cambi le ore.
        SwiftUI.Section(L.t("Quando interrompe", "When it interrupts")) {
            // **Le due frecce restano sempre a schermo, spente finché l'interruttore è acceso**
            // (2026-08-04, sua richiesta esplicita: *«sia comunque mostrata grigia, che vuol dire
            // che non è selezionabile, però è lì»*). Nasconderle era la prima versione, ed era
            // peggio: un comando che sparisce non insegna che esiste, e chi vuole il silenzio
            // notturno deve prima indovinare che spegnendo l'interruttore comparirà qualcosa.
            // Grigie dicono due cose insieme — la finestra esiste, e adesso non conta.
            conNota(draft.activeHoursAlwaysOn
                    ? L.t("Accendi «Personalizzato» per tenere una finestra di silenzio, per esempio la notte.",
                          "Turn on “Custom” to keep a quiet window, at night for instance.")
                    : L.t("Fuori da questa finestra Otium non interrompe.",
                          "Outside this window Otium does not interrupt.")) {
                // **Una riga per comando, tutte allineate sullo stesso bordo destro.** La prima
                // versione metteva un interruttore e due frecce a distanze diverse dal margine, e
                // il risultato non era brutto per gusto: era brutto perché *niente* era in linea
                // con niente. Visto all'uso il 2026-08-04: *«troppo attaccato, non è
                // armonioso»*.
                //
                // Il selettore a due caselle è la stessa forma di Lingua e Sesso, che sono già
                // nella finestra: la coerenza dentro l'app vale più di somigliare a un pannello
                // di sistema. Le ore si scrivono **07:00**, non `7`, perché un numero nudo è una
                // quantità e questa è un'ora del giorno.
                // **Un interruttore, come gli altri due della pagina.** Il selettore a due caselle
                // era la versione di mezzo, e il difetto era che nessun altro comando qui dentro
                // è fatto così: due interruttori sopra, due frecce accanto, e in mezzo un
                // segmento che non si allineava con nessuno dei due. La forma giusta era già
                // sulla pagina.
                //
                // **Acceso vuol dire «personalizzato», non «attivo».** Il campo sotto resta
                // `activeHoursAlwaysOn` perché è così che lo legge il motore, ma l'interruttore
                // dice la cosa che *aggiunge* qualcosa: un interruttore chiamato «Attivo sempre»
                // spegne una funzione accendendosi, e si legge al contrario.
                // Dodici punti fra le righe invece dei sei di `conNota`: tre comandi a sei punti
                // l'uno dall'altro si leggono come un blocco unico, ed è il secondo rilievo dello
                // stesso pomeriggio sulla stessa sezione.
                VStack(alignment: .leading, spacing: 12) {
                LabeledContent(L.t("Otium interrompe", "Otium interrupts")) {
                    Text(statoOrario)
                        .foregroundStyle(Palette.accentOnWindow)
                        .fontWeight(.medium)
                }
                // Rovesciato, e vivo come ogni altro interruttore: il campo dice «sempre attivo»,
                // l'interruttore dice la cosa che *aggiunge* qualcosa.
                Toggle(L.t("Personalizzato", "Custom"),
                       isOn: Binding(get: { !draft.activeHoursAlwaysOn },
                                     set: { vivo(\.activeHoursAlwaysOn).wrappedValue = !$0 }))
                // Il numero a sinistra e le frecce all'estremità, con otto punti in mezzo: è la
                // stessa geometria dei rinvii a mano, che dal 2026-08-12 vivono in «Cadenza».
                // Attaccati erano il rilievo del 2026-08-04 — *«le parti sulla destra sono troppo
                // appiccicate»*.
                LabeledContent(L.t("Dalle", "From")) {
                    oraSelettore($draft.activeFromHour)
                }
                .disabled(draft.activeHoursAlwaysOn)
                LabeledContent(L.t("Alle", "To")) {
                    oraSelettore($draft.activeToHour)
                }
                .disabled(draft.activeHoursAlwaysOn)
                }
            }
        }
    }

    /// Lo stato a parole, derivato dalle impostazioni e mai scritto due volte. È l'unica riga
    /// della sezione che non si può cambiare: si legge.
    private var statoOrario: String {
        guard !draft.activeHoursAlwaysOn else {
            return L.t("sempre, a qualunque ora", "always, at any hour")
        }
        let da = String(format: "%02d:00", draft.activeFromHour)
        let a = String(format: "%02d:00", draft.activeToHour)
        return L.t("dalle \(da) alle \(a)", "from \(da) to \(a)")
    }

    /// **Il valore sta a destra, attaccato alle frecce, come ogni altro comando della finestra.**
    ///
    /// Mia richiesta, 2026-08-12, guardando «Pausa piena ogni 3 micro-pause»: *«il
    /// numero dovrebbe essere messo vicino alle frecce completamente a destra»*. Lo `Stepper` con
    /// etichetta fa l'opposto — testo a sinistra, numero dentro il testo, frecce sole sul bordo —
    /// quindi il numero cadeva a metà riga mentre tutti gli altri valori della pagina sono
    /// incolonnati a destra, e nessuna spaziatura poteva ripararlo.
    ///
    /// Non è una forma nuova: è quella che `oraSelettore` usava già per «Dalle 07:00», ora tenuta
    /// in un posto solo perché quattro righe la usano e quattro copie divergono.
    ///
    /// **Numero scuro, unità tenue**, che è la forma già usata da «Intervallo 30 min» e da
    /// «Preavviso 60 s». `LabeledContent` dipinge da sé in secondario il proprio contenuto quando è
    /// testo: nella prima versione «3 micro-pause» e «2» uscivano grigi in mezzo a valori neri, e
    /// il numero che stavo spostando per renderlo leggibile era il più smorto della pagina. Visto
    /// nella fotografia del pannello intero, non nel codice.
    private func numeroSelettore(_ valore: Binding<Int>, in intervallo: ClosedRange<Int>,
                                 unità: String = "",
                                 numero: @escaping (Int) -> String = { "\($0)" }) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Text(numero(valore.wrappedValue))
                    .monospacedDigit()
                    .foregroundStyle(Palette.text)
                if !unità.isEmpty {
                    Text(unità).foregroundStyle(.secondary)
                }
            }
            Stepper("", value: valore, in: intervallo)
                .labelsHidden()
        }
    }

    /// L'ora del giorno. Le frecce restano un controllo di sistema — tastiera e VoiceOver ci
    /// arrivano — ma l'etichetta è nostra, perché quella dello `Stepper` si incolla alle frecce e
    /// non si può distanziare.
    private func oraSelettore(_ ora: Binding<Int>) -> some View {
        numeroSelettore(ora, in: 0...23) { String(format: "%02d:00", $0) }
    }

    @ViewBuilder
    private var aspettoSection: some View {
        SwiftUI.Section {
            conNota(draft.theme.palette.description) {
                Picker(L.t("Livrea", "Theme"), selection: $draft.theme) {
                    ForEach(ThemeName.allCases, id: \.self) { Text($0.palette.name).tag($0) }
                }
            }
            LabeledContent(L.t("Suono del preavviso", "Warning sound")) {
                HStack {
                    Picker("", selection: $draft.notificationSound) {
                        Text(L.t("nessuno", "none")).tag(NotificationSounds.silent)
                        ForEach(NotificationSounds.names, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                    // Sceglierlo senza sentirlo è come scegliere un colore al buio.
                    Button(L.t("ascolta", "play")) {
                        model.previewSound(draft.notificationSound, volume: draft.soundVolume)
                    }
                    .disabled(draft.notificationSound.isEmpty)
                }
            }
            // **Un secondo suono, perché sono due momenti diversi.** Il preavviso arriva mentre
            // lavori e lo puoi ignorare; questo chiude una tenuta, e ti arriva mentre sei a terra
            // con gli occhi sul pavimento. Se fossero lo stesso suono, l'unico modo di sapere
            // quale dei due è suonato sarebbe alzare la testa.
            conNota(L.t("Chiude plank, plank laterale e hollow hold. Durante la tenuta due tocchi brevi ti avvisano del cambio di lato.",
                        "Ends plank, side plank and hollow hold. During the hold two short taps warn you about the side switch.")) {
                LabeledContent(L.t("Suono di fine tenuta", "Hold end sound")) {
                    HStack {
                        Picker("", selection: $draft.holdEndSound) {
                            Text(L.t("nessuno", "none")).tag(NotificationSounds.silent)
                            ForEach(NotificationSounds.names, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                        Button(L.t("ascolta", "play")) {
                            model.previewSound(draft.holdEndSound, volume: draft.soundVolume)
                        }
                        .disabled(draft.holdEndSound.isEmpty)
                    }
                }
            }
            // **Il volume sta sotto i due suoni perché vale per tutti e due**, più i tocchi del
            // cambio lato e il via del respiro. Sopra sarebbe una manopola che governa qualcosa
            // che non hai ancora scelto.
            conNota(L.t("Vale per il preavviso, la fine della tenuta e i tocchi durante gli esercizi. È una quota del volume del Mac: puoi stare più piano di quello che stai ascoltando, non più forte, e col Mac muto non si sente niente.",
                        "Applies to the warning, the hold end and the taps during exercises. It is a share of your Mac's volume: you can stay quieter than what you are listening to, not louder, and with the Mac muted nothing comes through.")) {
                LabeledContent(L.t("Volume dei suoni", "Sound volume")) {
                    HStack(spacing: 8) {
                        // Numero prima del comando, come nei selettori numerici delle altre
                        // pagine: il valore si legge senza doverlo dedurre dalla posizione.
                        Text(percentuale(draft.soundVolume))
                            .monospacedDigit()
                            .foregroundStyle(Palette.text)
                            // Allineato a destra: così il numero sta sempre alla stessa distanza
                            // dal cursore e le cifre non ballano quando passa da 100% a 5%.
                            .frame(width: 44, alignment: .trailing)
                        // Il cursore è dell'app, non del Mac: senza la tinta arriverebbe col blu
                        // di sistema in mezzo a una livrea che ha il suo accento.
                        Slider(value: $draft.soundVolume, in: 0...1, step: 0.05)
                            .tint(Palette.accent)
                            .frame(width: 98)
                        Button(L.t("ascolta", "play")) {
                            model.previewSound(suonoDiProva, volume: draft.soundVolume)
                        }
                        .disabled(suonoDiProva.isEmpty)
                    }
                }
            }
        }
    }

    /// Il suono con cui si prova il volume: il preavviso, o la fine tenuta se il preavviso è muto.
    /// Provare il volume con un suono spento non direbbe niente, e a suoni entrambi spenti il
    /// pulsante si spegne invece di non fare niente quando lo premi.
    private var suonoDiProva: String {
        draft.notificationSound.isEmpty ? draft.holdEndSound : draft.notificationSound
    }

    /// Il volume scritto come lo leggi tu. `0,05` di passo non produce mai decimali, quindi
    /// l'arrotondamento non nasconde nulla.
    private func percentuale(_ valore: Double) -> String {
        "\(Int((valore * 100).rounded()))%"
    }

    /// Le tre cose che si aprono una volta ogni tanto, con accanto la riga che dice cosa sono.
    ///
    /// Stavano nel menu della barra di stato, che è la lista delle cose che fai spesso, e due su
    /// tre erano nomi senza spiegazione: «Apri il registro» non dice a nessuno cosa ci trova
    /// dentro. Spostate qui il 2026-07-31 per mia scelta.
    @ViewBuilder
    private var avanzateSection: some View {
        // **L'avvio automatico stava da solo in una voce sua** e la riempiva per un quarto, con
        // una riga di stato in mezzo a tanto vuoto. Visto all'uso il 2026-07-31: una
        // voce di menu che contiene una cosa sola è una voce che fa perdere tempo a chi la cerca.
        // Qui sta con le altre cose di macchina, prima delle fonti perché è l'unica che si tocca.
        sistemaSection

        SwiftUI.Section(L.t("Le fonti", "The sources")) {
            Button(L.t("Da dove vengono questi numeri…", "Where these numbers come from…")) {
                model.onShowEvidence?()
            }
            Text(L.t("Ogni parametro di Otium — ogni quanto interrompe, quanto dura la pausa, quante ripetizioni — risponde a uno studio, con autore, rivista e anno. In fondo ci sono anche le cose che l'app NON fa e non promette.",
                     "Every parameter in Otium — how often it interrupts, how long the break lasts, how many reps — answers to a study, with author, journal and year. At the end there are also the things the app does NOT do and does not promise."))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        SwiftUI.Section(L.t("Il registro", "The log")) {
            Button(L.t("Apri il registro", "Open the log")) { model.onRevealLedger?() }
            Text(L.t("Un file di testo dove finisce, riga per riga, tutto quello che è successo: i minuti al Mac, le pause fatte, saltate e spontanee, e ogni esercizio con le sue ripetizioni. È la sola verità da cui l'app ricava le statistiche — non c'è un secondo conto da qualche parte — e non esce mai da questo Mac. Serve a due cose: guardare i tuoi dati con i tuoi strumenti, e portarteli via.",
                     "A text file where everything that happened is written line by line: the minutes at the Mac, the breaks taken, skipped and spontaneous, and every exercise with its reps. It is the single truth the app derives its statistics from — there is no second tally anywhere — and it never leaves this Mac. It is there for two things: looking at your own data with your own tools, and taking it with you."))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        SwiftUI.Section(L.t("Diagnostica", "Diagnostics")) {
            Button(L.t("Apri la diagnostica…", "Open diagnostics…")) { model.onShowDoctor?() }
            Text(L.t("Il controllo di salute dell'app: permessi, avvio automatico, integrità del registro, orologio. È la finestra da aprire quando qualcosa non va.",
                     "The app's health check: permissions, start at login, log integrity, clock. It is the window to open when something is wrong."))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        // **La segnalazione sta accanto alla diagnostica**, perché è il gesto dopo: si guarda cosa
        // è rotto e lo si dice a qualcuno. La strada c'era già, ma passava dal copiare a mano un
        // referto dentro una pagina da trovare da soli, e nessuno lo fa mentre è arrabbiato.
        SwiftUI.Section(L.t("Segnalazioni", "Reporting")) {
            Button(L.t("Segnala un problema…", "Report a problem…")) { model.onReportIssue?() }
            Text(L.t("Apre su GitHub una segnalazione già compilata con versione, sistema e diagnostica: resta da scrivere cosa è successo. L'app non manda niente da sola, apre la pagina nel browser, e quello che parte lo decidi tu dopo averlo letto.",
                     "Opens a GitHub issue already filled in with version, system and diagnostics: what is left is describing what happened. The app sends nothing by itself, it opens the page in your browser, and you decide what goes out after reading it."))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var sistemaSection: some View {
        SwiftUI.Section(L.t("Avvio automatico", "Start at login")) {
            switch model.loginItemState {
            case .notRegistered:
                HStack {
                    Text(L.t("Otium non riparte da sola.", "Otium does not restart on its own.")).foregroundStyle(.secondary)
                    Spacer()
                    Button(L.t("Attiva", "Turn on")) { model.enableLoginItem() }
                }
            case .enabled:
                HStack {
                    // Il verde di sistema qui era l'unico colore della finestra che non veniva
                    // dalla livrea: verde mela accanto al verde alloro, e si vedeva. Visto all'uso
                    // il 2026-07-31. L'arancione degli avvisi qui sotto resta,
                    // perché quello non è una livrea, è un semaforo.
                    Label(L.t("Attivo: Otium parte all'accensione", "On: Otium starts at login"), systemImage: "checkmark.seal")
                        .foregroundStyle(Palette.accentOnWindow)
                    Spacer()
                    Button(L.t("Rimuovi", "Remove")) { model.disableLoginItem() }
                }
            case .requiresApproval:
                // **L'app non prova a riaccenderlo da sé.** L'interruttore è in Impostazioni di
                // Sistema, è tuo, e l'unica cosa onesta che Otium può fare è portarti lì.
                VStack(alignment: .leading) {
                    Label(L.t("Spento da te in Impostazioni di Sistema", "Turned off by you in System Settings"),
                          systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    Text(L.t("Otium resta registrata, ma non partirà finché non riaccendi l'interruttore. Può farlo solo tu.",
                             "Otium stays registered but will not start until you turn the switch back on. Only you can."))
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(L.t("Apri Impostazioni di Sistema", "Open System Settings")) { model.openLoginItemsSettings() }
                }
            case .notFound:
                // Non è un guasto da riparare con un bottone: è l'app lanciata da fuori un
                // bundle, cioè il binario di sviluppo. Dirlo è più utile che offrire una cura
                // che non curerebbe niente.
                VStack(alignment: .leading) {
                    Label(L.t("Questa copia non è registrabile", "This copy cannot be registered"),
                          systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    Text(L.t("macOS registra l'avvio automatico di un'app dentro il suo bundle. Stai usando Otium fuori da un «.app» — di solito il binario di sviluppo. Apri Otium.app e l'avvio automatico torna disponibile.",
                             "macOS registers start at login for an app inside its bundle. You are running Otium outside a “.app” — usually the development binary. Open Otium.app and start at login becomes available again."))
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// Un controllo e la sua spiegazione sono **una riga sola**.
    ///
    /// In un `Form` raggruppato ogni figlio diretto della `Section` diventa una riga, e fra due
    /// righe macOS disegna un divisore. Interruttore e nota erano due figli, quindi c'era una
    /// linea in mezzo: la nota sembrava riferita a quello **sotto** invece che a quello sopra.
    /// Visto all'uso il 2026-07-31 guardando le preferenze — *«tra parti dello stesso
    /// contesto non deve esserci quella linea»*.
    ///
    /// Non si toglie il divisore, si smette di produrlo: i due stanno in una `VStack`, cioè in un
    /// figlio solo, e la linea resta dov'è utile — fra un'impostazione e la prossima.
    @ViewBuilder
    private func conNota<C: View>(_ nota: String, @ViewBuilder _ contenuto: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            contenuto()
            Text(nota)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Quanti esercizi girano in questa famiglia, e quanti ce ne sono. È il numero nella
    /// linguetta: senza, aprire un pannello per volta costerebbe la vista d'insieme.
    private func attivi(_ c: ExerciseCategory) -> Int {
        ExerciseKind.allCases.filter { $0.category == c }.count { binding(for: $0).wrappedValue }
    }

    private func totali(_ c: ExerciseCategory) -> Int {
        ExerciseKind.allCases.count { $0.category == c }
    }

    /// «Tutti» e «nessuno» su una famiglia intera. `nessuno` non può svuotare del tutto un pool:
    /// una rotazione senza esercizi non è una preferenza, è un'app che non fa più niente — e il
    /// modello ricadrebbe comunque sul suo default, mentendo alla casella.
    ///
    /// **Una scrittura sola per clic**, non una per esercizio: passando dalle singole caselle,
    /// «nessuno» su una famiglia da sette salverebbe sette volte, e le prime sei di quelle scritture
    /// direbbero una cosa che non hai chiesto.
    private func setAll(_ category: ExerciseCategory, on: Bool) {
        let kinds = ExerciseKind.allCases.filter { $0.category == category }
        for pool in Set(kinds.map(poolKeyPath(for:))) {
            var next = draft[keyPath: pool]
            let miei = kinds.filter { poolKeyPath(for: $0) == pool }
            if on {
                next.append(contentsOf: miei.filter { !next.contains($0) })
            } else {
                next.removeAll { miei.contains($0) }
            }
            vivo(pool).wrappedValue = next.isEmpty ? [fallback(for: pool)] : next
        }
    }

    /// Le caselle degli esercizi sono interruttori, quindi si applicano da sole (regola del
    /// 2026-08-12, vedi `vivo`). Il pool non resta mai vuoto: il difetto sarebbe silenzioso,
    /// perché il modello ricadrebbe sul suo default e la casella spenta racconterebbe un'altra cosa.
    private func binding(for kind: ExerciseKind) -> Binding<Bool> {
        let pool = poolKeyPath(for: kind)
        return Binding(
            get: { draft[keyPath: pool].contains(kind) },
            set: { on in
                var next = draft[keyPath: pool]
                if on {
                    if !next.contains(kind) { next.append(kind) }
                } else {
                    next.removeAll { $0 == kind }
                }
                vivo(pool).wrappedValue = next.isEmpty ? [fallback(for: pool)] : next
            }
        )
    }

    private func poolKeyPath(for kind: ExerciseKind) -> WritableKeyPath<OtiumCore.Settings, [ExerciseKind]> {
        kind.isVigorous ? \.vigorousPool : \.exercisePool
    }

    private func fallback(for pool: WritableKeyPath<OtiumCore.Settings, [ExerciseKind]>) -> ExerciseKind {
        pool == \OtiumCore.Settings.vigorousPool ? .jumpingJack : .squat
    }

    private func minuteField(_ value: Binding<Double>) -> some View {
        HStack {
            TextField("", value: Binding(
                get: { Int(value.wrappedValue / 60) },
                set: { value.wrappedValue = Double(max(1, $0)) * 60 }
            ), format: .number)
            .frame(width: 60)
            Text(L.t("min", "min")).foregroundStyle(.secondary)
        }
    }

    private func secondField(_ value: Binding<Double>) -> some View {
        HStack {
            TextField("", value: Binding(
                get: { Int(value.wrappedValue) },
                set: { value.wrappedValue = Double(max(0, $0)) }
            ), format: .number)
            .frame(width: 60)
            Text("s").foregroundStyle(.secondary)
        }
    }

    /// Cosa ti ha portato fuori dai preset, campo per campo.
    ///
    /// **Esiste per un caso vero, non per completezza.** Il 2026-07-31 ho trovato
    /// «personalizzata» senza aver toccato la cadenza: la trappola era che «consenti N rinvii a
    /// mano» viveva nel pannello *Interruzioni* pur essendo un campo della *cadenza*, quindi
    /// cambiarlo spostava un preset che stava due voci più in là.
    ///
    /// **Il 2026-08-12 il campo è stato spostato**, cioè la cura vera, ed è stata sua la chiamata
    /// contro la riga che stava qui («nessuno cerca i rinvii sotto Cadenza»): un campo che governa
    /// la cadenza sta con la cadenza, e la vicinanza rende visibile l'effetto sul preset invece di
    /// doverlo spiegare. Questa spiegazione resta perché gli altri cinque campi possono ancora
    /// portarti fuori dai preset, ed è giusto che l'app dica quale.
    private func differenzeDalPresetPiuVicino() -> String {
        let c = draft.cadence

        func scarti(_ p: Cadence) -> [String] {
            var out: [String] = []
            if c.intervalSeconds != p.intervalSeconds {
                out.append(L.t("intervallo \(Int(c.intervalSeconds / 60)) min", "interval \(Int(c.intervalSeconds / 60)) min"))
            }
            if c.microDurationSeconds != p.microDurationSeconds {
                out.append(L.t("micro-pausa \(Int(c.microDurationSeconds)) s", "micro-break \(Int(c.microDurationSeconds)) s"))
            }
            if c.longDurationSeconds != p.longDurationSeconds {
                out.append(L.t("pausa piena \(Int(c.longDurationSeconds / 60)) min", "full break \(Int(c.longDurationSeconds / 60)) min"))
            }
            if c.longEveryNBreaks != p.longEveryNBreaks {
                out.append(L.t("piena ogni \(c.longEveryNBreaks)", "full every \(c.longEveryNBreaks)"))
            }
            if c.warningSeconds != p.warningSeconds {
                out.append(L.t("preavviso \(Int(c.warningSeconds)) s", "warning \(Int(c.warningSeconds)) s"))
            }
            if c.postponesAllowed != p.postponesAllowed {
                out.append(L.t("\(c.postponesAllowed) rinvii a mano", "\(c.postponesAllowed) manual postponements"))
            }
            return out
        }

        // Il preset più vicino è quello da cui ti scosti di meno: dirti che sei «lontano da A»
        // quando hai cambiato un campo solo rispetto a B sarebbe una diagnosi peggiore di niente.
        let migliore = [("A", Cadence.optionA), ("B", .optionB), ("C", .optionC)]
            .map { ($0.0, scarti($0.1)) }
            .min { $0.1.count < $1.1.count }
        guard let migliore, !migliore.1.isEmpty else {
            return L.t("valori fuori dai preset", "values outside the presets")
        }
        return migliore.1.joined(separator: ", ")
            + L.t(" (invece del preset \(migliore.0))", " (instead of preset \(migliore.0))")
    }

    private func presetName(_ c: Cadence) -> String {
        if c == .optionA { return "A" }
        if c == .optionB { return "B" }
        if c == .optionC { return "C" }
        return "X"
    }

    private func applyPreset(_ name: String) {
        switch name {
        case "A": draft.cadence = .optionA
        case "B": draft.cadence = .optionB
        case "C": draft.cadence = .optionC
        default: break
        }
    }
}

// MARK: - Statistiche

/// La scheda: una sola forma, un solo raggio, un solo respiro interno.
///
/// Il report prima era un collage — riquadri con bordi diversi, spaziature diverse, titoli di
/// tre misure. Armonia qui non vuol dire "più bello": vuol dire che l'occhio non deve
/// ricominciare da capo a ogni blocco.
private struct Card<Content: View>: View {
    var title: String? = nil
    var subtitle: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    if let subtitle {
                        Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct StatsView: View {
    @ObservedObject var model: AppModel
    /// Il periodo scelto vive nel **modello**, non nella vista: la finestra viene ricostruita a
    /// ogni apertura per non mostrare i numeri di quando l'hai chiusa, e uno `@State` qui
    /// riporterebbe la scelta su «Oggi» ogni volta.
    /// Solo per `--snapshot --surface=stats --expanded`: un gruppo chiuso in un'immagine ferma
    /// non mostra cosa c'è dentro, e quello che non si vede non si può dire di aver verificato.
    /// A schermo i gruppi partono chiusi — la carta deve restare compatta.
    static var expandGroupsForSnapshot = false
    @State private var openGroups: Set<String> = []

    private var period: StatsPeriod { model.statsPeriod }
    private var stats: PeriodStats { model.stats(for: period) }
    private var previous: PeriodStats { model.previousStats(for: period) }

    /// Le due pagine della finestra. **Il periodo vale solo sul riepilogo**: la crescita si legge
    /// per forza su tutto il registro, perché una progressione guardata dentro «Oggi» non è una
    /// progressione. Per questo il selettore del periodo sparisce sulla seconda pagina invece di
    /// restare lì a non fare niente.
    enum Page: String, CaseIterable, Hashable {
        case allenamento, pause
        var title: String {
            switch self {
            case .allenamento: return L.t("Allenamento", "Training")
            case .pause:       return L.t("Pause", "Breaks")
            }
        }
    }

    /// Solo per la sonda: `--surface=stats --pagina=crescita` apre già sulla seconda pagina.
    /// Senza, una fotografia della finestra mostrerebbe per sempre solo la prima, che è
    /// esattamente il modo in cui una pagina nuova resta non verificata.
    static var initialPageForSnapshot: Page = .allenamento

    @State private var page: Page = StatsView.initialPageForSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch page {
                    // **Prima l'allenamento, poi le pause** (2026-08-04, sua richiesta). Le due
                    // pagine adesso rispondono a due domande diverse invece che a «tutto» e «una
                    // cosa»: cosa sto facendo col corpo, e come sta andando la disciplina delle
                    // interruzioni. Gli esercizi svolti sono passati di qua perché sono
                    // allenamento, non contabilità delle pause.
                    case .allenamento:
                        growthPage
                        muscleCards
                    case .pause:
                        numbers
                        compliance
                        hourStrip
                        insights
                    }
                }
                .padding(.horizontal, 22).padding(.bottom, 24)
            }
        }
        .frame(minWidth: 640, minHeight: 540)
        .livrea()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Otium").font(.system(size: 22, weight: .semibold, design: .rounded))   // lingua: ok nome proprio
                Spacer()
                pagePicker
            }
            if page == .pause { periodPicker }
        }
        .padding(.horizontal, 22).padding(.top, 18).padding(.bottom, 14)
    }

    private var pagePicker: some View {
        SegmentedChoice(options: Page.allCases.map { ($0, $0.title) }, selection: $page)
    }

    // MARK: - La pagina della crescita

    /// **Quello che è successo, non quello che l'app promette.** Il moltiplicatore della
    /// progressione dice dove sei arrivato; qui accanto c'è la prima conferma e l'ultima, che è
    /// la stessa cosa detta da chi le ha fatte. Quando i due numeri divergono ha ragione il
    /// secondo, e vederli insieme è tutto il punto della pagina.
    ///
    /// Decisa il 2026-08-04: *«far vedere come quei numeri stanno aumentando»*.
    @ViewBuilder
    private var growthPage: some View {
        let report = model.growth()
        if report.lines.isEmpty {
            Text(L.t("Nessun esercizio confermato, ancora. La crescita comincia alla prima pausa fatta davvero.",
                     "No exercise confirmed yet. Growth starts at the first break you actually do."))
                .foregroundStyle(.secondary)
                .padding(.vertical, 30)
        } else {
            HStack(spacing: 10) {
                tile("\(report.totalReps)",
                     plural(report.totalReps, it: "ripetizione", "ripetizioni", en: "rep", "reps"),
                     delta: nil, riservaSpazioDelta: false)
                tile("\(report.activeDays)",
                     plural(report.activeDays, it: "giorno", "giorni", en: "day", "days"),
                     delta: nil, riservaSpazioDelta: false)
                tile("\(report.grownCount)/\(report.measuredCount)",
                     L.t("oltre il 100%", "past 100%"), delta: nil, riservaSpazioDelta: false)
            }
            // **Una legenda, perché il grafico non si spiegava da solo.** Le barre erano lì e
            // basta, e ho chiesto cosa fossero: *«non capisco le barre che sono in
            // mezzo»*. Un grafico che ha bisogno di essere chiesto è un grafico senza etichetta,
            // non un grafico difficile.
            Text(L.t("Ogni barra è una pausa, in ordine di tempo: l'altezza sono le ripetizioni di quella volta. La percentuale dice dove sei rispetto a quante ne erano previste.",
                     "Each bar is one break, in time order: its height is the reps you did that time. The percentage says where you are against how many were prescribed."))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !model.settings.progressBeyondFull {
                Text(L.t("La crescita oltre il 100% è spenta, quindi l'app non ti proporrà più ripetizioni in più. Quello che vedi qui resta la tua storia.",
                         "Growth past 100% is off, so the app will not propose more reps. What you see here is still your history."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                ForEach(Array(report.lines.enumerated()), id: \.offset) { riga in
                    growthRow(riga.element)
                    if riga.offset < report.lines.count - 1 {
                        Divider().opacity(0.35)
                    }
                }
            }
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(Palette.isDarkAppearance ? 0.06 : 0.04))
            )
        }
    }

    private func growthRow(_ line: GrowthLine) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(line.kind.localizedName)
                    .font(.system(size: 13, weight: .medium))
                Text(L.t("\(line.all.count)× · \(line.totalReps) in tutto",
                         "\(line.all.count)× · \(line.totalReps) total"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(width: 190, alignment: .leading)

            sparkline(line.all)
                .frame(height: 26)
                .frame(maxWidth: .infinity)

            // Prima → ultima, che è la crescita come l'hai vissuta. Le tenute sono **secondi**,
            // e scriverne il numero nudo accanto a un push-up direbbe che hai fatto 45 plank.
            // **Il pieno, poi dove sei.** Prima qui c'era «prima conferma → ultima», e la prima
            // conferma cadeva dentro la rampa: tornare al pieno si leggeva come un miglioramento.
            // Il pieno è lo stesso metro per tutti gli esercizi, ed è quello che l'app usa per
            // proporre. Correzione sua, 2026-08-04.
            HStack(spacing: 6) {
                Text("\(line.all.last?.base ?? line.baseReps)").foregroundStyle(.secondary)
                Text("→").foregroundStyle(.secondary)
                Text(line.all.last.map { line.kind.isTimed ? "\($0.reps) s" : "\($0.reps)" } ?? "—")
                    .fontWeight(.semibold)
            }
            .font(.system(size: 13)).monospacedDigit()
            .frame(width: 92, alignment: .trailing)

            // **La variazione vera, non il moltiplicatore.** Prima qui c'era `level`, e accanto a
            // `6 → 4` diceva «110%»: due numeri sulla stessa riga che si contraddicono sono un
            // numero sbagliato. Adesso la pastiglia è la stessa aritmetica delle ripetizioni che
            // ha di fianco, segno compreso — scendere si dice, non si nasconde.
            Text(line.percentOfBase.map { "\($0)%" } ?? "—")
                .font(.system(size: 12, weight: .semibold)).monospacedDigit()
                .foregroundStyle(line.grown ? Palette.onAccentOnWindow : Color.secondary)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(
                    Capsule().fill(line.grown ? Palette.accentOnWindow
                                              : Color.primary.opacity(0.06))
                )
                .frame(width: 72, alignment: .trailing)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
    }

    /// Le barre delle conferme, in ordine di tempo. **Altezza relativa al massimo di quella
    /// riga**, non a un massimo globale: confrontare 45 secondi di plank con 4 push-up su una
    /// scala sola farebbe sparire i push-up, e la domanda qui è «questo esercizio sta salendo?»,
    /// non «quale esercizio è il più grosso».
    private func sparkline(_ values: [GrowthSession]) -> some View {
        let massimo = max(1, values.map(\.reps).max() ?? 1)
        return GeometryReader { geo in
            let spazio: CGFloat = 3
            let larghezza = max(2, (geo.size.width - spazio * CGFloat(max(0, values.count - 1)))
                                / CGFloat(max(1, values.count)))
            HStack(alignment: .bottom, spacing: spazio) {
                ForEach(Array(values.enumerated()), id: \.offset) { barra in
                    // Le stazioni di circuito si vedono ma **non si confondono**: portano meno
                    // volume per costruzione, e messe alla pari del singolo farebbero sembrare
                    // un calo una giornata in cui hai fatto quattro esercizi invece di uno.
                    // **Barre tutte uguali, tranne quelle di circuito.** L'enfasi sull'ultima
                    // l'ho provata e a schermo non si vedeva dove la volevo: una regola che non
                    // si verifica non si spedisce. Il circuito resta più chiaro, perché quello
                    // sì cambia il significato del numero.
                    let opacita: Double = barra.element.circuit ? 0.22 : 0.55
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Palette.accentOnWindow.opacity(opacita))
                        .frame(width: min(larghezza, 22),
                               height: max(3, geo.size.height * CGFloat(barra.element.reps) / CGFloat(massimo)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
    }

    /// Il selettore del periodo, scritto a mano invece che con `.pickerStyle(.segmented)`.
    ///
    /// Il controllo di sistema prende l'accento **del Mac**, non quello dell'app: restava blu in
    /// tutte e tre le livree, l'unico pezzo della finestra che non seguiva il tema. Restano
    /// pulsanti veri, non testo cliccabile, o si perderebbero tastiera e VoiceOver.
    private var periodPicker: some View {
        HStack(spacing: 2) {
            ForEach(StatsPeriod.allCases.filter { $0 != .all }, id: \.self) { p in
                let selected = model.statsPeriod == p
                Button { model.statsPeriod = p } label: {
                    Text(p.title)
                        .font(.system(size: 12, weight: selected ? .semibold : .regular))
                        .foregroundStyle(selected ? Palette.onAccentOnWindow : Color.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selected ? Palette.accentOnWindow : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(Palette.isDarkAppearance ? 0.10 : 0.06))
        )
        .frame(width: 300)
    }

    private var numbers: some View {
        let s = stats, p = previous
        return HStack(spacing: 10) {
            tile("\(s.interruptions)",
                 plural(s.interruptions, it: "interruzione", "interruzioni",
                        en: "interruption", "interruptions"),
                 delta: s.interruptions - p.interruptions)
            tile("\(s.totalReps)",
                 plural(s.totalReps, it: "ripetizione", "ripetizioni", en: "rep", "reps"),
                 delta: s.totalReps - p.totalReps)
            tile(s.label(s.activeSeconds), L.t("davanti al Mac", "at the Mac"), delta: nil)
            tile("\(s.vigorousBouts)",
                 plural(s.vigorousBouts, it: "sessione intensa", "sessioni intense",
                        en: "vigorous bout", "vigorous bouts"),
                 delta: s.vigorousBouts - p.vigorousBouts)
        }
    }

    /// «1 interruzioni» è il genere di dettaglio che fa sembrare fatta male anche la parte fatta
    /// bene. Lo zero in italiano vuole il plurale, l'uno il singolare.
    ///
    /// **Era italiano e basta**, e non lo vedeva nessuno: la parola arriva a schermo passando per
    /// `tile`, quindi nel sorgente non è dentro una `Text` e il primo lettore della lingua non la
    /// guardava. Trovata il 2026-07-29 riscrivendo quel lettore. Il numero resta fuori, perché le
    /// targhette ce l'hanno già grande sopra: `L.plural` lo metterebbe due volte.
    private func plural(_ n: Int, it one: String, _ many: String,
                        en oneEN: String, _ manyEN: String) -> String {
        L.language == .italian ? (n == 1 ? one : many) : (n == 1 ? oneEN : manyEN)
    }

    /// «3 fatte · 1 saltata · 1 d'emergenza». Ogni pezzo sa già la propria lingua, quindi la riga
    /// intera non passa da `L.t`: incartarla in un `L.t` vorrebbe dire scriverla due volte identica.
    private func riepilogoPause(_ s: PeriodStats) -> String {
        let fatte = plural(s.completed, it: "fatta", "fatte", en: "done", "done")
        let saltate = plural(s.skipped, it: "saltata", "saltate", en: "skipped", "skipped")
        let emergenze = s.emergency > 0
            ? L.t(" · \(s.emergency) d'emergenza", " · \(s.emergency) emergency")
            : ""
        return "\(s.completed) \(fatte) · \(s.skipped) \(saltate)\(emergenze)"
    }

    /// - Parameter riservaSpazioDelta: nel riepilogo la riga del confronto c'è quasi sempre, e
    ///   quando manca si tiene uno spazio vuoto per non far ballare le tessere vicine. Nella
    ///   pagina dell'andamento **non c'è mai**, e quello spazio spingeva tutto il contenuto in
    ///   alto: la tessera sembrava scentrata, ed era vero. Mio rilievo, 2026-08-04.
    private func tile(_ value: String, _ caption: String, delta: Int?,
                      riservaSpazioDelta: Bool = true) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 25, weight: .semibold, design: .rounded))
                .monospacedDigit().foregroundStyle(Palette.accentOnWindow)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(caption).font(.system(size: 10)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if riservaSpazioDelta {
                Text(delta.map { $0 == 0 ? " " : "\($0 > 0 ? "+" : "")\($0) vs \(period == .day ? L.t("ieri", "yesterday") : L.t("prima", "before"))" } ?? " ")   // lingua: ok «vs» si scrive uguale nelle due lingue
                    .font(.system(size: 9))
                    .foregroundStyle((delta ?? 0) > 0 ? Palette.accentOnWindow : Color.secondary)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(Color.primary.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var compliance: some View {
        let s = stats
        if s.completed + s.skipped + s.emergency > 0 {
            Card {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(Int(s.complianceRate * 100))%")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundStyle(Palette.accentOnWindow).monospacedDigit()
                            Text(L.t("delle pause proposte", "of the breaks offered")).font(.system(size: 13, weight: .medium))
                        }
                        // **Larga quanto la carta, non 260 punti.** Con la finestra a 640 quella
                        // misura fissa lasciava una barra piena a metà accanto alla scritta
                        // «100%»: due cose che si contraddicono nello stesso riquadro. Rilievo
                        // suo, 2026-08-04: *«perché 100% mi dimostra però metà giornata?»*.
                        ProgressView(value: s.complianceRate).tint(Palette.accentOnWindow)
                            .frame(maxWidth: .infinity)
                        Text(s.complianceRate < 0.5
                             ? L.t("Sotto la metà, è la cadenza a essere sbagliata, non tu. Allungala nelle preferenze.",
                                   "Below half: it is the cadence that is wrong, not you. Lengthen it in preferences.")
                             : riepilogoPause(s))
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if s.streakDays > 1 {
                        VStack(spacing: 2) {
                            Text("\(s.streakDays)").font(.system(size: 22, weight: .semibold, design: .rounded))
                                .foregroundStyle(Palette.accentOnWindow)
                            Text(L.t("giorni\ndi fila", "days\nin a row")).font(.system(size: 10))
                                .multilineTextAlignment(.center).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var muscleCards: some View {
        // Sulla pagina dell'allenamento il periodo non esiste, quindi si legge tutto: è la stessa
        // scala dell'andamento che sta sopra, e due scale diverse nella stessa pagina sono un
        // modo garantito di far sbagliare i conti a chi legge.
        let groups = model.stats(for: page == .allenamento ? .all : period).repsByMuscleGroup
        if !groups.isEmpty {
            let peak = Double(groups.first?.reps ?? 1)
            Card(title: L.t("Esercizi svolti", "Exercises done"),
                 subtitle: L.t("ripetizioni per catena muscolare, apri un gruppo per vedere gli esercizi",
                               "reps by muscle chain, open a group to see the exercises")) {
                VStack(spacing: 4) {
                    ForEach(groups, id: \.group) { g in
                        // La barra dice **quanto**, il gruppo aperto dice **cosa**: senza, «petto
                        // 3» non fa distinguere tre push-up normali da tre archer, che non sono
                        // affatto la stessa giornata.
                        DisclosureGroup(isExpanded: Binding(
                            get: { Self.expandGroupsForSnapshot || openGroups.contains(g.group) },
                            set: { open in
                                if open { openGroups.insert(g.group) } else { openGroups.remove(g.group) }
                            }
                        )) {
                            VStack(spacing: 5) {
                                ForEach(g.exercises, id: \.0) { kind, reps in
                                    HStack(spacing: 8) {
                                        Text(kind.localizedName)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                        if let nota = detail(kind, reps) {
                                            Text(nota)
                                                .font(.system(size: 11))
                                                .foregroundStyle(.tertiary)
                                        }
                                        Spacer()
                                        Text(kind.isTimed ? "\(reps) s" : "\(reps)")
                                            .font(.system(size: 12, weight: .medium))
                                            .monospacedDigit()
                                    }
                                }
                            }
                            .padding(.top, 6)
                            .padding(.leading, 4)
                        } label: {
                            HStack(spacing: 12) {
                                // `g.group` è la **chiave** con cui `Stats` raggruppa, e resta
                                // italiana per costruzione: qui va tradotta, o in inglese la pagina
                                // scrive «addome, gambe, petto». Era così, e l'ha trovato la
                                // fotografia della pagina in inglese, non un test.
                                Text(ExerciseKind.localizedGroup(g.group))
                                    .font(.system(size: 12, weight: .medium))
                                    .frame(width: 84, alignment: .leading)
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.06))
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Palette.accentOnWindow.opacity(g.group == "total body" ? 1 : 0.55))
                                            .frame(width: max(6, geo.size.width * Double(g.reps) / max(1, peak)))
                                    }
                                }
                                .frame(height: 16)
                                Text("\(g.reps)").font(.system(size: 12, weight: .medium))
                                    .monospacedDigit().frame(width: 34, alignment: .trailing)
                            }
                        }
                    }
                }
            }
        }
    }

    /// La riga piccola accanto al nome, quando il numero da solo si legge male: i secondi di una
    /// tenuta e il conto per lato di un esercizio che alterna. Il numero grande resta il totale,
    /// così le somme del gruppo tornano.
    private func detail(_ kind: ExerciseKind, _ reps: Int) -> String? {
        guard kind.isPerSide else { return nil }
        let perSide = max(1, reps / 2)
        return kind.isTimed ? L.t("\(perSide) s per lato", "\(perSide) s per side")
                            : L.t("\(perSide) per lato", "\(perSide) per side")
    }

    @ViewBuilder
    private var hourStrip: some View {
        let hours = stats.byHour
        if !hours.isEmpty {
            let peak = Double(hours.map { $0.done + $0.missed }.max() ?? 1)
            // Il titolo dice «per ora del giorno» e non «oggi» di proposito: in Settimana e Mese
            // queste barre sommano più giornate, e chiamarle «la giornata» le faceva leggere come
            // se fossero di oggi.
            Card(title: L.t("Trend pause · h/giorno", "Break trend · h/day"),
                 subtitle: L.t("verde le pause fatte, rosso le saltate. Se un'ora è sempre rossa, cambia quell'ora",
                               "green means taken, red means skipped. If one hour is always red, change that hour")) {
                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(hours, id: \.hour) { h in
                        VStack(spacing: 4) {
                            VStack(spacing: 2) {
                                Spacer(minLength: 0)
                                if h.missed > 0 {
                                    RoundedRectangle(cornerRadius: 3).fill(Color.red.opacity(0.6))
                                        .frame(height: max(4, 44 * Double(h.missed) / peak))
                                }
                                if h.done > 0 {
                                    RoundedRectangle(cornerRadius: 3).fill(Palette.accentOnWindow)
                                        .frame(height: max(4, 44 * Double(h.done) / peak))
                                }
                            }
                            .frame(height: 48)
                            Text("\(h.hour)").font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                        // Un tetto alla larghezza, o con una sola ora attiva la barra si allarga
                        // per tutta la scheda e non si legge più come una barra: sembra un blocco
                        // pieno, cioè un errore di disegno.
                        .frame(maxWidth: 46)
                    }
                    if hours.count < 4 { Spacer(minLength: 0) }
                }
            }
        }
    }

    private var insights: some View {
        Card(title: L.t("Cosa dicono gli studi per numeri come questi",
                        "What the studies say for numbers like these"),
             subtitle: L.t("non è una misura su di te, è ciò che è stato osservato su chi ha fatto numeri simili",
                           "it is not a measurement of you, it is what was observed in people with similar numbers")) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Stats.insights(for: stats, target: model.settings.vigorousDailyTarget)) { insight in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: insight.met ? "checkmark.circle.fill" : "circle.dashed")
                            .foregroundStyle(insight.met ? Palette.accentOnWindow : Color.secondary)
                            .font(.system(size: 13))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(insight.headline).font(.system(size: 12, weight: .medium))
                            Text(insight.detail).font(.system(size: 11)).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            if let study = insight.study {
                                Text("\(study.citation), \(String(study.year)).")
                                    .font(.system(size: 9)).foregroundStyle(.tertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }
}
