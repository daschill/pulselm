import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var client: MonitorClient
    @State private var showHostEditor = false
    @State private var showCourses = false
    @State private var showScorecard = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    header
                    ShotHUD(shot: client.latest, compact: true)
                    playBanner
                    RangeView(
                        shot: client.latest,
                        session: client.shots,
                        practice: client.practice,
                        pinOverride: client.play?.playing == true ? (client.play?.remaining_yd ?? client.play?.pin_yd) : nil,
                        selectedClub: $client.selectedClub,
                        gameMode: $client.gameMode
                    )
                    sessionStrip
                    armButton
                    statusLine
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 28)
            }
            .background(Color(red: 0.027, green: 0.035, blue: 0.051).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("PULSELM")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .tracking(3)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showHostEditor.toggle()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Monitor address")
                }
            }
            .sheet(isPresented: $showHostEditor) {
                hostSheet
            }
            .sheet(isPresented: $showCourses) {
                courseSheet
            }
            .sheet(isPresented: $showScorecard) {
                scorecardSheet
            }
            .task {
                await client.refresh()
            }
            .refreshable {
                await client.refresh()
            }
        }
    }

    private var playBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    showCourses = true
                    Task { _ = try? await client.searchCourses() }
                } label: {
                    Text(client.play?.playing == true ? (client.play?.course_name ?? "Course") : "Play a course")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                Spacer()
                if client.play?.playing == true || client.play?.round_complete == true {
                    Button("Card") { showScorecard = true }
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                if client.play?.playing == true {
                    Button("Gimme") {
                        Task {
                            _ = try? await client.gimmePlay()
                            _ = try? await client.fetchPlay()
                        }
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
            }
            if client.play?.playing == true {
                Text(playLine)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
    }

    private var playLine: String {
        let p = client.play
        let hole = p?.hole.map { "Hole \($0)" } ?? "Hole"
        let par = p?.hole_par.map { "par \($0)" } ?? ""
        let rem = p?.remaining_yd.map { String(format: "%.0f yd left", $0) } ?? ""
        let st = p?.strokes.map { "\($0) strokes" } ?? ""
        let tp = p?.to_par.map { $0 == 0 ? "E" : String(format: "%+d", $0) } ?? ""
        return [hole, par, rem, st, tp].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private var scorecardSheet: some View {
        let card = client.play?.scorecard ?? []
        let holes = client.play?.holes ?? []
        return NavigationStack {
            List {
                Section(client.play?.course_name ?? "Scorecard") {
                    ForEach(1...18, id: \.self) { n in
                        let scored = card.first { $0.hole == n }
                        let def = holes.first { $0.hole == n }
                        HStack {
                            Text("\(n)")
                                .frame(width: 28)
                            Text("par \(scored?.par ?? def?.par ?? 4)")
                                .foregroundStyle(.secondary)
                            Spacer()
                            if let s = scored {
                                Text("\(s.strokes)")
                                    .bold()
                                Text(s.to_par == 0 ? "E" : String(format: "%+d", s.to_par))
                                    .foregroundStyle(s.to_par < 0 ? Color.green : .secondary)
                            } else if client.play?.hole == n {
                                Text("playing")
                                    .foregroundStyle(Color(red: 0.24, green: 1.0, blue: 0.60))
                            } else {
                                Text(def?.pin_yd.map { "\($0) yd" } ?? "—")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if let tp = client.play?.to_par, let thru = client.play?.thru {
                    Section {
                        Text("Thru \(thru) · \(tp == 0 ? "E" : String(format: "%+d", tp))")
                    }
                }
            }
            .navigationTitle("18 holes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showScorecard = false }
                }
            }
        }
    }

    private var courseSheet: some View {
        NavigationStack {
            List(client.courseResults) { c in
                Button {
                    Task {
                        if let id = Optional(c.id) {
                            _ = try? await client.startPlay(courseId: id)
                            showCourses = false
                        }
                    }
                } label: {
                    VStack(alignment: .leading) {
                        Text(c.name ?? c.id)
                            .font(.headline)
                        Text([c.city, c.state, c.par.map { "par \($0)" }].compactMap { $0 }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Play")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showCourses = false }
                }
            }
            .task { _ = try? await client.searchCourses() }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Indoor dual-strobe")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text("iPhone display only")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            healthBadge
        }
        .padding(.top, 8)
    }

    private var healthBadge: some View {
        let ok = client.health?.ok == true
        return HStack(spacing: 6) {
            Circle()
                .fill(ok ? Color(red: 0.24, green: 1.0, blue: 0.60) : Color.orange)
                .frame(width: 8, height: 8)
            Text(ok ? (client.health?.demo == true ? "demo" : "live") : "offline")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .textCase(.uppercase)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06), in: Capsule())
    }

    private var sessionStrip: some View {
        let s = client.sessionSummary
        return HStack(spacing: 10) {
            sessionCell("Shots", s.map { "\($0.shot_count)" } ?? "—")
            sessionCell("Avg mph", ShotMapping.speedString(s?.ball_speed_mph_mean))
            sessionCell("Avg carry", ShotMapping.carryString(s?.carry_yd_est_mean))
            sessionCell("Best", ShotMapping.speedString(s?.ball_speed_mph_max))
        }
    }

    private func sessionCell(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    private var armButton: some View {
        Button {
            Task { await arm() }
        } label: {
            HStack {
                if client.isBusy {
                    ProgressView()
                        .tint(Color(red: 0.02, green: 0.13, blue: 0.08))
                }
                Text(client.isBusy ? "Arming…" : "Arm")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .tracking(1.4)
                    .textCase(.uppercase)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(Color(red: 0.02, green: 0.13, blue: 0.08))
            .background(Color(red: 0.24, green: 1.0, blue: 0.60), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(client.isBusy)
        .accessibilityLabel("Arm")
        .accessibilityHint("Posts arm and updates HUD and range landing from the JSON payload")
    }

    private var statusLine: some View {
        VStack(spacing: 4) {
            if let err = client.lastError {
                Text(err)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
            Text(footer)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var footer: String {
        let gap = client.latest?.pulse_gap_s ?? client.health?.pulse_gap_s ?? 0.002
        let ok = client.latest.map { $0.ok ? "ok" : ($0.error ?? "error") } ?? "no shot"
        return "\(ok) · pulse_gap_s \(gap) · HLA / spin / club from JSON"
    }

    private var hostSheet: some View {
        NavigationStack {
            Form {
                Section("Pi monitor") {
                    TextField("Base URL", text: $client.baseURLString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Text("Default \(MonitorClient.defaultBaseURLString). HTTP on the LAN is allowed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Connection")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showHostEditor = false
                        Task { await client.refresh() }
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func arm() async {
        do {
            _ = try await client.arm()
            _ = try? await client.fetchShots()
            _ = try? await client.fetchSession()
            _ = try? await client.fetchPlay()
            if let pin = client.play?.remaining_yd ?? client.play?.pin_yd {
                _ = try? await client.fetchPractice(pin: pin)
            }
        } catch {
            client.lastError = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(MonitorClient())
}
