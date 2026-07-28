import SwiftUI
import OtiumCore

/// La domanda della settimana al 100%: **vuoi che le ripetizioni continuino a crescere?**
///
/// Arriva dopo sette giorni passati al programma pieno, non dopo sette giorni dall'installazione.
/// La differenza è tutta: chi ha appena finito la partenza graduale sa cosa vuol dire il 100% e
/// può rispondere; chi ha installato l'app la settimana scorsa starebbe indovinando.
///
/// **Perché è una domanda e non un default.** Otium nasce per interrompere la sedentarietà, e per
/// quello il 100% basta e avanza: è il programma, ed è quello che gli studi citati sostengono. La
/// crescita oltre è un'altra cosa, è allenamento, e non è ciò per cui l'app è stata installata.
/// Accenderla da soli significherebbe cambiare il patto senza chiedere.
struct GrowthCheckInView: View {

    @ObservedObject var model: AppModel
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L.t("Una settimana al 100%.", "One week at 100%."))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.accentOnWindow)
                Text(L.t("Da qui l'app può smettere di chiederti sempre lo stesso numero. Se lo vuoi, le ripetizioni salgono un po' ogni volta che confermi di averle fatte tutte, e la pausa diventa anche allenamento.",
                         "From here the app can stop asking you for the same number forever. If you want, the reps go up a little every time you confirm you did them all, and the break becomes training too."))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                riga(L.t("Si sale del 5% dopo **due** conferme piene di fila, mai dopo una sola.",
                         "It goes up 5% after **two** full confirmations in a row, never after one."))
                riga(L.t("Se non ce la fai due volte, scende di un gradino e non sotto il 100%.",
                         "If you fall short twice, it steps back down, never below 100%."))
                riga(L.t("Quando il numero non ci sta più nella pausa, ti propone il movimento più duro invece di allungarla.",
                         "When the number no longer fits the break, it offers the harder movement instead of stretching it."))
            }

            Text(L.t("Regola dell'ACSM (2-for-2), e crescere di ripetizioni vale quanto crescere di carico: Plotkin 2022, PeerJ. Le trovi in «Da dove vengono questi numeri».",
                     "ACSM's 2-for-2 rule, and progressing reps is as good as progressing load: Plotkin 2022, PeerJ. Both are in «Where these numbers come from»."))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Spacer()
                button(L.t("No, resto al 100%", "No, I'll stay at 100%"), filled: false) { answer(false) }
                button(L.t("Sì, falle crescere", "Yes, let them grow"), filled: true) { answer(true) }
            }
        }
        .padding(30)
        .frame(width: 520)
    }

    private func riga(_ testo: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("·").foregroundStyle(Palette.accentOnWindow)
            Text(.init(testo)).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func button(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: filled ? .semibold : .medium, design: .rounded))
                .frame(width: 190, height: 40)
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

    private func answer(_ grow: Bool) {
        var s = model.settings
        s.growthAnswered = true
        s.progressBeyondFull = grow
        model.update(settings: s)
        if grow {
            model.announce(
                title: L.t("Da adesso si cresce", "From now on it grows"),
                subtitle: L.t("A fine esercizio dirai se le hai fatte tutte.",
                              "At the end of each exercise you'll say whether you did them all.")
            )
        }
        onDone()
    }
}
