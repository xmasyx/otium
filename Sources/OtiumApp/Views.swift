import SwiftUI
import OtiumCore

extension Color {
    init(_ rgb: RGB) { self.init(red: rgb.r, green: rgb.g, blue: rgb.b) }
}

/// I colori in uso, presi dal tema scelto.
///
/// Statici e non iniettati per una ragione pratica: sono letti da decine di punti, e passarli
/// per parametro renderebbe illeggibile ogni vista. Cambiano quando cambi tema in preferenze,
/// e la schermata di blocco si costruisce a ogni pausa — quindi il colore nuovo si vede subito.
enum Palette {
    private(set) static var current: ThemePalette = ThemeName.alloro.palette

    static func apply(_ theme: ThemeName) { current = theme.palette }

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
                // grigio di tutto il resto — settima di dodici cose impilate. Segnalata dal
                // principale il 2026-07-29 con le parole giuste: «lì sembra persa».
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
                        if model.exerciseDone { restHeader(plan) } else { header(plan) }
                    }
                    // **Lo spazio sopra è limitato, quello sotto no.** Con due molle uguali il
                    // contenuto si centra, e nel riposo — dove la frase è corta — finiva un terzo
                    // più in basso del numero grande dell'esercizio: nella dissolvenza il punto
                    // dove guardi saltava giù di centoventi punti. Bloccando la molla di sopra il
                    // baricentro delle due facce coincide, e in fase 1 non cambia niente perché
                    // lì il contenuto è alto e la molla è già schiacciata.
                    Spacer(minLength: 8).frame(maxHeight: 140)
                    // Il crossfade: le due facce si scambiano dentro la stessa `ZStack`, quindi
                    // una sfuma mentre l'altra compare invece di sostituirla di scatto.
                    ZStack {
                        if model.exerciseDone {
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

    private func header(_ plan: BreakPlan) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text(plan.kind == .long ? L.t("PAUSA PIENA", "FULL BREAK") : L.t("MICRO-PAUSA", "MICRO-BREAK"))
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
                    Image(systemName: presence.kind == .media ? "play.rectangle" : "doc.text")
                        .foregroundStyle(Palette.dim)
                    Text(presence.kind == .media
                         ? L.t("fermo davanti a un video: \(presence.detail)", "still, watching a video: \(presence.detail)")
                         : L.t("fermo su un documento: \(presence.detail)", "still, on a document: \(presence.detail)"))
                        .foregroundStyle(Palette.dim)
                    Spacer()
                }
                .font(.system(size: 12))
            }
        }
    }

    private func exercise(_ plan: BreakPlan) -> some View {
        VStack(spacing: 20) {
            if plan.circuitActive { circuitTrack(plan) }
            // Il numero grande è quello **da eseguire adesso**: per gli esercizi a lati alterni è
            // il per lato, non il totale.
            Text("\(plan.exercise.displayReps)")
                .font(.system(size: 140, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.paper)
                .monospacedDigit()
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

            variantRow
            circuitOffer(plan)
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
    /// Segnalato dal principale il 2026-07-28, quando il numero era 60 e le pause della giornata
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
            RestQuote(phrase: phrase)
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
    @ViewBuilder
    private var variantRow: some View {
        let options = model.variants
        if !options.isEmpty {
            VStack(spacing: 8) {
                Text(L.t("oppure", "or"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(Palette.dim)
                HStack(spacing: 8) {
                    ForEach(options, id: \.kind) { option in
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
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, 6)
        }
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
            // spiegasse cosa succede quando arriva a zero. Segnalato dal principale il
            // 2026-07-30 con la soluzione già dentro la domanda — l'etichetta resta ferma sulla
            // destinazione, ed è lo stato spento a dire «non ancora». Il tempo lo racconta
            // l'orologio, che è lì apposta.
            if model.exerciseDone {
                primary(L.t("Torna al lavoro", "Back to work"), enabled: model.canReturnToWork) {
                    model.returnToWork()
                }
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
                if !model.exerciseDone {
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
                // vista dal principale il 2026-07-30. Il minimo tiene la forma quando l'etichetta
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
/// in mezzo agli esercizi sembrava una didascalia — che è esattamente il difetto segnalato dal
/// principale il 2026-07-29.
///
/// **La misura scende sulle frasi lunghe.** Il mazzo ne ammette fino a 145 caratteri, e una da 145
/// a quaranta punti mangerebbe l'altezza del cronometro. La soglia non si stima: sta qui perché il
/// provino la misura con `--surface=provino --riposo --misura`, e la misura vale solo se il
/// provino disegna **questa** vista invece di ricopiarne i numeri.
struct RestQuote: View {
    let phrase: Phrase

    /// Larghezza vera della fase di riposo: 1440 di schermo meno i 48+48 di margine, arrotondati
    /// al valore che la vista impone. Serve al provino per misurare la stessa cosa che si vede.
    static let width: CGFloat = 1000

    var body: some View {
        VStack(spacing: 24) {
            Text(phrase.kind == .voce ? phrase.localizedText : "«\(phrase.localizedText)»")
                .font(.system(size: phrase.localizedText.count > 95 ? 30 : 40, design: .serif))
                .foregroundStyle(Palette.paper.opacity(0.94))
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
            Text(phrase.kind == .voce ? phrase.localizedText : "«\(phrase.localizedText)»")
                .font(.system(size: 18, design: .serif))
                .foregroundStyle(Palette.paper.opacity(0.62))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 620)
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
                // distingue il tempo di lavoro vero dall'orologio a muro. Segnalato dal principale
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

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 2).fill(Palette.accent).frame(width: 4)
            VStack(alignment: .leading, spacing: 8) {
                // Stessa regola della pausa: via i caporali e la firma, il carattere non si tocca.
                Text(phrase.kind == .voce ? phrase.localizedText : "«\(phrase.localizedText)»")
                    .font(.system(size: 14, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
                if phrase.kind != .voce {
                    Text(phrase.localizedCredit)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 380, height: 132, alignment: .leading)
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

struct PrefsView: View {
    @ObservedObject var model: AppModel
    /// Qualificato: in un file che importa SwiftUI, `Settings` da solo è ambiguo — SwiftUI ha
    /// una sua `Settings` (la scena delle preferenze).
    @State private var draft: OtiumCore.Settings
    @State private var applied = false
    /// La voce aperta. Si riparte sempre da `profilo`: una finestra che riapre dove l'avevi
    /// lasciata la volta scorsa è comoda finché non ti chiedi perché non vedi più le altre.
    @State private var section: Section = .profilo

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
    /// Segnalato dal principale il 2026-07-31 — *«la lista unica da scorrere è brutta e
    /// scomoda»*. Le voci ricalcano i raggruppamenti che le sezioni avevano già: non è una
    /// tassonomia nuova, è quella di prima resa navigabile.
    enum Section: String, CaseIterable, Identifiable, Hashable {
        case profilo, cadenza, esercizi, interruzioni, aspetto, sistema

        var id: String { rawValue }

        var title: String {
            switch self {
            case .profilo:      return L.t("Profilo", "Profile")
            case .cadenza:      return L.t("Cadenza", "Cadence")
            case .esercizi:     return L.t("Esercizi", "Exercises")
            case .interruzioni: return L.t("Interruzioni", "Interruptions")
            case .aspetto:      return L.t("Aspetto", "Appearance")
            case .sistema:      return L.t("Sistema", "System")
            }
        }

        /// Il sottotitolo dice **cosa ci trovi**, che è l'unica cosa che rende una barra laterale
        /// meglio di una lista: senza, per trovare un interruttore devi aprirle tutte.
        var subtitle: String {
            switch self {
            case .profilo:      return L.t("lingua, ripetizioni, partenza", "language, reps, ramp-up")
            case .cadenza:      return L.t("ogni quanto, quanto dura", "how often, how long")
            // Corto perché la colonna è stretta: «quali girano, come vengono proposti» finiva in
            // «come vengono…», che è un sottotitolo che non dice niente. Visto nella finestra
            // vera il 2026-07-31, non nella resa.
            case .esercizi:     return L.t("rotazione e varianti", "rotation and variants")
            case .interruzioni: return L.t("call, rinvii, ore attive", "calls, postponements, active hours")
            case .aspetto:      return L.t("livrea, suono", "theme, sound")
            case .sistema:      return L.t("avvio automatico", "start at login")
            }
        }

        var icon: String {
            switch self {
            case .profilo:      return "person.crop.circle"
            case .cadenza:      return "metronome"
            case .esercizi:     return "figure.strengthtraining.functional"
            case .interruzioni: return "bell.badge"
            case .aspetto:      return "paintpalette"
            case .sistema:      return "gearshape"
            }
        }
    }

    var body: some View {
        // La barra del salvataggio sta **fuori** dalla vista divisa, e questo è il punto: la
        // bozza è una sola e attraversa i pannelli, quindi il pulsante non può vivere dentro uno
        // solo. Prima era l'ultima sezione di un modulo lungo, cioè visibile solo se avevi finito
        // di scorrere.
        VStack(spacing: 0) {
            NavigationSplitView {
                List(Section.allCases, selection: $section) { voce in
                    // L'etichetta sta **dentro** la riga con tutta la sua altezza: una riga di
                    // lista si clicca tutta, non solo dove c'è scritto. È la stessa regola del
                    // pulsante della pausa, pagata due volte fra Otium e Kalamos.
                    Label {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(voce.title)
                            Text(voce.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 3)
                    } icon: {
                        Image(systemName: voce.icon)
                    }
                    .tag(voce)
                }
                .navigationSplitViewColumnWidth(min: 190, ideal: 205, max: 240)
            } detail: {
                Form {
                    switch section {
                    case .profilo:      profiloSection
                    case .cadenza:      cadenzaSection
                    case .esercizi:     eserciziSection
                    case .interruzioni: interruzioniSection
                    case .aspetto:      aspettoSection
                    case .sistema:      sistemaSection
                    }
                }
                .formStyle(.grouped)
                // **Niente `navigationTitle`.** Ne aveva uno con il nome della voce, e quel nome
                // si prendeva la barra del titolo della finestra: al posto di «Preferenze di
                // Otium» si leggeva «Profilo», cioè la finestra smetteva di dire cos'è. Dove sei
                // lo dice già la voce selezionata, che è a due centimetri.
            }
            // La barra laterale non si può stringere fino a sparire: una voce a metà è peggio di
            // nessuna barra.
            .navigationSplitViewStyle(.balanced)

            Divider()
            applyBar
        }
        .frame(width: 760, height: 580)
        .livrea()
    }

    /// Il piede fisso: lo stato del salvataggio a sinistra, il pulsante a destra, sempre lì.
    private var applyBar: some View {
        HStack {
            // Un pulsante che non risponde è indistinguibile da un pulsante rotto: prima
            // "Applica" salvava in silenzio, e l'unico modo di sapere se aveva funzionato
            // era riaprire la finestra.
            if applied {
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
                model.update(settings: draft)
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
            Picker(L.t("Lingua", "Language"), selection: Binding(
                get: { draft.language ?? AppLanguage.systemDefault },
                set: { draft.language = $0 }
            )) {
                ForEach(AppLanguage.allCases, id: \.self) { Text($0.nativeName).tag($0) }
            }
            .pickerStyle(.segmented)

            Picker(L.t("Sesso", "Sex"), selection: Binding(
                get: { draft.sex ?? .male },
                set: { draft.sex = $0 }
            )) {
                Text(L.t("Uomo", "Male")).tag(Sex.male)
                Text(L.t("Donna", "Female")).tag(Sex.female)
            }
            .pickerStyle(.segmented)

            Text(L.t("Il sesso decide da dove parti, cioè le ripetizioni per gruppo muscolare (Miller 1993) e la versione della spinta, sulle ginocchia invece che a terra. Non cambia la cadenza né nient'altro, e ogni esercizio resta scambiabile dentro la pausa.",
                     "Sex decides where you start: the reps per muscle group (Miller 1993) and the version of the push — on your knees instead of full. It changes nothing else, and every exercise stays swappable inside the break."))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Una scelta fatta al primo avvio e mai più modificabile è una trappola: la terza
            // volta che la incontro in questo file, e la terza volta che la chiudo.
            Picker(L.t("Livello per i push-up", "Push-up level"), selection: Binding(
                get: { draft.pushVariant },
                set: { draft.pushVariant = $0 }
            )) {
                Text(L.t("automatica", "automatic")).tag(ExerciseKind?.none)
                Text(L.t("al muro", "wall")).tag(ExerciseKind?.some(.wallPushUp))
                Text(L.t("sulle ginocchia", "knees")).tag(ExerciseKind?.some(.kneePushUp))
                Text(L.t("su rialzo", "elevated")).tag(ExerciseKind?.some(.inclinePushUp))
                Text(L.t("a terra", "floor")).tag(ExerciseKind?.some(.pushUp))
            }
            .pickerStyle(.menu)
        }

        SwiftUI.Section(L.t("Ripetizioni", "Reps")) {
            Toggle(L.t("Fai crescere le ripetizioni oltre il 100%",
                       "Let the reps grow beyond 100%"), isOn: $draft.progressBeyondFull)
            Text(L.t("Si sale del 5% dopo due conferme piene di fila (regola 2-for-2 dell'ACSM) e si scende dopo due mancate, mai sotto il 100%. A fine esercizio l'app ti chiede se le hai fatte tutte.",
                     "It goes up 5% after two full confirmations in a row (ACSM's 2-for-2 rule) and steps back after two shortfalls, never below 100%. At the end of each exercise the app asks whether you did them all."))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // «Rampa» era il calco di *ramp*: in italiano è la salita di un garage, non un
            // modo di allenarsi. Segnalato dal principale il 2026-07-28.
            Stepper(L.t("Partenza graduale: \(draft.rampWeeks) settimane",
                        "Gradual start: \(draft.rampWeeks) weeks"),
                    value: $draft.rampWeeks, in: 1...12)
            // **La percentuale di partenza si tocca.** Il 55% viene da un default, non da una
            // misura su di te: chi riprende dopo un infortunio vuole meno, chi si allena già
            // vuole di più, e senza questo cursore l'unica alternativa era «tutto o niente».
            Stepper(L.t("Si parte \(ItalianNumber.al(Int(draft.rampStartFactor * 100)))% delle ripetizioni",
                        "Start at \(Int(draft.rampStartFactor * 100))% of the reps"),
                    value: Binding(
                        get: { Int((draft.rampStartFactor * 100).rounded()) },
                        set: { nuovo in
                            draft.rampStartFactor = Double(nuovo) / 100
                            // Scendendo sotto il pieno, la data del pieno non ha più senso: se
                            // restasse, la domanda sulla crescita oltre il 100% arriverebbe a
                            // qualcuno che al 100% non c'è.
                            if nuovo < 100 { draft.fullReachedAt = nil }
                        }
                    ), in: 20...100, step: 5)
            Text(L.t("Le ripetizioni partono ridotte e salgono un pochino ogni giorno, fino al 100%. Oggi sei \(ItalianNumber.al(Int(draft.rampFactor(now: Date()) * 100)))%.",
                     "The reps start reduced and go up a little every day, until 100%. Today you are at \(Int(draft.rampFactor(now: Date()) * 100))%."))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // **Il pieno si sceglie, non si aspetta.** Lo stepper arrivava già a 100, ma dice
            // «si parte al…» — parla di com'è cominciata, non di adesso — e chi vuole il numero
            // pieno oggi non ha motivo di leggerlo come la risposta alla sua domanda. L'unica
            // altra via era la finestra che l'app propone da sé dopo una settimana: una domanda
            // che arriva quando decide lei. Chiesto dal principale il 2026-07-31.
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
        SwiftUI.Section {
            Picker(L.t("Preset", "Preset"), selection: Binding(
                get: { presetName(draft.cadence) },
                set: { applyPreset($0) }
            )) {
                Text(L.t("A — 30 min + pausa piena ogni 90 (consigliata)", "A — 30 min + full break every 90 (recommended)")).tag("A")
                Text(L.t("B — 5 min ogni 50 (deep work)", "B — 5 min every 50 (deep work)")).tag("B")
                Text(L.t("C — 5 min ogni 30 (protocollo Duran)", "C — 5 min every 30 (Duran protocol)")).tag("C")
                Text(L.t("personalizzata", "custom")).tag("X")
            }
            .pickerStyle(.menu)
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
            Stepper(L.t("Pausa piena ogni \(draft.cadence.longEveryNBreaks) micro-pause", "Full break every \(draft.cadence.longEveryNBreaks) micro-breaks"),
                    value: $draft.cadence.longEveryNBreaks, in: 1...8)
            // Detto qui perché è la domanda che il principale ha fatto guardando lo schermo: la
            // prima pausa di oggi era piena, e la ragione stava in un contatore che non sapeva
            // che fosse cambiato il giorno.
            Text(L.t("Il conto riparte ogni giorno: la prima pausa della giornata è sempre breve.",
                     "The count restarts every day: the first break of the day is always a short one."))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            LabeledContent(L.t("Preavviso", "Warning")) {
                secondField($draft.cadence.warningSeconds)
            }
        }
    }

    @ViewBuilder
    private var eserciziSection: some View {
        // Una sezione per famiglia invece di venticinque caselle in fila: sono quattro
        // decisioni, non venticinque, e con gli addominali l'elenco piatto era diventato
        // illeggibile.
        ForEach(ExerciseCategory.allCases, id: \.self) { category in
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

        SwiftUI.Section(L.t("Come vengono proposti", "How they are offered")) {
            Toggle(L.t("Offri le varianti dentro la pausa", "Offer variants during the break"), isOn: $draft.offerVariants)
            Text(L.t("Durante una pausa push-up puoi passare a diamond, archer, dip su sedia, "
               + "pike o inclinati con un clic. Le ripetizioni si adeguano alla difficoltà.",
                "During a push-up break you can switch to diamond, archer, chair dips, pike or "
                + "incline with one click. The reps adjust to the difficulty."))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Toggle(L.t("Proponi il microcircuito nelle pause piene", "Offer the circuit in full breaks"), isOn: $draft.offerCircuit)
            Text(L.t("Nella pausa piena puoi scegliere il giro completo, una stazione per "
               + "famiglia esplosivo compreso, invece del solo esercizio del turno. Resta "
               + "una proposta: si decide dentro la pausa, e le stazioni valgono i tre quarti "
               + "delle ripetizioni, o quattro esercizi non stanno in cinque minuti.",
                "In a full break you can choose the whole circuit — one station per family, "
                + "explosive included — instead of just the exercise of the turn. It stays a "
                + "proposal: you decide, inside the break."))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var interruzioniSection: some View {
        SwiftUI.Section {
            Toggle(L.t("Rimanda se un microfono è in uso (call)", "Defer while a microphone is in use (a call)"), isOn: $draft.deferWhenMicrophoneActive)
            Toggle(L.t("Conta anche video e lettura come tempo fermo", "Count video and reading as sitting time too"), isOn: $draft.detectQuietPresence)
            Text(L.t("Un film o un PDF sono immobilità perfetta, e senza questo guardare Netflix "
               + "vale come una pausa ben fatta. Tetti senza un solo input: 45 min per un "
               + "video, 15 per un documento.",
                "A film or a PDF is perfect stillness: without this, watching Netflix counts as "
                + "a well-taken break. Caps without a single input: 45 min for a video, 15 for "
                + "reading."))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        SwiftUI.Section(L.t("Vie d'uscita", "Ways out")) {
            Stepper(L.t("Consenti \(draft.cadence.postponesAllowed) rinvio/i a mano",
                        "Allow \(draft.cadence.postponesAllowed) manual postponement(s)"),
                    value: $draft.cadence.postponesAllowed, in: 0...3)
            LabeledContent(L.t("Frase per saltare", "Skip phrase")) {
                TextField("", text: $draft.escapePhrase).frame(width: 180)
            }
        }

        SwiftUI.Section {
            LabeledContent(L.t("Ore attive", "Active hours")) {
                HStack {
                    Stepper("\(draft.activeFromHour)", value: $draft.activeFromHour, in: 0...23)
                    Text("→")
                    Stepper("\(draft.activeToHour)", value: $draft.activeToHour, in: 0...23)
                }
            }
            Text(L.t("Fuori da questa finestra Otium non interrompe.",
                     "Outside this window Otium does not interrupt."))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var aspettoSection: some View {
        SwiftUI.Section {
            Picker(L.t("Livrea", "Theme"), selection: $draft.theme) {
                ForEach(ThemeName.allCases, id: \.self) { Text($0.palette.name).tag($0) }
            }
            Text(draft.theme.palette.description)
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            LabeledContent(L.t("Suono del preavviso", "Warning sound")) {
                HStack {
                    Picker("", selection: $draft.notificationSound) {
                        Text(L.t("nessuno", "none")).tag(NotificationSounds.silent)
                        ForEach(NotificationSounds.names, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                    // Sceglierlo senza sentirlo è come scegliere un colore al buio.
                    Button(L.t("ascolta", "play")) { model.previewSound(draft.notificationSound) }
                        .disabled(draft.notificationSound.isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private var sistemaSection: some View {
        SwiftUI.Section(L.t("Avvio automatico", "Start at login")) {
            switch model.launchAgentState {
            case .notInstalled:
                HStack {
                    Text(L.t("Otium non riparte da sola.", "Otium does not restart on its own.")).foregroundStyle(.secondary)
                    Button(L.t("Installa", "Install")) { model.installLaunchAgent() }
                }
            case .healthy:
                HStack {
                    Label(L.t("Attivo e puntato a questa copia", "Active and pointing at this copy"), systemImage: "checkmark.seal")
                        .foregroundStyle(.green)
                    Spacer()
                    Button(L.t("Rimuovi", "Remove")) { model.removeLaunchAgent() }
                }
            case .danglingTarget(let path):
                VStack(alignment: .leading) {
                    Label(L.t("L'avvio automatico punta a un file che non esiste più", "Start at login points at a file that no longer exists"),
                          systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    Text(path).font(.caption).foregroundStyle(.secondary)
                    Button(L.t("Ripara", "Repair")) { model.installLaunchAgent() }
                }
            case .pointsElsewhere(let path):
                VStack(alignment: .leading) {
                    Label(L.t("L'avvio automatico punta a un'altra copia di Otium", "Start at login points at another copy of Otium"),
                          systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    Text(path).font(.caption).foregroundStyle(.secondary)
                    Button(L.t("Punta a questa", "Point at this one")) { model.installLaunchAgent() }
                }
            }
        }
    }

    /// «Tutti» e «nessuno» su una famiglia intera. `nessuno` non può svuotare del tutto un pool:
    /// una rotazione senza esercizi non è una preferenza, è un'app che non fa più niente — e il
    /// modello ricadrebbe comunque sul suo default, mentendo alla casella.
    private func setAll(_ category: ExerciseCategory, on: Bool) {
        let kinds = ExerciseKind.allCases.filter { $0.category == category }
        for kind in kinds { binding(for: kind).wrappedValue = on }
    }

    private func binding(for kind: ExerciseKind) -> Binding<Bool> {
        Binding(
            get: {
                kind.isVigorous ? draft.vigorousPool.contains(kind) : draft.exercisePool.contains(kind)
            },
            set: { on in
                if kind.isVigorous {
                    var pool = draft.vigorousPool
                    if on { if !pool.contains(kind) { pool.append(kind) } } else { pool.removeAll { $0 == kind } }
                    draft.vigorousPool = pool.isEmpty ? [.jumpingJack] : pool
                } else {
                    var pool = draft.exercisePool
                    if on { if !pool.contains(kind) { pool.append(kind) } } else { pool.removeAll { $0 == kind } }
                    draft.exercisePool = pool.isEmpty ? [.squat] : pool
                }
            }
        )
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    numbers
                    compliance
                    muscleCards
                    hourStrip
                    insights
                }
                .padding(.horizontal, 22).padding(.bottom, 24)
            }
        }
        .frame(minWidth: 640, minHeight: 540)
        .livrea()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Otium").font(.system(size: 22, weight: .semibold, design: .rounded))   // lingua: ok nome proprio
            periodPicker
        }
        .padding(.horizontal, 22).padding(.top, 18).padding(.bottom, 14)
    }

    /// Il selettore del periodo, scritto a mano invece che con `.pickerStyle(.segmented)`.
    ///
    /// Il controllo di sistema prende l'accento **del Mac**, non quello dell'app: restava blu in
    /// tutte e tre le livree, l'unico pezzo della finestra che non seguiva il tema. Restano
    /// pulsanti veri, non testo cliccabile, o si perderebbero tastiera e VoiceOver.
    private var periodPicker: some View {
        HStack(spacing: 2) {
            ForEach(StatsPeriod.allCases, id: \.self) { p in
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

    private func tile(_ value: String, _ caption: String, delta: Int?) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 25, weight: .semibold, design: .rounded))
                .monospacedDigit().foregroundStyle(Palette.accentOnWindow)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(caption).font(.system(size: 10)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(delta.map { $0 == 0 ? " " : "\($0 > 0 ? "+" : "")\($0) vs \(period == .day ? L.t("ieri", "yesterday") : L.t("prima", "before"))" } ?? " ")   // lingua: ok «vs» si scrive uguale nelle due lingue
                .font(.system(size: 9))
                .foregroundStyle((delta ?? 0) > 0 ? Palette.accentOnWindow : Color.secondary)
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
                        ProgressView(value: s.complianceRate).tint(Palette.accentOnWindow)
                            .frame(width: 260)
                        Text(s.complianceRate < 0.5
                             ? L.t("Sotto la metà: è la cadenza a essere sbagliata, non tu. Allungala nelle preferenze.",
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
        let groups = stats.repsByMuscleGroup
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
                                Text(g.group).font(.system(size: 12, weight: .medium))
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
