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
    @FocusState private var escapeFocused: Bool

    private var plan: BreakPlan? { model.plan }

    var body: some View {
        ZStack {
            Palette.ink.ignoresSafeArea()
            if let plan {
                VStack(spacing: 0) {
                    header(plan)
                    Spacer()
                    exercise(plan)
                    Spacer()
                    controls(plan)
                    footer
                }
                .padding(48)
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
                        .foregroundStyle(Palette.dim.opacity(0.8))
                }
                .padding(48)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private func header(_ plan: BreakPlan) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text(plan.kind == .long ? L.t("PAUSA PIENA", "FULL BREAK") : L.t("MICRO-PAUSA", "MICRO-BREAK"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(Palette.accent)
                Spacer()
                // **Due numeri accanto devono parlare dello stesso periodo.** Qui c'era
                // `plan.index`, che è il contatore di sempre — serve alla rotazione degli
                // esercizi, non a te — messo accanto alle ripetizioni **di oggi**: si leggeva
                // «sessanta pause oggi», e non erano sessanta. Segnalato dal principale il
                // 2026-07-28, quando il numero era 60 e le pause della giornata due.
                Text(L.t("oggi: \(model.summary.completed + model.summary.natural + 1)ª pausa · \(model.summary.totalReps) ripetizioni",
                     "today: break #\(model.summary.completed + model.summary.natural + 1) · \(model.summary.totalReps) reps"))
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
            breakQuoteView
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

    /// La citazione, al centro della schermata.
    ///
    /// Sta qui e non in fondo perché i due testi hanno due mestieri diversi: **lo studio** in
    /// fondo risponde a «perché mi stai interrompendo» ed è quello che ti tiene fedele al
    /// quarantesimo giorno; **la citazione** riempie i secondi in cui stai lì a contare, ed è
    /// quella che rende il momento sopportabile. Toglierei la citazione prima dello studio, se
    /// dovessi sceglierne una — ma non devo, e non competono: occupano due punti diversi
    /// dell'occhio e due momenti diversi della pausa.
    @ViewBuilder
    private var breakQuoteView: some View {
        if let phrase = model.currentPhrase {
            VStack(spacing: 6) {
                Text("«\(phrase.localizedText)»")
                    .font(.system(size: 18, design: .serif))
                    .foregroundStyle(Palette.paper.opacity(0.62))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 620)
                Text(phrase.localizedCredit)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.dim.opacity(0.55))
            }
            .padding(.top, 26)
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
                    .foregroundStyle(Palette.dim.opacity(0.65))
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
        VStack(spacing: 16) {
            Text(clock(model.secondsLeftOfBreak))
                .font(.system(size: 34, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(model.canReturnToWork ? Palette.accent : Palette.dim)

            progressBar(plan)

            if model.canReturnToWork {
                primary(L.t("Torna al lavoro", "Back to work"), enabled: true) { model.returnToWork() }
            } else if model.exerciseDone {
                primary(L.t("ancora \(clock(model.secondsLeftOfBreak))", "\(clock(model.secondsLeftOfBreak)) left"), enabled: false) {}
            } else if model.canFinishNow {
                primary(model.moreStationsAhead ? L.t("Fatto — avanti", "Done — next") : "Fatto", enabled: true) {
                    model.markExerciseDone()
                }
            } else {
                primary(L.t("\(plan.exercise.label) — ancora \(Int(model.secondsUntilCanFinish.rounded(.up))) s", "\(plan.exercise.label) — \(Int(model.secondsUntilCanFinish.rounded(.up))) s to go"),
                        enabled: false) {}
            }

            // Uscire dal circuito resta possibile a metà: le stazioni già confermate restano
            // fatte, e la pausa si chiude con l'esercizio singolo che le toccava.
            if plan.circuitActive && !model.canReturnToWork {
                Button(L.t("Basta così, torno all'esercizio singolo", "That's enough, back to the single exercise")) { model.leaveCircuit() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.dim)
            }

            if model.exerciseDone && !model.canReturnToWork {
                Text(L.t("Esercizio fatto. Resta il tempo della pausa: alzati, guarda lontano.",
                     "Exercise done. The rest of the break is yours: stand up, look far away."))
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Palette.accent)
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
                .frame(width: 300, height: 54)
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
        VStack(spacing: 14) {
            Divider().overlay(Color.white.opacity(0.08)).frame(width: 620)

            // Sempre "Perché": qui girano solo le fonti che giustificano qualcosa che sta
            // succedendo. Le due voci «non promesso» sono uscite dal giro della pausa — nel
            // mezzo di un esercizio spiegavano una funzione assente — e vivono nella finestra
            // delle fonti, dove le apri tu.
            Text("Perché: \(model.currentStudy.localizedGoverns) — "
               + "\(model.currentStudy.citation), \(String(model.currentStudy.year)).")
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
                .foregroundStyle(Palette.dim.opacity(0.7))
                .multilineTextAlignment(.center)

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
                    Text(L.t("Ogni salto finisce nel registro. Non è un giudizio: è un dato.",
                     "Every skip goes into the log. It is not a judgement: it is data."))
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.dim.opacity(0.7))
                }
            }
        }
    }

    private func clock(_ seconds: Double) -> String {
        let s = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", s / 60, s % 60)
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
                Text("«\(phrase.localizedText)»")
                    .font(.system(size: 14, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
                Text(phrase.localizedCredit)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
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
                Text("Otium").font(.system(size: 15, weight: .semibold, design: .rounded))
                Spacer()
                Text(model.phase == .paused ? "sospesa" : "prossima fra \(model.minutesToNextBreak) min")
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
                            Link("apri l'articolo", destination: url)
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

    init(model: AppModel) {
        self.model = model
        _draft = State(initialValue: model.settings)
    }

    var body: some View {
        Form {
            // Le due risposte del primo avvio, dove si possono cambiare. Una scelta fatta una
            // volta sola e mai più modificabile è una trappola, non una configurazione.
            Section(L.t("Profilo", "Profile")) {
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

                Text(L.t("Il sesso decide da dove parti: le ripetizioni per gruppo muscolare (Miller 1993) e la versione della spinta — sulle ginocchia invece che a terra. Non cambia la cadenza né nient'altro, e ogni esercizio resta scambiabile dentro la pausa.",
                         "Sex decides where you start: the reps per muscle group (Miller 1993) and the version of the push — on your knees instead of full. It changes nothing else, and every exercise stays swappable inside the break."))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
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
                            set: { draft.rampStartFactor = Double($0) / 100 }
                        ), in: 20...100, step: 5)
                Text(L.t("Le ripetizioni partono ridotte e salgono un pochino ogni giorno, fino al numero pieno. Oggi sei \(ItalianNumber.al(Int(draft.rampFactor(now: Date()) * 100)))%.",
                         "The reps start reduced and go up a little every day, until the full number. Today you are at \(Int(draft.rampFactor(now: Date()) * 100))%."))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section(L.t("Cadenza", "Cadence")) {
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
                LabeledContent(L.t("Preavviso", "Warning")) {
                    secondField($draft.cadence.warningSeconds)
                }
            }

            // Una sezione per famiglia invece di venticinque caselle in fila: sono quattro
            // decisioni, non venticinque, e con gli addominali l'elenco piatto era diventato
            // illeggibile.
            ForEach(ExerciseCategory.allCases, id: \.self) { category in
                Section {
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

            Section(L.t("Come vengono proposti", "How they are offered")) {
                Toggle(L.t("Offri le varianti dentro la pausa", "Offer variants during the break"), isOn: $draft.offerVariants)
                Text(L.t("Durante una pausa push-up puoi passare a diamond, archer, dip su sedia, "
                   + "pike o inclinati con un clic. Le ripetizioni si adeguano alla difficoltà.",
                    "During a push-up break you can switch to diamond, archer, chair dips, pike or "
                    + "incline with one click. The reps adjust to the difficulty."))
                    .font(.caption).foregroundStyle(.secondary)
                Toggle(L.t("Proponi il microcircuito nelle pause piene", "Offer the circuit in full breaks"), isOn: $draft.offerCircuit)
                Text(L.t("Nella pausa piena puoi scegliere il giro completo — una stazione per "
                   + "famiglia, esplosivo compreso — invece del solo esercizio del turno. Resta "
                   + "una proposta: si decide dentro la pausa, e le stazioni valgono i tre quarti "
                   + "delle ripetizioni, o quattro esercizi non stanno in cinque minuti.",
                    "In a full break you can choose the whole circuit — one station per family, "
                    + "explosive included — instead of just the exercise of the turn. It stays a "
                    + "proposal: you decide, inside the break."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section(L.t("Comportamento", "Behaviour")) {
                Picker(L.t("Livrea", "Theme"), selection: $draft.theme) {
                    ForEach(ThemeName.allCases, id: \.self) { Text($0.palette.name).tag($0) }
                }
                Text(draft.theme.palette.description)
                    .font(.caption).foregroundStyle(.secondary)
                LabeledContent("Suono del preavviso") {
                    HStack {
                        Picker("", selection: $draft.notificationSound) {
                            Text("nessuno").tag(NotificationSounds.silent)
                            ForEach(NotificationSounds.names, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                        // Sceglierlo senza sentirlo è come scegliere un colore al buio.
                        Button(L.t("ascolta", "play")) { model.previewSound(draft.notificationSound) }
                            .disabled(draft.notificationSound.isEmpty)
                    }
                }
                Toggle(L.t("Rimanda se un microfono è in uso (call)", "Defer while a microphone is in use (a call)"), isOn: $draft.deferWhenMicrophoneActive)
                Toggle(L.t("Conta anche video e lettura come tempo fermo", "Count video and reading as sitting time too"), isOn: $draft.detectQuietPresence)
                Text(L.t("Un film o un PDF sono immobilità perfetta: senza questo, guardare Netflix "
                   + "vale come una pausa ben fatta. Tetti senza un solo input: 45 min per un "
                   + "video, 15 per un documento.",
                    "A film or a PDF is perfect stillness: without this, watching Netflix counts as "
                    + "a well-taken break. Caps without a single input: 45 min for a video, 15 for "
                    + "reading."))
                    .font(.caption).foregroundStyle(.secondary)
                Stepper("Consenti \(draft.cadence.postponesAllowed) rinvio/i a mano",
                        value: $draft.cadence.postponesAllowed, in: 0...3)
                LabeledContent("Frase per saltare") {
                    TextField("", text: $draft.escapePhrase).frame(width: 180)
                }
                LabeledContent("Ore attive") {
                    HStack {
                        Stepper("\(draft.activeFromHour)", value: $draft.activeFromHour, in: 0...23)
                        Text("→")
                        Stepper("\(draft.activeToHour)", value: $draft.activeToHour, in: 0...23)
                    }
                }
            }

            Section(L.t("Avvio automatico", "Start at login")) {
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

            Section {
                HStack {
                    // Un pulsante che non risponde è indistinguibile da un pulsante rotto: prima
                    // "Applica" salvava in silenzio, e l'unico modo di sapere se aveva funzionato
                    // era riaprire la finestra.
                    if applied {
                        Label(L.t("Preferenze aggiornate", "Preferences updated"), systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Palette.accentOnWindow)
                            .font(.system(size: 13, weight: .medium))
                            .transition(.opacity)
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
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 620)
        .livrea()
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
            Text("Otium").font(.system(size: 22, weight: .semibold, design: .rounded))
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
            tile("\(s.interruptions)", plural(s.interruptions, "interruzione", "interruzioni"),
                 delta: s.interruptions - p.interruptions)
            tile("\(s.totalReps)", plural(s.totalReps, "ripetizione", "ripetizioni"),
                 delta: s.totalReps - p.totalReps)
            tile(s.label(s.activeSeconds), "davanti al Mac", delta: nil)
            tile("\(s.vigorousBouts)", plural(s.vigorousBouts, "sessione intensa", "sessioni intense"),
                 delta: s.vigorousBouts - p.vigorousBouts)
        }
    }

    /// «1 interruzioni» è il genere di dettaglio che fa sembrare fatta male anche la parte fatta
    /// bene. Lo zero in italiano vuole il plurale, l'uno il singolare.
    private func plural(_ n: Int, _ one: String, _ many: String) -> String {
        n == 1 ? one : many
    }

    private func tile(_ value: String, _ caption: String, delta: Int?) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 25, weight: .semibold, design: .rounded))
                .monospacedDigit().foregroundStyle(Palette.accentOnWindow)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(caption).font(.system(size: 10)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(delta.map { $0 == 0 ? " " : "\($0 > 0 ? "+" : "")\($0) vs \(period == .day ? "ieri" : "prima")" } ?? " ")
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
                             ? "Sotto la metà: è la cadenza a essere sbagliata, non tu. Allungala nelle preferenze."
                             : "\(s.completed) \(plural(s.completed, "fatta", "fatte")) · \(s.skipped) \(plural(s.skipped, "saltata", "saltate"))\(s.emergency > 0 ? " · \(s.emergency) d'emergenza" : "")")
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
            Card(title: "Esercizi svolti",
                 subtitle: "ripetizioni per catena muscolare — apri un gruppo per vedere gli esercizi") {
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
        return kind.isTimed ? "\(perSide) s per lato" : "\(perSide) per lato"
    }

    @ViewBuilder
    private var hourStrip: some View {
        let hours = stats.byHour
        if !hours.isEmpty {
            let peak = Double(hours.map { $0.done + $0.missed }.max() ?? 1)
            // Il titolo dice «per ora del giorno» e non «oggi» di proposito: in Settimana e Mese
            // queste barre sommano più giornate, e chiamarle «la giornata» le faceva leggere come
            // se fossero di oggi.
            Card(title: "Trend pause · h/giorno",
                 subtitle: "verde: pause fatte · rosso: saltate — se un'ora è sempre rossa, cambia quell'ora") {
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
        Card(title: "Cosa dicono gli studi per numeri come questi",
             subtitle: "non è una misura su di te: è ciò che è stato osservato su chi ha fatto numeri simili") {
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
