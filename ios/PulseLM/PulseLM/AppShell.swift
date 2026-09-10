import SwiftUI

/// Garmin Golf / GSPro-style home: Range, Play, Shots, Connect.
struct AppShell: View {
    @EnvironmentObject private var client: MonitorClient

    var body: some View {
        TabView {
            ContentView()
                .tabItem { Label("Range", systemImage: "flag.fill") }
            PlayHubView()
                .tabItem { Label("Play", systemImage: "map.fill") }
            ShotsTableView()
                .tabItem { Label("Shots", systemImage: "list.bullet.rectangle") }
            ConnectHubView()
                .tabItem { Label("Connect", systemImage: "dot.radiowaves.left.and.right") }
        }
        .tint(Color(red: 0.24, green: 1.0, blue: 0.60))
        .preferredColorScheme(.dark)
        .task { await client.refresh() }
    }
}

struct PlayHubView: View {
    @EnvironmentObject private var client: MonitorClient
    @State private var query = ""
    @State private var busy = false

    var body: some View {
        NavigationStack {
            List {
                if client.play?.playing == true {
                    Section("Current round") {
                        Text(client.play?.course_name ?? "Round")
                            .font(.headline)
                        Text(playStatus)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Open scorecard") {}
                            .disabled(true)
                    }
                }
                Section {
                    HStack {
                        TextField("Search 16,000+ courses", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit { Task { await search() } }
                        Button("Go") { Task { await search() } }
                    }
                }
                if let err = client.lastError {
                    Section { Text(err).font(.footnote).foregroundStyle(.orange) }
                }
                Section("Courses") {
                    ForEach(client.courseResults) { c in
                        Button {
                            Task { await start(c) }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(c.name ?? c.id).font(.headline).foregroundStyle(.primary)
                                Text([c.city, c.state, c.type, c.par.map { "Par \($0)" }].compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Play")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if busy { ProgressView() }
                }
            }
            .task { await search() }
        }
    }

    private var playStatus: String {
        let p = client.play
        let hole = p?.hole.map { "Hole \($0)" } ?? ""
        let rem = p?.remaining_yd.map { String(format: "%.0f yd left", $0) } ?? ""
        let tp = p?.to_par.map { $0 == 0 ? "E" : String(format: "%+d", $0) } ?? ""
        return [hole, rem, tp].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func search() async {
        busy = true
        defer { busy = false }
        _ = try? await client.searchCourses(q: query)
    }

    private func start(_ c: CourseSummary) async {
        busy = true
        defer { busy = false }
        do {
            _ = try await client.startPlay(courseId: c.id)
        } catch {
            client.lastError = error.localizedDescription
        }
    }
}

struct ShotsTableView: View {
    @EnvironmentObject private var client: MonitorClient

    var body: some View {
        NavigationStack {
            List {
                Section("Last shot") {
                    if let s = client.latest {
                        metricRow("Ball speed", ShotMapping.speedString(s.ball_speed_mph), "mph")
                        metricRow("Carry", ShotMapping.carryString(s.carry_yd_est), "yd")
                        metricRow("Total", ShotMapping.carryString(s.total_yd_est), "yd")
                        metricRow("Launch (VLA)", ShotMapping.vlaString(s.vla_deg), "°")
                        metricRow("HLA", ShotMapping.metricString(s.hla_deg, decimals: 1), "°")
                        metricRow("Spin", ShotMapping.metricString(s.spin_rpm, decimals: 0), "rpm")
                        metricRow("Spin axis", ShotMapping.metricString(s.spin_axis_deg, decimals: 1), "°")
                        metricRow("Club speed", ShotMapping.metricString(s.club_speed_mph, decimals: 1), "mph")
                        metricRow("Face", ShotMapping.metricString(s.face_deg, decimals: 1), "°")
                        metricRow("Path", ShotMapping.metricString(s.path_deg, decimals: 1), "°")
                        metricRow("Smash", smash(s), "")
                        metricRow("Apex", client.practice?.tiles?.apex_yd.map { String(format: "%.0f", $0) } ?? "—", "yd")
                        metricRow("Hang time", client.practice?.tiles?.hang_time_s.map { String(format: "%.1f", $0) } ?? "—", "s")
                        metricRow("Land angle", client.practice?.tiles?.land_angle_deg.map { String(format: "%.0f", $0) } ?? "—", "°")
                        metricRow("Offline", client.practice?.tiles?.offline_yd.map { String(format: "%.1f", $0) } ?? "—", "yd")
                    } else {
                        Text("No shot yet. Connect the PC, then Arm or hit the R10.")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Session (\(client.shots.count))") {
                    ForEach(client.shots.reversed()) { s in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(s.shot_id).font(.caption.monospaced())
                            Text("\(ShotMapping.speedString(s.ball_speed_mph)) mph  ·  \(ShotMapping.carryString(s.carry_yd_est)) yd  ·  VLA \(ShotMapping.vlaString(s.vla_deg))")
                                .font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle("Shots")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Refresh") { Task { await client.refresh() } }
                }
            }
            .refreshable { await client.refresh() }
        }
    }

    private func smash(_ s: ShotResult) -> String {
        guard let b = s.ball_speed_mph, let c = s.club_speed_mph, c > 0 else { return "—" }
        return String(format: "%.2f", b / c)
    }

    private func metricRow(_ title: String, _ value: String, _ unit: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(unit.isEmpty ? value : "\(value) \(unit)")
                .font(.body.monospacedDigit().weight(.semibold))
        }
    }
}

struct ConnectHubView: View {
    @EnvironmentObject private var client: MonitorClient
    @ObservedObject private var r10 = R10Bluetooth.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This iPhone is the app. No PC.")
                        .font(.headline)
                    Text(r10.connected ? "R10 linked" : "Practice with ARM, or pair your R10")
                        .foregroundStyle(.secondary)
                }
                Section("Garmin Approach R10") {
                    Text(r10.status)
                    Button(r10.connected ? "Disconnect R10" : "Scan & pair R10") {
                        if r10.connected { r10.stop() } else { r10.scan() }
                    }
                    Text("Turn the R10 on (LED solid blue). Close Garmin Golf so this app can own Bluetooth. Place the R10 6–8 ft behind the ball.")
                        .font(.footnote)
                }
                Section("Play without a monitor") {
                    Text("Range → ARM records a practice shot on this phone. Play → pick Bethpage (or search) → ARM each swing. 18 holes, scorecard, 3D hole.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Connect")
            .onAppear {
                r10.onShot = { shot in
                    Task { @MainActor in
                        _ = PhoneHub.shared.ingest(shot)
                        client.latest = shot
                        client.shots = PhoneHub.shared.shots
                        client.play = PhoneHub.shared.play
                    }
                }
            }
        }
    }
}
