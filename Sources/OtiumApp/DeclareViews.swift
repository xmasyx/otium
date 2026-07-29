import SwiftUI
import OtiumCore

/// «Ne ho già fatta una»: quale esercizio, e quante ripetizioni.
///
/// Prima bastava un clic sul tipo di pausa e le ripetizioni non venivano contate — onesto, ma
/// inutile: le pause fatte a app chiusa sparivano dalle statistiche proprio nel numero che
/// interessa. Chiedere due cose in un pannello costa tre secondi e le fa esistere.
struct DeclareBreakView: View {
    @ObservedObject var model: AppModel
    var onDone: () -> Void

    @State private var kind: BreakKind = .micro
    // Opzionale davvero: "non lo ricordo" deve registrare **niente**, non squat. Etichettarlo
    // con un esercizio qualunque avrebbe messo nel registro ripetizioni mai fatte — e un
    // registro che si inventa i numeri è peggio di un registro vuoto.
    @State private var exercise: ExerciseKind?
    @State private var reps: Int = 15
    @State private var minutesAgo: Int = 0

    var body: some View {
        Form {
            Section(L.t("Che pausa era", "Which break it was")) {
                Picker(L.t("Tipo", "Kind"), selection: $kind) {
                    Text(L.t("micro-pausa", "micro-break")).tag(BreakKind.micro)
                    Text(L.t("pausa piena", "full break")).tag(BreakKind.long)
                }
                .pickerStyle(.segmented)

                Picker(L.t("Esercizio", "Exercise"), selection: $exercise) {
                    Text(L.t("non lo ricordo", "I don't remember")).tag(ExerciseKind?.none)
                    Divider()
                    ForEach(ExerciseKind.allCases, id: \.self) { k in
                        Text("\(k.localizedName)\(k.isVigorous ? L.t(" · intenso", " · vigorous") : "")").tag(ExerciseKind?.some(k))
                    }
                }
                .onChange(of: exercise) { _, new in
                    if let new { reps = model.suggestedReps(for: new) }
                }

                if let exercise {
                    // Il numero che digiti è il **totale**, come nel registro; accanto si legge
                    // quanto fa per lato, così non devi fare il conto tu.
                    //
                    // Su un esercizio a lati alterni si sale di **due**: di uno si arrivava a 7,
                    // che a schermo diventava «3 per lato» e lasciava un lato scoperto.
                    Stepper(Exercise(kind: exercise, reps: reps).stepperLabel,
                            value: $reps,
                            in: exercise.isPerSide ? 2...200 : 1...200,
                            step: exercise.isPerSide ? 2 : 1)
                } else {
                    Text(L.t("Senza esercizio la pausa viene contata, le ripetizioni no.",
                             "Without an exercise the break is counted, the reps are not."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Stepper(minutesAgo == 0 ? L.t("adesso", "just now") : L.t("\(minutesAgo) minuti fa", "\(minutesAgo) minutes ago"),
                        value: $minutesAgo, in: 0...240, step: 5)
            }

            Section {
                HStack {
                    Text(L.t("Il conto alla prossima pausa non viene toccato.",
                         "The countdown to the next break is left alone."))
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(L.t("Annulla", "Cancel")) { onDone() }
                    Button(L.t("Registra", "Log it")) {
                        model.recordCompletedBreak(kind: kind, exercise: exercise,
                                                   reps: exercise == nil ? nil : reps,
                                                   minutesAgo: minutesAgo)
                        onDone()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 330)
        .livrea()
        .onAppear { if let exercise { reps = model.suggestedReps(for: exercise) } }
    }
}

/// «Sono già al computer da…», e il totale di oggi quando è sbagliato.
///
/// Due sezioni perché sono **due numeri diversi**, ed è la confusione che è costata un errore
/// vero: il *conto per la prossima pausa* prende il valore che dichiari; il *totale di oggi
/// davanti al Mac* è una somma di righe del registro. Chiamarli entrambi "tempo al computer" li
/// faceva sembrare uno solo, e correggerne uno sballava l'altro.
struct DeclareSeatedView: View {
    @ObservedObject var model: AppModel
    var onDone: () -> Void

    @State private var minutes: Int = 30
    @State private var mode: SessionEngine.SeatedMode = .total
    @State private var totalMinutes: Int = 0

    var body: some View {
        Form {
            Section(L.t("Il conto per la prossima pausa", "The countdown to the next break")) {
                Picker("", selection: $mode) {
                    Text(L.t("in tutto sono", "in total it is")).tag(SessionEngine.SeatedMode.total)
                    Text(L.t("aggiungine", "add")).tag(SessionEngine.SeatedMode.add)
                }
                .pickerStyle(.segmented).labelsHidden()

                HStack {
                    TextField("", value: $minutes, format: .number)
                        .frame(width: 74)
                    Text("minuti").foregroundStyle(.secondary)
                    Spacer()
                    ForEach([30, 60, 90, 120, 180], id: \.self) { m in
                        Button("\(m)") { minutes = m }.buttonStyle(.bordered)
                    }
                }
                Text(mode == .total
                     ? L.t("Il conto diventa esattamente questo. Se ti sei seduto alle 13 e adesso sono 100 minuti, scrivi 100. Serve anche per abbassarlo, quando hai dichiarato troppo.",
                           "The count becomes exactly this. If you sat down at 1pm and it is now 100 minutes, write 100. It also works to lower it, when you declared too much.")
                     : L.t("Questi minuti si sommano a quelli già contati.",
                           "These minutes are added to the ones already counted."))
                    .font(.caption).foregroundStyle(.secondary)

                HStack {
                    Text(L.t("adesso il conto dice \(Int(model.engine.clock.activeSeconds / 60)) min",
                         "the count currently says \(Int(model.engine.clock.activeSeconds / 60)) min"))
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Applica") {
                        model.declareTimeAlreadySeated(minutes: minutes, mode: mode)
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }

            Section(L.t("Il totale di oggi davanti al Mac", "Today's total at the Mac")) {
                HStack {
                    TextField("", value: $totalMinutes, format: .number)
                        .frame(width: 74)
                    Text(L.t("minuti in tutto oggi", "minutes in total today")).foregroundStyle(.secondary)
                    Spacer()
                    Button("Correggi") { model.correctTodayActiveTime(toMinutes: totalMinutes) }
                }
                Text(L.t("È un numero diverso da quello sopra, qui è quanto sei stato al Mac in tutta la giornata. Correggerlo scrive una riga di rettifica, il registro non si riscrive mai.",
                         "It is a different number from the one above: this is how long you were at the Mac all day. Correcting it writes a correction row, the log is never rewritten."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Spacer()
                    Button("Chiudi") { onDone() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 420)
        .livrea()
        .onAppear { totalMinutes = model.todayActiveMinutes }
    }
}
