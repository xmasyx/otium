import SwiftUI
import OtiumCore

/// La domanda delle due settimane: **vuoi già il numero pieno?**
///
/// Perché è una domanda e non una tacca automatica. La partenza graduale esiste per una ragione
/// vera — cominciare a quindici squat quando sei fermo da mesi è il modo di smettere in tre
/// giorni — ma quattro settimane sono lunghe per chi è già allenato, e nessuna app sa quanto sei
/// in forma. Dedurlo dai dati sarebbe peggio: il registro dice che hai fatto le ripetizioni che
/// **ti sono state chieste**, non quante ne avresti potute fare.
///
/// Si presenta una volta sola, e «non ancora» non è un rinvio: è una risposta. La salita continua
/// come prima e arriva al pieno da sé. Un'app che ripropone la stessa scelta ogni settimana non
/// sta chiedendo, sta insistendo.
struct PaceCheckInView: View {

    @ObservedObject var model: AppModel
    let onDone: () -> Void

    private var percentualeOggi: Int { Int(model.settings.rampFactor(now: Date()) * 100) }
    private var settimane: Int {
        max(1, Ramp.weeksElapsed(since: model.settings.startDate, now: Date()))
    }

    private var titolo: String {
        settimane == 1
            ? L.t("Una settimana.", "One week in.")
            : L.t("\(settimane) settimane.", "\(settimane) weeks in.")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                // Il titolo dice quante settimane sono passate davvero: «Due settimane» a una
                // settimana dall'installazione sarebbe la prima bugia che l'app racconta.
                Text(titolo)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.accentOnWindow)
                Text(L.t("Sei partito piano, come si deve, e oggi fai \(ItalianNumber.il(percentualeOggi))% delle ripetizioni. Se ti stanno venendo facili, puoi passare al 100% da adesso.",
                         "You started gently, as you should: today you do \(percentualeOggi)% of the reps. If they are coming easy, you can move to the full ones right now."))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Prima diceva «è quello a cui la salita arriva da sola», che è contorto e non
            // significa niente a prima lettura. Visto all'uso il 2026-07-28.
            Text(L.t("Non c'è una risposta giusta. Se rispondi «non ancora», al 100% ci arrivi comunque fra qualche settimana.",
                     "There is no right answer: if you say «not yet», you get to 100% anyway in a few weeks."))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Spacer()
                button(L.t("Non ancora", "Not yet"), filled: false) { answer(fullPace: false) }
                button(L.t("Sì, al 100%", "Yes, 100%"), filled: true) { answer(fullPace: true) }
            }
        }
        .padding(30)
        .frame(width: 480)
    }

    private func button(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: filled ? .semibold : .medium, design: .rounded))
                .frame(width: 170, height: 40)
                .foregroundStyle(filled ? Palette.onAccentOnWindow : Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(filled ? Palette.accentOnWindow : Palette.accentOnWindow.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Palette.accentOnWindow.opacity(filled ? 1.0 : 0.55),
                                      lineWidth: filled ? 2 : 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func answer(fullPace: Bool) {
        var s = model.settings
        s.fullPaceAnswered = true
        // Sì significa **adesso**, non «fra una settimana»: si porta il punto di partenza al
        // pieno, e la salita non ha più niente da salire.
        if fullPace { s.rampStartFactor = 1.0 }
        model.update(settings: s)
        if fullPace {
            model.announce(title: L.t("Sei al 100%", "You are at 100%"),
                           subtitle: L.t("Da adesso i set sono completi.",
                                         "From now on the sets are complete."))
        }
        onDone()
    }
}
