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
        .tint(PulseTheme.lime)
        .preferredColorScheme(.dark)
        .task {
            await client.refresh()
            OpenConnectServer.shared.refreshAddress()
            if !OpenConnectServer.shared.listening {
                OpenConnectServer.shared.start()
            }
            let apply: (ShotResult) -> Void = { shot in
                Task { @MainActor in
                    client.latest = shot
                    client.shots = PhoneHub.shared.shots
                    client.play = PhoneHub.shared.play
                }
            }
            OpenConnectServer.shared.onShot = apply
            R10Bluetooth.shared.onShot = { shot in
                _ = PhoneHub.shared.ingest(shot)
                apply(shot)
            }
        }
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
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(client.play?.course_name ?? "Round")
                                .font(.headline)
                            Text(playStatus)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Current round")
                    }
                }
                Section {
                    HStack {
                        TextField("Search courses", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit { Task { await search() } }
                        Button("Search") { Task { await search() } }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PulseTheme.lime)
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
                                Text(c.name ?? c.id)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text([c.city, c.state, c.type, c.par.map { "Par \($0)" }].compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(PulseTheme.ink)
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
                Section {
                    if let s = client.latest {
                        HStack {
                            lastShotHero("SPEED", ShotMapping.speedString(s.ball_speed_mph), "mph", accent: true)
                            lastShotHero("CARRY", ShotMapping.carryString(s.carry_yd_est), "yd")
                            lastShotHero("LAUNCH", ShotMapping.vlaString(s.vla_deg), "°")
                        }
                        .listRowBackground(Color.clear)
                        metricRow("Total", ShotMapping.carryString(s.total_yd_est), "yd")
                        metricRow("HLA", ShotMapping.metricString(s.hla_deg, decimals: 1), "°")
                        metricRow("Spin", ShotMapping.metricString(s.spin_rpm, decimals: 0), "rpm")
                        metricRow("Spin axis", ShotMapping.metricString(s.spin_axis_deg, decimals: 1), "°")
                        metricRow("Club speed", ShotMapping.metricString(s.club_speed_mph, decimals: 1), "mph")
                        metricRow("Smash", smash(s), "")
                        metricRow("Face", ShotMapping.metricString(s.face_deg, decimals: 1), "°")
                        metricRow("Path", ShotMapping.metricString(s.path_deg, decimals: 1), "°")
                        metricRow("Apex", client.practice?.tiles?.apex_yd.map { String(format: "%.0f", $0) } ?? "—", "yd")
                        metricRow("Hang time", client.practice?.tiles?.hang_time_s.map { String(format: "%.1f", $0) } ?? "—", "s")
                        metricRow("Offline", client.practice?.tiles?.offline_yd.map { String(format: "%.1f", $0) } ?? "—", "yd")
                    } else {
                        Text("No shot yet. Hit on Range, or pair an R10 in Connect.")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Last shot")
                }
                Section("Session (\(client.shots.count))") {
                    ForEach(client.shots.reversed()) { s in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(s.shot_id).font(.caption.monospaced()).foregroundStyle(.secondary)
                            Text("\(ShotMapping.speedString(s.ball_speed_mph)) mph  ·  \(ShotMapping.carryString(s.carry_yd_est)) yd  ·  \(ShotMapping.vlaString(s.vla_deg))°")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(PulseTheme.ink)
            .navigationTitle("Shots")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Refresh") { Task { await client.refresh() } }
                }
            }
            .refreshable { await client.refresh() }
        }
    }

    private func lastShotHero(_ title: String, _ value: String, _ unit: String, accent: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(PulseTheme.mute)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(accent ? PulseTheme.lime : .white)
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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
    @EnvironmentObject private var settings: PlayerSettings
    @ObservedObject private var r10 = R10Bluetooth.shared
    @ObservedObject private var oc = OpenConnectServer.shared

    private var selectedMonitor: LaunchMonitorKind {
        LaunchMonitorKind.all.first { $0.id == settings.monitorId } ?? LaunchMonitorKind.all[0]
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(oc.listening ? "OpenConnect live" : "Listener off")
                            .font(.title3.weight(.bold))
                        Text(oc.status)
                            .foregroundStyle(.secondary)
                        if oc.listening {
                            Text("In your monitor software pick GSPro / OpenConnect.\nIP \(oc.wifiAddress)   port \(oc.port)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    Toggle("Listen for launch monitors", isOn: Binding(
                        get: { oc.listening },
                        set: { on in
                            if on { oc.start() } else { oc.stop() }
                        }
                    ))
                }
                Section("Your monitor") {
                    Picker("Device", selection: $settings.monitorId) {
                        ForEach(LaunchMonitorKind.all) { m in
                            Text("\(m.brand) \(m.name)").tag(m.id)
                        }
                    }
                    Text(selectedMonitor.setup)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if selectedMonitor.ble {
                    Section("Garmin Bluetooth") {
                        Text(r10.status)
                            .foregroundStyle(.secondary)
                        Button(r10.connected ? "Disconnect R10" : "Scan & pair R10") {
                            if r10.connected { r10.stop() } else { r10.scan() }
                        }
                        .foregroundStyle(PulseTheme.ink)
                        .listRowBackground(PulseTheme.lime)
                    }
                }
                Section("You") {
                    TextField("Name", text: $settings.playerName)
                    Picker("Units", selection: $settings.units) {
                        ForEach(UnitSystem.allCases) { u in
                            Text(u.label).tag(u)
                        }
                    }
                    Picker("Hand", selection: $settings.handedness) {
                        ForEach(Handedness.allCases) { h in
                            Text(h.label).tag(h)
                        }
                    }
                    Picker("Default club", selection: $settings.defaultClub) {
                        ForEach(PulseTheme.clubs, id: \.self) { c in
                            Text(c).tag(c)
                        }
                    }
                    Picker("Default pin", selection: $settings.defaultPinYd) {
                        ForEach(PulseTheme.pins, id: \.self) { yd in
                            Text("\(Int(yd)) yd").tag(yd)
                        }
                    }
                }
                Section("Practice") {
                    Text("Range → HIT records a shot on this phone. Play → pick a course → HIT each swing.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Replay walkthrough") {
                        settings.resetOnboarding()
                    }
                    .foregroundStyle(PulseTheme.lime)
                }
            }
            .scrollContentBackground(.hidden)
            .background(PulseTheme.ink)
            .navigationTitle("Connect")
            .onAppear {
                oc.refreshAddress()
            }
        }
    }
}
