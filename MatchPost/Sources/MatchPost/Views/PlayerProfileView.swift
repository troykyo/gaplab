import SwiftUI

struct PlayerProfileView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = ProfileViewModel()
    @State private var showSavedBanner = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Player Profile").font(.title.bold()).padding(.bottom, 4)

                // Basic Info
                GroupBox("Basic Info") {
                    VStack(spacing: 12) {
                        LabeledTextField("Full Name", text: $vm.name)
                        Picker("Position", selection: $vm.position) {
                            ForEach(vm.positions, id: \.self) { Text($0) }
                        }
                        LabeledTextField("Current Club", text: $vm.currentTeam)
                        LabeledTextField("Jersey Number", text: $vm.jerseyNumber)
                        LabeledTextField("Instagram Handle (@)", text: $vm.instagramHandle)
                        DatePicker("Date of Birth", selection: $vm.dateOfBirth, displayedComponents: .date)
                    }
                    .padding(.top, 4)
                }

                // Career Entries
                GroupBox("Career History") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach($vm.careerEntries) { $entry in
                            CareerEntryRow(entry: $entry) {
                                vm.careerEntries.removeAll { $0.id == entry.id }
                            }
                        }
                        Button(action: vm.addCareerEntry) {
                            Label("Add Club", systemImage: "plus.circle")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 4)
                }

                HStack {
                    Spacer()
                    Button("Save Profile") {
                        if let player = appState.activePlayer {
                            vm.save(to: player, context: appState.viewContext)
                        } else {
                            let player = vm.createPlayer(context: appState.viewContext)
                            appState.activePlayer = player
                        }
                        PersistenceController.shared.save()
                        withAnimation { showSavedBanner = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showSavedBanner = false }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .overlay(alignment: .top) {
            if showSavedBanner {
                Label("Profile saved", systemImage: "checkmark.circle.fill")
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color.green.opacity(0.9))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        .onAppear { if let p = appState.activePlayer { vm.load(from: p) } }
    }
}

struct LabeledTextField: View {
    let label: String
    @Binding var text: String
    init(_ label: String, text: Binding<String>) { self.label = label; _text = text }
    var body: some View {
        HStack {
            Text(label).frame(width: 140, alignment: .leading).foregroundStyle(.secondary)
            TextField(label, text: $text).textFieldStyle(.roundedBorder)
        }
    }
}

struct CareerEntryRow: View {
    @Binding var entry: CareerEntryDraft
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Club name", text: $entry.teamName).textFieldStyle(.roundedBorder)
                TextField("Age group (U14)", text: $entry.ageGroup).textFieldStyle(.roundedBorder).frame(width: 110)
                TextField("#", text: $entry.jerseyNumber).textFieldStyle(.roundedBorder).frame(width: 50)
                Button(action: onDelete) { Image(systemName: "minus.circle.fill").foregroundStyle(.red) }
                    .buttonStyle(.plain)
            }
            HStack {
                DatePicker("From", selection: $entry.seasonStart, displayedComponents: .date)
                Toggle("Current", isOn: $entry.isCurrent)
                if !entry.isCurrent {
                    DatePicker("To", selection: Binding(
                        get: { entry.seasonEnd ?? Date() },
                        set: { entry.seasonEnd = $0 }
                    ), displayedComponents: .date)
                }
            }
            .font(.callout)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
