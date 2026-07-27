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

                if exercise != nil {
                    Stepper("\(reps) ripetizioni", value: $reps, in: 1...200)
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

/// «Sono già al computer da…», con la possibilità di scrivere il numero invece di sceglierlo.
struct DeclareSeatedView: View {
    @ObservedObject var model: AppModel
    var onDone: () -> Void

    @State private var minutes: Int = 30

    var body: some View {
        Form {
            Section("Da quanto sei già al computer") {
                HStack {
                    TextField("", value: $minutes, format: .number)
                        .frame(width: 70)
                    Text("minuti").foregroundStyle(.secondary)
                    Spacer()
                    ForEach([15, 30, 45, 60, 90], id: \.self) { m in
                        Button("\(m)") { minutes = m }.buttonStyle(.bordered)
                    }
                }
                Text("Il contatore sale a questo valore: se sei seduto da un'ora, la pausa è "
                   + "in ritardo, non fra mezz'ora. Dichiarare meno di quanto l'app ha già "
                   + "misurato non toglie tempo.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                HStack {
                    Spacer()
                    Button("Annulla") { onDone() }
                    Button("Conta") {
                        model.declareTimeAlreadySeated(minutes: minutes)
                        onDone()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 230)
    }
}
