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
    /// Solo per le rese: permette di guardare com'è fatta la schermata **a scelta già fatta**,
    /// che è l'unico modo di giudicare il bottone selezionato senza cliccarlo a mano.
    var preselectedSex: Sex?

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Otium")
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
                detail: L.t("Si cambia quando vuoi dalle preferenze.",
                            "You can change it any time in preferences.")
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
                detail: L.t("Serve solo a decidere da quante ripetizioni partire.",
                            "Used only to decide how many reps to start from.")
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        choice(title: L.t("Uomo", "Male"), selected: sex == .male) { sex = .male }
                        choice(title: L.t("Donna", "Female"), selected: sex == .female) { sex = .female }
                    }
                    // L'app dice **perché** chiede, mentre lo chiede. Una domanda sul corpo senza
                    // una ragione visibile è una domanda a cui è ragionevole non voler rispondere.
                    Text(L.t("Uno studio su otto uomini e otto donne (Miller 1993) misura circa il 52% della forza maschile nella parte alta del corpo e il 66% in quella bassa. Proporre a tutti lo stesso numero di flessioni significa proporre a metà delle persone un compito che non riescono a fare. Non è un tetto: è il primo giorno, e da lì si sale.",
                             "A study of eight men and eight women (Miller 1993) measured roughly 52% of male strength in the upper body and 66% in the lower body. Offering everyone the same number of push-ups means offering half of them a task they cannot do. It is not a ceiling: it is day one, and it goes up from there."))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            question(
                number: 3,
                title: L.t("Da che numeri parti", "Where you start from"),
                detail: L.t("Si cambia dalle preferenze.", "You can change it in preferences.")
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        choice(title: L.t("Partenza graduale", "Gradual start"),
                               selected: gradual, wide: true) { gradual = true }
                        choice(title: L.t("Numeri pieni", "Full numbers"),
                               selected: !gradual, wide: true) { gradual = false }
                    }
                    // **I numeri veri, non una percentuale.** «Parti al 55%» non dice niente a
                    // nessuno; «8 squat invece di 15» si capisce senza pensarci, e cambia sotto
                    // gli occhi quando tocchi la domanda qui sopra.
                    Text(esempio)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Palette.accentOnWindow)
                    Text(gradual
                         ? L.t("Si sale un pochino ogni giorno fino ai numeri interi, in tre settimane. Serve a non smettere dopo tre giorni.",
                               "It goes up a little every day until the whole numbers, over three weeks. It is there so you don't quit after three days.")
                         : L.t("Nessuna partenza morbida: da domani i numeri sono quelli. Se sei già allenato è la scelta giusta.",
                               "No soft start: from tomorrow those are the numbers. If you already train, this is the right choice."))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack {
                Spacer()
                Button(action: finish) {
                    Text(L.t("Comincia", "Start"))
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
        .padding(34)
        .frame(width: 540)
        .onAppear { if let preselectedSex { sex = preselectedSex } }
    }

    /// Due esercizi che tutti conoscono, coi numeri che vedrebbe davvero questa persona: il
    /// sesso scelto qui sopra entra nel conto, quindi la riga cambia anche cambiando la seconda
    /// risposta.
    private var esempio: String {
        let fattore = gradual ? Settings().rampStartFactor : 1.0
        let squat = Ramp.reps(for: .squat, factor: fattore, sex: sex ?? .male)
        let push = Ramp.reps(for: .pushUp, factor: fattore, sex: sex ?? .male)
        return L.t("Il primo giorno: \(squat) squat, \(push) push-up.",
                   "Day one: \(squat) squats, \(push) push-ups.")
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
    private func choice(title: String, selected: Bool, wide: Bool = false,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: selected ? .semibold : .medium, design: .rounded))
                .frame(width: wide ? 175 : 130, height: 38)
                // Scelto: il testo sta **sopra** il riempimento pieno, quindi prende il colore
                // che regge su quel verde — bianco su fondo chiaro, verde notte su fondo scuro.
                // Non scelto: il testo sta sulla finestra, quindi è il colore normale del testo,
                // nero di giorno e bianco di notte. Bianco fisso era il difetto: su una finestra
                // chiara spariva, ed è esattamente quello che il principale ha visto.
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
