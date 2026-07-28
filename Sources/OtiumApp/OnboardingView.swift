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
    /// Solo per le rese: permette di guardare com'è fatta la schermata **a scelta già fatta**,
    /// che è l'unico modo di giudicare il bottone selezionato senza cliccarlo a mano.
    var preselectedSex: Sex?

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Otium")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.accent)
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
                        .foregroundStyle(Palette.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack {
                Spacer()
                Button(action: finish) {
                    Text(L.t("Comincia", "Start"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .frame(width: 190, height: 44)
                        .foregroundStyle(sex == nil ? Palette.dim : Palette.ink)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(sex == nil ? Color.white.opacity(0.07) : Palette.accent)
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

    private func question<Content: View>(
        number: Int, title: String, detail: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("\(number)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Palette.accent))
                Text(title).font(.system(size: 16, weight: .semibold, design: .rounded))
                Text(detail).font(.system(size: 11)).foregroundStyle(Palette.dim)
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
    private func choice(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: selected ? .semibold : .medium, design: .rounded))
                .frame(width: 130, height: 38)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Palette.accent.opacity(selected ? 0.55 : 0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Palette.accent.opacity(selected ? 1.0 : 0.45),
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
        model.update(settings: s)
        onDone()
    }
}
