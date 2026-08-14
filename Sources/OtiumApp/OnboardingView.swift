import SwiftUI
import OtiumCore

/// Il primo avvio: due domande, e poi l'app sparisce nella barra dei menu.
///
/// **Due, non dieci.** Ogni domanda in più al primo avvio è gente che chiude la finestra e non
/// torna: si chiede solo ciò che l'app non può dedurre e senza cui farebbe la cosa sbagliata. La
/// lingua e il punto di partenza delle ripetizioni sono esattamente quelle due. Tutto il resto —
/// cadenza, esercizi, livrea, ore di silenzio — ha un default sensato ed è nelle preferenze.
///
/// La lingua è la prima domanda e si applica **mentre la scegli**: una schermata che ti chiede in
/// italiano quale lingua parli ha già risposto da sola.
struct OnboardingView: View {

    @ObservedObject var model: AppModel
    let onDone: () -> Void

    @State private var language: AppLanguage = AppLanguage.systemDefault
    @State private var sex: Sex?
    /// Terza domanda: si comincia a metà e si sale, o si parte dai numeri interi.
    @State private var gradual = true
    /// La versione della spinta da cui si parte. `nil` = quella che propone l'app.
    @State private var pushVariant: ExerciseKind?
    /// Solo per le rese: permette di guardare com'è fatta la schermata **a scelta già fatta**,
    /// che è l'unico modo di giudicare il bottone selezionato senza cliccarlo a mano.
    ///
    /// Entra nello stato dall'`init` e non da `onAppear`, perché la misura della finestra viene
    /// presa **prima** che la vista compaia: applicandola dopo, la resa della schermata femminile
    /// aveva la stessa altezza di quella maschile e la domanda in più restava tagliata fuori.
    let preselectedSex: Sex?

    /// Come `preselectedSex`, ed è lì per lo stesso motivo: la seconda pagina esiste solo dopo un
    /// clic, e una resa che non sa arrivarci non la guarda mai nessuno.
    init(model: AppModel, onDone: @escaping () -> Void, preselectedSex: Sex? = nil,
         initialStep: Int = 1) {
        self.model = model
        self.onDone = onDone
        self.preselectedSex = preselectedSex
        _sex = State(initialValue: preselectedSex)
        _passo = State(initialValue: initialStep)
    }

    /// **Due passi, non uno.** Il primo avvio chiede e spiega; la modalità Zen ha una pagina sua
    /// dal 2026-08-11, per mia scelta. La ragione è che Zen non compare nell'elenco
    /// degli esercizi, perché il respiro non è un esercizio: chi cerca lì «e se non posso
    /// muovermi» non trova niente, e una pagina che deve spiegare un meccanismo non ci sta in
    /// coda a una schermata di domande.
    ///
    /// Il passo resta uno `State` e non una navigazione di sistema: sono due schermate, e una
    /// pila di navigazione porterebbe una barra del titolo che questa finestra non ha.
    @State private var passo = 1

    var body: some View {
        Group {
            if passo == 1 { paginaDomande } else { paginaZen }
        }
        .padding(34)
        .frame(width: 540)
    }

