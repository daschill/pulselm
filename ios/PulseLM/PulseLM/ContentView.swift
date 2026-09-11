import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var client: MonitorClient
    @EnvironmentObject private var settings: PlayerSettings
    @State private var showHostEditor = false
    @State private var showCourses = false
    @State private var showScorecard = false
    @State private var courseQuery = ""
    @State private var pinYards: Double = PlayerSettings.shared.defaultPinYd
    @State private var cameraMode: RangeCameraMode = .auto

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                PhotorealRangeView(
                    shot: client.latest,
                    session: client.shots,
                    pinYards: pinYards,
                    cameraMode: cameraMode,
                    apexYd: client.practice?.tiles?.apex_yd,
                    hangTimeS: client.practice?.tiles?.hang_time_s,
                    totalYd: client.practice?.tiles?.total_yd_est
                )
                .ignoresSafeArea()
                VStack(spacing: 0) {
                    rangeTopBar
                    HStack(alignment: .top) {
                        Spacer(minLength: 0)
                        rangeSideRail
                    }
                    .padding(.horizontal, 12)
                    Spacer(minLength: 0)
                    rangeBottomDock
                }
                .padding(.bottom, 6)
            }
            .onChange(of: client.play?.remaining_yd) { _, new in
                if let new { pinYards = new }
            }
            .onChange(of: client.gameMode) { _, mode in
                if mode == "random" {
                    pinYards = [150, 200, 250, 300, 400].randomElement() ?? 250
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
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
                if ProcessInfo.processInfo.environment["PULSELM_AUTOHIT"] == "1" {
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    await arm()
                }
            }
            .refreshable {
                await client.refresh()
            }
        }
    }

    private var rangeTopBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("PULSELM")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(.white)
                Text(client.play?.playing == true ? playLine : "Driving range")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.mute)
                    .lineLimit(1)
            }
            Spacer()
            clubMenu
            if client.play?.playing == true {
                Button("Card") { showScorecard = true }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(PulseTheme.panel, in: Capsule())
            }
            statusDot
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private var clubMenu: some View {
        Menu {
            ForEach(PulseTheme.clubs, id: \.self) { c in
                Button(c) {
                    client.selectedClub = c
                    settings.defaultClub = c
                }
            }
        } label: {
            Text(client.selectedClub)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(PulseTheme.panel, in: Capsule())
                .overlay(Capsule().stroke(PulseTheme.stroke, lineWidth: 1))
        }
    }

    private var statusDot: some View {
        let live = client.health?.ok == true && client.health?.demo != true
        return Circle()
            .fill(live ? PulseTheme.lime : Color.orange)
            .frame(width: 9, height: 9)
            .accessibilityLabel(live ? "Live" : "Demo")
    }

    private var rangeSideRail: some View {
        VStack(alignment: .trailing, spacing: 8) {
            minimapPanel
            HStack(spacing: 8) {
                pinMenu
                cameraMenu
            }
        }
    }

    private var minimapPanel: some View {
        RangeView(
            shot: client.latest,
            session: client.shots,
            practice: client.practice,
            holeMap: client.play?.playing == true ? client.holeMap : nil,
            pinOverride: pinYards,
            minimap: true,
            selectedClub: $client.selectedClub,
            gameMode: $client.gameMode
        )
        .frame(width: 104, height: 132)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(PulseTheme.stroke, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
    }

    private var pinMenu: some View {
        Menu {
            ForEach(PulseTheme.pins, id: \.self) { yd in
                Button("\(Int(yd)) yd") {
                    pinYards = yd
                    settings.defaultPinYd = yd
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 10))
                Text("\(Int(pinYards))")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(PulseTheme.panel, in: Capsule())
            .overlay(Capsule().stroke(PulseTheme.stroke, lineWidth: 1))
        }
        .accessibilityLabel("Target \(Int(pinYards)) yards")
    }

    private var cameraMenu: some View {
        Menu {
            ForEach(RangeCameraMode.allCases) { mode in
                Button {
                    cameraMode = mode
                } label: {
                    if cameraMode == mode {
                        Label(mode.label, systemImage: "checkmark")
                    } else {
                        Text(mode.label)
                    }
                }
            }
        } label: {
            Image(systemName: "video.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(PulseTheme.panel, in: Circle())
                .overlay(Circle().stroke(PulseTheme.stroke, lineWidth: 1))
        }
        .accessibilityLabel("Camera \(cameraMode.label)")
    }

    private var rangeBottomDock: some View {
        HStack(alignment: .bottom, spacing: 10) {
            metricDock
            hitButton
        }
        .padding(.horizontal, 12)
    }

    private var metricDock: some View {
        let shot = client.latest
        let t = client.practice?.tiles
        return HStack(spacing: 0) {
            dockCell("SPEED", ShotMapping.speedString(shot?.ball_speed_mph), ShotMapping.speedUnit, accent: true)
            dockCell("CARRY", ShotMapping.carryString(shot?.carry_yd_est), ShotMapping.distUnit)
            dockCell("LAUNCH", ShotMapping.vlaString(shot?.vla_deg), "°")
            dockCell("SPIN", ShotMapping.metricString(shot?.spin_rpm, decimals: 0), "rpm")
            dockCell("HLA", ShotMapping.metricString(shot?.hla_deg, decimals: 1), "°")
            dockCell("TOTAL", t?.total_yd_est.map { ShotMapping.carryString($0) } ?? ShotMapping.carryString(shot?.total_yd_est), ShotMapping.distUnit)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(PulseTheme.panelStrong, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PulseTheme.stroke, lineWidth: 1)
        )
    }

    private func dockCell(_ title: String, _ value: String, _ unit: String, accent: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(PulseTheme.mute)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(accent ? PulseTheme.lime : .white)
                .monospacedDigit()
                .minimumScaleFactor(0.55)
                .lineLimit(1)
            Text(unit)
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
                .opacity(unit.isEmpty ? 0 : 1)
        }
        .frame(maxWidth: .infinity)
    }

    private var hitButton: some View {
        Button {
            Task { await arm() }
        } label: {
            ZStack {
                Circle().fill(PulseTheme.lime)
                if client.isBusy {
                    ProgressView().tint(PulseTheme.ink)
                } else {
                    VStack(spacing: 1) {
                        Text("HIT")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .tracking(1)
                        Text(client.selectedClub)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .opacity(0.7)
                    }
                    .foregroundStyle(PulseTheme.ink)
                }
            }
            .frame(width: 64, height: 64)
            .shadow(color: PulseTheme.lime.opacity(0.35), radius: 10, y: 4)
        }
        .disabled(client.isBusy)
        .accessibilityLabel("Hit")
        .accessibilityHint("Records a practice shot and plays ball flight")
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
            List {
                Section {
                    TextField("Search courses (bethpage, torrey…)", text: $courseQuery)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit {
                            Task { _ = try? await client.searchCourses(q: courseQuery) }
                        }
                    Button("Search") {
                        Task { _ = try? await client.searchCourses(q: courseQuery) }
                    }
                }
                if let err = client.lastError {
                    Section {
                        Text(err).font(.footnote).foregroundStyle(.orange)
                    }
                }
                Section("Courses") {
                    ForEach(client.courseResults) { c in
                        Button {
                            Task {
                                do {
                                    _ = try await client.startPlay(courseId: c.id)
                                    showCourses = false
                                } catch {
                                    client.lastError = error.localizedDescription
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(c.name ?? c.id)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text([c.city, c.state, c.type, c.par.map { "par \($0)" }].compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Play 18 holes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showCourses = false }
                }
            }
            .task {
                _ = try? await client.searchCourses(q: courseQuery)
            }
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
                Section("1. Start PulseLM on the PC") {
                    Text("In PowerShell:\npython pulselm.py --demo --r10 --host 0.0.0.0 --port 18080")
                        .font(.footnote)
                        .textSelection(.enabled)
                }
                Section("2. This phone talks to that PC") {
                    TextField("http://192.168.0.139:18080", text: $client.baseURLString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Button("Test connection") {
                        Task { await client.refresh() }
                    }
                    HStack {
                        Text("Status")
                        Spacer()
                        healthBadge
                    }
                    if let err = client.lastError {
                        Text(err).font(.footnote).foregroundStyle(.orange)
                    }
                }
                Section("3. Garmin R10") {
                    Text("Pair the R10 to the Windows PC (not this iPhone). Close Garmin Golf on the phone. The PC ingest is TCP 921 / POST /api/v1/r10. This iPhone is display only.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Connect")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showHostEditor = false
                        Task { await client.refresh() }
                    }
                }
            }
        }
    }

    private func arm() async {
        do {
            _ = try await client.arm()
            _ = try? await client.fetchShots()
            _ = try? await client.fetchSession()
            _ = try? await client.fetchPlay()
            let pin = client.play?.remaining_yd ?? client.play?.pin_yd ?? pinYards
            _ = try? await client.fetchPractice(pin: pin)
        } catch {
            client.lastError = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(MonitorClient())
        .environmentObject(PlayerSettings.shared)
}
