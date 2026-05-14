import SwiftUI
import PhotosUI

struct AddMatchView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = AddMatchViewModel()

    var body: some View {
        Group {
            switch vm.step {
            case .photoSelection: photoSelectionStep
            case .analyzing:      analyzingStep
            case .reviewMatch:    reviewMatchStep
            case .editCaption:    captionStep
            case .confirmPost:    confirmPostStep
            case .posting:        postingStep
            case .done:           doneStep
            case .failed:         failedStep
            }
        }
        .navigationTitle("Add Match")
        .onAppear {
            vm.viewContext = appState.viewContext
            vm.player = appState.activePlayer
            // If the queue handed us a staged photo, load it immediately
            if let staged = appState.pendingStagedPhoto {
                appState.pendingStagedPhoto = nil
                vm.loadFromQueue(staged)
            }
        }
    }

    // MARK: - Step Views

    private var photoSelectionStep: some View {
        VStack(spacing: 24) {
            if let image = vm.selectedImage {
                Image(nsImage: image)
                    .resizable().scaledToFit()
                    .frame(maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Button("Analyze Photo") { vm.analyze() }
                    .buttonStyle(.borderedProminent)
                Button("Choose Different Photo") { vm.selectedImage = nil }
                    .buttonStyle(.bordered)
            } else {
                PhotoDropZone { image, data in vm.photoSelected(image, data: data) }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var analyzingStep: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Analyzing photo…").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var reviewMatchStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let analysis = vm.analysis {
                    VisionResultCard(analysis: analysis, exif: vm.exifData)
                }

                if vm.knvbMatches.isEmpty {
                    Text("No KNVB matches found — enter details manually:")
                        .foregroundStyle(.secondary)
                    ManualMatchForm(input: $vm.manualMatch)
                    Button("Continue with Manual Entry") { vm.confirmManual() }
                        .buttonStyle(.borderedProminent)
                } else {
                    Text("Select the matching fixture:").font(.headline)
                    ForEach(vm.knvbMatches, id: \.id) { match in
                        KNVBMatchRow(match: match) { vm.confirmMatch(match) }
                    }
                    Divider()
                    Button("Enter Manually Instead") { vm.confirmManual() }
                        .buttonStyle(.bordered)
                }
            }
            .padding()
        }
    }

    private var captionStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if var post = vm.post {
                    Text("Caption").font(.headline)
                    TextEditor(text: Binding(
                        get: { post.caption },
                        set: { post.caption = $0; vm.post = post }
                    ))
                    .frame(minHeight: 120)
                    .padding(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))

                    Text("Hashtags").font(.headline)
                    HashtagChipsView(tags: post.hashtags)

                    HStack {
                        Text("\(post.characterCount)/2200")
                            .font(.caption)
                            .foregroundStyle(post.isOverLimit ? .red : .secondary)
                        Spacer()
                        Button("Upload & Preview") { vm.uploadAndConfirm() }
                            .buttonStyle(.borderedProminent)
                            .disabled(post.isOverLimit)
                    }
                }
            }
            .padding()
        }
    }

    private var confirmPostStep: some View {
        VStack(spacing: 20) {
            Text("Ready to Post").font(.title2.bold())
            if let image = vm.selectedImage {
                Image(nsImage: image)
                    .resizable().scaledToFill()
                    .frame(width: 300, height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            if let caption = vm.post?.fullCaption {
                ScrollView {
                    Text(caption).font(.caption).padding()
                }
                .frame(maxHeight: 120)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
            }
            HStack {
                Button("Back") { vm.step = .editCaption }.buttonStyle(.bordered)
                Button("Post to Instagram") { vm.publishToInstagram() }.buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var postingStep: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Posting to Instagram…").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var doneStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 60)).foregroundStyle(.green)
            Text("Posted!").font(.largeTitle.bold())
            if let id = vm.post?.publishedPostID {
                Text("Post ID: \(id)").font(.caption).foregroundStyle(.secondary)
            }
            Button("Add Another Match") { vm.reset() }.buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var failedStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 40)).foregroundStyle(.red)
            Text(vm.error?.errorDescription ?? "Something went wrong").multilineTextAlignment(.center)
            Button("Try Again") { vm.reset() }.buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Supporting Views

struct PhotoDropZone: View {
    let onDrop: (NSImage, Data) -> Void
    @State private var isTargeted = false
    @State private var showPicker = false
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.badge.plus").font(.system(size: 60)).foregroundStyle(.secondary)
            Text("Drop a photo here or click to choose").foregroundStyle(.secondary)
            PhotosPicker("Choose from Photos", selection: $pickerItem, matching: .images)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .background(isTargeted ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(
            isTargeted ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 2))
        .onDrop(of: [.image], isTargeted: $isTargeted) { providers in
            providers.first?.loadDataRepresentation(forTypeIdentifier: "public.image") { data, _ in
                if let data, let image = NSImage(data: data) {
                    DispatchQueue.main.async { onDrop(image, data) }
                }
            }
            return true
        }
        .onChange(of: pickerItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let image = NSImage(data: data) {
                    onDrop(image, data)
                }
            }
        }
    }
}

struct VisionResultCard: View {
    let analysis: MatchAnalysis
    let exif: EXIFData?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Vision Analysis", systemImage: "eye.fill")
                    .font(.headline)
                Spacer()
                ConfidenceBadge(confidence: analysis.confidence)
            }
            HStack {
                Label(analysis.homeTeam.isEmpty ? "Unknown" : analysis.homeTeam, systemImage: "house.fill")
                Text("vs")
                Label(analysis.awayTeam.isEmpty ? "Unknown" : analysis.awayTeam, systemImage: "airplane.departure")
            }
            .font(.subheadline)
            if let score = analysis.visibleScore {
                Text("Scoreboard: \(score.home)–\(score.away)").font(.caption).foregroundStyle(.secondary)
            }
            if let date = exif?.date {
                Label(date.formatted(date: .long, time: .shortened), systemImage: "calendar")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ConfidenceBadge: View {
    let confidence: Double
    var body: some View {
        Text("\(Int(confidence * 100))%")
            .font(.caption.bold())
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(confidence >= 0.7 ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
            .foregroundStyle(confidence >= 0.7 ? .green : .orange)
            .clipShape(Capsule())
    }
}

struct KNVBMatchRow: View {
    let match: KNVBMatch
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(match.homeTeam) vs \(match.awayTeam)").font(.subheadline.bold())
                    if let hg = match.homeGoals, let ag = match.awayGoals {
                        Text("Result: \(hg)–\(ag)").font(.caption).foregroundStyle(.green)
                    }
                    Text(match.date, style: .date).font(.caption).foregroundStyle(.secondary)
                    if let comp = match.competition { Text(comp).font(.caption2).foregroundStyle(.secondary) }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

struct ManualMatchForm: View {
    @Binding var input: ManualMatchInput

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Opponent", text: $input.opponent)
                    .textFieldStyle(.roundedBorder)
                Toggle("Home", isOn: $input.wasHome)
            }
            HStack {
                Stepper("Home: \(input.homeGoals)", value: $input.homeGoals, in: 0...99)
                Stepper("Away: \(input.awayGoals)", value: $input.awayGoals, in: 0...99)
            }
            TextField("Competition (optional)", text: $input.competition)
                .textFieldStyle(.roundedBorder)
            DatePicker("Date", selection: $input.date, displayedComponents: .date)
        }
        .padding()
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct HashtagChipsView: View {
    let tags: [String]
    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text("#\(tag)")
                    .font(.caption)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0; var y: CGFloat = 0; var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX; var y = bounds.minY; var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