    private var paginaDomande: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Otium")   // lingua: ok nome proprio dell'app
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.accentOnWindow)
                Text(L.t("Conta il tempo che passi davvero al computer e, ogni tanto, ti ferma per farti muovere.",
                         "It counts the time you actually spend at your computer and, every so often, stops you to make you move."))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            question(
                number: 1,
                title: L.t("Lingua", "Language"),
                detail: L.t("Selezionabile anche dopo, dalle preferenze.",
                            "Also selectable later, in preferences.")
            ) {
                HStack(spacing: 12) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        choice(title: lang.nativeName, selected: language == lang) {
                            language = lang
                            // Si applica subito: le parole di questa stessa finestra cambiano
                            // sotto le dita, ed è il modo più diretto di far vedere che ha preso.
                            L.language = lang
                        }
                    }
                }
            }

            question(
                number: 2,
                title: L.t("Sesso", "Sex"),
                detail: L.t("Decide da dove parti, ripetizioni e livello dell'esercizio.",
                            "Sets where you start: reps and exercise level.")
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        choice(title: L.t("Uomo", "Male"), selected: sex == .male) { sex = .male }
                        choice(title: L.t("Donna", "Female"), selected: sex == .female) { sex = .female }
                    }
                    // L'app dice **perché** chiede, mentre lo chiede. Una domanda sul corpo senza
                    // una ragione visibile è una domanda a cui è ragionevole non voler rispondere.
                    Text(L.t("Uno studio su otto uomini e otto donne (Miller 1993) misura circa il 52% della forza maschile nella parte alta del corpo e il 66% in quella bassa. Per questo l'app non taglia il numero fino a farlo diventare finto, ma cambia il movimento (push-up sulle ginocchia invece che a terra) e le ripetizioni restano quelle di un allenamento vero. Dentro la pausa puoi sempre passare alla versione più dura, o a quella più facile.",
                             "A study of eight men and eight women (Miller 1993) measured roughly 52% of male strength in the upper body and 66% in the lower body. That is why the app does not cut the number until it becomes token: it changes the movement — knee push-ups instead of full ones — and the reps stay those of a real workout. Inside the break you can always switch to the harder version, or the easier one."))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Compare **solo a chi riceverebbe la sostituzione**: a un uomo l'app non cambia il
            // push-up, quindi chiedergli quale preferisce sarebbe una domanda senza oggetto. Chi
            // ha dichiarato «donna» invece la sostituzione ce l'ha già, e questa è l'unica
            // occasione di dire «io a terra ci arrivo» prima che l'app decida per lei.
            if sex == .female {
                question(
                    number: 3,
                    title: L.t("Livello per i push-up", "Push-up level"),
                    detail: L.t("Selezionabile dalle preferenze e dentro ogni pausa.",
                                "Selectable in preferences and inside any break.")
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            ForEach([ExerciseKind.wallPushUp, .kneePushUp, .inclinePushUp, .pushUp],
                                    id: \.self) { kind in
                                choice(title: nomeBreve(kind),
                                       selected: (pushVariant ?? .kneePushUp) == kind,
                                       narrow: true) { pushVariant = kind }
                            }
                        }
                        // «Su rialzo» è l'unico dei quattro che non si capisce dal bottone. Gli
                        // altri tre li vedi mentre li leggi, questo ti chiede di immaginare cosa:
                        // la riga qui sotto nomina gli oggetti invece di allungare il bottone.
                        Text(L.t("Dal muro alle ginocchia al rialzo, cioè scrivania, divano o letto, fino a terra. È la stessa progressione per chiunque parta da zero, e se già li fai a terra dillo qui.",
                                 "From the wall to the knees to an elevated surface (a desk, a sofa, a bed) and finally the floor. It is the same progression for anyone starting from scratch, and if you already do them on the floor, say so here."))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            question(
                number: sex == .female ? 4 : 3,
                title: L.t("Quante ripetizioni", "How many reps"),
                detail: L.t("Selezionabile anche dopo, dalle preferenze.",
                            "Also selectable later, in preferences.")
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        choice(title: L.t("Partenza graduale", "Gradual start"),
                               selected: gradual, wide: true) { gradual = true }
                        choice(title: L.t("100%", "100%"),
                               selected: !gradual, wide: true) { gradual = false }
                    }
                    // **I numeri veri, non una percentuale.** «Parti al 55%» non dice niente a
                    // nessuno; «8 squat invece di 15» si capisce senza pensarci, e cambia sotto
                    // gli occhi quando tocchi la domanda qui sopra.
                    Text(esempio)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Palette.accentOnWindow)
                    Text(gradual
                         ? L.t("Si sale un pochino ogni giorno fino al 100%, in tre settimane. Serve a non smettere dopo tre giorni.",
                               "It goes up a little every day until 100%, over three weeks. It is there so you don't quit after three days.")
                         : L.t("Nessuna partenza morbida, da subito si fa il 100% delle ripetizioni. Se sei già allenato è la scelta giusta.",
                               "No soft start, it's 100% of the reps from day one. If you already train, this is the right choice."))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            primaDiCominciare

            HStack {
                Spacer()
                Button { passo = 2 } label: {
                    Text(L.t("Avanti", "Next"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .frame(width: 190, height: 44)
                        .foregroundStyle(sex == nil ? Color.secondary : Palette.onAccentOnWindow)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(sex == nil ? Color.primary.opacity(0.08) : Palette.accentOnWindow)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(sex == nil)
            }
        }
    }

    /// Il secondo passo: la modalità Zen, con il suo perché e il suo tetto.
    private var paginaZen: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L.t("La modalità Zen", "Zen mode"))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.accentOnWindow)
                Text(L.t("Per i posti dove muoversi non si può.", "For the places where moving is not an option."))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            laModalitaZen

            HStack(spacing: 12) {
                Button { passo = 1 } label: {
                    Text(L.t("Indietro", "Back"))
                        .font(.system(size: 15, design: .rounded))
                        .frame(width: 110, height: 44)
                        .foregroundStyle(Color.primary)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.07)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                Button(action: finish) {
                    Text(L.t("Comincia", "Start"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .frame(width: 190, height: 44)
                        .foregroundStyle(Palette.onAccentOnWindow)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.accentOnWindow))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// **Cosa fa l'app, perché lo fa, e come si esce.** Non è una domanda: è l'unica cosa che
    /// l'onboarding deve *dire* invece di chiedere.
    ///
    /// Le ragioni stavano in fondo a ogni pausa, tre righe di grigio sotto l'esercizio, e da lì
    /// sono uscite il 2026-07-29: rubavano il ruolo alla frase e alla sedicesima ripetizione della
    /// giornata erano arredamento. Dette una volta qui, con calma, valgono di più. **Il rischio
    /// dichiarato è che chi salta questa schermata non le legga mai** — per questo nella pausa
    /// resta comunque la riga che dice dove trovarle.
    ///
    /// L'uscita d'emergenza sta qui per una ragione diversa e più seria: è una schermata che
    /// copre tutto e disabilita ⌘Q, e scoprire come uscirne **mentre** ti serve uscire è troppo
    /// tardi. Scelta esplicita, 2026-07-29.
    private var primaDiCominciare: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L.t("Prima di cominciare", "Before you start"))
                .font(.system(size: 16, weight: .semibold, design: .rounded))

            VStack(alignment: .leading, spacing: 6) {
                Text(L.t("Cosa fa", "What it does")).font(.system(size: 13, weight: .semibold))
                Text(comeFunziona)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L.t("Perché ti interrompe", "Why it interrupts you"))
                    .font(.system(size: 13, weight: .semibold))
                // **Le righe le scrivono gli studi, non io.** Ricopiarle a mano qui vorrebbe dire
                // due copie della stessa affermazione che invecchiano separate: il giorno che una
                // fonte cambia, questa schermata continuerebbe a citare la vecchia senza che
                // niente lo dica.
                ForEach(Self.ragioni, id: \.id) { studio in
                    Text("· \(studio.localizedGoverns) — \(studio.shortCitation), \(String(studio.year)).")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(L.t("Tutti gli studi, con i link, sono in Otium ▸ Le fonti.",
                         "All the studies, with links, are in Otium ▸ The sources."))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L.t("Come esci, se devi", "How to get out, if you must"))
                    .font(.system(size: 13, weight: .semibold))
                // L'istruzione che conta sta su una riga sua, in accento: è quella che uno cerca
                // con gli occhi mentre gli serve, e in mezzo a un paragrafo grigio non si trova.
                Text(L.t("Premi Esc due volte, oppure il pulsante «Emergenza» in fondo alla schermata.",
                         "Press Esc twice, or the «Emergency» button at the bottom of the screen."))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.accentOnWindow)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L.t("La pausa copre tutto lo schermo e non si chiude con ⌘Q né con ⌘W: è attrito voluto. Ogni uscita d'emergenza viene contata e compare nelle statistiche, e non è un giudizio, è un dato.",
                         "The break covers the whole screen and does not close with ⌘Q or ⌘W: the friction is deliberate. Every emergency exit is counted and shows up in your statistics — it is not a judgement, it is data."))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.accentOnWindow.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.accentOnWindow.opacity(0.25)))
    }

    /// I tre studi che spiegano la forma dell'app: ogni quanto, che esercizi, e chi decide.
    private static let ragioni: [Study] = [
        Evidence.sittingInterval, Evidence.squatsBeatWalking, Evidence.systematicBreaks,
    ]

    /// A cosa serve ciascun protocollo, letto dalle impostazioni invece che scritto a mano.
    /// Chi non è assegnato a nessuna delle due pause resta senza etichetta: è comunque
    /// selezionabile nelle preferenze, e dire «nessuno» sarebbe più lungo e meno vero.
    private func ruoloZen(_ p: BreathProtocol) -> String {
        let s = model.settings
        if p == s.zenProtocolShort && p == s.zenProtocolLong {
            return L.t(", su entrambe le pause", ", on both breaks")
        }
        if p == s.zenProtocolShort { return L.t(", sulla pausa breve", ", on the short break") }
        if p == s.zenProtocolLong { return L.t(", sulla pausa lunga", ", on the long break") }
        return ""
    }

    /// **La modalità Zen, spiegata prima che serva.**
    ///
    /// Sta nell'onboarding per mia scelta (2026-08-11) per un motivo preciso: Zen non
    /// compare nell'elenco degli esercizi, perché respirare non è un esercizio. Chi cerca lì dentro
    /// «e se non posso muovermi?» non trova niente, e conclude che l'app non ha una risposta.
    ///
    /// **Non è una domanda, ed è voluto.** La regola in cima al file dice due domande e non dieci:
    /// Zen ha un default sensato, cioè spenta, e si accende dalla barra dei menu in un gesto. Qui
    /// va detta, non chiesta.
    ///
    /// **Il tetto è parte della spiegazione, non una nota in fondo.** L'ultima riga viene da
    /// `Evidence.breathworkCeiling` e dice che il respiro non pareggia il movimento. Una funzione
    /// che si racconta per quello che non è dura finché nessuno la misura.
    private var laModalitaZen: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Nessun titolo qui dentro: la pagina ne ha già uno grande sopra, e ripeterlo
            // faceva leggere «La modalità Zen» due volte a due centimetri di distanza.
            Text(L.t("Ci sono posti dove non ti metti a fare push-up: un ufficio open space, un coworking, un treno. Con la modalità Zen la pausa resta, ma al posto dell'esercizio ti guida nel respiro, con l'animazione che detta il ritmo e niente da fare con il corpo. Vale sia per la pausa breve sia per quella lunga.",
                     "There are places where you don't drop and do push-ups: an open-plan office, a coworking space, a train. With Zen mode the break stays, but instead of the exercise it guides your breathing, with the animation setting the pace and nothing to do with your body. It applies to both the short break and the long one."))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // I protocolli si elencano da `BreathProtocol`, non a mano: il giorno che ne
            // aggiungiamo uno, questa schermata lo sa senza che nessuno se ne ricordi.
            //
            // **Accanto al nome va il RUOLO, non i respiri al minuto.** La prima stesura stampava
            // la frequenza e usciva «respiro a sei al minuto, 6 al minuto», cioè una tautologia; e
            // siccome il ciclo del sospiro dura anch'esso dieci secondi, due protocolli su tre
            // mostravano lo stesso numero, che quindi non distingueva niente. Il ruolo invece si
            // legge dalle impostazioni vere, quindi resta onesto se un domani cambiano.
            VStack(alignment: .leading, spacing: 5) {
                ForEach(BreathProtocol.allCases, id: \.self) { p in
                    Text("· \(p.localizedName)\(ruoloZen(p))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(L.t("Perché funziona", "Why it works"))
                .font(.system(size: 13, weight: .semibold))
            Text(L.t("Il respiro è l'unica funzione automatica che puoi prendere in mano, e rallentandolo sposti l'equilibrio del sistema nervoso verso la parte che frena invece di quella che accelera. Il segnale si misura: la variabilità del battito a mediazione vagale sale mentre respiri lento, e resta più alta anche dopo. L'espirazione lunga conta più dell'inspirazione, perché è mentre butti fuori l'aria che il freno vagale agisce di più. Attorno ai sei respiri al minuto cuore e respiro entrano in fase, ed è lì che l'effetto è più grande.",
                     "Breathing is the one automatic function you can take over, and slowing it shifts the balance of the nervous system towards the part that brakes rather than the part that accelerates. The signal is measurable: vagally-mediated heart rate variability rises while you breathe slowly, and stays higher afterwards. The long exhale matters more than the inhale, because it is while you let the air out that the vagal brake acts most. Around six breaths a minute heart and breath fall into phase, and that is where the effect is largest."))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(Evidence.slowBreathing.shortCitation), \(String(Evidence.slowBreathing.year)).")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            Text(L.t("Si accende dalla barra dei menu, ed è spenta finché non la accendi tu.",
                     "You switch it on from the menu bar, and it stays off until you do."))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.accentOnWindow)
                .fixedSize(horizontal: false, vertical: true)

            // `localizedClaim` e non `localizedGoverns`: il secondo dice a quale scelta dell'app
            // serve lo studio («l'esistenza della modalità Zen»), che qui non informa nessuno. Il
            // primo porta la misura e il limite, che è l'unica cosa per cui questa riga esiste.
            Text("\(Evidence.breathworkCeiling.localizedClaim) \(Evidence.breathworkCeiling.shortCitation), \(String(Evidence.breathworkCeiling.year)).")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.accentOnWindow.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.accentOnWindow.opacity(0.25)))
    }

    /// **I numeri vengono dalla cadenza vera**, non da una frase scritta a mano: cambiarla nelle
    /// preferenze e leggere qui i vecchi numeri sarebbe una bugia che nessun test vedrebbe.
    private var comeFunziona: String {
        let c = model.settings.cadence
        let ogni = Int(c.intervalSeconds / 60)
        let micro = Int(c.microDurationSeconds)
        let piena = Int(c.longDurationSeconds / 60)
        let quanto = c.longEveryNBreaks
        // Niente asterischi del grassetto: questa stringa arriva a `Text` come `String`
        // interpolata, non come letterale, quindi il markdown non viene interpretato e i due
        // asterischi si vedrebbero a schermo. È lo stesso difetto già pagato nei fatti.
        // **Nessun ordinale scritto a mano accanto a un numero che può cambiare.** La prima
        // stesura diceva «le prime \(quanto - 1) volte, 5 minuti la terza»: con `longEveryNBreaks`
        // a 4 sarebbe diventata «le prime 3 volte, 5 minuti la terza», che si contraddice da sola.
        // Trovato dall'audit cross-vendor del 2026-07-29 — e il difetto è più insidioso di come
        // sembra, perché nasce proprio dall'aver tirato dentro i numeri veri lasciando lì accanto
        // una parola che i numeri veri non li segue.
        return L.t("Ogni \(ogni) minuti passati davvero al computer lo schermo si copre e ti chiede un esercizio breve: \(micro) secondi, e una pausa ogni \(quanto) dura \(piena) minuti. Il conto sale solo mentre tocchi tastiera o mouse, quindi una riunione o un pranzo non ti fanno arrivare la pausa addosso appena torni.",
                   "Every \(ogni) minutes actually spent at the computer the screen covers itself and asks you for a short exercise: \(micro) seconds, and one break in every \(quanto) lasts \(piena) minutes. The count only rises while you touch the keyboard or the mouse, so a meeting or a lunch will not make a break land on you the moment you come back.")
    }

    /// Due esercizi che tutti conoscono, coi numeri che vedrebbe davvero questa persona: il
    /// sesso scelto qui sopra entra nel conto, quindi la riga cambia anche cambiando la seconda
    /// risposta.
    private var esempio: String {
        let fattore = gradual ? Settings().rampStartFactor : 1.0
        let chi = sex ?? .male
        let squat = Ramp.reps(for: .squat, factor: fattore, sex: chi)
        // **L'esercizio che riceverà davvero**, non quello che c'è in tabella: a chi ha dichiarato
        // «donna» tocca il push-up sulle ginocchia, e l'esempio deve dire quello o mentirebbe
        // proprio nella riga che serve a farsi un'idea concreta.
        let spinta = SexCalibration.regression(for: .pushUp, sex: chi, chosen: pushVariant)
        let push = Ramp.reps(for: spinta, factor: fattore, sex: chi)
        return L.t("Il primo giorno \(squat) squat, \(push) \(spinta.localizedName).",
                   "Day one: \(squat) squats, \(push) \(spinta.localizedName).")
    }

    /// Il nome che sta in un bottone da 100 punti: «push-up sulle ginocchia» non ci sta.
    private func nomeBreve(_ kind: ExerciseKind) -> String {
        switch kind {
        case .wallPushUp: return L.t("Al muro", "Wall")
        case .kneePushUp: return L.t("Ginocchia", "Knees")
        case .inclinePushUp: return L.t("Su rialzo", "Elevated")
        default: return L.t("A terra", "Floor")
        }
    }

    private func question<Content: View>(
        number: Int, title: String, detail: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("\(number)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.onAccentOnWindow)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Palette.accentOnWindow))
                Text(title).font(.system(size: 16, weight: .semibold, design: .rounded))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            content()
        }
    }

    /// **Bianco in tutti e due gli stati, e tutti e due sembrano premibili.**
    ///
    /// Prima il selezionato era testo scuro su verde pieno e il non selezionato un rettangolo
    /// appena accennato: il primo si leggeva come un'etichetta e il secondo come un fondale, e
    /// nessuno dei due diceva «premimi». Ora la differenza la fa il **riempimento**, non il colore
    /// del testo: stessa tinta per entrambi, densa su quello scelto e trasparente sull'altro, con
    /// il bordo a chiudere la forma del bottone anche quando è quasi vuoto.
    ///
    /// Il verde non arriva mai a pieno sotto il bianco per una ragione misurabile: la salvia della
    /// livrea (#8FC2A4) è chiara, e il bianco sopra darebbe un contrasto vicino a 1,5:1, cioè
    /// illeggibile. Steso al 55% sul verde notte del fondo diventa scuro quanto basta perché il
    /// bianco stia largo sopra, restando inequivocabilmente verde.
    private func choice(title: String, selected: Bool, wide: Bool = false, narrow: Bool = false,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: selected ? .semibold : .medium, design: .rounded))
                .frame(width: narrow ? 108 : (wide ? 175 : 130), height: 38)
                // Scelto: il testo sta **sopra** il riempimento pieno, quindi prende il colore
                // che regge su quel verde — bianco su fondo chiaro, verde notte su fondo scuro.
                // Non scelto: il testo sta sulla finestra, quindi è il colore normale del testo,
                // nero di giorno e bianco di notte. Bianco fisso era il difetto: su una finestra
                // chiara spariva, ed è esattamente quello che ho visto.
                .foregroundStyle(selected ? Palette.onAccentOnWindow : Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(selected ? Palette.accentOnWindow : Palette.accentOnWindow.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Palette.accentOnWindow.opacity(selected ? 1.0 : 0.55),
                                      lineWidth: selected ? 2 : 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func finish() {
        guard let sex else { return }
        var s = model.settings
        s.language = language
        s.sex = sex
        s.pushVariant = pushVariant
        // **La frase per saltare va digitata per intero, quindi dev'essere nella tua lingua.**
        // Il valore di serie è italiano perché le impostazioni nascono prima che si sappia chi
        // sei; qui la lingua è appena stata scelta. Si tocca **solo** se è ancora una delle due
        // di serie: una frase che hai cambiato tu è una tua decisione, e riscriverla te la
        // farebbe sparire senza dire niente.
        //
        // **E vale nei due versi.** La prima stesura traduceva solo verso l'inglese: chi tornava
        // all'italiano restava con «skip the break» per sempre, perché quel valore non era più
        // uguale al default italiano e nessun ramo lo riportava indietro. Rilievo dell'audit
        // cross-vendor, 2026-07-29 — ed è la forma classica del difetto, una migrazione a senso
        // unico che sembra completa perché il caso che si prova è quello che si è scritto.
        let diSerie = [AppLanguage.italian: Settings().escapePhrase, .english: "skip the break"]
        if let attesa = diSerie[language], diSerie.values.contains(s.escapePhrase) {
            s.escapePhrase = attesa
        }
        // **La rampa parte da oggi.** Chi installa l'app oggi non deve ereditare la data di
        // creazione del file delle impostazioni, che l'app scrive al primo avvio prima ancora di
        // sapere chi sei: significherebbe cominciare a settimane già passate.
        s.startDate = Date()
        // Chi sceglie i numeri pieni qui ha già risposto anche alla domanda delle due settimane:
        // rifargliela sarebbe chiedere due volte la stessa cosa.
        if !gradual {
            s.rampStartFactor = 1.0
            s.fullPaceAnswered = true
        }
        model.update(settings: s)
        onDone()
    }
}
