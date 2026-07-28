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
            Section("Che pausa era") {
                Picker("Tipo", selection: $kind) {
                    Text("micro-pausa").tag(BreakKind.micro)
                    Text("pausa piena").tag(BreakKind.long)
                }
                .pickerStyle(.segmented)

                Picker("Esercizio", selection: $exercise) {
                    Text("non lo ricordo").tag(ExerciseKind?.none)
                    Divider()
                    ForEach(ExerciseKind.allCases, id: \.self) { k in
                        Text("\(k.italianName)\(k.isVigorous ? " · intenso" : "")").tag(ExerciseKind?.some(k))
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
                    Text("Senza esercizio la pausa viene contata, le ripetizioni no.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Stepper(minutesAgo == 0 ? "adesso" : "\(minutesAgo) minuti fa",
                        value: $minutesAgo, in: 0...240, step: 5)
            }

            Section {
                HStack {
                    Text("Il conto alla prossima pausa non viene toccato.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Annulla") { onDone() }
                    Button("Registra") {
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
            Section("Il conto per la prossima pausa") {
                Picker("", selection: $mode) {
                    Text("in tutto sono").tag(SessionEngine.SeatedMode.total)
                    Text("aggiungine").tag(SessionEngine.SeatedMode.add)
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
                     ? "Il conto diventa esattamente questo: se ti sei seduto alle 13 e adesso sono 100 minuti, scrivi 100. Serve anche per abbassarlo, quando hai dichiarato troppo."
                     : "Questi minuti si sommano a quelli già contati.")
                    .font(.caption).foregroundStyle(.secondary)

                HStack {
                    Text("adesso il conto dice \(Int(model.engine.clock.activeSeconds / 60)) min")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Applica") {
                        model.declareTimeAlreadySeated(minutes: minutes, mode: mode)
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }

            Section("Il totale di oggi davanti al Mac") {
                HStack {
                    TextField("", value: $totalMinutes, format: .number)
                        .frame(width: 74)
                    Text("minuti in tutto oggi").foregroundStyle(.secondary)
                    Spacer()
                    Button("Correggi") { model.correctTodayActiveTime(toMinutes: totalMinutes) }
                }
                Text("È un numero diverso da quello sopra: qui è quanto sei stato al Mac in "
                   + "tutta la giornata. Correggerlo scrive una riga di rettifica — il registro "
                   + "non si riscrive mai.")
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
        .onAppear { totalMinutes = model.todayActiveMinutes }
    }
}
